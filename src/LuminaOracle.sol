// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ILuminaOracle} from "./interfaces/ILuminaOracle.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LuminaOracle
 * @notice Oracle for prediction market outcome verification
 * @dev Centralized oracle for MVP, can be upgraded to decentralized solution
 */
contract LuminaOracle is ILuminaOracle, Ownable {
    mapping(string => MarketOutcome) private marketOutcomes;
    mapping(address => bool) private authorizedResolvers;

    modifier onlyResolver() {
        require(authorizedResolvers[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    constructor() Ownable(msg.sender) {
        authorizedResolvers[msg.sender] = true;
    }

    /**
     * @notice Resolve prediction market outcome
     * @param marketId Market identifier
     * @param outcomeHash Hash of the outcome data
     */
    function resolveMarket(
        string calldata marketId,
        bytes32 outcomeHash
    ) external onlyResolver {
        require(bytes(marketId).length > 0, "Invalid market ID");
        require(outcomeHash != bytes32(0), "Invalid outcome hash");
        require(!marketOutcomes[marketId].isResolved, "Already resolved");

        marketOutcomes[marketId] = MarketOutcome({
            marketId: marketId,
            isResolved: true,
            outcomeHash: outcomeHash,
            resolvedAt: block.timestamp,
            status: MarketStatus.Resolved
        });

        emit MarketResolved(marketId, outcomeHash, block.timestamp);
    }

    /**
     * @notice Get market outcome details
     * @param marketId Market identifier
     * @return MarketOutcome struct
     */
    function getMarketOutcome(
        string calldata marketId
    ) external view returns (MarketOutcome memory) {
        return marketOutcomes[marketId];
    }

    /**
     * @notice Check if market is resolved
     * @param marketId Market identifier
     * @return bool True if resolved
     */
    function isMarketResolved(string calldata marketId) external view returns (bool) {
        return marketOutcomes[marketId].isResolved;
    }

    /**
     * @notice Verify outcome matches expected value
     * @param marketId Market identifier
     * @param expectedOutcome Expected outcome hash
     * @return bool True if matches
     */
    function verifyOutcome(
        string calldata marketId,
        bytes32 expectedOutcome
    ) external view returns (bool) {
        MarketOutcome memory outcome = marketOutcomes[marketId];
        return outcome.isResolved && outcome.outcomeHash == expectedOutcome;
    }

    /**
     * @notice Add authorized resolver
     * @param resolver Resolver address
     */
    function addResolver(address resolver) external onlyOwner {
        require(resolver != address(0), "Invalid resolver");
        authorizedResolvers[resolver] = true;
    }

    /**
     * @notice Remove authorized resolver
     * @param resolver Resolver address
     */
    function removeResolver(address resolver) external onlyOwner {
        authorizedResolvers[resolver] = false;
    }

    /**
     * @notice Check if address is authorized resolver
     * @param resolver Address to check
     * @return bool True if authorized
     */
    function isResolver(address resolver) external view returns (bool) {
        return authorizedResolvers[resolver];
    }
}
