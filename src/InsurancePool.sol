// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IInsurancePool} from "./interfaces/IInsurancePool.sol";
import {PremiumCalculator} from "./libraries/PremiumCalculator.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title InsurancePool - Liquidity pool for prediction market insurance
/// @author Lumina Protocol
/// @notice LP providers deposit funds to back insurance policies and earn premiums
contract InsurancePool is IInsurancePool, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using PremiumCalculator for uint256;

    IERC20 public immutable asset;
    address public immutable policyManager;

    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant MAX_UTILIZATION = 8000; // 80%

    PoolInfo private poolInfo;
    mapping(address => ProviderInfo) private providers;
    uint256 private totalShares;

    modifier onlyPolicyManager() {
        require(msg.sender == policyManager, "Only policy manager");
        _;
    }

    bool public paused;
    address public owner;
    
    event EmergencyPause(address indexed by);
    event EmergencyUnpause(address indexed by);
    
    modifier whenNotPaused() {
        require(!paused, "Pool paused");
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _asset, address _policyManager) {
        require(_asset != address(0), "Invalid asset");
        require(_policyManager != address(0), "Invalid policy manager");
        
        asset = IERC20(_asset);
        policyManager = _policyManager;
        poolInfo.isActive = true;
        owner = msg.sender;
        paused = false;
    }
    
    // Receive BNB payments from PolicyManager
    receive() external payable {
        require(msg.sender == policyManager, "Only from PolicyManager");
        // BNB received, will be converted to USDT by pool manager
    }
    
    function emergencyPause() external onlyOwner {
        paused = true;
        poolInfo.isActive = false;
        emit EmergencyPause(msg.sender);
    }
    
    function emergencyUnpause() external onlyOwner {
        paused = false;
        poolInfo.isActive = true;
        emit EmergencyUnpause(msg.sender);
    }

    function deposit(uint256 amount) external nonReentrant whenNotPaused returns (uint256 shares) {
        if (!poolInfo.isActive) revert("Pool not active");
        if (amount == 0) revert("Cannot deposit zero");

        // Calculate how many shares to mint based on current pool value
        uint256 shareValue = PremiumCalculator.calculateShareValue(
            poolInfo.totalLiquidity,
            totalShares
        );

        shares = (amount * 1e18) / shareValue;
        if (shares == 0) revert("Deposit too small");

        // Update provider's position
        ProviderInfo storage provider = providers[msg.sender];
        provider.shares += shares;
        provider.depositedAmount += amount;
        provider.lastUpdateTime = block.timestamp;

        // Update pool state
        totalShares += shares;
        poolInfo.totalLiquidity += amount;
        poolInfo.availableLiquidity += amount;

        asset.safeTransferFrom(msg.sender, address(this), amount);

        emit LiquidityDeposited(msg.sender, amount, shares);
    }

    function withdraw(uint256 shares) external nonReentrant whenNotPaused returns (uint256 amount) {
        if (shares == 0) revert("Cannot withdraw zero");
        
        ProviderInfo storage provider = providers[msg.sender];
        if (provider.shares < shares) revert("Not enough shares");

        // Calculate withdrawal amount including earned premiums
        uint256 shareValue = PremiumCalculator.calculateShareValue(
            poolInfo.totalLiquidity,
            totalShares
        );

        amount = (shares * shareValue) / 1e18;
        if (amount > poolInfo.availableLiquidity) revert("Pool liquidity locked");

        // Burn shares and update state
        provider.shares -= shares;
        totalShares -= shares;
        poolInfo.totalLiquidity -= amount;
        poolInfo.availableLiquidity -= amount;

        asset.safeTransfer(msg.sender, amount);

        emit LiquidityWithdrawn(msg.sender, amount, shares);
    }

    function collectPremium(uint256 policyId, uint256 amount) external onlyPolicyManager whenNotPaused {
        if (amount == 0) revert("Zero premium");

        // Premiums increase pool value, benefiting all LPs
        poolInfo.totalPremiums += amount;
        poolInfo.totalLiquidity += amount;
        poolInfo.availableLiquidity += amount;

        asset.safeTransferFrom(msg.sender, address(this), amount);

        emit PremiumCollected(policyId, amount);
    }

    // For BNB payments where USDT is minted directly to pool
    function collectPremiumDirect(uint256 policyId, uint256 amount) external onlyPolicyManager whenNotPaused {
        if (amount == 0) revert("Zero premium");

        // Premiums increase pool value, benefiting all LPs
        poolInfo.totalPremiums += amount;
        poolInfo.totalLiquidity += amount;
        poolInfo.availableLiquidity += amount;

        // No transfer needed - USDT already minted to this contract

        emit PremiumCollected(policyId, amount);
    }

    function payClaim(
        uint256 policyId,
        address beneficiary,
        uint256 amount
    ) external onlyPolicyManager nonReentrant {
        if (beneficiary == address(0)) revert("Invalid beneficiary");
        if (amount == 0) revert("Zero claim");
        if (amount > poolInfo.availableLiquidity) revert("Not enough liquidity");

        // Claims reduce pool value, shared by all LPs
        poolInfo.totalClaims += amount;
        poolInfo.totalLiquidity -= amount;
        poolInfo.availableLiquidity -= amount;

        asset.safeTransfer(beneficiary, amount);

        emit ClaimPaid(policyId, beneficiary, amount);
    }

    function getPoolInfo() external view returns (PoolInfo memory) {
        PoolInfo memory info = poolInfo;
        info.utilizationRate = _calculateUtilization();
        return info;
    }

    function getProviderInfo(address provider) external view returns (ProviderInfo memory) {
        return providers[provider];
    }

    function calculateShareValue() external view returns (uint256 value) {
        return PremiumCalculator.calculateShareValue(poolInfo.totalLiquidity, totalShares);
    }

    function _calculateUtilization() private view returns (uint256 rate) {
        if (poolInfo.totalLiquidity == 0) return 0;
        
        uint256 utilized = poolInfo.totalLiquidity - poolInfo.availableLiquidity;
        rate = (utilized * BASIS_POINTS) / poolInfo.totalLiquidity;
    }

    function canCoverPolicy(uint256 coverageAmount) external view returns (bool) {
        if (coverageAmount > poolInfo.availableLiquidity) return false;
        
        // Don't let pool get over-utilized
        uint256 newUtilization = ((poolInfo.totalLiquidity - poolInfo.availableLiquidity + coverageAmount) * BASIS_POINTS) 
            / poolInfo.totalLiquidity;
        
        return newUtilization <= MAX_UTILIZATION;
    }
}
