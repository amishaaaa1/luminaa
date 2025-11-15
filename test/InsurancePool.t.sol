// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract InsurancePoolTest is Test {
    InsurancePool public pool;
    MockERC20 public asset;
    
    address public policyManager = makeAddr("policyManager");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant INITIAL_BALANCE = 1000 ether;

    function setUp() public {
        asset = new MockERC20("Test Token", "TEST");
        pool = new InsurancePool(address(asset), policyManager);

        asset.mint(alice, INITIAL_BALANCE);
        asset.mint(bob, INITIAL_BALANCE);
    }

    function testDeposit() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(alice);
        asset.approve(address(pool), depositAmount);
        uint256 shares = pool.deposit(depositAmount);
        vm.stopPrank();

        assertGt(shares, 0, "Should receive shares");
        
        IInsurancePool.PoolInfo memory info = pool.getPoolInfo();
        assertEq(info.totalLiquidity, depositAmount, "Total liquidity mismatch");
        assertEq(info.availableLiquidity, depositAmount, "Available liquidity mismatch");
    }

    function testWithdraw() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(alice);
        asset.approve(address(pool), depositAmount);
        uint256 shares = pool.deposit(depositAmount);
        
        uint256 withdrawAmount = pool.withdraw(shares);
        vm.stopPrank();

        assertEq(withdrawAmount, depositAmount, "Withdraw amount mismatch");
        assertEq(asset.balanceOf(alice), INITIAL_BALANCE, "Balance not restored");
    }

    function testCollectPremium() public {
        uint256 premium = 1 ether;

        vm.startPrank(policyManager);
        asset.mint(policyManager, premium);
        asset.approve(address(pool), premium);
        pool.collectPremium(1, premium);
        vm.stopPrank();

        IInsurancePool.PoolInfo memory info = pool.getPoolInfo();
        assertEq(info.totalPremiums, premium, "Premium not collected");
    }

    function testCannotWithdrawMoreThanDeposited() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(alice);
        asset.approve(address(pool), depositAmount);
        uint256 shares = pool.deposit(depositAmount);
        
        vm.expectRevert("Insufficient shares");
        pool.withdraw(shares + 1);
        vm.stopPrank();
    }
}
