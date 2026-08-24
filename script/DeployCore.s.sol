// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {HNYToken} from "../src/token/HNYToken.sol";
import {ProjectRegistry} from "../src/payments/ProjectRegistry.sol";
import {ContributionLedger} from "../src/payments/ContributionLedger.sol";
import {ZonePaymentGateway} from "../src/payments/ZonePaymentGateway.sol";
import {AugmentedBondingCurve} from "../src/curve/AugmentedBondingCurve.sol";
import {PerpRevenueHook} from "../src/hooks/PerpRevenueHook.sol";
import {DeluxeAssetRebalancer} from "../src/rebalancing/DeluxeAssetRebalancer.sol";
import {ZoneFactory} from "../src/zones/ZoneFactory.sol";
import {CitizenTierManager} from "../src/glue/CitizenTierManager.sol";

contract DeployCoreScript is Script {
    function run() external {
        uint256 deployerPrivateKey =
            vm.envOr("DEPLOYER_PK", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);
        address reserveToken = vm.envOr("RESERVE_TOKEN", address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913)); // Default: Base USDC

        console2.log("Deploying Economic Zones Protocol from:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Token
        HNYToken hny = new HNYToken(deployer);
        console2.log("HNYToken deployed at:", address(hny));

        // 2. Deploy Registries & Ledgers
        ProjectRegistry registry = new ProjectRegistry(deployer);
        ContributionLedger ledger = new ContributionLedger(deployer);
        console2.log("ProjectRegistry deployed at:", address(registry));
        console2.log("ContributionLedger deployed at:", address(ledger));

        // 3. Deploy Rebalancer (acting as initial Treasury Hub)
        DeluxeAssetRebalancer rebalancer = new DeluxeAssetRebalancer(deployer, deployer);
        console2.log("DeluxeAssetRebalancer deployed at:", address(rebalancer));

        // 4. Deploy Augmented Bonding Curve
        AugmentedBondingCurve curve = new AugmentedBondingCurve(
            address(hny),
            reserveToken,
            address(rebalancer),
            deployer,
            1e18, // basePrice = 1.0
            1e12, // slope
            50, // 0.5% entry tribute
            100 // 1.0% exit tribute
        );
        console2.log("AugmentedBondingCurve deployed at:", address(curve));

        // 5. Deploy Payment Gateway
        ZonePaymentGateway gateway =
            new ZonePaymentGateway(address(hny), address(registry), address(ledger), address(rebalancer), deployer);
        console2.log("ZonePaymentGateway deployed at:", address(gateway));

        // 6. Deploy Perp Hook
        PerpRevenueHook perpHook = new PerpRevenueHook(address(hny), address(ledger), address(rebalancer), deployer);
        console2.log("PerpRevenueHook deployed at:", address(perpHook));

        // 7. Deploy Citizen Tier Manager
        CitizenTierManager tierManager = new CitizenTierManager(address(hny), deployer);
        console2.log("CitizenTierManager deployed at:", address(tierManager));

        // 8. Deploy Zone Factory
        ZoneFactory factory = new ZoneFactory(address(hny), address(rebalancer), address(registry), deployer);
        console2.log("ZoneFactory deployed at:", address(factory));

        // 9. Wire permissions
        hny.setMinter(address(curve), true);
        ledger.setReporter(address(gateway), true);
        ledger.setReporter(address(perpHook), true);
        tierManager.setAuthorizedAdapter(address(gateway), true);

        vm.stopBroadcast();

        console2.log("Core Protocol successfully deployed and wired!");
    }
}
