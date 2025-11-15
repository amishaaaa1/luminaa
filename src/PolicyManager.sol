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
    }

    function createPolicy(
        address holder,
        string calldata marketId,
        uint256 coverageAmount,
        uint256 premium,
        uint256 duration
    ) external nonReentrant returns (uint256 policyId) {
        if (holder == address(0)) revert("Invalid holder");
        if (bytes(marketId).length == 0) revert("Need market ID");
        if (coverageAmount < MIN_COVERAGE || coverageAmount > MAX_COVERAGE) {
            revert("Coverage out of range");
        }
        if (duration < MIN_DURATION || duration > MAX_DURATION) {
            revert("Duration out of range");
        }

        // Check if pool has enough liquidity
        if (!pool.canCoverPolicy(coverageAmount)) revert("Pool can't cover this");

        // Make sure premium is enough
        uint256 calculatedPremium = calculatePremium(marketId, coverageAmount);
        if (premium < calculatedPremium) revert("Premium too low");

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

        // Mint policy NFT
        _safeMint(holder, policyId);

        // Transfer premium to pool
        asset.safeTransferFrom(msg.sender, address(this), premium);
        asset.approve(address(pool), premium);
        pool.collectPremium(policyId, premium);

        emit PolicyCreated(policyId, holder, marketId, coverageAmount, premium);
    }

    function claimPolicy(uint256 policyId) external nonReentrant returns (uint256 payout) {
        Policy storage policy = policies[policyId];
        
        if (policy.status != PolicyStatus.Active) revert("Policy not active");
        if (ownerOf(policyId) != msg.sender) revert("Not your policy");
        if (block.timestamp > policy.expiryTime) revert("Policy expired");

        // Check oracle for market resolution
        if (!oracle.isMarketResolved(policy.marketId)) revert("Market not resolved yet");
        
        ILuminaOracle.MarketOutcome memory outcome = oracle.getMarketOutcome(policy.marketId);
        if (!outcome.isResolved) revert("Market not resolved yet");

        // Mark as claimed and pay out
        policy.status = PolicyStatus.Claimed;
        policy.marketOutcomeHash = outcome.outcomeHash;
        payout = policy.coverageAmount;

        pool.payClaim(policyId, msg.sender, payout);

        emit PolicyClaimed(policyId, payout);
    }

    function expirePolicy(uint256 policyId) external {
        Policy storage policy = policies[policyId];
        
        if (policy.status != PolicyStatus.Active) revert("Not active");
        if (block.timestamp <= policy.expiryTime) revert("Not expired yet");

        policy.status = PolicyStatus.Expired;

        emit PolicyExpired(policyId);
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
