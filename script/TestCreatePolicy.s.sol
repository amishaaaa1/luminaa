// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockUSDT} from "../src/MockUSDT.sol";
import {PolicyManager} from "../src/PolicyManager.sol";
import {InsurancePool} from "../src/InsurancePool.sol";

contract TestCreatePolicy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Contract addresses
        address usdtAddress = 0x715046Bdd7f9914bDFdec0795182809C28AC4a0C;
        address policyManagerAddress = 0xB921fE0670b59890FEB0ACE2E9595e59fFDb831c;
        address payable poolAddress = payable(0xcef0d7a219f98de961586D5e895d36b31BA89997);
        
        vm.startBroadcast(deployerPrivateKey);

        MockUSDT usdt = MockUSDT(usdtAddress);
        PolicyManager pm = PolicyManager(policyManagerAddress);
        InsurancePool pool = InsurancePool(poolAddress);
        
        // Check balances
        console.log("USDT Balance:", usdt.balanceOf(deployer) / 10**18);
        console.log("Pool Liquidity:", pool.getPoolInfo().totalLiquidity / 10**18);
        
        // Test parameters (from actual failed transaction)
        string memory marketId = "16106";
        uint256 coverageAmount = 200000000000000000; // 0.2 USDT
        uint256 premium = 30000000000000000; // 0.03 USDT
        uint256 duration = 2592000; // 30 days
        
        // Step 1: Approve
        console.log("Approving USDT...");
        usdt.approve(policyManagerAddress, premium);
        console.log("Approved!");
        
        // Step 2: Create policy
        console.log("Creating policy...");
        try pm.createPolicy(deployer, marketId, coverageAmount, premium, duration) returns (uint256 policyId) {
            console.log("Success! Policy ID:", policyId);
        } catch Error(string memory reason) {
            console.log("Failed with reason:", reason);
        } catch {
            console.log("Failed with no reason");
        }

        vm.stopBroadcast();
    }
}
