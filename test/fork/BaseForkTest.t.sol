// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {HNYToken} from "../../src/token/HNYToken.sol";
import {AugmentedBondingCurve} from "../../src/curve/AugmentedBondingCurve.sol";
import {ZonePaymentGateway} from "../../src/payments/ZonePaymentGateway.sol";
import {ProjectRegistry} from "../../src/payments/ProjectRegistry.sol";
import {ContributionLedger} from "../../src/payments/ContributionLedger.sol";
import {DeluxeAssetRebalancer} from "../../src/rebalancing/DeluxeAssetRebalancer.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

contract BaseForkTest is Test {
    // Base Mainnet Canonical Addresses
    address public constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant BASE_WETH = 0x4200000000000000000000000000000000000006;
    address public constant AAVE_V3_BASE = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address public constant MORPHO_BASE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    HNYToken public hny;
    AugmentedBondingCurve public curve;
    ZonePaymentGateway public gateway;
    ProjectRegistry public registry;
    ContributionLedger public ledger;
    DeluxeAssetRebalancer public rebalancer;

    address public deployer = address(0xAA);
    address public alice = address(0x11);
    address public projectPayout = address(0x88);

    uint256 public forkId;

    function setUp() public {
        // Create fork of Base if RPC is reachable, or fallback gracefully in test environment
        string memory baseRpc = vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org"));
        try vm.createSelectFork(baseRpc) returns (uint256 id) {
            forkId = id;
        } catch {
            return;
        }

        vm.startPrank(deployer);
        hny = new HNYToken(deployer);
        registry = new ProjectRegistry(deployer);
        ledger = new ContributionLedger(deployer);
        rebalancer = new DeluxeAssetRebalancer(deployer, deployer);

        curve = new AugmentedBondingCurve(
            address(hny),
            BASE_USDC,
            address(rebalancer),
            deployer,
            1e6, // 1 USDC (6 decimals)
            1e2, // slope
            50,  // 0.5%
            100  // 1.0%
        );

        gateway = new ZonePaymentGateway(
            address(hny),
            address(registry),
            address(ledger),
            address(rebalancer),
            deployer
        );

        hny.setMinter(address(curve), true);
        ledger.setReporter(address(gateway), true);
        vm.stopPrank();

        // Deal real USDC on Base to Alice
        deal(BASE_USDC, alice, 10_000 * 1e6);
    }

    function test_BaseLiveUSDC_BuyAndPayFlow() public {
        if (forkId == 0) return; // Skip if no network connectivity

        // Alice buys HNY with real Base USDC
        vm.startPrank(alice);
        ERC20(BASE_USDC).approve(address(curve), 1000 * 1e6);
        uint256 hnyBought = curve.buy(1000 * 1e6, 0, alice);
        vm.stopPrank();

        assertTrue(hnyBought > 0);
        assertEq(hny.balanceOf(alice), hnyBought);

        // Register project and pay in HNY
        vm.prank(deployer);
        uint256 pid = registry.registerProject(projectPayout, "ipfs://base-ai-agent", 0);

        vm.startPrank(alice);
        hny.approve(address(gateway), 100e18);
        (uint256 netProject, uint256 cashback) = gateway.pay(pid, 100e18);
        vm.stopPrank();

        assertEq(netProject, 98e18);
        assertEq(cashback, 1e18);
        assertEq(hny.balanceOf(projectPayout), 98e18);
    }
}
