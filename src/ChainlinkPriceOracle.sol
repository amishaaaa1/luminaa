// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ChainlinkPriceOracle
 * @notice Decentralized price oracle using Chainlink data feeds
 */
contract ChainlinkPriceOracle is Ownable {
    struct PriceFeed {
        AggregatorV3Interface feed;
        uint8 decimals;
        bool active;
    }

    // Market ID => Price Feed
    mapping(bytes32 => PriceFeed) public priceFeeds;
    
    // Market resolution data
    mapping(bytes32 => bool) public marketResolved;
    mapping(bytes32 => bool) public marketOutcome;
    
    event PriceFeedAdded(bytes32 indexed marketId, address feed);
    event PriceFeedRemoved(bytes32 indexed marketId);
    event MarketResolved(bytes32 indexed marketId, bool outcome, int256 price);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Add Chainlink price feed for a market
     * @param marketId Unique market identifier
     * @param feedAddress Chainlink aggregator address
     */
    function addPriceFeed(bytes32 marketId, address feedAddress) external onlyOwner {
        require(feedAddress != address(0), "Invalid feed address");
        require(!priceFeeds[marketId].active, "Feed already exists");

        AggregatorV3Interface feed = AggregatorV3Interface(feedAddress);
        uint8 decimals = feed.decimals();

        priceFeeds[marketId] = PriceFeed({
            feed: feed,
            decimals: decimals,
            active: true
        });

        emit PriceFeedAdded(marketId, feedAddress);
    }

    /**
     * @notice Remove price feed for a market
     */
    function removePriceFeed(bytes32 marketId) external onlyOwner {
        require(priceFeeds[marketId].active, "Feed not active");
        delete priceFeeds[marketId];
        emit PriceFeedRemoved(marketId);
    }

    /**
     * @notice Get latest price for a market
     * @return price Latest price with 8 decimals
     * @return timestamp Price update timestamp
     */
    function getLatestPrice(bytes32 marketId) public view returns (int256 price, uint256 timestamp) {
        PriceFeed memory feed = priceFeeds[marketId];
        require(feed.active, "Feed not active");

        (
            /* uint80 roundID */,
            int256 answer,
            /* uint256 startedAt */,
            uint256 updatedAt,
            /* uint80 answeredInRound */
        ) = feed.feed.latestRoundData();

        require(answer > 0, "Invalid price");
        require(updatedAt > 0, "Price not updated");

        return (answer, updatedAt);
    }

    /**
     * @notice Resolve market based on price threshold
     * @param marketId Market to resolve
     * @param targetPrice Price threshold (8 decimals)
     * @param isAbove True if checking price >= target, false for price < target
     */
    function resolveMarket(
        bytes32 marketId,
        int256 targetPrice,
        bool isAbove
    ) external onlyOwner {
        require(!marketResolved[marketId], "Already resolved");
        
        (int256 currentPrice, uint256 timestamp) = getLatestPrice(marketId);
        require(block.timestamp - timestamp < 1 hours, "Price too stale");

        bool outcome;
        if (isAbove) {
            outcome = currentPrice >= targetPrice;
        } else {
            outcome = currentPrice < targetPrice;
        }

        marketResolved[marketId] = true;
        marketOutcome[marketId] = outcome;

        emit MarketResolved(marketId, outcome, currentPrice);
    }

    /**
     * @notice Check if market is resolved and get outcome
     */
    function getMarketOutcome(bytes32 marketId) external view returns (bool resolved, bool outcome) {
        return (marketResolved[marketId], marketOutcome[marketId]);
    }

    /**
     * @notice Get price feed info
     */
    function getPriceFeedInfo(bytes32 marketId) external view returns (
        address feedAddress,
        uint8 decimals,
        bool active
    ) {
        PriceFeed memory feed = priceFeeds[marketId];
        return (address(feed.feed), feed.decimals, feed.active);
    }
}
