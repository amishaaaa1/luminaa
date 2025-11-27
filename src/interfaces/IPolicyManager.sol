// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IPolicyManager
 * @notice Interface for insurance policy management
 * @dev Handles policy creation, tracking, and NFT representation
 */
interface IPolicyManager {
    enum PolicyStatus {
        Active,
        Claimed,
        Expired,
        Cancelled
    }

    struct Policy {
        uint256 id;
        address holder;
        string marketId;
        uint256 coverageAmount;
        uint256 premium;
        uint256 startTime;
        uint256 expiryTime;
        PolicyStatus status;
        bytes32 marketOutcomeHash;
    }

    event PolicyCreated(
        uint256 indexed policyId,
        address indexed holder,
        string marketId,
        uint256 coverageAmount,
        uint256 premium
    );
    event PolicyClaimed(uint256 indexed policyId, uint256 payoutAmount);
    event PolicyExpired(uint256 indexed policyId);
    event PolicyCancelled(uint256 indexed policyId);

    function createPolicy(
        address holder,
        string calldata marketId,
        uint256 coverageAmount,
        uint256 premium,
        uint256 duration
    ) external payable returns (uint256 policyId);

    function claimPolicy(uint256 policyId) external returns (uint256 payout);
    function expirePolicy(uint256 policyId) external;
    function getPolicy(uint256 policyId) external view returns (Policy memory);
    function getUserPolicies(address user) external view returns (uint256[] memory);
    function calculatePremium(string calldata marketId, uint256 coverageAmount) external view returns (uint256);
}
