// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/LuminaOracle.sol";

/**
 * @title SetupMarkets
 * @notice Script to setup sample markets for demo
 */
contract SetupMarkets is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracleAddress = vm.envAddress("LUMINA_ORACLE_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        LuminaOracle oracle = LuminaOracle(oracleAddress);

        // Add sample markets
        string memory btcMarket = "BTC > $70K by EOY";
        string memory ethMarket = "ETH > $5K by Q1 2025";
        string memory trumpMarket = "Trump wins 2024";

        // Note: LuminaOracle uses optimistic resolution, no need to pre-register markets
        // Markets are created when first proposal is made via proposeOutcome()
        console.log("Sample Market IDs:");
        console.log("1. BTC Market:", btcMarket);
        console.log("2. ETH Market:", ethMarket);
        console.log("3. Trump Market:", trumpMarket);

        console.log("\nOracle Address:", address(oracle));
        console.log("Markets ready for use!");
        console.log("\nNote: Markets will be created when first policy is purchased");

        vm.stopBroadcast();
    }
}
