// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {AugmentedBondingCurve} from "../../src/curve/AugmentedBondingCurve.sol";
import {FloorDripper} from "../../src/rebalancing/FloorDripper.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract FloorDripperTest is Test {
    HNYToken public hny;
    MockERC20 public reserve;
    AugmentedBondingCurve public curve;
    FloorDripper public dripper;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public buyer = address(0x11);

    uint256 public constant DRIP_RATE = 1e16; // 0.01 USDC per second

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        reserve = new MockERC20("USD Coin", "USDC", 18);

        curve = new AugmentedBondingCurve(
            address(hny),
            address(reserve),
            treasuryVault,
            owner,
            1e18, // 1.0 basePrice
            1e12,
            50,
            100
        );

        dripper = new FloorDripper(address(reserve), address(curve), DRIP_RATE, owner);

        hny.setMinter(address(curve), true);
        vm.stopPrank();

        // 1. Initial buy on curve to establish supply
        reserve.mint(buyer, 10_000e18);
        vm.startPrank(buyer);
        reserve.approve(address(curve), 1000e18);
        curve.buy(1000e18, 0, buyer);
        vm.stopPrank();

        // 2. Fund dripper with 1000 USDC yield
        reserve.mint(owner, 1000e18);
        vm.startPrank(owner);
        reserve.approve(address(dripper), 1000e18);
        dripper.fundYield(1000e18);
        vm.stopPrank();
    }

    function test_StreamingYieldDripper_IncreasesFloorMonotonically() public {
        uint256 initialFloor = curve.getFloorPrice();

        // Advance 1000 seconds -> 10 USDC dripped
        skip(1000);
        uint256 dripped = dripper.drip();

        assertEq(dripped, 1000 * DRIP_RATE); // 10 USDC

        uint256 newFloor = curve.getFloorPrice();
        assertTrue(newFloor > initialFloor);

        // Advance 10,000 more seconds -> 100 USDC dripped
        skip(10_000);
        dripper.drip();

        uint256 evenHigherFloor = curve.getFloorPrice();
        assertTrue(evenHigherFloor > newFloor);
    }
}
