// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {ContinuousPayrollStreamer} from "../../src/payments/ContinuousPayrollStreamer.sol";

contract ContinuousPayrollStreamerTest is Test {
    HNYToken public hny;
    ContinuousPayrollStreamer public streamer;

    address public owner = address(0xAA);
    address public employer = address(0xEEEE);
    address public worker = address(0x9999);
    address public taxCollector = address(0x7777);

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        streamer = new ContinuousPayrollStreamer(owner);

        hny.setMinter(owner, true);
        hny.mint(employer, 100_000e18);
        vm.stopPrank();
    }

    function test_CreateStream_Vesting_AndWithdrawalWithTax() public {
        uint256 duration = 30 days; // 2,592,000 seconds
        uint256 rate = 1e18; // 1 HNY per second
        uint256 deposit = rate * duration; // ~2.592M HNY

        vm.prank(owner);
        hny.mint(employer, deposit);

        // 1. Employer creates stream with 5% tax withholding (500 bps)
        vm.startPrank(employer);
        hny.approve(address(streamer), deposit);
        uint256 streamId = streamer.createStream(worker, address(hny), deposit, duration, 500, taxCollector);
        vm.stopPrank();

        assertEq(streamId, 1);

        // 2. Warp 10 days
        vm.warp(block.timestamp + 10 days);
        uint256 vested = streamer.vestedAmountOf(streamId);
        assertEq(vested, 10 days * 1e18);

        // 3. Worker withdraws 1,000 HNY
        vm.startPrank(worker);
        (uint256 netPaid, uint256 taxPaid) = streamer.withdrawFromStream(streamId, 1_000e18);
        vm.stopPrank();

        // 5% tax on 1,000 = 50 HNY, 950 HNY net
        assertEq(taxPaid, 50e18);
        assertEq(netPaid, 950e18);
        assertEq(hny.balanceOf(worker), 950e18);
        assertEq(hny.balanceOf(taxCollector), 50e18);

        // 4. Cancel stream after 15 days total
        vm.warp(block.timestamp + 5 days);
        vm.prank(employer);
        (uint256 refund, uint256 recipientVested) = streamer.cancelStream(streamId);

        // 15 days total vested = 15 days * 1e18 = 1,296,000 HNY. Unvested = 15 days * 1e18 refunded to employer.
        assertEq(refund, 15 days * 1e18);
        assertTrue(recipientVested > 0);
    }
}
