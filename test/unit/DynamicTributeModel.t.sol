// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DynamicTributeModel} from "../../src/curve/DynamicTributeModel.sol";

contract DynamicTributeModelTest is Test {
    DynamicTributeModel public model;

    function setUp() public {
        model = new DynamicTributeModel();
    }

    function test_GraduatedTributesScaling() public view {
        // At 0 reserve: base tributes (0.5% entry, 1.0% exit)
        assertEq(model.getEntryTributeBps(0), 50);
        assertEq(model.getExitTributeBps(0), 100);

        // At 500k reserve (halfway to 1M scale threshold)
        assertEq(model.getEntryTributeBps(500_000e18), 150); // 1.5%
        assertEq(model.getExitTributeBps(500_000e18), 300); // 3.0%

        // At 1M+ reserve: capped max tributes (2.5% entry, 5.0% exit)
        assertEq(model.getEntryTributeBps(1_000_000e18), 250);
        assertEq(model.getExitTributeBps(1_000_000e18), 500);

        assertEq(model.getEntryTributeBps(5_000_000e18), 250);
        assertEq(model.getExitTributeBps(5_000_000e18), 500);
    }
}
