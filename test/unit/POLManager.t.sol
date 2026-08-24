// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {POLManager} from "../../src/rebalancing/POLManager.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract POLManagerTest is Test {
    HNYToken public hny;
    MockERC20 public reserve;
    POLManager public pol;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public dexPool = address(0x777);

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        reserve = new MockERC20("USD Coin", "USDC", 18);

        pol = new POLManager(address(hny), address(reserve), treasuryVault, owner);

        hny.setMinter(owner, true);
        vm.stopPrank();

        reserve.mint(dexPool, 10_000e18);
        vm.prank(owner);
        hny.mint(dexPool, 10_000e18);
    }

    function test_HarvestFees_BurnsHNYAndRoutesReserve() public {
        vm.prank(owner);
        pol.recordLiquidityDeployment(dexPool, 50_000e18, 50_000e18);

        uint256 reserveFee = 500e18;
        uint256 hnyFee = 300e18;

        vm.startPrank(dexPool);
        reserve.approve(address(pol), reserveFee);
        hny.approve(address(pol), hnyFee);
        uint256 burned = pol.harvestFees(dexPool, reserveFee, hnyFee);
        vm.stopPrank();

        assertEq(burned, 300e18);
        assertEq(reserve.balanceOf(treasuryVault), 500e18);
    }
}
