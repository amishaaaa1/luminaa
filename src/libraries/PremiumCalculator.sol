// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PremiumCalculator - Dynamic pricing for insurance premiums
/// @notice Calculates premiums based on pool utilization and risk factors
library PremiumCalculator {
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant BASE_PREMIUM_RATE = 200; // 2% base rate
    uint256 private constant MAX_PREMIUM_RATE = 1000; // 10% cap

    function calculatePremium(
        uint256 coverageAmount,
        uint256 utilizationRate
    ) internal pure returns (uint256 premium) {
        require(coverageAmount > 0, "Coverage must be positive");
        require(utilizationRate <= BASIS_POINTS, "Invalid utilization");

        // Start with base premium (2% of coverage)
        uint256 basePremium = (coverageAmount * BASE_PREMIUM_RATE) / BASIS_POINTS;

        // Higher utilization = higher premiums (incentivizes more LP deposits)
        uint256 utilizationMultiplier = BASIS_POINTS + (utilizationRate * 2);
        
        premium = (basePremium * utilizationMultiplier) / BASIS_POINTS;

        // Don't let premiums get too crazy
        uint256 maxPremium = (coverageAmount * MAX_PREMIUM_RATE) / BASIS_POINTS;
        if (premium > maxPremium) {
            premium = maxPremium;
        }
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
