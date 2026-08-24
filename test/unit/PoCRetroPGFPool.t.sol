// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {PoCRetroPGFPool} from "../../src/zones/PoCRetroPGFPool.sol";
import {ContributionLedger} from "../../src/payments/ContributionLedger.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract PoCRetroPGFPoolTest is Test {
    PoCRetroPGFPool public pool;
    ContributionLedger public ledger;
    MockERC20 public fundingToken;

    address public owner = address(0xAA);
    address public reporter = address(0xBB);
    address public project1Payout = address(0x91); // Low commerce (Bronze)
    address public project2Payout = address(0x92); // High commerce (Gold)
    address public voter = address(0x11);

    uint256 public constant PROJECT_1 = 1;
    uint256 public constant PROJECT_2 = 2;

    function setUp() public {
        vm.startPrank(owner);
        fundingToken = new MockERC20("USD Coin", "USDC", 18);
        ledger = new ContributionLedger(owner);
        ledger.setReporter(reporter, true);

        pool = new PoCRetroPGFPool(address(fundingToken), address(ledger), owner);

        fundingToken.mint(owner, 100_000e18);
        fundingToken.mint(voter, 10_000e18);
        vm.stopPrank();

        // Project 2 has $150k active volume -> GOLD Tier (1.5x boost)
        vm.prank(reporter);
        ledger.recordContribution(PROJECT_2, address(0x999), 150_000e18, 1500e18, 0);
    }

    function test_ProofOfCommerceBoostsMatchingShare() public {
        uint256[] memory projectIds = new uint256[](2);
        projectIds[0] = PROJECT_1;
        projectIds[1] = PROJECT_2;

        address[] memory payouts = new address[](2);
        payouts[0] = project1Payout;
        payouts[1] = project2Payout;

        // 1. Start round with 10,000 USDC matching pool
        vm.startPrank(owner);
        fundingToken.approve(address(pool), 10_000e18);
        pool.startRound(10_000e18, 7 days, projectIds, payouts);
        vm.stopPrank();

        // 2. Voter donates same 100 USDC to BOTH projects
        vm.startPrank(voter);
        fundingToken.approve(address(pool), 200e18);
        pool.vote(PROJECT_1, 100e18);
        pool.vote(PROJECT_2, 100e18);
        vm.stopPrank();

        // 3. Advance past deadline
        skip(8 days);

        // 4. Claim payouts
        uint256 payout1 = pool.claimPayout(PROJECT_1);
        uint256 payout2 = pool.claimPayout(PROJECT_2);

        // Project 2 gets 1.5x higher matching than Project 1 despite identical votes!
        // Project 1: 100 donation + 4000 matching = 4100
        // Project 2: 100 donation + 6000 matching = 6100
        assertTrue(payout2 > payout1);
        assertEq(payout1, 100e18 + 4000e18);
        assertEq(payout2, 100e18 + 6000e18);
    }
}
