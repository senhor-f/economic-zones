// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ProjectRegistry} from "../../src/payments/ProjectRegistry.sol";
import {RetroPGFPool} from "../../src/zones/RetroPGFPool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract RetroPGFPoolTest is Test {
    ProjectRegistry public registry;
    RetroPGFPool public pool;
    MockERC20 public rewardToken;

    address public owner = address(0xAA);
    address public voter1 = address(0x11);
    address public voter2 = address(0x22);
    address public projectPayout = address(0x88);

    uint256 public projectId;

    function setUp() public {
        vm.startPrank(owner);
        registry = new ProjectRegistry(owner);
        pool = new RetroPGFPool(address(registry), owner);
        rewardToken = new MockERC20("USD Coin", "USDC", 18);

        pool.setBadgeholder(voter1, true);
        pool.setBadgeholder(voter2, true);

        rewardToken.mint(owner, 100_000e18);
        rewardToken.approve(address(pool), 100_000e18);
        vm.stopPrank();

        // Register project
        projectId = registry.registerProject(projectPayout, "ipfs://open-source-tooling", 4);
    }

    function test_RetroPGFQuadraticVotingAndClaim() public {
        uint256 roundBudget = 10_000e18;
        uint256 roundDuration = 7 days;

        // 1. Owner creates round
        vm.prank(owner);
        uint256 roundId = pool.createRound(address(rewardToken), roundBudget, roundDuration);

        // 2. Voter 1 votes 100 points, Voter 2 votes 100 points
        vm.prank(voter1);
        pool.vote(roundId, projectId, 100e18);

        vm.prank(voter2);
        pool.vote(roundId, projectId, 100e18);

        // 3. Warp past round duration
        vm.warp(block.timestamp + 8 days);

        // 4. Finalize round
        uint256[] memory pids = new uint256[](1);
        pids[0] = projectId;

        vm.prank(owner);
        pool.finalizeRound(roundId, pids);

        // 5. Claim reward
        uint256 reward = pool.claimReward(roundId, projectId);
        assertEq(reward, roundBudget);
        assertEq(rewardToken.balanceOf(projectPayout), roundBudget);
    }
}
