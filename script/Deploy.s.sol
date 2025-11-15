// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {PolicyManager} from "../src/PolicyManager.sol";
import {LuminaOracle} from "../src/LuminaOracle.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address assetToken = vm.envAddress("ASSET_TOKEN"); // USDT/USDC on BNB Chain

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Oracle
        LuminaOracle oracle = new LuminaOracle();
        console.log("Oracle deployed at:", address(oracle));

        // Deploy Insurance Pool (placeholder for policy manager)
        InsurancePool pool = new InsurancePool(assetToken, address(0));
        console.log("Pool deployed at:", address(pool));

        // Deploy Policy Manager
        PolicyManager policyManager = new PolicyManager(
            assetToken,
            address(pool),
            address(oracle)
        );
        console.log("PolicyManager deployed at:", address(policyManager));

        // Update pool with policy manager address (requires pool upgrade or setter)
        // Note: In production, use upgradeable pattern or deploy in correct order

        vm.stopBroadcast();

        // Log deployment addresses
        console.log("\n=== Deployment Complete ===");
        console.log("Oracle:", address(oracle));
        console.log("Pool:", address(pool));
        console.log("PolicyManager:", address(policyManager));
        console.log("Asset Token:", assetToken);
    }
}
