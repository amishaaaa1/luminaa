// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {IInsurancePool} from "../src/interfaces/IInsurancePool.sol";

contract CheckPool is Script {
    function run() external view {
        address poolAddress = vm.envAddress("INSURANCE_POOL_ADDRESS");
        
        InsurancePool pool = InsurancePool(payable(poolAddress));

        // Get pool info - returns a struct
        IInsurancePool.PoolInfo memory poolInfo = pool.getPoolInfo();

        console.log("\n=== Pool Status ===");
        console.log("Total Liquidity:", poolInfo.totalLiquidity / 1e18, "USDT");
        console.log("Available Liquidity:", poolInfo.availableLiquidity / 1e18, "USDT");
        console.log("Total Premiums:", poolInfo.totalPremiums / 1e18, "USDT");
        console.log("Total Claims:", poolInfo.totalClaims / 1e18, "USDT");
        console.log("Utilization Rate:", poolInfo.utilizationRate / 100, "%");
        console.log("Is Active:", poolInfo.isActive);

        // Test coverage amounts
        uint256[] memory testAmounts = new uint256[](5);
        testAmounts[0] = 1 * 1e18;      // 1 USDT
        testAmounts[1] = 10 * 1e18;     // 10 USDT
        testAmounts[2] = 100 * 1e18;    // 100 USDT
        testAmounts[3] = 1000 * 1e18;   // 1000 USDT
        testAmounts[4] = 10000 * 1e18;  // 10000 USDT

        console.log("\n=== Coverage Tests ===");
        for (uint256 i = 0; i < testAmounts.length; i++) {
            bool canCover = pool.canCoverPolicy(testAmounts[i]);
            console.log("Can cover", testAmounts[i] / 1e18, "USDT:", canCover);
        }
    }
}
