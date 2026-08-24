// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";

contract HNYTokenTest is Test {
    HNYToken public hny;
    address public owner = address(0xAA);
    address public minter = address(0xBB);
    address public alice = address(0x11);
    address public bob = address(0x22);

    function setUp() public {
        vm.prank(owner);
        hny = new HNYToken(owner);

        vm.prank(owner);
        hny.setMinter(minter, true);
    }

    function test_InitialMetadata() public view {
        assertEq(hny.name(), "Honey");
        assertEq(hny.symbol(), "HNY");
        assertEq(hny.decimals(), 18);
        assertEq(hny.totalSupply(), 0);
        assertEq(hny.owner(), owner);
    }

    function test_AuthorizedMint() public {
        vm.prank(minter);
        hny.mint(alice, 1000e18);

        assertEq(hny.balanceOf(alice), 1000e18);
        assertEq(hny.totalSupply(), 1000e18);
    }

    function test_RevertWhen_UnauthorizedMint() public {
        vm.prank(alice);
        vm.expectRevert(HNYToken.NotAuthorizedMinter.selector);
        hny.mint(alice, 1000e18);
    }

    function test_Burn() public {
        vm.prank(minter);
        hny.mint(alice, 1000e18);

        vm.prank(alice);
        hny.burn(400e18);

        assertEq(hny.balanceOf(alice), 600e18);
        assertEq(hny.totalSupply(), 600e18);
    }

    function test_BurnFrom() public {
        vm.prank(minter);
        hny.mint(alice, 1000e18);

        vm.prank(alice);
        hny.approve(bob, 300e18);

        vm.prank(bob);
        hny.burnFrom(alice, 300e18);

        assertEq(hny.balanceOf(alice), 700e18);
        assertEq(hny.totalSupply(), 700e18);
    }
}
