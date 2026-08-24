// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MilestoneFutarchy} from "../../src/governance/MilestoneFutarchy.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract MilestoneFutarchyTest is Test {
    MilestoneFutarchy public futarchy;
    MockERC20 public usdc;
    MockERC20 public fundingToken;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public builder = address(0x99);
    address public bullPredictor = address(0x11);
    address public bearPredictor = address(0x22);

    function setUp() public {
        vm.startPrank(owner);
        usdc = new MockERC20("USD Coin", "USDC", 18);
        fundingToken = new MockERC20("HNY Token", "HNY", 18);

        futarchy = new MilestoneFutarchy(
            address(usdc),
            treasuryVault,
            owner
        );
        vm.stopPrank();

        fundingToken.mint(owner, 100_000e18);
        usdc.mint(bullPredictor, 10_000e18);
        usdc.mint(bearPredictor, 10_000e18);
    }

    function test_MilestonePasses_ReleasesTrancheAndRewardsWinners() public {
        uint256 trancheAmount = 25_000e18;

        // 1. Create milestone escrow funded by owner
        vm.startPrank(owner);
        fundingToken.approve(address(futarchy), trancheAmount);
        uint256 milestoneId = futarchy.createMilestone(
            1, // Grant #1
            1, // Tranche #1
            trancheAmount,
            builder,
            address(fundingToken),
            7 days
        );
        vm.stopPrank();

        // 2. Predictors bet: Bull bets $3000 on YES, Bear bets $1000 on NO (75% YES confidence)
        vm.startPrank(bullPredictor);
        usdc.approve(address(futarchy), 3000e18);
        futarchy.predict(milestoneId, true, 3000e18);
        vm.stopPrank();

        vm.startPrank(bearPredictor);
        usdc.approve(address(futarchy), 1000e18);
        futarchy.predict(milestoneId, false, 1000e18);
        vm.stopPrank();

        // 3. Advance past deadline
        skip(8 days);

        // 4. Resolve milestone
        futarchy.resolveMilestone(milestoneId);

        // Verify tranche released to builder
        assertEq(fundingToken.balanceOf(builder), trancheAmount);

        // 5. Bull claims reward from prediction pool (all $4000)
        vm.prank(bullPredictor);
        uint256 reward = futarchy.claimPredictionReward(milestoneId);
        assertEq(reward, 4000e18);
        assertEq(usdc.balanceOf(bullPredictor), 11_000e18); // +$1000 profit
    }
}
