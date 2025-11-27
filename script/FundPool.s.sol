// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {MockUSDT} from "../src/MockUSDT.sol";

contract FundPool is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Use the newly deployed addresses
        address usdtAddress = 0x715046Bdd7f9914bDFdec0795182809C28AC4a0C;
        address payable poolAddress = payable(0xcef0d7a219f98de961586D5e895d36b31BA89997);
        
        vm.startBroadcast(deployerPrivateKey);

        MockUSDT usdt = MockUSDT(usdtAddress);
        InsurancePool pool = InsurancePool(poolAddress);

        // Amount to deposit (100,000 USDT)
        uint256 depositAmount = 100000 * 10**18;
        
        console.log("Approving USDT...");
        usdt.approve(poolAddress, depositAmount);
        
        console.log("Depositing to pool...");
        pool.deposit(depositAmount);
        
        console.log("Pool funded with 100,000 USDT!");

        vm.stopBroadcast();
    }
}
