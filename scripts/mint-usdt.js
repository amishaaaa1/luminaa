// Script to mint USDT using ethers.js
// Run with: node scripts/mint-usdt.js

require('dotenv').config();
const { ethers } = require('ethers');

const USDT_ADDRESS = process.env.ASSET_TOKEN;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const RPC_URL = process.env.BNB_TESTNET_RPC;

// MockUSDT ABI (only functions we need)
const USDT_ABI = [
  "function mint(address to, uint256 amount) external",
  "function faucet() external",
  "function balanceOf(address account) external view returns (uint256)",
  "function canUseFaucet(address user) external view returns (bool canUse, uint256 timeLeft)"
];

async function main() {
  console.log("🚀 Minting USDT...\n");

  // Setup provider and wallet
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  
  console.log("Wallet Address:", wallet.address);
  console.log("USDT Contract:", USDT_ADDRESS);
  console.log("RPC:", RPC_URL, "\n");

  // Connect to USDT contract
  const usdt = new ethers.Contract(USDT_ADDRESS, USDT_ABI, wallet);

  // Check current balance
  const balanceBefore = await usdt.balanceOf(wallet.address);
  console.log("Balance Before:", ethers.formatEther(balanceBefore), "USDT\n");

  try {
    // Option 1: Try mint function (100,000 USDT)
    console.log("Attempting to mint 100,000 USDT...");
    const mintAmount = ethers.parseEther("100000");
    const tx = await usdt.mint(wallet.address, mintAmount);
    console.log("Transaction sent:", tx.hash);
    
    console.log("Waiting for confirmation...");
    await tx.wait();
    console.log("✅ Mint successful!\n");

  } catch (error) {
    console.log("❌ Mint failed:", error.message);
    console.log("\nTrying faucet instead (1000 USDT)...\n");
    
    try {
      // Option 2: Use faucet (1000 USDT)
      const [canUse, timeLeft] = await usdt.canUseFaucet(wallet.address);
      
      if (!canUse) {
        console.log(`⏰ Faucet cooldown active. Wait ${timeLeft} seconds`);
        return;
      }

      const faucetTx = await usdt.faucet();
      console.log("Faucet transaction sent:", faucetTx.hash);
      
      console.log("Waiting for confirmation...");
      await faucetTx.wait();
      console.log("✅ Faucet successful!\n");

    } catch (faucetError) {
      console.log("❌ Faucet also failed:", faucetError.message);
      return;
    }
  }

  // Check new balance
  const balanceAfter = await usdt.balanceOf(wallet.address);
  console.log("Balance After:", ethers.formatEther(balanceAfter), "USDT");
  console.log("Received:", ethers.formatEther(balanceAfter - balanceBefore), "USDT");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
