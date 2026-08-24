// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {HNYMigrator} from "../../src/token/HNYMigrator.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract HNYMigratorTest is Test {
    HNYToken public newHny;
    MockERC20 public oldHny;
    HNYMigrator public migrator;

    address public owner = address(0xAA);
    address public alice = address(0x11);
    address public bob = address(0x22);

    uint256 public constant BONUS_BPS = 500; // 5% bonus
    uint256 public constant BONUS_DURATION = 30 days;

    function setUp() public {
        vm.startPrank(owner);
        newHny = new HNYToken(owner);
        oldHny = new MockERC20("Honey Legacy", "HNYv1", 18);

        migrator = new HNYMigrator(address(oldHny), address(newHny), owner, BONUS_BPS, BONUS_DURATION);

        newHny.setMinter(address(migrator), true);
        vm.stopPrank();

        oldHny.mint(alice, 1000e18);
        oldHny.mint(bob, 1000e18);
    }

    function test_MigrateWithEarlyBonus() public {
        uint256 amount = 1000e18;

        vm.startPrank(alice);
        oldHny.approve(address(migrator), amount);
        migrator.migrate(amount);
        vm.stopPrank();

        // 1000 + 5% bonus = 1050 new HNY
        assertEq(newHny.balanceOf(alice), 1050e18);
        assertEq(oldHny.balanceOf(migrator.DEAD_ADDRESS()), 1000e18);
        assertEq(migrator.totalOldMigrated(), 1000e18);
        assertEq(migrator.totalNewMinted(), 1050e18);
    }

    function test_MigrateAfterBonusExpiry() public {
        // Warp past 30 days
        vm.warp(block.timestamp + 31 days);

        uint256 amount = 1000e18;

        vm.startPrank(bob);
        oldHny.approve(address(migrator), amount);
        migrator.migrate(amount);
        vm.stopPrank();

        // Exactly 1:1, 0 bonus
        assertEq(newHny.balanceOf(bob), 1000e18);
        assertEq(oldHny.balanceOf(migrator.DEAD_ADDRESS()), 1000e18);
    }
}
