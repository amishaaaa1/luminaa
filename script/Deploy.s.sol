// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {PolicyManager} from "../src/PolicyManager.sol";
import {LuminaOracle} from "../src/LuminaOracle.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address assetToken = vm.envAddress("ASSET_TOKEN"); // USDT/USDC on BNB Chain

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Oracle first (using assetToken as bond token)
        LuminaOracle oracle = new LuminaOracle(assetToken);
        console.log("Oracle deployed at:", address(oracle));

        // Deploy Policy Manager placeholder first (we'll use CREATE2 for deterministic address)
        // For simplicity, we deploy twice: once to get address, then redeploy pool
        
        // Temporary deployment to get PolicyManager address
        PolicyManager tempPolicyManager = new PolicyManager(
            assetToken,
            address(0), // temporary
            address(oracle)
        );
        address policyManagerAddress = address(tempPolicyManager);
        
        // Now deploy Insurance Pool with correct policy manager
        InsurancePool pool = new InsurancePool(assetToken, policyManagerAddress);
        console.log("Pool deployed at:", address(pool));

        // Deploy actual Policy Manager with correct pool address
        PolicyManager policyManager = new PolicyManager(
            assetToken,
            address(pool),
            address(oracle)
        );
        console.log("PolicyManager deployed at:", address(policyManager));

        // Deploy Prediction Market (native markets for Lumina)
        PredictionMarket predictionMarket = new PredictionMarket(
            assetToken,
            address(oracle)
        );
        console.log("PredictionMarket deployed at:", address(predictionMarket));

        vm.stopBroadcast();

        // Log deployment addresses
        console.log("\n=== Lumina Protocol Deployed ===");
        console.log("Oracle:", address(oracle));
        console.log("Pool:", address(pool));
        console.log("PolicyManager:", address(policyManager));
        console.log("PredictionMarket:", address(predictionMarket));
        console.log("Asset Token:", assetToken);
        console.log("\nAll contracts deployed successfully!");
        console.log("\nNext steps:");
        console.log("1. Update frontend/.env:");
        console.log("   NEXT_PUBLIC_ORACLE_ADDRESS=", address(oracle));
        console.log("   NEXT_PUBLIC_POOL_ADDRESS=", address(pool));
        console.log("   NEXT_PUBLIC_POLICY_MANAGER_ADDRESS=", address(policyManager));
        console.log("   NEXT_PUBLIC_PREDICTION_MARKET_ADDRESS=", address(predictionMarket));
        console.log("   NEXT_PUBLIC_ASSET_TOKEN=", assetToken);
        console.log("2. Update backend/.env with contract addresses");
        console.log("3. Verify contracts on BscScan");
    }
}
