// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {LuminaOracle} from "../src/LuminaOracle.sol";
import {ILuminaOracle} from "../src/interfaces/ILuminaOracle.sol";

contract LuminaOracleTest is Test {
    LuminaOracle public oracle;

    address public owner;
    address public resolver = makeAddr("resolver");
    address public unauthorized = makeAddr("unauthorized");

    function setUp() public {
        owner = address(this);
        oracle = new LuminaOracle();
        oracle.addResolver(resolver);
    }

    function testResolveMarket() public {
        string memory marketId = "btc-100k";
        bytes32 outcomeHash = keccak256("yes");

        vm.prank(resolver);
        oracle.resolveMarket(marketId, outcomeHash);

        ILuminaOracle.MarketOutcome memory outcome = oracle.getMarketOutcome(
            marketId
        );

        assertTrue(outcome.isResolved, "Market should be resolved");
        assertEq(outcome.outcomeHash, outcomeHash, "Outcome hash mismatch");
        assertEq(outcome.resolvedAt, block.timestamp, "Timestamp mismatch");
    }

    function testCannotResolveMarketTwice() public {
        string memory marketId = "btc-100k";
        bytes32 outcomeHash = keccak256("yes");

        vm.startPrank(resolver);
        oracle.resolveMarket(marketId, outcomeHash);

        vm.expectRevert("Already resolved");
        oracle.resolveMarket(marketId, keccak256("no"));
        vm.stopPrank();
    }

    function testUnauthorizedCannotResolve() public {
        string memory marketId = "btc-100k";
        bytes32 outcomeHash = keccak256("yes");

        vm.prank(unauthorized);
        vm.expectRevert("Not authorized");
        oracle.resolveMarket(marketId, outcomeHash);
    }

    function testOwnerCanResolve() public {
        string memory marketId = "btc-100k";
        bytes32 outcomeHash = keccak256("yes");

        oracle.resolveMarket(marketId, outcomeHash);

        assertTrue(
            oracle.isMarketResolved(marketId),
            "Market should be resolved"
        );
    }

    function testAddResolver() public {
        address newResolver = makeAddr("newResolver");

        oracle.addResolver(newResolver);

        assertTrue(
            oracle.isResolver(newResolver),
            "Should be authorized resolver"
        );
    }

    function testRemoveResolver() public {
        oracle.removeResolver(resolver);

        assertFalse(oracle.isResolver(resolver), "Should not be authorized");

        vm.prank(resolver);
        vm.expectRevert("Not authorized");
        oracle.resolveMarket("test", keccak256("outcome"));
    }

    function testVerifyOutcome() public {
        string memory marketId = "btc-100k";
        bytes32 outcomeHash = keccak256("yes");

        vm.prank(resolver);
        oracle.resolveMarket(marketId, outcomeHash);

        assertTrue(
            oracle.verifyOutcome(marketId, outcomeHash),
            "Should verify correct outcome"
        );

        assertFalse(
            oracle.verifyOutcome(marketId, keccak256("no")),
            "Should not verify wrong outcome"
        );
    }

    function testIsMarketResolved() public {
        string memory marketId = "btc-100k";

        assertFalse(
            oracle.isMarketResolved(marketId),
            "Should not be resolved yet"
        );

        vm.prank(resolver);
        oracle.resolveMarket(marketId, keccak256("yes"));

        assertTrue(oracle.isMarketResolved(marketId), "Should be resolved");
    }

    function testGetMarketOutcome() public {
        string memory marketId = "btc-100k";
        bytes32 outcomeHash = keccak256("yes");

        vm.prank(resolver);
        oracle.resolveMarket(marketId, outcomeHash);

        ILuminaOracle.MarketOutcome memory outcome = oracle.getMarketOutcome(
            marketId
        );

        assertEq(outcome.marketId, marketId, "Market ID mismatch");
        assertTrue(outcome.isResolved, "Should be resolved");
        assertEq(outcome.outcomeHash, outcomeHash, "Outcome hash mismatch");
        assertEq(
            uint8(outcome.status),
            uint8(ILuminaOracle.MarketStatus.Resolved),
            "Status should be Resolved"
        );
    }
}
