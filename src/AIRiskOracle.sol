// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AIRiskOracle
 * @notice ML-powered risk scoring for prediction markets
 * @dev Off-chain AI model calculates risk, on-chain oracle stores scores
 * 
 * INNOVATION: First AI-assisted premium calculation in prediction market insurance
 * 
 * Risk factors analyzed by AI:
 * - Market volatility (historical price swings)
 * - Liquidity depth (order book analysis)
 * - Time to expiry (theta decay)
 * - Sentiment analysis (social media, news)
 * - Correlation with other markets
 * - Historical accuracy of similar predictions
 * 
 * Score: 0-10000 (0% - 100% risk multiplier)
 */
contract AIRiskOracle is Ownable {
    struct RiskScore {
        uint256 score;          // 0-10000 (basis points)
        uint256 confidence;     // 0-10000 (AI model confidence)
        uint256 updatedAt;
        string modelVersion;    // e.g. "v1.2.3"
    }

    mapping(string => RiskScore) private marketRiskScores;
    mapping(address => bool) private authorizedUpdaters;

    uint256 public constant MAX_RISK_SCORE = 10000; // 100%
    uint256 public constant STALE_THRESHOLD = 1 hours;

    event RiskScoreUpdated(
        string indexed marketId,
        uint256 score,
        uint256 confidence,
        string modelVersion
    );
    event UpdaterAuthorized(address updater);
    event UpdaterRevoked(address updater);

    modifier onlyUpdater() {
        require(authorizedUpdaters[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    constructor() Ownable(msg.sender) {
        authorizedUpdaters[msg.sender] = true;
    }

    /**
     * @notice Update risk score from AI model
     * @param marketId Market identifier
     * @param score Risk score (0-10000)
     * @param confidence Model confidence (0-10000)
     * @param modelVersion AI model version
     */
    function updateRiskScore(
        string calldata marketId,
        uint256 score,
        uint256 confidence,
        string calldata modelVersion
    ) external onlyUpdater {
        require(bytes(marketId).length > 0, "Invalid market ID");
        require(score <= MAX_RISK_SCORE, "Score too high");
        require(confidence <= MAX_RISK_SCORE, "Confidence too high");
        require(bytes(modelVersion).length > 0, "Need model version");

        marketRiskScores[marketId] = RiskScore({
            score: score,
            confidence: confidence,
            updatedAt: block.timestamp,
            modelVersion: modelVersion
        });

        emit RiskScoreUpdated(marketId, score, confidence, modelVersion);
    }

    /**
     * @notice Batch update multiple markets (gas efficient)
     * @param marketIds Array of market identifiers
     * @param scores Array of risk scores
     * @param confidences Array of confidence scores
     * @param modelVersion AI model version
     */
    function batchUpdateRiskScores(
        string[] calldata marketIds,
        uint256[] calldata scores,
        uint256[] calldata confidences,
        string calldata modelVersion
    ) external onlyUpdater {
        require(marketIds.length == scores.length, "Length mismatch");
        require(marketIds.length == confidences.length, "Length mismatch");
        require(marketIds.length > 0, "Empty arrays");

        for (uint256 i = 0; i < marketIds.length; i++) {
            require(scores[i] <= MAX_RISK_SCORE, "Score too high");
            require(confidences[i] <= MAX_RISK_SCORE, "Confidence too high");

            marketRiskScores[marketIds[i]] = RiskScore({
                score: scores[i],
                confidence: confidences[i],
                updatedAt: block.timestamp,
                modelVersion: modelVersion
            });

            emit RiskScoreUpdated(marketIds[i], scores[i], confidences[i], modelVersion);
        }
    }

    /**
     * @notice Get risk score for market
     * @param marketId Market identifier
     * @return RiskScore struct
     */
    function getRiskScore(string calldata marketId) external view returns (RiskScore memory) {
        return marketRiskScores[marketId];
    }

    /**
     * @notice Check if risk score is stale
     * @param marketId Market identifier
     * @return bool True if stale
     */
    function isStale(string calldata marketId) external view returns (bool) {
        RiskScore memory risk = marketRiskScores[marketId];
        if (risk.updatedAt == 0) return true;
        return block.timestamp > risk.updatedAt + STALE_THRESHOLD;
    }

    /**
     * @notice Get adjusted premium multiplier
     * @param marketId Market identifier
     * @param baseMultiplier Base premium multiplier
     * @return uint256 Adjusted multiplier
     */
    function getAdjustedMultiplier(
        string calldata marketId,
        uint256 baseMultiplier
    ) external view returns (uint256) {
        RiskScore memory risk = marketRiskScores[marketId];
        
        // If no score or stale, return base
        if (risk.updatedAt == 0 || block.timestamp > risk.updatedAt + STALE_THRESHOLD) {
            return baseMultiplier;
        }

        // Weight by confidence: adjustedScore = score * confidence / 10000
        uint256 weightedScore = (risk.score * risk.confidence) / MAX_RISK_SCORE;

        // Apply to base: newMultiplier = base * (1 + weightedScore/10000)
        return baseMultiplier + (baseMultiplier * weightedScore) / MAX_RISK_SCORE;
    }

    /**
     * @notice Authorize AI updater address
     * @param updater Address to authorize
     */
    function authorizeUpdater(address updater) external onlyOwner {
        require(updater != address(0), "Invalid updater");
        authorizedUpdaters[updater] = true;
        emit UpdaterAuthorized(updater);
    }

    /**
     * @notice Revoke AI updater authorization
     * @param updater Address to revoke
     */
    function revokeUpdater(address updater) external onlyOwner {
        authorizedUpdaters[updater] = false;
        emit UpdaterRevoked(updater);
    }

    /**
     * @notice Check if address is authorized updater
     * @param updater Address to check
     * @return bool True if authorized
     */
    function isAuthorizedUpdater(address updater) external view returns (bool) {
        return authorizedUpdaters[updater];
    }
}
