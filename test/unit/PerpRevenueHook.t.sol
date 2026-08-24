// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {ContributionLedger} from "../../src/payments/ContributionLedger.sol";
import {PerpRevenueHook} from "../../src/hooks/PerpRevenueHook.sol";

contract PerpRevenueHookTest is Test {
    HNYToken public hny;
    ContributionLedger public ledger;
    PerpRevenueHook public hook;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public perpRouter = address(0x777);
    address public trader = address(0x123);

    uint256 public constant PROJECT_ID = 1;

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        ledger = new ContributionLedger(owner);

        hook = new PerpRevenueHook(address(hny), address(ledger), treasuryVault, owner);

        ledger.setReporter(address(hook), true);
        hook.setAuthorizedRouter(perpRouter, true);
        hny.setMinter(owner, true);
        vm.stopPrank();

        // Mint HNY to router
        vm.prank(owner);
        hny.mint(perpRouter, 10_000e18);
    }

    function test_PerpTradeFeeRouting() public {
        uint256 notionalVolume = 100_000e18; // $100k perp trade
        uint256 feeAmount = 60e18; // 0.06% fee = 60 HNY

        vm.startPrank(perpRouter);
        hny.approve(address(hook), feeAmount);
        (uint256 burned, uint256 treasuryCut, uint256 cashback) =
            hook.onPerpTradeExecuted(PROJECT_ID, trader, notionalVolume, feeAmount);
        vm.stopPrank();

        // 50% burn = 30 HNY, 30% treasury = 18 HNY, 20% cashback = 12 HNY
        assertEq(burned, 30e18);
        assertEq(treasuryCut, 18e18);
        assertEq(cashback, 12e18);

        assertEq(hny.balanceOf(treasuryVault), 18e18);
        assertEq(hny.balanceOf(trader), 12e18);

        // Verify contribution ledger metrics
        (uint256 vol, uint256 rev, uint256 burnedAmount, uint256 txs, uint256 users) = ledger.metrics(PROJECT_ID);
        assertEq(vol, notionalVolume);
        assertEq(rev, 18e18);
        assertEq(burnedAmount, 30e18);
        assertEq(txs, 1);
        assertEq(users, 1);
    }
}
