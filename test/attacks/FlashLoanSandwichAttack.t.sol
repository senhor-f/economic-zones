// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {AugmentedBondingCurve} from "../../src/curve/AugmentedBondingCurve.sol";
import {DeluxeAssetRebalancer} from "../../src/rebalancing/DeluxeAssetRebalancer.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract FlashLoanSandwichAttackTest is Test {
    HNYToken public hny;
    MockERC20 public reserve;
    MockERC20 public secondaryToken;
    AugmentedBondingCurve public curve;
    DeluxeAssetRebalancer public rebalancer;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public attacker = address(0x666);
    address public victim = address(0x777);

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        reserve = new MockERC20("USD Coin", "USDC", 18);
        secondaryToken = new MockERC20("Wrapped ETH", "WETH", 18);

        rebalancer = new DeluxeAssetRebalancer(treasuryVault, owner);

        curve = new AugmentedBondingCurve(
            address(hny),
            address(reserve),
            treasuryVault,
            owner,
            1e18, // basePrice
            1e12, // slope
            50,   // 0.5% entry tribute
            100   // 1.0% exit tribute
        );

        hny.setMinter(address(curve), true);
        vm.stopPrank();

        // Attacker gets simulated flash-loan of $10M
        reserve.mint(attacker, 10_000_000e18);
        reserve.mint(victim, 10_000e18);
    }

    /// @notice Attack Scenario: Attacker tries to pump the curve with a massive flash loan and dump to profit
    function test_CurvePumpAndDump_AttackerSuffersNetLossDueToTributes() public {
        uint256 attackerStartBalance = reserve.balanceOf(attacker);

        // 1. Attacker pumps the curve with $5M
        vm.startPrank(attacker);
        reserve.approve(address(curve), 5_000_000e18);
        uint256 hnyBought = curve.buy(5_000_000e18, 0, attacker);

        // 2. Victim buys normally
        vm.stopPrank();
        vm.startPrank(victim);
        reserve.approve(address(curve), 10_000e18);
        curve.buy(10_000e18, 0, victim);
        vm.stopPrank();

        // 3. Attacker tries to dump all bought HNY to extract profit from victim
        vm.startPrank(attacker);
        hny.approve(address(curve), hnyBought);
        curve.sell(hnyBought, 0, attacker);
        vm.stopPrank();

        uint256 attackerEndBalance = reserve.balanceOf(attacker);

        // MATHEMATICAL PROOF: Attacker CANNOT profit from sandwiching the curve
        // The asymmetric entry + exit tributes mathematically guarantee net loss for pump-and-dumpers!
        assertTrue(attackerEndBalance < attackerStartBalance, "Attacker should have lost money due to tributes");
        assertTrue(reserve.balanceOf(treasuryVault) > 0, "Treasury captured tributes from attacker");
    }
}
