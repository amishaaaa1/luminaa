// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PolicyManager} from "../src/PolicyManager.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {LuminaOracle} from "../src/LuminaOracle.sol";
import {IInsurancePool} from "../src/interfaces/IInsurancePool.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @title Integration Test - Full user flow
/// @notice Tests the complete insurance lifecycle
contract IntegrationTest is Test {
    PolicyManager public policyManager;
    InsurancePool public pool;
    LuminaOracle public oracle;
    MockERC20 public asset;
    
    address public lpProvider = makeAddr("lpProvider");
    address public trader = makeAddr("trader");
    address public resolver = makeAddr("resolver");
    
    function setUp() public {
        // Deploy contracts
        asset = new MockERC20("USDT", "USDT");
        oracle = new LuminaOracle();
        
        // Calculate future PolicyManager address
        address predictedPolicyManager = computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        
        // Deploy pool with predicted address
        pool = new InsurancePool(address(asset), predictedPolicyManager);
        
        // Deploy policy manager
        policyManager = new PolicyManager(
            address(asset),
            address(pool),
            address(oracle)
        );
        
        // Verify
        require(address(policyManager) == predictedPolicyManager, "Address mismatch");
        
        // Setup oracle
        oracle.addResolver(resolver);
        
        // Fund accounts
        asset.mint(lpProvider, 100000 ether);
        asset.mint(trader, 10000 ether);
    }
    
    function computeCreateAddress(address deployer, uint256 nonce) internal pure override returns (address) {
        if (nonce == 0x00) return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(0x80))))));
        if (nonce <= 0x7f) return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, uint8(nonce))))));
        if (nonce <= 0xff) return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd7), bytes1(0x94), deployer, bytes1(0x81), uint8(nonce))))));
        if (nonce <= 0xffff) return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd8), bytes1(0x94), deployer, bytes1(0x82), uint16(nonce))))));
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd9), bytes1(0x94), deployer, bytes1(0x83), uint24(nonce))))));
    }

    function testFullInsuranceFlow() public {
        // 1. LP provides liquidity
        console.log("=== Step 1: LP Deposits Liquidity ===");
        vm.startPrank(lpProvider);
        asset.approve(address(pool), 50000 ether);
        uint256 shares = pool.deposit(50000 ether);
        vm.stopPrank();
        
        console.log("LP deposited 50000 USDT");
        console.log("LP received shares:", shares);
        
        // 2. Trader buys insurance
        console.log("\n=== Step 2: Trader Buys Insurance ===");
        uint256 coverage = 10 ether;
        uint256 premium = policyManager.calculatePremium("btc-100k", coverage);
        
        console.log("Coverage amount:", coverage / 1e18);
        console.log("Premium:", premium / 1e18);
        
        vm.startPrank(trader);
        asset.approve(address(policyManager), premium);
        uint256 policyId = policyManager.createPolicy(
            trader,
            "btc-100k",
            coverage,
            premium,
            30 days
        );
        vm.stopPrank();
        
        console.log("Policy ID:", policyId);
        
        // 3. Check pool state after premium collection
        console.log("\n=== Step 3: Pool State After Premium ===");
        IInsurancePool.PoolInfo memory poolInfo = pool.getPoolInfo();
        console.log("Total liquidity:", poolInfo.totalLiquidity / 1e18);
        console.log("Total premiums:", poolInfo.totalPremiums / 1e18);
        
        // 4. Market resolves
        console.log("\n=== Step 4: Market Resolves ===");
        vm.prank(resolver);
        oracle.resolveMarket("btc-100k", keccak256("trader_loses"));
        console.log("Market resolved");
        
        // 5. Trader claims insurance
        console.log("\n=== Step 5: Trader Claims Insurance ===");
        uint256 traderBalanceBefore = asset.balanceOf(trader);
        
        vm.prank(trader);
        uint256 payout = policyManager.claimPolicy(policyId);
        
        uint256 traderBalanceAfter = asset.balanceOf(trader);
        console.log("Payout:", payout / 1e18);
        console.log("Trader balance increase:", (traderBalanceAfter - traderBalanceBefore) / 1e18);
        
        // 6. LP withdraws
        console.log("\n=== Step 6: LP Withdraws ===");
        IInsurancePool.ProviderInfo memory providerInfo = pool.getProviderInfo(lpProvider);
        
        uint256 lpBalanceBefore = asset.balanceOf(lpProvider);
        
        vm.prank(lpProvider);
        uint256 withdrawn = pool.withdraw(providerInfo.shares);
        
        uint256 lpBalanceAfter = asset.balanceOf(lpProvider);
        console.log("LP withdrew:", withdrawn / 1e18);
        
        // Calculate profit (withdrawn - initial deposit)
        uint256 initialDeposit = 50000 ether;
        if (withdrawn > initialDeposit) {
            console.log("LP profit:", (withdrawn - initialDeposit) / 1e18);
        } else {
            console.log("LP loss:", (initialDeposit - withdrawn) / 1e18);
        }
        
        // Assertions
        assertEq(payout, coverage, "Payout should equal coverage");
        // LP earned premium but paid out claim, so might have loss
        assertGt(withdrawn, 0, "LP should receive something");
    }

    function testMultiplePoliciesAndClaims() public {
        // Setup liquidity
        vm.startPrank(lpProvider);
        asset.approve(address(pool), 100000 ether);
        pool.deposit(100000 ether);
        vm.stopPrank();
        
        // Create multiple policies
        address trader1 = makeAddr("trader1");
        address trader2 = makeAddr("trader2");
        address trader3 = makeAddr("trader3");
        
        asset.mint(trader1, 5000 ether);
        asset.mint(trader2, 5000 ether);
        asset.mint(trader3, 5000 ether);
        
        uint256[] memory policyIds = new uint256[](3);
        
        // Trader 1 buys insurance
        vm.startPrank(trader1);
        uint256 premium1 = policyManager.calculatePremium("market-1", 5 ether);
        asset.approve(address(policyManager), premium1);
        policyIds[0] = policyManager.createPolicy(trader1, "market-1", 5 ether, premium1, 30 days);
        vm.stopPrank();
        
        // Trader 2 buys insurance
        vm.startPrank(trader2);
        uint256 premium2 = policyManager.calculatePremium("market-2", 7 ether);
        asset.approve(address(policyManager), premium2);
        policyIds[1] = policyManager.createPolicy(trader2, "market-2", 7 ether, premium2, 30 days);
        vm.stopPrank();
        
        // Trader 3 buys insurance
        vm.startPrank(trader3);
        uint256 premium3 = policyManager.calculatePremium("market-3", 10 ether);
        asset.approve(address(policyManager), premium3);
        policyIds[2] = policyManager.createPolicy(trader3, "market-3", 10 ether, premium3, 30 days);
        vm.stopPrank();
        
        // Resolve markets
        vm.startPrank(resolver);
        oracle.resolveMarket("market-1", keccak256("outcome1"));
        oracle.resolveMarket("market-2", keccak256("outcome2"));
        oracle.resolveMarket("market-3", keccak256("outcome3"));
        vm.stopPrank();
        
        // Only trader 1 and 3 claim
        vm.prank(trader1);
        policyManager.claimPolicy(policyIds[0]);
        
        vm.prank(trader3);
        policyManager.claimPolicy(policyIds[2]);
        
        // Check pool state
        IInsurancePool.PoolInfo memory finalPoolInfo = pool.getPoolInfo();
        
        console.log("Final pool liquidity:", finalPoolInfo.totalLiquidity / 1e18);
        console.log("Total premiums collected:", finalPoolInfo.totalPremiums / 1e18);
        console.log("Total claims paid:", finalPoolInfo.totalClaims / 1e18);
        
        assertEq(finalPoolInfo.totalClaims, 15 ether, "Should have paid 15 in claims");
    }

    function testUtilizationCap() public {
        // Setup liquidity
        vm.startPrank(lpProvider);
        asset.approve(address(pool), 100 ether);
        pool.deposit(100 ether);
        vm.stopPrank();
        
        // Try to create policy that would exceed 80% utilization
        uint256 coverage = 90 ether; // Would be 90% utilization
        uint256 premium = policyManager.calculatePremium("market-1", coverage);
        
        vm.startPrank(trader);
        asset.approve(address(policyManager), premium);
        
        vm.expectRevert("Pool can't cover this");
        policyManager.createPolicy(trader, "market-1", coverage, premium, 30 days);
        vm.stopPrank();
    }
}
