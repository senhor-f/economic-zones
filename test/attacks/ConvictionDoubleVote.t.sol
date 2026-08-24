// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {ConvictionVoting} from "../../src/zones/ConvictionVoting.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract ConvictionDoubleVoteTest is Test {
    HNYToken public hny;
    MockERC20 public fundingToken;
    ConvictionVoting public voting;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public attacker = address(0x666);
    address public beneficiary1 = address(0x91);
    address public beneficiary2 = address(0x92);

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        fundingToken = new MockERC20("USD Coin", "USDC", 18);

        voting = new ConvictionVoting(address(hny), treasuryVault, owner);

        hny.setMinter(owner, true);
        vm.stopPrank();

        // Attacker has 10,000 HNY
        vm.prank(owner);
        hny.mint(attacker, 10_000e18);
    }

    /// @notice Attack Scenario: Attacker attempts to stake 10,000 HNY in Proposal 1 AND another 10,000 HNY in Proposal 2
    function test_DoubleVotingAcrossProposals_IsBlocked() public {
        uint256 prop1 = voting.createProposal(beneficiary1, address(fundingToken), 1000e18, "ipfs://prop1");
        uint256 prop2 = voting.createProposal(beneficiary2, address(fundingToken), 1000e18, "ipfs://prop2");

        // 1. Attacker stakes full 10,000 HNY on Proposal 1
        vm.prank(attacker);
        voting.stake(prop1, 10_000e18);

        // 2. Attacker attempts to stake again on Proposal 2 without having more tokens
        vm.prank(attacker);
        vm.expectRevert(ConvictionVoting.InsufficientBalance.selector);
        voting.stake(prop2, 10_000e18);

        // 3. Attacker reduces stake on Proposal 1 to 4,000 and can now stake 6,000 on Proposal 2
        vm.prank(attacker);
        voting.stake(prop1, 4_000e18);

        vm.prank(attacker);
        voting.stake(prop2, 6_000e18);

        assertEq(voting.userStake(prop1, attacker), 4_000e18);
        assertEq(voting.userStake(prop2, attacker), 6_000e18);
        assertEq(voting.totalUserStakedAcrossProposals(attacker), 10_000e18);
    }
}
