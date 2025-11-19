// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPredictionMarket {
    enum RiskType {
        Hack,
        Depeg,
        Exploit,
        Rug
    }

    enum MarketStatus {
        Active,
        Resolved,
        Cancelled
    }

    enum Outcome {
        Unresolved,
        Yes,
        No
    }

    event MarketCreated(
        uint256 indexed marketId,
        string protocol,
        RiskType riskType,
        uint256 deadline,
        address creator
    );

    event PredictionPlaced(
        uint256 indexed marketId,
        address indexed user,
        Outcome prediction,
        uint256 amount
    );

    event MarketResolved(
        uint256 indexed marketId,
        Outcome outcome,
        uint256 timestamp
    );

    event WinningsClaimed(
        uint256 indexed marketId,
        address indexed user,
        uint256 amount
    );

    function createMarket(
        string memory protocol,
        RiskType riskType,
        uint256 deadline,
        bool insuranceEnabled
    ) external returns (uint256);

    function placePrediction(
        uint256 marketId,
        Outcome prediction,
        uint256 amount
    ) external;

    function resolveMarket(uint256 marketId) external;

    function claimWinnings(uint256 marketId) external;

    function calculatePayout(uint256 marketId, address user) external view returns (uint256);

    function getMarketOdds(uint256 marketId) external view returns (uint256 yesOdds, uint256 noOdds);

    function getMarket(uint256 marketId) external view returns (
        uint256 id,
        string memory protocol,
        RiskType riskType,
        uint256 deadline,
        uint256 resolutionTime,
        MarketStatus status,
        Outcome outcome,
        uint256 yesPool,
        uint256 noPool,
        uint256 totalVolume,
        address creator,
        bool insuranceEnabled
    );

    function getUserPosition(uint256 marketId, address user) external view returns (
        uint256 yesAmount,
        uint256 noAmount,
        bool claimed
    );
}
