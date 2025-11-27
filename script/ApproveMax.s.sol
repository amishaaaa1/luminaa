// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockUSDT} from "../src/MockUSDT.sol";

contract ApproveMax is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Your wallet address
        address yourWallet = 0xD114410e64De8e14AF6B22Db779e74c3fBcc5f0A;
        
        // Contract addresses
        address usdtAddress = 0x715046Bdd7f9914bDFdec0795182809C28AC4a0C;
        address policyManagerAddress = 0xB921fE0670b59890FEB0ACE2E9595e59fFDb831c;
        
        vm.startBroadcast(deployerPrivateKey);

        MockUSDT usdt = MockUSDT(usdtAddress);
        
        // Check current allowance
        uint256 currentAllowance = usdt.allowance(yourWallet, policyManagerAddress);
        console.log("Current allowance:", currentAllowance / 10**18, "USDT");
        
        // Approve MAX amount (infinite approval)
        uint256 maxAmount = type(uint256).max;
        console.log("Approving MAX USDT...");
        usdt.approve(policyManagerAddress, maxAmount);
        
        // Check new allowance
        uint256 newAllowance = usdt.allowance(yourWallet, policyManagerAddress);
        console.log("New allowance: MAX (infinite)");

        vm.stopBroadcast();
        
        console.log("\nNow you can buy insurance without approving every time!");
    }
}
