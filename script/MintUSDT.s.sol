// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockUSDT} from "../src/MockUSDT.sol";

contract MintUSDT is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Your wallet address
        address yourWallet = 0xD114410e64De8e14AF6B22Db779e74c3fBcc5f0A;
        
        // USDT address
        address usdtAddress = 0x715046Bdd7f9914bDFdec0795182809C28AC4a0C;
        
        vm.startBroadcast(deployerPrivateKey);

        MockUSDT usdt = MockUSDT(usdtAddress);
        
        // Check current balance
        uint256 currentBalance = usdt.balanceOf(yourWallet);
        console.log("Current USDT balance:", currentBalance / 10**18);
        
        // Mint 10,000 USDT to your wallet
        uint256 mintAmount = 10000 * 10**18;
        console.log("Minting 10,000 USDT...");
        usdt.mint(yourWallet, mintAmount);
        
        // Check new balance
        uint256 newBalance = usdt.balanceOf(yourWallet);
        console.log("New USDT balance:", newBalance / 10**18);

        vm.stopBroadcast();
    }
}
