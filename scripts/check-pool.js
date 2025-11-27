// Check Pool Liquidity
const hre = require("hardhat");

async function main() {
  console.log("=== Checking Pool Liquidity ===\n");

  const POOL_ADDRESS = "0x73b988b8308e50f515ea25f4673070eb480889c1";
  const USDT_ADDRESS = "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd";
  const POLICY_MANAGER = "0xc03fc0366d91ea1e3eb0f92bcc20c78f988d370c";

  // Get signer
  const [signer] = await hre.ethers.getSigners();
  console.log("Checking from address:", signer.address);

  // Get contracts
  const Pool = await hre.ethers.getContractAt("InsurancePool", POOL_ADDRESS);
  const USDT = await hre.ethers.getContractAt("IERC20", USDT_ADDRESS);
  const PolicyManager = await hre.ethers.getContractAt("PolicyManager", POLICY_MANAGER);

  // Check pool info
  console.log("\n📊 POOL STATUS:");
  const poolInfo = await Pool.getPoolInfo();
  console.log("- Total Liquidity:", hre.ethers.formatEther(poolInfo.totalLiquidity), "USDT");
  console.log("- Available:", hre.ethers.formatEther(poolInfo.availableLiquidity), "USDT");
  console.log("- Total Premiums:", hre.ethers.formatEther(poolInfo.totalPremiums), "USDT");
  console.log("- Total Claims:", hre.ethers.formatEther(poolInfo.totalClaims), "USDT");
  console.log("- Utilization:", poolInfo.utilizationRate.toString() / 100, "%");
  console.log("- Active:", poolInfo.isActive);

  // Check deployer balance
  console.log("\n💰 YOUR BALANCES:");
  const usdtBalance = await USDT.balanceOf(signer.address);
  console.log("- USDT:", hre.ethers.formatEther(usdtBalance), "USDT");
  
  const ethBalance = await hre.ethers.provider.getBalance(signer.address);
  console.log("- BNB:", hre.ethers.formatEther(ethBalance), "BNB");

  // Check if paused
  console.log("\n🔒 CONTRACT STATUS:");
  const isPaused = await PolicyManager.paused();
  console.log("- Paused:", isPaused);

  // Test premium calculation
  console.log("\n💵 PREMIUM TEST:");
  try {
    const coverage = hre.ethers.parseEther("1"); // 1 USDT
    const premium = await PolicyManager.calculatePremium("1", coverage);
    console.log("- Coverage: 1 USDT");
    console.log("- Premium:", hre.ethers.formatEther(premium), "USDT");
    console.log("- Rate:", (parseFloat(hre.ethers.formatEther(premium)) * 100).toFixed(2), "%");
  } catch (error) {
    console.log("- ERROR:", error.message);
  }

  // Diagnosis
  console.log("\n🔍 DIAGNOSIS:");
  if (poolInfo.totalLiquidity == 0n) {
    console.log("❌ PROBLEM FOUND: Pool has NO liquidity!");
    console.log("   Insurance purchases will FAIL without pool liquidity");
    console.log("\n✅ SOLUTION:");
    console.log("   Run: node scripts/deposit-to-pool.js");
  } else if (!poolInfo.isActive) {
    console.log("❌ PROBLEM: Pool is not active");
  } else if (isPaused) {
    console.log("❌ PROBLEM: Contract is paused");
  } else if (usdtBalance == 0n) {
    console.log("❌ PROBLEM: You have no USDT tokens");
  } else {
    console.log("✅ Everything looks good!");
    console.log("   Pool has liquidity, contract is active");
    console.log("   You should be able to buy insurance");
  }

  console.log("\n=== Check Complete ===");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
