// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ILuminaOracle
 * @notice Interface for prediction market outcome verification
 * @dev Provides market data and outcome resolution for insurance claims
 */
interface ILuminaOracle {
    enum MarketStatus {
        Active,
        Resolved,
        Disputed,
        Cancelled
    }

    struct MarketOutcome {
        string marketId;
        bool isResolved;
        bytes32 outcomeHash;
        uint256 resolvedAt;
        MarketStatus status;
    }

    event MarketResolved(string indexed marketId, bytes32 outcomeHash, uint256 timestamp);
    event MarketDisputed(string indexed marketId, address indexed disputer);
    event OracleUpdated(address indexed newOracle);

    function resolveMarket(string calldata marketId, bytes32 outcomeHash) external;
    function getMarketOutcome(string calldata marketId) external view returns (MarketOutcome memory);
    function isMarketResolved(string calldata marketId) external view returns (bool);
    function verifyOutcome(string calldata marketId, bytes32 expectedOutcome) external view returns (bool);
}
