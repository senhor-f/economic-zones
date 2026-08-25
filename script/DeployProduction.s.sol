// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {HNYToken} from "../src/token/HNYToken.sol";
import {StakedHNY} from "../src/token/StakedHNY.sol";
import {AugmentedBondingCurve} from "../src/curve/AugmentedBondingCurve.sol";
import {DynamicTributeModel} from "../src/curve/DynamicTributeModel.sol";
import {ProjectRegistry} from "../src/payments/ProjectRegistry.sol";
import {ContributionLedger} from "../src/payments/ContributionLedger.sol";
import {ZonePaymentGateway} from "../src/payments/ZonePaymentGateway.sol";
import {SwapPayRouter} from "../src/payments/SwapPayRouter.sol";
import {SubscriptionManager} from "../src/payments/SubscriptionManager.sol";
import {ZoneRevenueSplitter} from "../src/payments/ZoneRevenueSplitter.sol";
import {ContinuousPayrollStreamer} from "../src/payments/ContinuousPayrollStreamer.sol";
import {x402Settler} from "../src/payments/x402Settler.sol";
import {ProjectCollateral} from "../src/payments/ProjectCollateral.sol";
import {FloorDripper} from "../src/rebalancing/FloorDripper.sol";
import {TreasuryYieldVault} from "../src/rebalancing/TreasuryYieldVault.sol";
import {POLManager} from "../src/rebalancing/POLManager.sol";
import {FloorLockedSavings} from "../src/zones/FloorLockedSavings.sol";
import {ZoneClearingHouse} from "../src/zones/ZoneClearingHouse.sol";
import {CustomTariffHook} from "../src/hooks/CustomTariffHook.sol";
import {CoreAccessControl} from "../src/core/CoreAccessControl.sol";
import {CoreTimelock} from "../src/core/CoreTimelock.sol";

/// @title DeployProduction
/// @notice Automated production deployment script for Base / Arbitrum / Mainnet.
contract DeployProduction is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xA11CE));
        address deployer = vm.addr(deployerPrivateKey);
        address reserveToken = vm.envOr("RESERVE_TOKEN", address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913)); // Base USDC default
        address treasuryVault = vm.envOr("TREASURY_VAULT", deployer);

        console2.log("=== Deploying Economic Zones Protocol v2.1 (Full Suite) ===");
        console2.log("Deployer:", deployer);
        console2.log("Reserve Token (USDC):", reserveToken);
        console2.log("Treasury Vault:", treasuryVault);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Core Access Control & Timelock
        CoreAccessControl accessControl = new CoreAccessControl(deployer);
        CoreTimelock timelock = new CoreTimelock(deployer, 2 days);

        // 2. Token & Liquid Staking
        HNYToken hny = new HNYToken(deployer);
        StakedHNY sHny = new StakedHNY(address(hny), deployer);
        DynamicTributeModel tributeModel = new DynamicTributeModel();

        // 3. Augmented Bonding Curve
        AugmentedBondingCurve curve = new AugmentedBondingCurve(
            address(hny),
            reserveToken,
            treasuryVault,
            deployer,
            1e18, // 1.0 USDC basePrice
            1e12, // Linear slope
            50,   // 0.5% entry tribute
            100   // 1.0% exit tribute
        );

        hny.setMinter(address(curve), true);

        // 4. Commerce, Payments & Splitters
        ProjectRegistry registry = new ProjectRegistry(deployer);
        ContributionLedger ledger = new ContributionLedger(deployer);

        ZonePaymentGateway gateway = new ZonePaymentGateway(
            address(hny),
            address(registry),
            address(ledger),
            treasuryVault,
            deployer
        );

        ZoneRevenueSplitter splitter = new ZoneRevenueSplitter(
            address(hny),
            address(sHny),
            address(registry),
            treasuryVault,
            deployer
        );

        ContinuousPayrollStreamer payroll = new ContinuousPayrollStreamer(deployer);

        SwapPayRouter swapRouter = new SwapPayRouter(
            address(hny),
            reserveToken,
            address(curve),
            address(gateway),
            deployer
        );

        SubscriptionManager subManager = new SubscriptionManager(
            address(hny),
            address(registry),
            address(gateway),
            deployer
        );

        x402Settler x402 = new x402Settler(
            address(hny),
            address(gateway),
            deployer
        );

        ProjectCollateral collateral = new ProjectCollateral(
            reserveToken,
            address(ledger),
            address(registry),
            treasuryVault,
            5000e18, // 5000 USDC min collateral
            deployer
        );

        ledger.setReporter(address(gateway), true);

        // 5. Yield, Floor Dripping & Lockers
        FloorDripper dripper = new FloorDripper(
            reserveToken,
            address(curve),
            1e15, // 0.001 USDC / sec drip rate
            deployer
        );

        TreasuryYieldVault treasuryVaultContract = new TreasuryYieldVault(
            reserveToken,
            address(curve),
            deployer
        );

        POLManager pol = new POLManager(
            address(hny),
            reserveToken,
            treasuryVault,
            deployer
        );

        FloorLockedSavings savings = new FloorLockedSavings(
            address(hny),
            address(curve),
            deployer
        );

        // 6. Fiscal Sovereignty & Inter-Zone Clearing
        CustomTariffHook tariffHook = new CustomTariffHook(deployer);
        ZoneClearingHouse clearingHouse = new ZoneClearingHouse(deployer);

        vm.stopBroadcast();

        console2.log("--- Deployment Successful ---");
        console2.log("HNYToken:", address(hny));
        console2.log("StakedHNY:", address(sHny));
        console2.log("AugmentedBondingCurve:", address(curve));
        console2.log("ZonePaymentGateway:", address(gateway));
        console2.log("ZoneRevenueSplitter:", address(splitter));
        console2.log("ContinuousPayrollStreamer:", address(payroll));
        console2.log("SwapPayRouter:", address(swapRouter));
        console2.log("SubscriptionManager:", address(subManager));
        console2.log("FloorLockedSavings:", address(savings));
        console2.log("CustomTariffHook:", address(tariffHook));
        console2.log("ZoneClearingHouse:", address(clearingHouse));
        console2.log("x402Settler:", address(x402));
        console2.log("FloorDripper:", address(dripper));
        console2.log("TreasuryYieldVault:", address(treasuryVaultContract));
        console2.log("POLManager:", address(pol));
    }
}
