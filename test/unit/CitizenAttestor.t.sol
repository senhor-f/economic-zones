// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CitizenAttestor, IEAS} from "../../src/glue/CitizenAttestor.sol";
import {CitizenTierManager} from "../../src/glue/CitizenTierManager.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";

contract MockEAS is IEAS {
    uint256 public counter;

    function attest(AttestationRequest calldata) external payable override returns (bytes32) {
        counter++;
        return bytes32(counter);
    }
}

contract CitizenAttestorTest is Test {
    CitizenAttestor public attestor;
    CitizenTierManager public tierManager;
    HNYToken public hny;
    MockEAS public eas;

    address public owner = address(0xAA);
    address public alice = address(0x11);
    bytes32 public constant SCHEMA_UID = keccak256("CITIZEN_TIER_SCHEMA");

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        eas = new MockEAS();

        tierManager = new CitizenTierManager(address(hny), owner);

        attestor = new CitizenAttestor(address(eas), address(tierManager), SCHEMA_UID, owner);

        hny.setMinter(owner, true);
        vm.stopPrank();

        // Alice holds 2,500 HNY (Silver Tier: 1,000 to 10,000 HNY)
        vm.prank(owner);
        hny.mint(alice, 2500e18);
    }

    function test_AttestCitizenTier() public {
        bytes32 uid = attestor.attestCitizenTier(alice);
        assertTrue(uid != bytes32(0));
        assertEq(attestor.latestAttestationUID(alice), uid);
    }
}
