// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {ConvictionVoting} from "../../src/zones/ConvictionVoting.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract ConvictionVotingTest is Test {
    HNYToken public hny;
    MockERC20 public fundingToken;
    ConvictionVoting public voting;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public beneficiary = address(0x99);
    address public alice = address(0x11);

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        fundingToken = new MockERC20("USD Coin", "USDC", 18);

        voting = new ConvictionVoting(address(hny), treasuryVault, owner);

        hny.setMinter(owner, true);
        vm.stopPrank();

        // Mint HNY to Alice
        vm.prank(owner);
        hny.mint(alice, 50_000e18);

        // Fund treasuryVault
        fundingToken.mint(treasuryVault, 100_000e18);
        vm.prank(treasuryVault);
        fundingToken.approve(address(voting), type(uint256).max);
    }

    function test_CreateProposalAndStake() public {
        uint256 grantAmount = 1000e18;

        // Alice creates proposal
        vm.prank(alice);
        uint256 propId = voting.createProposal(beneficiary, address(fundingToken), grantAmount, "ipfs://grant-proposal");

        assertEq(propId, 1);

        // Alice stakes her conviction
        vm.prank(alice);
        voting.stake(propId, 50_000e18);

        // Roll blocks forward to accumulate conviction
        vm.roll(block.number + 50);

        uint256 conviction = voting.getConviction(propId);
        assertTrue(conviction > 0);

        // Check threshold
        uint256 threshold = voting.calculateThreshold(propId);
        assertTrue(threshold > 0);

        // Execute proposal once conviction passes threshold
        voting.executeProposal(propId);

        assertEq(fundingToken.balanceOf(beneficiary), grantAmount);
    }
}
