// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {MockUSDT} from "../src/MockUSDT.sol";

contract AddLiquidity is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address payable poolAddress = payable(vm.envAddress("INSURANCE_POOL_ADDRESS"));
        address usdtAddress = vm.envAddress("ASSET_TOKEN");
        
        vm.startBroadcast(deployerPrivateKey);

        MockUSDT usdt = MockUSDT(usdtAddress);
        InsurancePool pool = InsurancePool(poolAddress);

        // Mint 100,000 USDT to deployer
        uint256 liquidityAmount = 100_000 * 1e18;
        usdt.mint(msg.sender, liquidityAmount);
        console.log("Minted USDT:", liquidityAmount);

        // Approve pool to spend USDT
        usdt.approve(address(pool), liquidityAmount);
        console.log("Approved pool to spend USDT");

        // Deposit liquidity
        uint256 shares = pool.deposit(liquidityAmount);
        console.log("Deposited liquidity, received shares:", shares);

        vm.stopBroadcast();

        console.log("\n=== Liquidity Added ===");
        console.log("Amount:", liquidityAmount / 1e18, "USDT");
        console.log("Shares:", shares);
    }
}
