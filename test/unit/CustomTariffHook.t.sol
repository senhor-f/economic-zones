// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {CustomTariffHook} from "../../src/hooks/CustomTariffHook.sol";

contract CustomTariffHookTest is Test {
    HNYToken public hny;
    CustomTariffHook public hook;

    address public owner = address(0xAA);
    address public zoneTreasury = address(0xCAFE);
    address public zoneAdmin = address(0xAD1);
    address public payer = address(0x1234);
    address public merchant = address(0x5678);

    uint256 public zoneId = 1;

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        hook = new CustomTariffHook(owner);

        hny.setMinter(owner, true);
        hny.mint(payer, 50_000e18);
        vm.stopPrank();

        // Configure policy: 3% cross-zone tariff
        vm.prank(owner);
        hook.configureZonePolicy(zoneId, zoneTreasury, zoneAdmin, 300);

        // Zone admin sets 5% VAT on category 0 (Goods) and 2% on category 1 (Digital Services)
        vm.startPrank(zoneAdmin);
        hook.setCategoryVat(zoneId, 0, 500); // 5%
        hook.setCategoryVat(zoneId, 1, 200); // 2%
        vm.stopPrank();
    }

    function test_LocalAndCrossZoneTariffAssessment() public {
        uint256 gross = 10_000e18;

        // 1. Local purchase in Category 0 (5% VAT)
        (uint256 tariffLocal, uint256 netLocal) = hook.calculateTariff(zoneId, gross, 0, false);
        assertEq(tariffLocal, 500e18); // 5% of 10,000 = 500
        assertEq(netLocal, 9_500e18);

        // 2. Cross-zone purchase in Category 0 (5% VAT + 3% Tariff = 8% total)
        (uint256 tariffCross, uint256 netCross) = hook.calculateTariff(zoneId, gross, 0, true);
        assertEq(tariffCross, 800e18); // 8% of 10,000 = 800
        assertEq(netCross, 9_200e18);

        // 3. Execute collectTariff for cross-zone transaction
        vm.startPrank(payer);
        hny.approve(address(hook), tariffCross);
        (uint256 collected, uint256 netMerchant) =
            hook.collectTariff(zoneId, address(hny), payer, merchant, gross, 0, true);
        vm.stopPrank();

        assertEq(collected, 800e18);
        assertEq(netMerchant, 9_200e18);
        assertEq(hny.balanceOf(zoneTreasury), 800e18);
    }
}
