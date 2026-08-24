// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {ProjectRegistry} from "../../src/payments/ProjectRegistry.sol";
import {ContributionLedger} from "../../src/payments/ContributionLedger.sol";
import {ZonePaymentGateway} from "../../src/payments/ZonePaymentGateway.sol";
import {SubscriptionManager} from "../../src/payments/SubscriptionManager.sol";

contract SubscriptionManagerTest is Test {
    HNYToken public hny;
    ProjectRegistry public registry;
    ContributionLedger public ledger;
    ZonePaymentGateway public gateway;
    SubscriptionManager public subManager;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public saasPayout = address(0x88);
    address public subscriber = address(0x11);

    uint256 public projectId;
    uint256 public planId;

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        registry = new ProjectRegistry(owner);
        ledger = new ContributionLedger(owner);

        gateway = new ZonePaymentGateway(
            address(hny),
            address(registry),
            address(ledger),
            treasuryVault,
            owner
        );

        subManager = new SubscriptionManager(
            address(hny),
            address(registry),
            address(gateway),
            owner
        );

        hny.setMinter(owner, true);
        ledger.setReporter(address(gateway), true);
        vm.stopPrank();

        // Register project and create plan ($29 HNY / 30 days)
        projectId = registry.registerProject(saasPayout, "ipfs://saas", 0);

        vm.prank(saasPayout);
        planId = subManager.createPlan(projectId, 29e18, 30 days);

        // Mint HNY to subscriber
        vm.prank(owner);
        hny.mint(subscriber, 1000e18);
    }

    function test_SubscribeAndRecurringBillingWithCashback() public {
        // 1. Subscriber subscribes for 3 months
        vm.startPrank(subscriber);
        hny.approve(address(subManager), 300e18);
        uint256 subId = subManager.subscribe(planId, 3);
        vm.stopPrank();

        // Initial month billed: 29 HNY * 98% = 28.42 to merchant, 0.29 cashback to subscriber
        assertEq(hny.balanceOf(saasPayout), 28.42e18);

        // 2. Advance 31 days -> Keeper triggers 2nd billing
        skip(31 days);
        subManager.processBilling(subId);

        // 2nd month billed
        assertEq(hny.balanceOf(saasPayout), 28.42e18 * 2);

        // 3. Advance 31 more days -> Keeper triggers 3rd (final) billing
        skip(31 days);
        subManager.processBilling(subId);

        assertEq(hny.balanceOf(saasPayout), 28.42e18 * 3);

        // Subscription completes maxPeriods
        (,,,,,,, bool isActive) = subManager.subscriptions(subId);
        assertFalse(isActive);
    }
}
