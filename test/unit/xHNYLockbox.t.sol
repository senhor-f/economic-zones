// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {xHNYLockbox} from "../../src/crosschain/xHNYLockbox.sol";

contract xHNYLockboxTest is Test {
    HNYToken public hny;
    xHNYLockbox public lockbox;

    address public owner = address(0xAA);
    address public bridge = address(0xBBBB);
    address public user = address(0x1111);
    address public recipient = address(0x2222);

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        lockbox = new xHNYLockbox(address(hny), owner);

        hny.setMinter(owner, true);
        hny.mint(user, 200_000e18);

        // Authorize bridge with 100k daily rate limit
        lockbox.setBridgeLimits(bridge, 100_000e18, true);
        vm.stopPrank();
    }

    function test_Lock_And_UnlockWithinRateLimit() public {
        // 1. User locks 40,000 HNY to bridge to L2
        vm.startPrank(user);
        hny.approve(address(lockbox), 40_000e18);
        lockbox.lock(bridge, 40_000e18);
        vm.stopPrank();

        assertEq(hny.balanceOf(address(lockbox)), 40_000e18);
        assertEq(hny.balanceOf(user), 160_000e18);

        // 2. Bridge unlocks 20,000 HNY to recipient on L1
        vm.prank(bridge);
        lockbox.unlock(recipient, 20_000e18);

        assertEq(hny.balanceOf(recipient), 20_000e18);
        assertEq(hny.balanceOf(address(lockbox)), 20_000e18);
    }

    function test_RevertWhen_DailyRateLimitExceeded() public {
        vm.startPrank(user);
        hny.approve(address(lockbox), 150_000e18);

        // 100k allowed
        lockbox.lock(bridge, 100_000e18);

        // Next 1 HNY reverts due to rate limit
        vm.expectRevert(xHNYLockbox.RateLimitExceeded.selector);
        lockbox.lock(bridge, 1e18);
        vm.stopPrank();

        // Warp 24 hours -> limit resets
        vm.warp(block.timestamp + 1 days + 1);

        vm.prank(user);
        lockbox.lock(bridge, 10_000e18); // succeeds!
        assertEq(hny.balanceOf(address(lockbox)), 110_000e18);
    }
}
