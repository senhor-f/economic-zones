// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {ProjectRegistry} from "../../src/payments/ProjectRegistry.sol";
import {ContributionLedger} from "../../src/payments/ContributionLedger.sol";
import {ZonePaymentGateway} from "../../src/payments/ZonePaymentGateway.sol";

contract ZonePaymentGatewayTest is Test {
    HNYToken public hny;
    ProjectRegistry public registry;
    ContributionLedger public ledger;
    ZonePaymentGateway public gateway;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public projectOwner = address(0x99);
    address public projectPayout = address(0x88);
    address public alice = address(0x11);

    uint256 public projectId;

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        registry = new ProjectRegistry(owner);
        ledger = new ContributionLedger(owner);

        gateway = new ZonePaymentGateway(address(hny), address(registry), address(ledger), treasuryVault, owner);

        // Authorize gateway to report contributions
        ledger.setReporter(address(gateway), true);
        hny.setMinter(owner, true);
        vm.stopPrank();

        // Register project
        vm.prank(projectOwner);
        projectId = registry.registerProject(projectPayout, "ipfs://project-metadata", 0);

        // Mint HNY to Alice
        vm.prank(owner);
        hny.mint(alice, 10_000e18);
    }

    function test_PaymentWithInstantCashback() public {
        uint256 payAmount = 100e18;

        vm.startPrank(alice);
        hny.approve(address(gateway), payAmount);
        (uint256 netProject, uint256 cashback) = gateway.pay(projectId, payAmount);
        vm.stopPrank();

        // 2% base fee = 2 HNY. 50% cashback = 1 HNY. Net project = 98 HNY. Treasury = 1 HNY.
        assertEq(netProject, 98e18);
        assertEq(cashback, 1e18);
        assertEq(hny.balanceOf(projectPayout), 98e18);
        assertEq(hny.balanceOf(treasuryVault), 1e18);
        assertEq(hny.balanceOf(alice), 10_000e18 - payAmount + cashback);

        (uint256 vol, uint256 epochVol, uint256 rev, uint256 burned, uint256 txs, uint256 users, uint256 lastEpoch) = ledger.metrics(projectId);
        assertEq(vol, 100e18);
        assertEq(epochVol, 100e18);
        assertEq(rev, 1e18);
        assertEq(burned, 0);
        assertEq(txs, 1);
        assertEq(users, 1);
        assertEq(lastEpoch, 1);
    }

    function test_ProjectTierDiscount() public {
        // Set higher volume on project to reach GOLD tier ($100k)
        address reporter = address(0x77);
        vm.prank(owner);
        ledger.setReporter(reporter, true);

        vm.prank(reporter);
        ledger.recordContribution(projectId, address(0x33), 150_000e18, 1500e18, 0);

        // Gold tier has 50 bps discount (fee drops from 200 bps to 150 bps)
        uint256 payAmount = 100e18;
        vm.startPrank(alice);
        hny.approve(address(gateway), payAmount);
        (uint256 netProject, uint256 cashback) = gateway.pay(projectId, payAmount);
        vm.stopPrank();

        // Effective fee = 1.50% (1.50 HNY). Net to project = 98.50 HNY. Cashback = 0.75 HNY.
        assertEq(netProject, 98.5e18);
        assertEq(cashback, 0.75e18);
    }
}
