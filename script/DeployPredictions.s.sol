// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PredictionMarket.sol";
import "../src/LuminaOracle.sol";

contract DeployPredictions is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address usdcToken = vm.envAddress("USDC_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy or use existing LuminaOracle
        address oracleAddress = vm.envOr("LUMINA_ORACLE_ADDRESS", address(0));
        
        if (oracleAddress == address(0)) {
            console.log("Deploying new LuminaOracle...");
            LuminaOracle oracle = new LuminaOracle(usdcToken, 100 * 10**18); // 100 USDC bond
            oracleAddress = address(oracle);
            console.log("LuminaOracle deployed at:", oracleAddress);
        } else {
            console.log("Using existing LuminaOracle at:", oracleAddress);
        }

        // Deploy PredictionMarket
        console.log("Deploying PredictionMarket...");
        PredictionMarket predictionMarket = new PredictionMarket(
            usdcToken,
            oracleAddress
        );

        console.log("=== Deployment Complete ===");
        console.log("PredictionMarket:", address(predictionMarket));
        console.log("LuminaOracle:", oracleAddress);
        console.log("USDC Token:", usdcToken);
        
        // Create sample markets
        console.log("\nCreating sample markets...");
        
        string[5] memory protocols = [
            "Uniswap V4",
            "Aave V3",
            "Curve Finance",
            "Lido Staked ETH",
            "Arbitrum Bridge"
        ];
        
        IPredictionMarket.RiskType[5] memory riskTypes = [
            IPredictionMarket.RiskType.Exploit,
            IPredictionMarket.RiskType.Hack,
            IPredictionMarket.RiskType.Depeg,
            IPredictionMarket.RiskType.Depeg,
            IPredictionMarket.RiskType.Hack
        ];
        
        for (uint i = 0; i < 5; i++) {
            uint256 deadline = block.timestamp + 30 days;
            uint256 marketId = predictionMarket.createMarket(
                protocols[i],
                riskTypes[i],
                deadline,
                true // insurance enabled
            );
            console.log("Created market", marketId, "for", protocols[i]);
        }

        vm.stopBroadcast();
        
        // Save addresses to .env format
        console.log("\n=== Add to .env ===");
        console.log("PREDICTION_MARKET_ADDRESS=", address(predictionMarket));
        console.log("LUMINA_ORACLE_ADDRESS=", oracleAddress);
    }
}
