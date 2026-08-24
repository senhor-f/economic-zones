// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeluxeAssetRebalancer} from "../../src/rebalancing/DeluxeAssetRebalancer.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract DeluxeAssetRebalancerTest is Test {
    DeluxeAssetRebalancer public rebalancer;
    MockERC20 public sellToken;
    MockERC20 public buyToken;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public solver = address(0x999);

    function setUp() public {
        vm.startPrank(owner);
        rebalancer = new DeluxeAssetRebalancer(treasuryVault, owner);
        sellToken = new MockERC20("Token A", "TKNA", 18);
        buyToken = new MockERC20("Token B", "TKNB", 18);

        sellToken.mint(owner, 10_000e18);
        buyToken.mint(solver, 10_000e18);
        vm.stopPrank();
    }

    function test_StartAndFillDutchAuction() public {
        uint256 sellAmount = 1000e18;
        uint256 startPrice = 1.05e18; // 1.05 TKNB per TKNA
        uint256 minPrice = 0.95e18; // 0.95 TKNB per TKNA
        uint256 duration = 1 hours;

        vm.startPrank(owner);
        sellToken.approve(address(rebalancer), sellAmount);
        uint256 auctionId =
            rebalancer.startAuction(address(sellToken), address(buyToken), sellAmount, startPrice, minPrice, duration);
        vm.stopPrank();

        // Warp 30 minutes in (halfway through auction)
        vm.warp(block.timestamp + 30 minutes);

        uint256 currentPrice = rebalancer.getCurrentPrice(auctionId);
        assertEq(currentPrice, 1.0e18); // Exactly halfway between 1.05 and 0.95

        // Solver fills the auction
        vm.startPrank(solver);
        buyToken.approve(address(rebalancer), 1000e18);
        uint256 cost = rebalancer.fillAuction(auctionId, 1000e18);
        vm.stopPrank();

        assertEq(cost, 1000e18);
        assertEq(buyToken.balanceOf(treasuryVault), 1000e18);
        assertEq(sellToken.balanceOf(solver), 1000e18);
    }
}
