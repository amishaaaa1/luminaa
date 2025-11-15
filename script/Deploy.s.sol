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

        // Deploy Oracle first
        LuminaOracle oracle = new LuminaOracle();
        console.log("Oracle deployed at:", address(oracle));

        // Deploy Insurance Pool with deployer as temporary policy manager
        // We'll transfer control after PolicyManager is deployed
        InsurancePool pool = new InsurancePool(assetToken, msg.sender);
        console.log("Pool deployed at:", address(pool));

        // Deploy Policy Manager
        PolicyManager policyManager = new PolicyManager(
            assetToken,
            address(pool),
            address(oracle)
        );
        console.log("PolicyManager deployed at:", address(policyManager));

        // Note: In production, you would need to:
        // 1. Make InsurancePool upgradeable, OR
        // 2. Add a setPolicyManager() function with onlyOwner, OR
        // 3. Redeploy pool with correct policy manager address
        
        // For now, pool accepts calls from deployer (msg.sender)
        // You'll need to manually update this or redeploy

        vm.stopBroadcast();

        // Log deployment addresses
        console.log("\n=== Deployment Complete ===");
        console.log("Oracle:", address(oracle));
        console.log("Pool:", address(pool));
        console.log("PolicyManager:", address(policyManager));
        console.log("Asset Token:", assetToken);
        console.log("\nWARNING: Pool's policyManager is set to deployer");
        console.log("You may need to redeploy pool with PolicyManager address");
    }
}
