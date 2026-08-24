// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {AugmentedBondingCurve} from "../../src/curve/AugmentedBondingCurve.sol";
import {ProjectRegistry} from "../../src/payments/ProjectRegistry.sol";
import {ContributionLedger} from "../../src/payments/ContributionLedger.sol";
import {ZonePaymentGateway} from "../../src/payments/ZonePaymentGateway.sol";
import {SwapPayRouter} from "../../src/payments/SwapPayRouter.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract SwapPayRouterTest is Test {
    HNYToken public hny;
    MockERC20 public reserve;
    AugmentedBondingCurve public curve;
    ProjectRegistry public registry;
    ContributionLedger public ledger;
    ZonePaymentGateway public gateway;
    SwapPayRouter public router;

    address public owner = address(0xAA);
    address public treasuryVault = address(0xCAFE);
    address public alice = address(0x11);
    address public projectPayout = address(0x88);

    uint256 public projectId;

    function setUp() public {
        vm.startPrank(owner);
        hny = new HNYToken(owner);
        reserve = new MockERC20("USD Coin", "USDC", 18);

        curve = new AugmentedBondingCurve(
            address(hny),
            address(reserve),
            treasuryVault,
            owner,
            1e18, // basePrice = 1.0
            1e12, // slope
            50, // 0.5%
            100 // 1.0%
        );

        registry = new ProjectRegistry(owner);
        ledger = new ContributionLedger(owner);

        gateway = new ZonePaymentGateway(address(hny), address(registry), address(ledger), treasuryVault, owner);

        router = new SwapPayRouter(address(hny), address(reserve), address(curve), address(gateway), owner);

        hny.setMinter(address(curve), true);
        ledger.setReporter(address(gateway), true);
        vm.stopPrank();

        // Register project
        projectId = registry.registerProject(projectPayout, "ipfs://saas-tool", 0);

        // Mint USDC to Alice
        reserve.mint(alice, 10_000e18);
    }

    function test_1Click_SwapAndPayWithCashback() public {
        uint256 reserveToSpend = 1000e18;
        uint256 hnyRequiredForCheckout = 500e18;

        vm.startPrank(alice);
        reserve.approve(address(router), reserveToSpend);
        (uint256 netProject, uint256 cashback) =
            router.swapAndPay(projectId, reserveToSpend, hnyRequiredForCheckout, hnyRequiredForCheckout);
        vm.stopPrank();

        // 1. Project receives 98% of 500 HNY = 490 HNY
        assertEq(netProject, 490e18);
        assertEq(hny.balanceOf(projectPayout), 490e18);

        // 2. Alice receives leftover HNY + instant cashback!
        assertTrue(hny.balanceOf(alice) > 0);
        assertTrue(cashback > 0);
    }
}
