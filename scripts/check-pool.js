// Script to check pool liquidity status
require('dotenv').config();
const { ethers } = require('ethers');

const POOL_ADDRESS = process.env.INSURANCE_POOL_ADDRESS;
const RPC_URL = process.env.BNB_TESTNET_RPC;

// InsurancePool ABI (only functions we need)
const POOL_ABI = [
  "function getPoolInfo() external view returns (tuple(uint256 totalLiquidity, uint256 availableLiquidity, uint256 totalPremiums, uint256 totalClaims, uint256 utilizationRate, bool isActive))",
  "function canCoverPolicy(uint256 coverageAmount) external view returns (bool)",
  "function totalAssets() external view returns (uint256)"
];

async function main() {
  console.log("🔍 Checking Pool Status...\n");

  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const pool = new ethers.Contract(POOL_ADDRESS, POOL_ABI, provider);

  console.log("Pool Address:", POOL_ADDRESS);
  console.log("RPC:", RPC_URL, "\n");

  try {
    // Get pool info
    const poolInfo = await pool.getPoolInfo();
    
    console.log("=== Pool Status ===");
    console.log("Total Liquidity:", ethers.formatEther(poolInfo.totalLiquidity), "USDT");
    console.log("Available Liquidity:", ethers.formatEther(poolInfo.availableLiquidity), "USDT");
    console.log("Total Premiums:", ethers.formatEther(poolInfo.totalPremiums), "USDT");
    console.log("Total Claims:", ethers.formatEther(poolInfo.totalClaims), "USDT");
    console.log("Utilization Rate:", poolInfo.utilizationRate.toString() / 100, "%");
    console.log("Is Active:", poolInfo.isActive);

    // Test coverage amounts
    const testAmounts = [
      ethers.parseEther("1"),      // 1 USDT
      ethers.parseEther("10"),     // 10 USDT
      ethers.parseEther("100"),    // 100 USDT
      ethers.parseEther("1000"),   // 1000 USDT
      ethers.parseEther("10000"),  // 10000 USDT
    ];

    console.log("\n=== Coverage Tests ===");
    for (const amount of testAmounts) {
      const canCover = await pool.canCoverPolicy(amount);
      console.log(`Can cover ${ethers.formatEther(amount)} USDT: ${canCover ? '✅' : '❌'}`);
    }

  } catch (error) {
    console.error("❌ Error:", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
