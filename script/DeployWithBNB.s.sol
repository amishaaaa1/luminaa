// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PolicyManager} from "../src/PolicyManager.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {MockUSDT} from "../src/MockUSDT.sol";
import {LuminaOracle} from "../src/LuminaOracle.sol";

contract DeployWithBNB is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockUSDT
        MockUSDT usdt = new MockUSDT();
        console.log("MockUSDT deployed at:", address(usdt));

        // Deploy LuminaOracle (with bond token = USDT)
        LuminaOracle oracle = new LuminaOracle(address(usdt));
        console.log("LuminaOracle deployed at:", address(oracle));

        // Calculate future PolicyManager address (deterministic)
        address futurePoolAddress = vm.computeCreateAddress(vm.addr(deployerPrivateKey), vm.getNonce(vm.addr(deployerPrivateKey)) + 1);
        
        // Deploy InsurancePool (with future PolicyManager address)
        InsurancePool pool = new InsurancePool(address(usdt), futurePoolAddress);
        console.log("InsurancePool deployed at:", address(pool));

        // Deploy PolicyManager (with payable support)
        PolicyManager policyManager = new PolicyManager(
            address(usdt),
            address(pool),
            address(oracle)
        );
        console.log("PolicyManager deployed at:", address(policyManager));

        // Add initial liquidity to pool (100,000 USDT)
        uint256 initialLiquidity = 100_000 * 1e18;
        usdt.mint(msg.sender, initialLiquidity);
        console.log("Minted initial liquidity:", initialLiquidity);
        
        usdt.approve(address(pool), initialLiquidity);
        uint256 shares = pool.deposit(initialLiquidity);
        console.log("Deposited liquidity, received shares:", shares);

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("USDT:", address(usdt));
        console.log("Oracle:", address(oracle));
        console.log("Pool:", address(pool));
        console.log("PolicyManager:", address(policyManager));
        console.log("\n=== Initial Liquidity ===");
        console.log("Amount: 100,000 USDT");
        console.log("Shares:", shares);
        console.log("\nUpdate your .env with these addresses!");
    }
}
