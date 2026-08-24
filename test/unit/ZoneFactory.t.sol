// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {ProjectRegistry} from "../../src/payments/ProjectRegistry.sol";
import {ZoneFactory} from "../../src/zones/ZoneFactory.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract ZoneFactoryTest is Test {
    HNYToken public hny;
    ProjectRegistry public registry;
    ZoneFactory public factory;
    MockERC20 public usdc;

    address public owner = address(0xAA);
    address public coreTreasury = address(0xCAFE);
    address public zoneAdmin = address(0x88);

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        registry = new ProjectRegistry(owner);
        factory = new ZoneFactory(address(hny), coreTreasury, address(registry), owner);
        usdc = new MockERC20("USD Coin", "USDC", 18);
        vm.stopPrank();
    }

    function test_CreateZone() public {
        (uint256 zoneId, address vault, address voting, address rpgf) =
            factory.createZone("Buenos Aires Tech Zone", zoneAdmin, address(usdc));

        assertEq(zoneId, 1);
        assertTrue(vault != address(0));
        assertTrue(voting != address(0));
        assertTrue(rpgf != address(0));

        (address zVault, address zVoting, address zRpgf, address zAdmin, string memory zName, bool isActive) =
            factory.zones(zoneId);
        assertEq(zVault, vault);
        assertEq(zVoting, voting);
        assertEq(zRpgf, rpgf);
        assertEq(zAdmin, zoneAdmin);
        assertEq(zName, "Buenos Aires Tech Zone");
        assertTrue(isActive);
    }
}
