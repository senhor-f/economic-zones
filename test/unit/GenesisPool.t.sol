// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {GenesisPool} from "../../src/token/GenesisPool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract GenesisPoolTest is Test {
    HNYToken public hny;
    MockERC20 public reserve;
    GenesisPool public pool;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public polManager = address(0xDEEE);
    address public bondingCurve = address(0xBEEF);
    address public alice = address(0x11);

    uint256 public constant HARD_CAP = 500_000e18;
    uint256 public constant GENESIS_PRICE = 0.8e18; // 0.80 USDC per HNY
    uint256 public constant DURATION = 14 days;

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        reserve = new MockERC20("USD Coin", "USDC", 18);

        pool = new GenesisPool(
            address(hny),
            address(reserve),
            treasuryVault,
            polManager,
            bondingCurve,
            owner,
            HARD_CAP,
            GENESIS_PRICE,
            DURATION
        );

        hny.setMinter(address(pool), true);
        vm.stopPrank();

        reserve.mint(alice, 100_000e18);
    }

    function test_GenesisDepositAndFinalize() public {
        uint256 depositAmount = 100_000e18;

        vm.startPrank(alice);
        reserve.approve(address(pool), depositAmount);
        uint256 hnyMinted = pool.deposit(depositAmount);
        vm.stopPrank();

        // 100,000 / 0.8 = 125,000 HNY
        assertEq(hnyMinted, 125_000e18);
        assertEq(hny.balanceOf(alice), 125_000e18);
        assertEq(pool.totalRaised(), depositAmount);

        // Warp past deadline
        vm.warp(block.timestamp + 15 days);

        // Finalize pool
        pool.finalize();
        assertTrue(pool.isFinalized());

        // Check distribution: 20% to Treasury, 15% to POL, 65% to Curve
        assertEq(reserve.balanceOf(treasuryVault), 20_000e18);
        assertEq(reserve.balanceOf(polManager), 15_000e18);
        assertEq(reserve.balanceOf(bondingCurve), 65_000e18);
    }
}
