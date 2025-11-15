// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PolicyManager} from "../src/PolicyManager.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {LuminaOracle} from "../src/LuminaOracle.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract PolicyManagerTest is Test {
    PolicyManager public policyManager;
    InsurancePool public pool;
    LuminaOracle public oracle;
    MockERC20 public asset;
    
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    
    uint256 constant INITIAL_BALANCE = 10000 ether;
    uint256 constant POOL_LIQUIDITY = 100000 ether;

    function setUp() public {
        asset = new MockERC20("Test USDT", "USDT");
        oracle = new LuminaOracle();
        
        // Deploy pool with placeholder for policy manager
        pool = new InsurancePool(address(asset), address(this));
        
        // Deploy policy manager
        policyManager = new PolicyManager(
            address(asset),
            address(pool),
            address(oracle)
        );
        
        // Setup initial liquidity
        asset.mint(address(this), POOL_LIQUIDITY);
        asset.approve(address(pool), POOL_LIQUIDITY);
        pool.deposit(POOL_LIQUIDITY);
        
        // Setup test users
        asset.mint(alice, INITIAL_BALANCE);
        asset.mint(bob, INITIAL_BALANCE);
    }

    function testCreatePolicy() public {
        uint256 coverage = 100 ether;
        uint256 premium = policyManager.calculatePremium("market-1", coverage);
        
        vm.startPrank(alice);
        asset.approve(address(policyManager), premium);
        
        uint256 policyId = policyManager.createPolicy(
            alice,
            "market-1",
            coverage,
            premium,
            30 days
        );
        vm.stopPrank();
        
        assertEq(policyId, 1, "First policy should have ID 1");
        assertEq(policyManager.ownerOf(policyId), alice, "Alice should own the policy");
    }

    function testCannotCreatePolicyWithInsufficientPremium() public {
        uint256 coverage = 100 ether;
        uint256 premium = policyManager.calculatePremium("market-1", coverage);
        
        vm.startPrank(alice);
        asset.approve(address(policyManager), premium);
        
        vm.expectRevert("Premium too low");
        policyManager.createPolicy(
            alice,
            "market-1",
            coverage,
            premium - 1, // Too low
            30 days
        );
        vm.stopPrank();
    }

    function testClaimPolicy() public {
        // Create policy
        uint256 coverage = 100 ether;
        uint256 premium = policyManager.calculatePremium("market-1", coverage);
        
        vm.startPrank(alice);
        asset.approve(address(policyManager), premium);
        uint256 policyId = policyManager.createPolicy(
            alice,
            "market-1",
            coverage,
            premium,
            30 days
        );
        vm.stopPrank();
        
        // Resolve market
        oracle.resolveMarket("market-1", keccak256("outcome"));
        
        // Claim policy
        uint256 balanceBefore = asset.balanceOf(alice);
        
        vm.prank(alice);
        uint256 payout = policyManager.claimPolicy(policyId);
        
        assertEq(payout, coverage, "Payout should equal coverage");
        assertEq(
            asset.balanceOf(alice),
            balanceBefore + coverage,
            "Alice should receive payout"
        );
    }

    function testCannotClaimUnresolvedMarket() public {
        uint256 coverage = 100 ether;
        uint256 premium = policyManager.calculatePremium("market-1", coverage);
        
        vm.startPrank(alice);
        asset.approve(address(policyManager), premium);
        uint256 policyId = policyManager.createPolicy(
            alice,
            "market-1",
            coverage,
            premium,
            30 days
        );
        
        vm.expectRevert("Market not resolved yet");
        policyManager.claimPolicy(policyId);
        vm.stopPrank();
    }

    function testCannotClaimExpiredPolicy() public {
        uint256 coverage = 100 ether;
        uint256 premium = policyManager.calculatePremium("market-1", coverage);
        
        vm.startPrank(alice);
        asset.approve(address(policyManager), premium);
        uint256 policyId = policyManager.createPolicy(
            alice,
            "market-1",
            coverage,
            premium,
            30 days
        );
        vm.stopPrank();
        
        // Fast forward past expiry
        vm.warp(block.timestamp + 31 days);
        
        oracle.resolveMarket("market-1", keccak256("outcome"));
        
        vm.prank(alice);
        vm.expectRevert("Policy expired");
        policyManager.claimPolicy(policyId);
    }

    function testExpirePolicy() public {
        uint256 coverage = 100 ether;
        uint256 premium = policyManager.calculatePremium("market-1", coverage);
        
        vm.startPrank(alice);
        asset.approve(address(policyManager), premium);
        uint256 policyId = policyManager.createPolicy(
            alice,
            "market-1",
            coverage,
            premium,
            30 days
        );
        vm.stopPrank();
        
        // Fast forward past expiry
        vm.warp(block.timestamp + 31 days);
        
        // Anyone can expire
        policyManager.expirePolicy(policyId);
        
        IPolicyManager.Policy memory policy = policyManager.getPolicy(policyId);
        assertEq(
            uint8(policy.status),
            uint8(IPolicyManager.PolicyStatus.Expired),
            "Policy should be expired"
        );
    }

    function testGetUserPolicies() public {
        uint256 coverage = 100 ether;
        uint256 premium = policyManager.calculatePremium("market-1", coverage);
        
        vm.startPrank(alice);
        asset.approve(address(policyManager), premium * 3);
        
        policyManager.createPolicy(alice, "market-1", coverage, premium, 30 days);
        policyManager.createPolicy(alice, "market-2", coverage, premium, 30 days);
        policyManager.createPolicy(alice, "market-3", coverage, premium, 30 days);
        vm.stopPrank();
        
        uint256[] memory policies = policyManager.getUserPolicies(alice);
        assertEq(policies.length, 3, "Alice should have 3 policies");
    }

    function testPremiumIncreasesWithUtilization() public {
        uint256 coverage = 1000 ether;
        
        uint256 premium1 = policyManager.calculatePremium("market-1", coverage);
        
        // Create large policy to increase utilization
        vm.startPrank(alice);
        asset.approve(address(policyManager), premium1);
        policyManager.createPolicy(alice, "market-1", coverage, premium1, 30 days);
        vm.stopPrank();
        
        uint256 premium2 = policyManager.calculatePremium("market-2", coverage);
        
        assertGt(premium2, premium1, "Premium should increase with utilization");
    }
}

interface IPolicyManager {
    enum PolicyStatus {
        Active,
        Claimed,
        Expired,
        Cancelled
    }

    struct Policy {
        uint256 id;
        address holder;
        string marketId;
        uint256 coverageAmount;
        uint256 premium;
        uint256 startTime;
        uint256 expiryTime;
        PolicyStatus status;
        bytes32 marketOutcomeHash;
    }
}
