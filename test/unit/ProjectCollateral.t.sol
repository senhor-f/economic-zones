// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ProjectCollateral} from "../../src/payments/ProjectCollateral.sol";
import {ContributionLedger} from "../../src/payments/ContributionLedger.sol";
import {ProjectRegistry} from "../../src/payments/ProjectRegistry.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract ProjectCollateralTest is Test {
    ProjectCollateral public collateral;
    ContributionLedger public ledger;
    ProjectRegistry public registry;
    MockERC20 public usdc;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public projectPayout = address(0x88);
    uint256 public projectId;

    function setUp() public {
        vm.startPrank(owner);
        usdc = new MockERC20("USD Coin", "USDC", 18);
        ledger = new ContributionLedger(owner);
        registry = new ProjectRegistry(owner);

        collateral = new ProjectCollateral(
            address(usdc),
            address(ledger),
            address(registry),
            treasuryVault,
            5000e18, // 5000 USDC min
            owner
        );
        vm.stopPrank();

        // Register project
        projectId = registry.registerProject(projectPayout, "ipfs://meta", 0);
        usdc.mint(projectPayout, 10_000e18);
    }

    function test_DepositAndWithdrawAfterCooldown() public {
        uint256 depositAmt = 5000e18;

        vm.startPrank(projectPayout);
        usdc.approve(address(collateral), depositAmt);
        collateral.depositCollateral(projectId, depositAmt);

        // Request unlock
        collateral.requestUnlock(projectId);

        // Advance 14 days
        skip(14 days);
        uint256 withdrawn = collateral.withdrawCollateral(projectId);
        vm.stopPrank();

        assertEq(withdrawn, depositAmt);
        assertEq(usdc.balanceOf(projectPayout), 10_000e18);
    }

    function test_SlashInactiveProject_RoutesToTreasury() public {
        uint256 depositAmt = 5000e18;

        vm.startPrank(projectPayout);
        usdc.approve(address(collateral), depositAmt);
        collateral.depositCollateral(projectId, depositAmt);
        vm.stopPrank();

        // Advance 4 epochs (124 days) with 0 activity
        for (uint256 i = 0; i < 4; i++) {
            skip(31 days);
            ledger.rollEpoch();
        }

        // Keeper slashes inactive project
        uint256 slashed = collateral.slashInactiveProject(projectId);
        assertEq(slashed, depositAmt);
        assertEq(usdc.balanceOf(treasuryVault), depositAmt);
    }
}
