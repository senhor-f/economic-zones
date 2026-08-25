// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ProtocolVersion} from "../../src/core/ProtocolVersion.sol";
import {Versioned} from "../../src/core/Versioned.sol";

contract MockVersionedContract is Versioned {
    constructor() Versioned("AugmentedCurve") {}
}

contract ProtocolVersionTest is Test {
    function test_PackAndUnpackVersion() public {
        vm.warp(1756118400); // Specific timestamp

        MockVersionedContract mock = new MockVersionedContract();
        bytes32 tag = mock.PROTOCOL_VERSION();
        assertTrue(tag != bytes32(0));

        (
            bytes4 magic,
            uint8 major,
            uint8 minor,
            uint8 patch,
            uint48 deployedAt,
            bytes19 name
        ) = mock.getVersionMetadata();

        assertEq(magic, bytes4("HNY2"));
        assertEq(major, 2);
        assertEq(minor, 1);
        assertEq(patch, 0);
        assertEq(deployedAt, 1756118400);
        assertEq(name, bytes19("AugmentedCurve"));
    }
}
