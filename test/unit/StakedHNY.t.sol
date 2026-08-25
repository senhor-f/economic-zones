// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {StakedHNY} from "../../src/token/StakedHNY.sol";

contract StakedHNYTest is Test {
    HNYToken public hny;
    StakedHNY public sHny;

    address public owner = address(0xAA);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public distributor = address(0xD157);

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        sHny = new StakedHNY(address(hny), owner);

        hny.setMinter(owner, true);
        hny.mint(alice, 100_000e18);
        hny.mint(bob, 100_000e18);
        hny.mint(distributor, 50_000e18);
        vm.stopPrank();
    }

    function test_Deposit_DistributeRewards_AndRedeemWithYield() public {
        // 1. Alice deposits 10,000 HNY
        vm.startPrank(alice);
        hny.approve(address(sHny), 10_000e18);
        uint256 sharesAlice = sHny.deposit(10_000e18, alice);
        vm.stopPrank();

        assertEq(sharesAlice, 10_000e18);
        assertEq(sHny.getHNYPerShare(), 1e18);

        // 2. Distributor injects 2,000 HNY in rewards
        vm.startPrank(distributor);
        hny.approve(address(sHny), 2_000e18);
        sHny.distributeRewards(2_000e18);
        vm.stopPrank();

        // Total assets is now 12,000 HNY for 10,000 sHNY shares -> 1.2 HNY per sHNY
        assertEq(sHny.getHNYPerShare(), 1.2e18);

        // 3. Bob deposits 6,000 HNY (gets 5,000 shares)
        vm.startPrank(bob);
        hny.approve(address(sHny), 6_000e18);
        uint256 sharesBob = sHny.deposit(6_000e18, bob);
        vm.stopPrank();

        assertEq(sharesBob, 5_000e18);

        // 4. Distributor injects another 1,500 HNY rewards (total assets = 12k + 6k + 1.5k = 19.5k for 15k shares = 1.3 HNY/share)
        vm.startPrank(distributor);
        hny.approve(address(sHny), 1_500e18);
        sHny.distributeRewards(1_500e18);
        vm.stopPrank();

        assertEq(sHny.getHNYPerShare(), 1.3e18);

        // 5. Alice redeems all shares -> receives 10,000 * 1.3 = 13,000 HNY
        vm.startPrank(alice);
        uint256 aliceAssets = sHny.redeem(sharesAlice, alice, alice);
        vm.stopPrank();

        assertApproxEqAbs(aliceAssets, 13_000e18, 1);
        assertApproxEqAbs(hny.balanceOf(alice), 90_000e18 + 13_000e18, 1);
    }
}
