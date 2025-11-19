// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PremiumCalculator - Dynamic pricing for insurance premiums
/// @notice Calculates premiums based on pool utilization and risk factors
library PremiumCalculator {
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant BASE_PREMIUM_RATE = 500; // 5% base rate (increased for sustainability)
    uint256 private constant MAX_PREMIUM_RATE = 2000; // 20% cap (increased for high-risk markets)
    uint256 private constant MIN_PREMIUM_RATE = 300; // 3% minimum
    
    // LUMINA CONCEPT: Payout rates based on risk (40-60% of coverage)
    uint256 private constant BASE_PAYOUT_RATE = 5000; // 50% base payout
    uint256 private constant MIN_PAYOUT_RATE = 4000; // 40% minimum (high risk)
    uint256 private constant MAX_PAYOUT_RATE = 6000; // 60% maximum (low risk)

    /**
     * @notice Calculate premium with sustainability checks
     * @dev Premium must ensure pool profitability: premium > expected_payout * claim_probability
     * @param coverageAmount Amount to insure
     * @param utilizationRate Pool utilization (0-10000)
     * @return premium Premium amount in tokens
     */
    function calculatePremium(
        uint256 coverageAmount,
        uint256 utilizationRate
    ) internal pure returns (uint256 premium) {
        require(coverageAmount > 0, "Coverage must be positive");
        require(utilizationRate <= BASIS_POINTS, "Invalid utilization");

        // Start with base premium (5% of coverage)
        uint256 basePremium = (coverageAmount * BASE_PREMIUM_RATE) / BASIS_POINTS;

        // Higher utilization = higher premiums (incentivizes more LP deposits)
        // Exponential curve: utilization^2 for aggressive scaling
        uint256 utilizationMultiplier = BASIS_POINTS + ((utilizationRate * utilizationRate) / BASIS_POINTS);
        
        premium = (basePremium * utilizationMultiplier) / BASIS_POINTS;

        // Enforce bounds
        uint256 minPremium = (coverageAmount * MIN_PREMIUM_RATE) / BASIS_POINTS;
        uint256 maxPremium = (coverageAmount * MAX_PREMIUM_RATE) / BASIS_POINTS;
        
        if (premium < minPremium) premium = minPremium;
        if (premium > maxPremium) premium = maxPremium;
    }
    
    /**
     * @notice Calculate payout amount based on risk score
     * @dev LUMINA CONCEPT: 40-60% payout, inversely related to risk
     * High risk = lower payout (40%), Low risk = higher payout (60%)
     * @param coverageAmount Original coverage amount
     * @param riskScore Risk score from AI (0-10000, where 10000 = 100% risk)
     * @return payout Payout amount if claim is valid
     */
    function calculatePayout(
        uint256 coverageAmount,
        uint256 riskScore
    ) internal pure returns (uint256 payout) {
        require(coverageAmount > 0, "Coverage must be positive");
        require(riskScore <= BASIS_POINTS, "Invalid risk score");
        
        // Inverse relationship: high risk = low payout
        // payoutRate = 60% - (risk * 20% / 10000)
        // Risk 0 (0%) → 60% payout
        // Risk 5000 (50%) → 50% payout
        // Risk 10000 (100%) → 40% payout
        uint256 payoutRate = MAX_PAYOUT_RATE - ((riskScore * (MAX_PAYOUT_RATE - MIN_PAYOUT_RATE)) / BASIS_POINTS);
        
        payout = (coverageAmount * payoutRate) / BASIS_POINTS;
    }
    
    /**
     * @notice Verify premium is sufficient for expected payout
     * @dev Pool sustainability check: premium should cover expected loss
     * @param premium Premium paid
     * @param coverageAmount Coverage amount
     * @param riskScore Risk score (0-10000)
     * @return isSufficient True if premium covers expected payout
     */
    function isPremiumSufficient(
        uint256 premium,
        uint256 coverageAmount,
        uint256 riskScore
    ) internal pure returns (bool isSufficient) {
        uint256 expectedPayout = calculatePayout(coverageAmount, riskScore);
        
        // Assume 30% claim probability for high-risk markets
        // Premium should be > expectedPayout * 0.3 for profitability
        uint256 expectedLoss = (expectedPayout * 3000) / BASIS_POINTS;
        
        return premium >= expectedLoss;
    }

    function calculateShareValue(
        uint256 totalLiquidity,
        uint256 totalShares
    ) internal pure returns (uint256 value) {
        // First deposit gets 1:1 ratio
        if (totalShares == 0) return 1e18;
        
        // Share value increases as premiums accumulate
        return (totalLiquidity * 1e18) / totalShares;
    }
}
