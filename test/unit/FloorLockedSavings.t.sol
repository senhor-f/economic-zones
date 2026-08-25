// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {AugmentedBondingCurve} from "../../src/curve/AugmentedBondingCurve.sol";
import {FloorLockedSavings} from "../../src/zones/FloorLockedSavings.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract FloorLockedSavingsTest is Test {
    HNYToken public hny;
    MockERC20 public usdc;
    AugmentedBondingCurve public curve;
    FloorLockedSavings public savings;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        usdc = new MockERC20("USD Coin", "USDC", 18);

        curve = new AugmentedBondingCurve(address(hny), address(usdc), treasuryVault, owner, 1e18, 1e12, 50, 100);
        savings = new FloorLockedSavings(address(hny), address(curve), owner);

        hny.setMinter(owner, true);
        hny.mint(alice, 100_000e18);
        hny.mint(bob, 100_000e18);
        vm.stopPrank();
    }

    function test_CreateLock_AndNormalUnlock() public {
        vm.startPrank(alice);
        hny.approve(address(savings), 10_000e18);
        uint256 duration = 365 days; // 1 year = 4.0x max boost
        uint256 lockId = savings.createLock(10_000e18, duration);
        vm.stopPrank();

        assertEq(lockId, 1);
        // 10k * 4.0x = 40,000 boosted voting power
        assertEq(savings.userActiveVotingPower(alice), 40_000e18);
        assertEq(savings.getUserCashbackBonusBps(alice), 50); // 40k >= 25k -> 50 bps bonus

        // Warp to unlock
        vm.warp(block.timestamp + 365 days + 1);

        vm.startPrank(alice);
        savings.unlock(lockId);
        vm.stopPrank();

        assertEq(savings.userActiveVotingPower(alice), 0);
        assertEq(hny.balanceOf(alice), 100_000e18);
    }

    function test_EarlyExit_DeductsPenaltyToCurve() public {
        vm.startPrank(bob);
        hny.approve(address(savings), 20_000e18);
        uint256 lockId = savings.createLock(20_000e18, 180 days);

        // Emergency early exit before unlock time
        (uint256 payout, uint256 penalty) = savings.earlyExit(lockId);
        vm.stopPrank();

        // 15% penalty on 20,000 = 3,000 HNY penalty, 17,000 payout
        assertEq(penalty, 3_000e18);
        assertEq(payout, 17_000e18);
        assertEq(hny.balanceOf(address(curve)), 3_000e18);
        assertEq(hny.balanceOf(bob), 80_000e18 + 17_000e18);
    }
}
