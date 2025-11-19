// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/ChainlinkPriceOracle.sol";

contract MockAggregator {
    int256 private price;
    uint256 private timestamp;
    uint8 public decimals = 8;

    function setPrice(int256 _price) external {
        price = _price;
        timestamp = block.timestamp;
    }

    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (1, price, timestamp, timestamp, 1);
    }
}

contract ChainlinkPriceOracleTest is Test {
    ChainlinkPriceOracle public oracle;
    MockAggregator public btcFeed;
    MockAggregator public ethFeed;

    bytes32 constant BTC_MARKET = keccak256("BTC_50K");
    bytes32 constant ETH_MARKET = keccak256("ETH_3K");

    function setUp() public {
        oracle = new ChainlinkPriceOracle();
        btcFeed = new MockAggregator();
        ethFeed = new MockAggregator();

        // Set initial prices
        btcFeed.setPrice(45000e8); // $45,000
        ethFeed.setPrice(2500e8);  // $2,500
    }

    function testAddPriceFeed() public {
        oracle.addPriceFeed(BTC_MARKET, address(btcFeed));

        (address feedAddress, uint8 decimals, bool active) = oracle.getPriceFeedInfo(BTC_MARKET);
        assertEq(feedAddress, address(btcFeed));
        assertEq(decimals, 8);
        assertTrue(active);
    }

    function testCannotAddDuplicateFeed() public {
        oracle.addPriceFeed(BTC_MARKET, address(btcFeed));
        
        vm.expectRevert("Feed already exists");
        oracle.addPriceFeed(BTC_MARKET, address(btcFeed));
    }

    function testGetLatestPrice() public {
        oracle.addPriceFeed(BTC_MARKET, address(btcFeed));

        (int256 price, uint256 timestamp) = oracle.getLatestPrice(BTC_MARKET);
        assertEq(price, 45000e8);
        assertEq(timestamp, block.timestamp);
    }

    function testResolveMarketAbove() public {
        oracle.addPriceFeed(BTC_MARKET, address(btcFeed));
        btcFeed.setPrice(51000e8); // Above threshold

        oracle.resolveMarket(BTC_MARKET, 50000e8, true);

        (bool resolved, bool outcome) = oracle.getMarketOutcome(BTC_MARKET);
        assertTrue(resolved);
        assertTrue(outcome); // Price is above target
    }

    function testResolveMarketBelow() public {
        oracle.addPriceFeed(BTC_MARKET, address(btcFeed));
        btcFeed.setPrice(48000e8); // Below threshold

        oracle.resolveMarket(BTC_MARKET, 50000e8, true);

        (bool resolved, bool outcome) = oracle.getMarketOutcome(BTC_MARKET);
        assertTrue(resolved);
        assertFalse(outcome); // Price is below target
    }

    function testCannotResolveWithStalePrice() public {
        oracle.addPriceFeed(BTC_MARKET, address(btcFeed));
        
        // Move time forward 2 hours
        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert("Price too stale");
        oracle.resolveMarket(BTC_MARKET, 50000e8, true);
    }

    function testRemovePriceFeed() public {
        oracle.addPriceFeed(BTC_MARKET, address(btcFeed));
        oracle.removePriceFeed(BTC_MARKET);

        (, , bool active) = oracle.getPriceFeedInfo(BTC_MARKET);
        assertFalse(active);
    }
}
