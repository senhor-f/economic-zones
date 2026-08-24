// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {AugmentedBondingCurve} from "../../src/curve/AugmentedBondingCurve.sol";
import {TreasuryYieldVault} from "../../src/rebalancing/TreasuryYieldVault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract TreasuryYieldVaultTest is Test {
    HNYToken public hny;
    MockERC20 public usdc;
    AugmentedBondingCurve public curve;
    TreasuryYieldVault public vault;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public daoTreasury = address(0x55);
    address public strategyManager = address(0x77);

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        usdc = new MockERC20("USD Coin", "USDC", 18);

        curve = new AugmentedBondingCurve(
            address(hny),
            address(usdc),
            treasuryVault,
            owner,
            1e18,
            1e12,
            50,
            100
        );

        vault = new TreasuryYieldVault(
            address(usdc),
            address(curve),
            owner
        );

        hny.setMinter(address(curve), true);
        vm.stopPrank();

        usdc.mint(daoTreasury, 1_000_000e18); // DAO has 1M USDC
        usdc.mint(strategyManager, 100_000e18); // Strategy generates 100k USDC yield
    }

    function test_DAODeposit_YieldHarvest_AndFullRedeem() public {
        uint256 depositAmt = 500_000e18;

        // 1. DAO deposits 500k USDC
        vm.startPrank(daoTreasury);
        usdc.approve(address(vault), depositAmt);
        uint256 shares = vault.deposit(depositAmt, daoTreasury);
        vm.stopPrank();

        assertEq(shares, depositAmt);
        assertEq(vault.totalAssets(), depositAmt);

        // 2. Strategy manager harvests 50k USDC gross yield
        uint256 grossYield = 50_000e18;
        vm.startPrank(strategyManager);
        usdc.approve(address(vault), grossYield);
        (uint256 daoCut, uint256 floorCut) = vault.harvestYield(grossYield);
        vm.stopPrank();

        // 80% to DAO (40k), 20% to Curve Floor (10k)
        assertEq(daoCut, 40_000e18);
        assertEq(floorCut, 10_000e18);
        assertEq(usdc.balanceOf(address(curve)), 10_000e18);

        // 3. DAO redeems all shares -> receives 500k principal + 40k interest (~540k USDC)
        vm.startPrank(daoTreasury);
        uint256 assetsReceived = vault.redeem(shares, daoTreasury, daoTreasury);
        vm.stopPrank();

        assertApproxEqAbs(assetsReceived, 540_000e18, 1);
        assertApproxEqAbs(usdc.balanceOf(daoTreasury), 500_000e18 + 540_000e18, 1);
    }
}
