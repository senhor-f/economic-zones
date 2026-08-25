// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {ZoneClearingHouse} from "../../src/zones/ZoneClearingHouse.sol";

contract ZoneClearingHouseTest is Test {
    MockERC20 public usdc;
    ZoneClearingHouse public clearingHouse;

    address public owner = address(0xAA);
    address public recorder = address(0xBB);
    address public zone1Vault = address(0x1111);
    address public zone2Vault = address(0x2222);

    uint256 public zone1Id = 1;
    uint256 public zone2Id = 2;

    function setUp() public {
        vm.startPrank(owner);
        usdc = new MockERC20("USD Coin", "USDC", 18);
        clearingHouse = new ZoneClearingHouse(owner);

        clearingHouse.setAuthorizedRecorder(recorder, true);
        clearingHouse.setZoneSettlementVault(zone1Id, zone1Vault);
        clearingHouse.setZoneSettlementVault(zone2Id, zone2Vault);
        vm.stopPrank();

        usdc.mint(zone2Vault, 50_000e18);
    }

    function test_CrossZoneBilateralNetting_AndSettlement() public {
        // 1. Zone 1 exports 10,000 USDC of services to Zone 2 (Zone 2 debtor, Zone 1 creditor)
        vm.prank(recorder);
        clearingHouse.recordCrossZoneTrade(zone1Id, zone2Id, address(usdc), 10_000e18);

        assertEq(clearingHouse.netBilateralBalances(zone1Id, zone2Id), 10_000e18);
        assertEq(clearingHouse.netBilateralBalances(zone2Id, zone1Id), -10_000e18);

        // 2. Zone 2 exports 3,000 USDC of goods to Zone 1 (Zone 1 debtor, Zone 2 creditor)
        vm.prank(recorder);
        clearingHouse.recordCrossZoneTrade(zone2Id, zone1Id, address(usdc), 3_000e18);

        // Net balance: Zone 2 owes Zone 1 exactly 7,000 USDC
        assertEq(clearingHouse.netBilateralBalances(zone1Id, zone2Id), 7_000e18);
        assertEq(clearingHouse.netBilateralBalances(zone2Id, zone1Id), -7_000e18);

        // 3. Settle net balance
        vm.prank(zone2Vault);
        usdc.approve(address(clearingHouse), 7_000e18);

        clearingHouse.settleNetBalance(zone1Id, zone2Id, address(usdc));

        // Balances cleared
        assertEq(clearingHouse.netBilateralBalances(zone1Id, zone2Id), 0);
        assertEq(clearingHouse.netBilateralBalances(zone2Id, zone1Id), 0);

        // Zone 1 vault received 7,000 USDC, Zone 2 paid 7,000 USDC
        assertEq(usdc.balanceOf(zone1Vault), 7_000e18);
        assertEq(usdc.balanceOf(zone2Vault), 50_000e18 - 7_000e18);
    }
}
