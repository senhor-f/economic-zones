// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CoreAccessControl} from "../../src/core/CoreAccessControl.sol";

contract CoreAccessControlTest is Test {
    CoreAccessControl public accessControl;
    address public rootAdmin = address(0xAA);
    address public guardian = address(0xBB);
    address public paramAdmin = address(0xCC);
    address public unauthorized = address(0x66);

    bytes32 public guardianRole;
    bytes32 public paramAdminRole;

    function setUp() public {
        accessControl = new CoreAccessControl(rootAdmin);
        guardianRole = accessControl.GUARDIAN_ROLE();
        paramAdminRole = accessControl.PARAMETER_ADMIN_ROLE();

        vm.startPrank(rootAdmin);
        accessControl.grantRole(guardianRole, guardian);
        accessControl.grantRole(paramAdminRole, paramAdmin);
        vm.stopPrank();
    }

    function test_RoleVerification() public view {
        assertTrue(accessControl.hasRole(accessControl.DEFAULT_ADMIN_ROLE(), rootAdmin));
        assertTrue(accessControl.hasRole(guardianRole, guardian));
        assertTrue(accessControl.hasRole(paramAdminRole, paramAdmin));
        assertFalse(accessControl.hasRole(guardianRole, unauthorized));
    }

    function test_RevokeRole() public {
        vm.prank(rootAdmin);
        accessControl.revokeRole(guardianRole, guardian);
        assertFalse(accessControl.hasRole(guardianRole, guardian));
    }
}
