// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {AugmentedBondingCurve} from "../../src/curve/AugmentedBondingCurve.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {CurveHandler} from "./CurveHandler.sol";

contract CurveInvariantTest is Test {
    HNYToken public hny;
    MockERC20 public reserve;
    AugmentedBondingCurve public curve;
    CurveHandler public handler;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        reserve = new MockERC20("USD Coin", "USDC", 18);

        curve = new AugmentedBondingCurve(
            address(hny),
            address(reserve),
            treasuryVault,
            owner,
            1e18, // basePrice
            1e12, // slope
            50, // entry tribute (0.5%)
            100 // exit tribute (1.0%)
        );

        hny.setMinter(address(curve), true);
        vm.stopPrank();

        handler = new CurveHandler(hny, reserve, curve);
        targetContract(address(handler));
    }

    /// @notice Invariant 1: Total Supply Conservation (TotalSupply == Minted - Burned)
    function invariant_SupplyConservation() public view {
        assertEq(
            hny.totalSupply(),
            handler.ghost_totalHnyMinted() - handler.ghost_totalHnyBurned(),
            "Invariant Violation: Token supply does not match ghost minted minus burned"
        );
    }

    /// @notice Invariant 2: Curve Solvency (Reserve in contract >= internal reserveBalance)
    function invariant_Solvency() public view {
        assertGe(
            reserve.balanceOf(address(curve)),
            curve.reserveBalance(),
            "Invariant Violation: Physical reserve less than tracked curve reserve"
        );
    }

    /// @notice Invariant 3: Floor Price is always positive
    function invariant_FloorPricePositive() public view {
        assertGt(curve.getFloorPrice(), 0, "Invariant Violation: Floor price dropped to zero");
    }
}
