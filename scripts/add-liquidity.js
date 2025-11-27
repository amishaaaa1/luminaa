// Script to add liquidity to pool
require('dotenv').config();
const { ethers } = require('ethers');

const POOL_ADDRESS = process.env.INSURANCE_POOL_ADDRESS;
const USDT_ADDRESS = process.env.ASSET_TOKEN;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const RPC_URL = process.env.BNB_TESTNET_RPC;

const USDT_ABI = [
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function balanceOf(address account) external view returns (uint256)",
  "function allowance(address owner, address spender) external view returns (uint256)"
];

const POOL_ABI = [
  "function deposit(uint256 assets) external returns (uint256 shares)",
  "function totalAssets() external view returns (uint256)"
];

async function main() {
  const amount = process.argv[2] || "100000"; // Default 100k USDT
  const liquidityAmount = ethers.parseEther(amount);

  console.log(`💰 Adding ${amount} USDT liquidity to pool...\n`);

  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  
  const usdt = new ethers.Contract(USDT_ADDRESS, USDT_ABI, wallet);
  const pool = new ethers.Contract(POOL_ADDRESS, POOL_ABI, wallet);

  console.log("Wallet:", wallet.address);
  console.log("Pool:", POOL_ADDRESS);
  console.log("USDT:", USDT_ADDRESS, "\n");

  // Check balance
  const balance = await usdt.balanceOf(wallet.address);
  console.log("Your USDT Balance:", ethers.formatEther(balance), "USDT");
  
  if (balance < liquidityAmount) {
    console.log("❌ Insufficient balance!");
    return;
  }

  // Check current pool liquidity
  const currentLiquidity = await pool.totalAssets();
  console.log("Current Pool Liquidity:", ethers.formatEther(currentLiquidity), "USDT\n");

  // Approve
  console.log("Approving USDT...");
  const approveTx = await usdt.approve(POOL_ADDRESS, liquidityAmount);
  await approveTx.wait();
  console.log("✅ Approved\n");

  // Deposit
  console.log("Depositing to pool...");
  const depositTx = await pool.deposit(liquidityAmount);
  console.log("Transaction:", depositTx.hash);
  
  const receipt = await depositTx.wait();
  console.log("✅ Deposit successful!\n");

  // Check new liquidity
  const newLiquidity = await pool.totalAssets();
  console.log("New Pool Liquidity:", ethers.formatEther(newLiquidity), "USDT");
  console.log("Added:", ethers.formatEther(newLiquidity - currentLiquidity), "USDT");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
