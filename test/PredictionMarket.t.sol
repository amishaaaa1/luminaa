// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";
import {LuminaOracle} from "../src/LuminaOracle.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract PredictionMarketTest is Test {
    PredictionMarket public market;
    LuminaOracle public oracle;
    MockERC20 public asset;
    
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant INITIAL_BALANCE = 100000 ether;
    uint256 constant INITIAL_LIQUIDITY = 10000 ether;

    function setUp() public {
        vm.startPrank(owner);
        
        asset = new MockERC20("Test USDC", "USDC");
        oracle = new LuminaOracle(address(asset));
        market = new PredictionMarket(address(asset), address(oracle));

        // Mint tokens
        asset.mint(owner, INITIAL_BALANCE);
        asset.mint(alice, INITIAL_BALANCE);
        asset.mint(bob, INITIAL_BALANCE);
        
        vm.stopPrank();
    }

    function testCreateMarket() public {
        vm.startPrank(owner);
        
        asset.approve(address(market), INITIAL_LIQUIDITY * 2);
        
        uint256 marketId = market.createMarket(
            "Will Uniswap V4 be exploited?",
            "Uniswap V4",
            "Exploit",
            30 days,
            INITIAL_LIQUIDITY,
            true
        );

        assertEq(marketId, 1, "Market ID should be 1");
        
        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(m.yesPool, INITIAL_LIQUIDITY, "Yes pool mismatch");
        assertEq(m.noPool, INITIAL_LIQUIDITY, "No pool mismatch");
        assertTrue(m.insuranceEnabled, "Insurance should be enabled");
        
        vm.stopPrank();
    }

    function testPlaceBet() public {
        // Create market
        vm.startPrank(owner);
        asset.approve(address(market), INITIAL_LIQUIDITY * 2);
        uint256 marketId = market.createMarket(
            "Will Uniswap V4 be exploited?",
            "Uniswap V4",
            "Exploit",
            30 days,
            INITIAL_LIQUIDITY,
            true
        );
        vm.stopPrank();

        // Alice bets YES
        vm.startPrank(alice);
        uint256 betAmount = 100 ether;
        asset.approve(address(market), betAmount);
        
        uint256 shares = market.placeBet(marketId, true, betAmount);
        assertGt(shares, 0, "Should receive shares");
        
        PredictionMarket.Position memory position = market.getPosition(marketId, alice);
        assertEq(position.yesAmount, shares, "Position mismatch");
        
        vm.stopPrank();
    }

    function testCalculatePayout() public {
        // Create market
        vm.startPrank(owner);
        asset.approve(address(market), INITIAL_LIQUIDITY * 2);
        uint256 marketId = market.createMarket(
            "Will Uniswap V4 be exploited?",
            "Uniswap V4",
            "Exploit",
            30 days,
            INITIAL_LIQUIDITY,
            true
        );
        vm.stopPrank();

        uint256 betAmount = 100 ether;
        (uint256 shares, uint256 payout) = market.calculatePayout(marketId, true, betAmount);
        
        assertGt(shares, 0, "Shares should be positive");
        assertGt(payout, betAmount, "Payout should be greater than bet");
    }

    function testGetOdds() public {
        // Create market
        vm.startPrank(owner);
        asset.approve(address(market), INITIAL_LIQUIDITY * 2);
        uint256 marketId = market.createMarket(
            "Will Uniswap V4 be exploited?",
            "Uniswap V4",
            "Exploit",
            30 days,
            INITIAL_LIQUIDITY,
            true
        );
        vm.stopPrank();

        (uint256 yesOdds, uint256 noOdds) = market.getOdds(marketId);
        
        // Initial odds should be 50/50
        assertEq(yesOdds, 5000, "Yes odds should be 50%");
        assertEq(noOdds, 5000, "No odds should be 50%");
    }

    function testCannotBetAfterDeadline() public {
        // Create market with short duration
        vm.startPrank(owner);
        asset.approve(address(market), INITIAL_LIQUIDITY * 2);
        uint256 marketId = market.createMarket(
            "Will Uniswap V4 be exploited?",
            "Uniswap V4",
            "Exploit",
            1 days,
            INITIAL_LIQUIDITY,
            true
        );
        vm.stopPrank();

        // Fast forward past deadline
        vm.warp(block.timestamp + 2 days);

        // Try to bet
        vm.startPrank(alice);
        uint256 betAmount = 100 ether;
        asset.approve(address(market), betAmount);
        
        vm.expectRevert("Market closed");
        market.placeBet(marketId, true, betAmount);
        
        vm.stopPrank();
    }

    function testMinMaxBetLimits() public {
        // Create market
        vm.startPrank(owner);
        asset.approve(address(market), INITIAL_LIQUIDITY * 2);
        uint256 marketId = market.createMarket(
            "Will Uniswap V4 be exploited?",
            "Uniswap V4",
            "Exploit",
            30 days,
            INITIAL_LIQUIDITY,
            true
        );
        vm.stopPrank();

        vm.startPrank(alice);
        
        // Test minimum bet
        asset.approve(address(market), 0.5 ether);
        vm.expectRevert("Invalid amount");
        market.placeBet(marketId, true, 0.5 ether);
        
        // Test maximum bet
        asset.approve(address(market), 20000 ether);
        vm.expectRevert("Invalid amount");
        market.placeBet(marketId, true, 20000 ether);
        
        vm.stopPrank();
    }
}
