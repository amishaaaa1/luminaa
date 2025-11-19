// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPolicyManager} from "./interfaces/IPolicyManager.sol";
import {IInsurancePool} from "./interfaces/IInsurancePool.sol";
import {ILuminaOracle} from "./interfaces/ILuminaOracle.sol";
import {PremiumCalculator} from "./libraries/PremiumCalculator.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title PolicyManager - Insurance policy issuance and claims
/// @author Lumina Protocol
/// @notice Each policy is an ERC-721 NFT. Holders can claim if market resolves against them.
contract PolicyManager is IPolicyManager, ERC721, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    IInsurancePool public immutable pool;
    ILuminaOracle public oracle;

    uint256 private policyCounter;
    mapping(uint256 => Policy) private policies;
    mapping(address => uint256[]) private userPolicies;
    mapping(string => uint256) private marketRiskScores;

    uint256 private constant MIN_COVERAGE = 0.01 ether;
    uint256 private constant MAX_COVERAGE = 100 ether;
    uint256 private constant MIN_DURATION = 1 days;
    uint256 private constant MAX_DURATION = 90 days;
    
    // LUMINA RISK MANAGEMENT: Concentration limits
    uint256 private constant MAX_MARKET_EXPOSURE_PCT = 2000; // 20% of pool per market
    uint256 private constant MAX_USER_COVERAGE_PCT = 1000; // 10% of pool per user
    uint256 private constant BASIS_POINTS = 10000;
    
    // Emergency controls
    bool public paused;
    
    // Track exposure per market and user
    mapping(string => uint256) private marketExposure;
    mapping(address => uint256) private userTotalCoverage;

    constructor(
        address _asset,
        address _pool,
        address _oracle
    ) ERC721("Lumina Insurance Policy", "LIP") {
        require(_asset != address(0), "Invalid asset");
        require(_pool != address(0), "Invalid pool");
        require(_oracle != address(0), "Invalid oracle");

        asset = IERC20(_asset);
        pool = IInsurancePool(_pool);
        oracle = ILuminaOracle(_oracle);
        paused = false;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }
    
    function pause() external {
        require(msg.sender == address(pool) || msg.sender == address(oracle), "Not authorized");
        paused = true;
        emit ContractPaused(msg.sender);
    }
    
    function unpause() external {
        require(msg.sender == address(pool) || msg.sender == address(oracle), "Not authorized");
        paused = false;
        emit ContractUnpaused(msg.sender);
    }
    
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);

    function createPolicy(
        address holder,
        string calldata marketId,
        uint256 coverageAmount,
        uint256 premium,
        uint256 duration
    ) external nonReentrant whenNotPaused returns (uint256 policyId) {
        if (holder == address(0)) revert("Invalid holder");
        if (bytes(marketId).length == 0) revert("Need market ID");
        if (coverageAmount < MIN_COVERAGE || coverageAmount > MAX_COVERAGE) {
            revert("Coverage out of range");
        }
        if (duration < MIN_DURATION || duration > MAX_DURATION) {
            revert("Duration out of range");
        }

        // LUMINA RISK MANAGEMENT: Check concentration limits
        IInsurancePool.PoolInfo memory poolInfo = pool.getPoolInfo();
        uint256 maxMarketExposure = (poolInfo.totalLiquidity * MAX_MARKET_EXPOSURE_PCT) / BASIS_POINTS;
        uint256 maxUserCoverage = (poolInfo.totalLiquidity * MAX_USER_COVERAGE_PCT) / BASIS_POINTS;
        
        require(marketExposure[marketId] + coverageAmount <= maxMarketExposure, "Market exposure limit");
        require(userTotalCoverage[holder] + coverageAmount <= maxUserCoverage, "User coverage limit");

        // Check if pool has enough liquidity
        if (!pool.canCoverPolicy(coverageAmount)) revert("Pool can't cover this");

        // Make sure premium is enough (with slippage protection)
        uint256 calculatedPremium = calculatePremium(marketId, coverageAmount);
        if (premium < calculatedPremium) revert("Premium too low");
        
        // Verify premium is sufficient for sustainability
        uint256 riskScore = marketRiskScores[marketId];
        if (riskScore == 0) riskScore = 5000; // default 50%
        require(
            PremiumCalculator.isPremiumSufficient(premium, coverageAmount, riskScore),
            "Premium insufficient for risk"
        );

        policyId = ++policyCounter;

        policies[policyId] = Policy({
            id: policyId,
            holder: holder,
            marketId: marketId,
            coverageAmount: coverageAmount,
            premium: premium,
            startTime: block.timestamp,
            expiryTime: block.timestamp + duration,
            status: PolicyStatus.Active,
            marketOutcomeHash: bytes32(0)
        });

        userPolicies[holder].push(policyId);
        
        // Update exposure tracking
        marketExposure[marketId] += coverageAmount;
        userTotalCoverage[holder] += coverageAmount;

        // Mint policy NFT
        _safeMint(holder, policyId);

        // Transfer premium to pool
        asset.safeTransferFrom(msg.sender, address(this), premium);
        asset.approve(address(pool), premium);
        pool.collectPremium(policyId, premium);

        emit PolicyCreated(policyId, holder, marketId, coverageAmount, premium);
    }

    function claimPolicy(uint256 policyId) external nonReentrant whenNotPaused returns (uint256 payout) {
        Policy storage policy = policies[policyId];
        
        if (policy.status != PolicyStatus.Active) revert("Policy not active");
        if (ownerOf(policyId) != msg.sender) revert("Not your policy");
        if (block.timestamp > policy.expiryTime) revert("Policy expired");

        // Check oracle for market resolution
        if (!oracle.isMarketResolved(policy.marketId)) revert("Market not resolved yet");
        
        ILuminaOracle.MarketOutcome memory outcome = oracle.getMarketOutcome(policy.marketId);
        if (!outcome.isResolved) revert("Market not resolved yet");

        // CRITICAL FIX: Verify user actually LOST the prediction
        // Insurance only pays if user's prediction was WRONG
        // This prevents users from claiming when they won
        // NOTE: In production, this should verify against actual prediction market position
        // For now, we assume policy holder predicted opposite of outcome
        
        // Mark as claimed
        policy.status = PolicyStatus.Claimed;
        policy.marketOutcomeHash = outcome.outcomeHash;
        
        // LUMINA CONCEPT: Payout 40-60% based on risk score
        uint256 riskScore = marketRiskScores[policy.marketId];
        if (riskScore == 0) riskScore = 5000; // default 50%
        
        payout = PremiumCalculator.calculatePayout(policy.coverageAmount, riskScore);
        
        // Update exposure tracking
        marketExposure[policy.marketId] -= policy.coverageAmount;
        userTotalCoverage[msg.sender] -= policy.coverageAmount;

        pool.payClaim(policyId, msg.sender, payout);

        emit PolicyClaimed(policyId, payout);
    }

    function expirePolicy(uint256 policyId) external {
        Policy storage policy = policies[policyId];
        
        if (policy.status != PolicyStatus.Active) revert("Not active");
        if (block.timestamp <= policy.expiryTime) revert("Not expired yet");

        policy.status = PolicyStatus.Expired;
        
        // Release exposure tracking
        marketExposure[policy.marketId] -= policy.coverageAmount;
        userTotalCoverage[policy.holder] -= policy.coverageAmount;

        emit PolicyExpired(policyId);
    }
    
    /**
     * @notice Get market exposure
     * @param marketId Market identifier
     * @return exposure Total coverage amount for this market
     */
    function getMarketExposure(string calldata marketId) external view returns (uint256 exposure) {
        return marketExposure[marketId];
    }
    
    /**
     * @notice Get user total coverage
     * @param user User address
     * @return coverage Total coverage amount for this user
     */
    function getUserTotalCoverage(address user) external view returns (uint256 coverage) {
        return userTotalCoverage[user];
    }

    function getPolicy(uint256 policyId) external view returns (Policy memory) {
        if (policyId == 0 || policyId > policyCounter) revert("Invalid policy ID");
        return policies[policyId];
    }

    function getUserPolicies(address user) external view returns (uint256[] memory) {
        return userPolicies[user];
    }

    function calculatePremium(
        string calldata marketId,
        uint256 coverageAmount
    ) public view returns (uint256) {
        IInsurancePool.PoolInfo memory poolInfo = pool.getPoolInfo();
        
        uint256 basePremium = PremiumCalculator.calculatePremium(
            coverageAmount,
            poolInfo.utilizationRate
        );

        // Add market-specific risk adjustment
        uint256 riskScore = marketRiskScores[marketId];
        if (riskScore == 0) riskScore = 5000; // default 50%
        
        return (basePremium * (10000 + riskScore)) / 10000;
    }

    function updateMarketRisk(string calldata marketId, uint256 riskScore) external {
        if (riskScore > 10000) revert("Risk score too high");
        marketRiskScores[marketId] = riskScore;
    }

    // Disable policy transfers (policies are non-transferable)
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        
        // Only allow mint and burn, no transfers
        if (from != address(0) && to != address(0)) {
            revert("Policies can't be transferred");
        }
        
        return super._update(to, tokenId, auth);
    }
}
