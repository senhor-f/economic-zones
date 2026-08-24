// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ZoneVault} from "../../src/zones/ZoneVault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract ZoneVaultTest is Test {
    ZoneVault public vault;
    MockERC20 public asset;

    address public owner = address(0xAA);
    address public coreTreasury = address(0xCAFE);
    address public alice = address(0x11);
    address public commercialApp = address(0x22);

    function setUp() public {
        vm.startPrank(owner);
        asset = new MockERC20("USD Coin", "USDC", 18);
        vault = new ZoneVault(address(asset), coreTreasury, owner);
        vm.stopPrank();

        asset.mint(alice, 10_000e18);
        asset.mint(commercialApp, 10_000e18);
    }

    function test_DepositAndRedeem() public {
        vm.startPrank(alice);
        asset.approve(address(vault), 1000e18);
        uint256 shares = vault.deposit(1000e18, alice);
        vm.stopPrank();

        assertEq(shares, 1000e18);
        assertEq(vault.totalAssets(), 1000e18);
        assertEq(vault.balanceOf(alice), 1000e18);

        vm.startPrank(alice);
        uint256 redeemedAssets = vault.redeem(shares, alice, alice);
        vm.stopPrank();

        assertEq(redeemedAssets, 1000e18);
        assertEq(vault.totalAssets(), 0);
    }

    function test_IngestRevenueWithCoreCut() public {
        // Commercial app sends 1000 USDC in revenue to the vault
        vm.startPrank(commercialApp);
        asset.approve(address(vault), 1000e18);
        vault.ingestRevenue(1000e18);
        vm.stopPrank();

        // 20% core cut = 200 USDC sent to coreTreasury, 800 USDC kept in vault
        assertEq(asset.balanceOf(coreTreasury), 200e18);
        assertEq(asset.balanceOf(address(vault)), 800e18);
        assertEq(vault.totalAssets(), 800e18);
    }
}
