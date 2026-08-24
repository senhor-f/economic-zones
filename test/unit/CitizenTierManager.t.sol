// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {CitizenTierManager} from "../../src/glue/CitizenTierManager.sol";

contract CitizenTierManagerTest is Test {
    HNYToken public hny;
    CitizenTierManager public manager;

    address public owner = address(0xAA);
    address public adapter = address(0x77);
    address public alice = address(0x11);

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        manager = new CitizenTierManager(address(hny), owner);

        manager.setAuthorizedAdapter(adapter, true);
        hny.setMinter(owner, true);
        vm.stopPrank();
    }

    function test_TierProgression() public {
        // Initial tier is NOVICE
        assertEq(uint256(manager.getCitizenTier(alice)), uint256(CitizenTierManager.CitizenTier.NOVICE));
        assertEq(manager.getVotingMultiplierBps(alice), 10000);

        // Add 200 points -> BRONZE
        vm.prank(adapter);
        manager.addPoints(alice, 200);

        assertEq(uint256(manager.getCitizenTier(alice)), uint256(CitizenTierManager.CitizenTier.BRONZE));
        assertEq(manager.getVotingMultiplierBps(alice), 11000);

        // Mint 2500 HNY to Alice -> GOLD
        vm.prank(owner);
        hny.mint(alice, 2500e18);

        assertEq(uint256(manager.getCitizenTier(alice)), uint256(CitizenTierManager.CitizenTier.GOLD));
        assertEq(manager.getVotingMultiplierBps(alice), 15000);
    }
}
