// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {AugmentedBondingCurve} from "../../src/curve/AugmentedBondingCurve.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract CurveHandler is Test {
    HNYToken public hny;
    MockERC20 public reserve;
    AugmentedBondingCurve public curve;

    address[] public actors;
    address public currentActor;

    // Ghost variables
    uint256 public ghost_totalReserveDeposited;
    uint256 public ghost_totalReserveWithdrawn;
    uint256 public ghost_totalHnyMinted;
    uint256 public ghost_totalHnyBurned;

    constructor(HNYToken _hny, MockERC20 _reserve, AugmentedBondingCurve _curve) {
        hny = _hny;
        reserve = _reserve;
        curve = _curve;

        actors.push(address(0x101));
        actors.push(address(0x102));
        actors.push(address(0x103));

        for (uint256 i = 0; i < actors.length; i++) {
            reserve.mint(actors[i], 1_000_000e18);
        }
    }

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[actorIndexSeed % actors.length];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    function buy(uint256 actorSeed, uint256 reserveAmount) public useActor(actorSeed) {
        reserveAmount = bound(reserveAmount, 1e18, 50_000e18);

        uint256 balance = reserve.balanceOf(currentActor);
        if (balance < reserveAmount) {
            reserve.mint(currentActor, reserveAmount);
        }

        reserve.approve(address(curve), reserveAmount);
        uint256 hnyOut = curve.buy(reserveAmount, 0, currentActor);

        ghost_totalReserveDeposited += reserveAmount;
        ghost_totalHnyMinted += hnyOut;
    }

    function sell(uint256 actorSeed, uint256 hnyAmount) public useActor(actorSeed) {
        uint256 userHny = hny.balanceOf(currentActor);
        if (userHny == 0) return;

        hnyAmount = bound(hnyAmount, 1e15, userHny);
        if (hnyAmount > hny.totalSupply()) return;

        hny.approve(address(curve), hnyAmount);
        uint256 reserveOut = curve.sell(hnyAmount, 0, currentActor);

        ghost_totalHnyBurned += hnyAmount;
        ghost_totalReserveWithdrawn += reserveOut;
    }

    function redeemAtFloor(uint256 actorSeed, uint256 hnyAmount) public useActor(actorSeed) {
        uint256 userHny = hny.balanceOf(currentActor);
        if (userHny == 0 || curve.reserveBalance() == 0) return;

        hnyAmount = bound(hnyAmount, 1e15, userHny);
        if (hnyAmount > hny.totalSupply()) return;

        hny.approve(address(curve), hnyAmount);
        uint256 reserveOut = curve.redeemAtFloor(hnyAmount, 0, currentActor);

        ghost_totalHnyBurned += hnyAmount;
        ghost_totalReserveWithdrawn += reserveOut;
    }
}
