// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AIRiskOracle} from "../src/AIRiskOracle.sol";

contract AIRiskOracleTest is Test {
    AIRiskOracle public oracle;
    address public owner;
    address public updater;
    address public user;

    function setUp() public {
        owner = address(this);
        updater = makeAddr("updater");
        user = makeAddr("user");

        oracle = new AIRiskOracle();
        oracle.authorizeUpdater(updater);
    }

    function testUpdateRiskScore() public {
        vm.prank(updater);
        oracle.updateRiskScore("BTC-100K", 6500, 8500, "v1.0.0");

        AIRiskOracle.RiskScore memory score = oracle.getRiskScore("BTC-100K");
        assertEq(score.score, 6500);
        assertEq(score.confidence, 8500);
        assertEq(score.modelVersion, "v1.0.0");
    }

    function testBatchUpdate() public {
        string[] memory marketIds = new string[](3);
        marketIds[0] = "BTC-100K";
        marketIds[1] = "ETH-5K";
        marketIds[2] = "BNB-1K";

        uint256[] memory scores = new uint256[](3);
        scores[0] = 6500;
        scores[1] = 5500;
        scores[2] = 4500;

        uint256[] memory confidences = new uint256[](3);
        confidences[0] = 8500;
        confidences[1] = 9000;
        confidences[2] = 8000;

        vm.prank(updater);
        oracle.batchUpdateRiskScores(marketIds, scores, confidences, "v1.0.0");

        AIRiskOracle.RiskScore memory score1 = oracle.getRiskScore("BTC-100K");
        assertEq(score1.score, 6500);

        AIRiskOracle.RiskScore memory score2 = oracle.getRiskScore("ETH-5K");
        assertEq(score2.score, 5500);
    }

    function testGetAdjustedMultiplier() public {
        vm.prank(updater);
        oracle.updateRiskScore("BTC-100K", 6500, 8500, "v1.0.0");

        uint256 baseMultiplier = 10000; // 100%
        uint256 adjusted = oracle.getAdjustedMultiplier("BTC-100K", baseMultiplier);

        // Expected: 10000 + (10000 * (6500 * 8500 / 10000) / 10000)
        // = 10000 + (10000 * 5525 / 10000) = 15525
        assertEq(adjusted, 15525);
    }

    function testIsStale() public {
        vm.prank(updater);
        oracle.updateRiskScore("BTC-100K", 6500, 8500, "v1.0.0");

        assertFalse(oracle.isStale("BTC-100K"));

        vm.warp(block.timestamp + 2 hours);
        assertTrue(oracle.isStale("BTC-100K"));
    }

    function testUnauthorizedUpdate() public {
        vm.prank(user);
        vm.expectRevert("Not authorized");
        oracle.updateRiskScore("BTC-100K", 6500, 8500, "v1.0.0");
    }

    function testScoreTooHigh() public {
        vm.prank(updater);
        vm.expectRevert("Score too high");
        oracle.updateRiskScore("BTC-100K", 10001, 8500, "v1.0.0");
    }

    function testAuthorizeUpdater() public {
        address newUpdater = makeAddr("newUpdater");
        oracle.authorizeUpdater(newUpdater);
        assertTrue(oracle.isAuthorizedUpdater(newUpdater));
    }

    function testRevokeUpdater() public {
        oracle.revokeUpdater(updater);
        assertFalse(oracle.isAuthorizedUpdater(updater));
    }
}
