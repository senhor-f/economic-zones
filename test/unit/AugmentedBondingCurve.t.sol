// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {AugmentedBondingCurve} from "../../src/curve/AugmentedBondingCurve.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract AugmentedBondingCurveTest is Test {
    HNYToken public hny;
    MockERC20 public reserve;
    AugmentedBondingCurve public curve;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public alice = address(0x11);
    address public bob = address(0x22);

    uint256 public constant BASE_PRICE = 1e18; // 1 reserve per HNY
    uint256 public constant SLOPE = 1e12; // gentle slope
    uint256 public constant ENTRY_TRIBUTE_BPS = 50; // 0.5%
    uint256 public constant EXIT_TRIBUTE_BPS = 100; // 1.0%

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        reserve = new MockERC20("USD Coin", "USDC", 18);

        curve = new AugmentedBondingCurve(
            address(hny), address(reserve), treasuryVault, owner, BASE_PRICE, SLOPE, ENTRY_TRIBUTE_BPS, EXIT_TRIBUTE_BPS
        );

        hny.setMinter(address(curve), true);
        vm.stopPrank();

        reserve.mint(alice, 100_000e18);
        reserve.mint(bob, 100_000e18);
    }

    function test_InitialState() public view {
        assertEq(curve.getSpotPrice(), BASE_PRICE);
        assertEq(curve.getFloorPrice(), BASE_PRICE);
        assertEq(curve.reserveBalance(), 0);
    }

    function test_BuyHNY() public {
        uint256 buyAmount = 1000e18;

        vm.startPrank(alice);
        reserve.approve(address(curve), buyAmount);
        uint256 hnyReceived = curve.buy(buyAmount, 0, alice);
        vm.stopPrank();

        assertTrue(hnyReceived > 0);
        assertEq(hny.balanceOf(alice), hnyReceived);

        // Check entry tribute went to treasury vault
        uint256 expectedTribute = (buyAmount * ENTRY_TRIBUTE_BPS) / 10_000;
        assertEq(reserve.balanceOf(treasuryVault), expectedTribute);
        assertEq(curve.reserveBalance(), buyAmount - expectedTribute);

        // Spot price and floor should be healthy
        assertTrue(curve.getSpotPrice() >= BASE_PRICE);
    }

    function test_SellHNY() public {
        // 1. Alice buys
        vm.startPrank(alice);
        reserve.approve(address(curve), 10_000e18);
        uint256 hnyReceived = curve.buy(10_000e18, 0, alice);

        // 2. Alice sells half
        uint256 hnyToSell = hnyReceived / 2;
        hny.approve(address(curve), hnyToSell);
        uint256 reserveReceived = curve.sell(hnyToSell, 0, alice);
        vm.stopPrank();

        assertTrue(reserveReceived > 0);
        assertEq(hny.balanceOf(alice), hnyReceived - hnyToSell);
    }

    function test_RedeemAtFloor() public {
        // 1. Alice buys
        vm.startPrank(alice);
        reserve.approve(address(curve), 10_000e18);
        uint256 hnyReceived = curve.buy(10_000e18, 0, alice);

        // 2. Alice redeems at floor
        hny.approve(address(curve), hnyReceived);
        uint256 reserveRedeemed = curve.redeemAtFloor(hnyReceived, 0, alice);
        vm.stopPrank();

        assertTrue(reserveRedeemed > 0);
        assertEq(hny.balanceOf(alice), 0);
        assertEq(hny.totalSupply(), 0);
        assertEq(curve.reserveBalance(), 0);
    }
}
