// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

/// @title Verify Contracts Script
/// @notice Helper script to verify deployed contracts on BscScan
contract VerifyContractsScript is Script {
    function run() external view {
        address assetToken = vm.envAddress("ASSET_TOKEN");
        
        // Deployed addresses
        address oracle = 0x14Fbdc2af23834356529e69BDA10fE4D22Fe9071;
        address pool = 0x73B988b8308e50f515EA25f4673070eB480889C1;
        address policyManager = 0xc03fc0366D91Ea1E3Eb0F92bcc20C78F988D370C;

        console.log("=== Verify Commands ===\n");
        
        console.log("1. Verify Oracle:");
        console.log("forge verify-contract \\");
        console.log("  --chain-id 97 \\");
        console.log("  --num-of-optimizations 200 \\");
        console.log("  --watch \\");
        console.log("  --constructor-args $(cast abi-encode \"constructor(address)\" %s) \\", assetToken);
        console.log("  --etherscan-api-key $BSCSCAN_API_KEY \\");
        console.log("  --compiler-version v0.8.24+commit.e11b9ed9 \\");
        console.log("  %s \\", oracle);
        console.log("  src/LuminaOracle.sol:LuminaOracle\n");

        console.log("2. Verify Pool:");
        console.log("forge verify-contract \\");
        console.log("  --chain-id 97 \\");
        console.log("  --num-of-optimizations 200 \\");
        console.log("  --watch \\");
        console.log("  --constructor-args $(cast abi-encode \"constructor(address,address)\" %s %s) \\", assetToken, policyManager);
        console.log("  --etherscan-api-key $BSCSCAN_API_KEY \\");
        console.log("  --compiler-version v0.8.24+commit.e11b9ed9 \\");
        console.log("  %s \\", pool);
        console.log("  src/InsurancePool.sol:InsurancePool\n");

        console.log("3. Verify PolicyManager:");
        console.log("forge verify-contract \\");
        console.log("  --chain-id 97 \\");
        console.log("  --num-of-optimizations 200 \\");
        console.log("  --watch \\");
        console.log("  --constructor-args $(cast abi-encode \"constructor(address,address,address)\" %s %s %s) \\", assetToken, pool, oracle);
        console.log("  --etherscan-api-key $BSCSCAN_API_KEY \\");
        console.log("  --compiler-version v0.8.24+commit.e11b9ed9 \\");
        console.log("  %s \\", policyManager);
        console.log("  src/PolicyManager.sol:PolicyManager\n");
    }
}
