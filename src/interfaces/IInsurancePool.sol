// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IInsurancePool
 * @notice Interface for insurance pool operations
 * @dev Defines core functionality for liquidity provision and claims
 */
interface IInsurancePool {
    struct PoolInfo {
        uint256 totalLiquidity;
        uint256 availableLiquidity;
        uint256 totalPremiums;
        uint256 totalClaims;
        uint256 utilizationRate;
        bool isActive;
    }

    struct ProviderInfo {
        uint256 shares;
        uint256 depositedAmount;
        uint256 earnedPremiums;
        uint256 lastUpdateTime;
    }

    event LiquidityDeposited(address indexed provider, uint256 amount, uint256 shares);
    event LiquidityWithdrawn(address indexed provider, uint256 amount, uint256 shares);
    event PremiumCollected(uint256 indexed policyId, uint256 amount);
    event ClaimPaid(uint256 indexed policyId, address indexed beneficiary, uint256 amount);
    event PoolStatusChanged(bool isActive);

    function deposit(uint256 amount) external returns (uint256 shares);
    function withdraw(uint256 shares) external returns (uint256 amount);
    function collectPremium(uint256 policyId, uint256 amount) external;
    function payClaim(uint256 policyId, address beneficiary, uint256 amount) external;
    function getPoolInfo() external view returns (PoolInfo memory);
    function getProviderInfo(address provider) external view returns (ProviderInfo memory);
    function calculateShareValue() external view returns (uint256);
}
