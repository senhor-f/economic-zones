// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ContributionLedger} from "../../src/payments/ContributionLedger.sol";

contract ContributionLedgerDecayTest is Test {
    ContributionLedger public ledger;
    address public owner = address(0xAA);
    address public reporter = address(0xBB);
    address public user = address(0x11);
    uint256 public constant PROJECT_ID = 1;

    function setUp() public {
        vm.startPrank(owner);
        ledger = new ContributionLedger(owner);
        ledger.setReporter(reporter, true);
        vm.stopPrank();
    }

    function test_TemporalDecay_ExpiresStaleTiers() public {
        // 1. Project achieves PLATINUM tier ($1M volume) in Epoch 1
        vm.prank(reporter);
        ledger.recordContribution(PROJECT_ID, user, 1_000_000e18, 10_000e18, 0);

        assertEq(uint256(ledger.getProjectTier(PROJECT_ID)), uint256(ContributionLedger.ProjectTier.PLATINUM));
        assertEq(ledger.getFeeDiscountBps(PROJECT_ID), 100);

        // 2. Advance 31 days and roll to Epoch 2 (1 epoch elapsed -> 50% decay = 500k -> GOLD)
        skip(31 days);
        ledger.rollEpoch();

        assertEq(uint256(ledger.getProjectTier(PROJECT_ID)), uint256(ContributionLedger.ProjectTier.GOLD));
        assertEq(ledger.getFeeDiscountBps(PROJECT_ID), 50);

        // 3. Advance 31 more days to Epoch 3 (2 epochs elapsed -> 25% = 250k -> GOLD)
        skip(31 days);
        ledger.rollEpoch();

        assertEq(uint256(ledger.getProjectTier(PROJECT_ID)), uint256(ContributionLedger.ProjectTier.GOLD));

        // 4. Advance to Epoch 5 (4 epochs elapsed -> 62.5k -> SILVER)
        skip(62 days);
        ledger.rollEpoch();

        assertEq(uint256(ledger.getProjectTier(PROJECT_ID)), uint256(ContributionLedger.ProjectTier.SILVER));
        assertEq(ledger.getFeeDiscountBps(PROJECT_ID), 25);

        // 5. Advance 3 more epochs (7 total epochs -> 7.8k < 10k -> BRONZE)
        skip(93 days);
        ledger.rollEpoch();

        assertEq(uint256(ledger.getProjectTier(PROJECT_ID)), uint256(ContributionLedger.ProjectTier.BRONZE));
        assertEq(ledger.getFeeDiscountBps(PROJECT_ID), 0);
    }
}
