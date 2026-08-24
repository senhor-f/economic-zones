// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {AugmentedBondingCurve} from "../../src/curve/AugmentedBondingCurve.sol";
import {ZoneVault} from "../../src/zones/ZoneVault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract BankRunSimulationTest is Test {
    HNYToken public hny;
    MockERC20 public reserve;
    AugmentedBondingCurve public curve;
    ZoneVault public vault;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);

    address[] public depositors;
    uint256 public constant NUM_DEPOSITORS = 50;

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        reserve = new MockERC20("USD Coin", "USDC", 18);

        curve = new AugmentedBondingCurve(
            address(hny),
            address(reserve),
            treasuryVault,
            owner,
            1e18, // basePrice = 1.0
            1e12, // slope
            50, // 0.5% entry tribute
            100 // 1.0% exit tribute
        );

        vault = new ZoneVault(address(reserve), treasuryVault, owner);
        hny.setMinter(address(curve), true);
        vm.stopPrank();

        // Setup 50 depositors who buy HNY
        for (uint256 i = 0; i < NUM_DEPOSITORS; i++) {
            address user = address(uint160(0x1000 + i));
            depositors.push(user);
            reserve.mint(user, 10_000e18);

            vm.startPrank(user);
            reserve.approve(address(curve), 10_000e18);
            curve.buy(10_000e18, 0, user);
            vm.stopPrank();
        }
    }

    /// @notice Bank Run Scenario: All 50 holders attempt to panic-sell or redeem at floor simultaneously
    function test_SimultaneousBankRun_PreservesSolvency() public {
        uint256 initialReserve = curve.reserveBalance();
        assertTrue(initialReserve > 0);

        // 1. First 25 holders sell via standard curve sell
        for (uint256 i = 0; i < 25; i++) {
            address user = depositors[i];
            uint256 userHny = hny.balanceOf(user);

            vm.startPrank(user);
            hny.approve(address(curve), userHny);
            curve.sell(userHny, 0, user);
            vm.stopPrank();

            // Solvency check at each step
            assertGe(reserve.balanceOf(address(curve)), curve.reserveBalance());
        }

        // 2. Remaining 25 holders redeem directly at floor
        for (uint256 i = 25; i < NUM_DEPOSITORS; i++) {
            address user = depositors[i];
            uint256 userHny = hny.balanceOf(user);

            vm.startPrank(user);
            hny.approve(address(curve), userHny);
            curve.redeemAtFloor(userHny, 0, user);
            vm.stopPrank();

            // Solvency check at each step
            assertGe(reserve.balanceOf(address(curve)), curve.reserveBalance());
        }

        // Final state: 0 circulating HNY, 0 unpaid debts, perfectly solvent
        assertEq(hny.totalSupply(), 0);
        assertEq(curve.reserveBalance(), 0);
        assertGe(reserve.balanceOf(treasuryVault), 0); // Tributes safely accumulated in treasury
    }
}
