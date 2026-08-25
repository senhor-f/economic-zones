// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {StakedHNY} from "../../src/token/StakedHNY.sol";
import {ProjectRegistry} from "../../src/payments/ProjectRegistry.sol";
import {ZoneRevenueSplitter} from "../../src/payments/ZoneRevenueSplitter.sol";

contract ZoneRevenueSplitterTest is Test {
    HNYToken public hny;
    StakedHNY public sHny;
    ProjectRegistry public registry;
    ZoneRevenueSplitter public splitter;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public merchant = address(0x1111);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public customer = address(0xC001);

    uint256 public projectId;

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        sHny = new StakedHNY(address(hny), owner);
        registry = new ProjectRegistry(owner);
        splitter = new ZoneRevenueSplitter(
            address(hny),
            address(sHny),
            address(registry),
            treasuryVault,
            owner
        );

        hny.setMinter(owner, true);
        hny.mint(customer, 50_000e18);
        vm.stopPrank();

        // Merchant registers project
        vm.prank(merchant);
        projectId = registry.registerProject(merchant, "ipfs://metadata", 0);
    }

    function test_ConfigureSplit_AndExecuteWithAutoStake() public {
        // Merchant sets split: 10% auto-stake (sHNY), 5% treasury, 60% Alice, 25% Bob
        ZoneRevenueSplitter.SplitRecipient[] memory recipients = new ZoneRevenueSplitter.SplitRecipient[](2);
        recipients[0] = ZoneRevenueSplitter.SplitRecipient({recipient: alice, shareBps: 6000});
        recipients[1] = ZoneRevenueSplitter.SplitRecipient({recipient: bob, shareBps: 2500});

        vm.prank(merchant);
        splitter.setSplitConfig(
            projectId,
            merchant, // primary beneficiary for sHNY
            1000,     // 10% auto-stake
            500,      // 5% treasury tax
            recipients
        );

        // Customer pays 10,000 HNY through the splitter
        vm.startPrank(customer);
        hny.approve(address(splitter), 10_000e18);
        splitter.splitRevenue(projectId, address(hny), 10_000e18);
        vm.stopPrank();

        // 1. Treasury receives 500 HNY (5%)
        assertEq(hny.balanceOf(treasuryVault), 500e18);

        // 2. Alice receives 6,000 HNY (60%)
        assertEq(hny.balanceOf(alice), 6_000e18);

        // 3. Bob receives 2,500 HNY (25%)
        assertEq(hny.balanceOf(bob), 2_500e18);

        // 4. Merchant receives 1,000 sHNY shares (from 10% auto-staked 1,000 HNY)
        assertEq(sHny.balanceOf(merchant), 1_000e18);
    }
}
