// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Versioned} from "../core/Versioned.sol";

/// @title CustomTariffHook
/// @notice Configurable fiscal sovereignty hook applying category VAT and cross-zone customs tariffs.
contract CustomTariffHook is Ownable, ReentrancyGuard, Versioned {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct ZoneFiscalPolicy {
        address zoneTreasury;
        uint16 crossZoneTariffBps; // e.g. 300 = 3%
        bool isActive;
        mapping(uint8 => uint16) categoryVatBps; // categoryId => VAT rate
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TariffAssessed(
        uint256 indexed zoneId,
        address indexed payer,
        address indexed merchant,
        uint8 categoryId,
        uint256 grossAmount,
        uint256 tariffAmount,
        uint256 netMerchantAmount
    );
    event FiscalPolicyConfigured(uint256 indexed zoneId, address indexed zoneTreasury, uint16 crossZoneTariffBps);
    event CategoryVatUpdated(uint256 indexed zoneId, uint8 categoryId, uint16 vatBps);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error InvalidRate();
    error PolicyNotActive();
    error UnauthorizedZoneAdmin();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => ZoneFiscalPolicy) internal zonePolicies;
    mapping(uint256 => address) public zoneAdmins;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) Versioned("CustomTariffHook") {
        if (_owner == address(0)) revert ZeroAddress();
        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           POLICY CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Configures or updates the fiscal policy for a specific Zone
    function configureZonePolicy(
        uint256 zoneId,
        address zoneTreasury,
        address zoneAdmin,
        uint16 crossZoneTariffBps
    ) external {
        if (msg.sender != owner() && msg.sender != zoneAdmins[zoneId]) revert UnauthorizedZoneAdmin();
        if (zoneTreasury == address(0)) revert ZeroAddress();
        if (crossZoneTariffBps > 2000) revert InvalidRate(); // Max 20% tariff

        ZoneFiscalPolicy storage policy = zonePolicies[zoneId];
        policy.zoneTreasury = zoneTreasury;
        policy.crossZoneTariffBps = crossZoneTariffBps;
        policy.isActive = true;

        if (zoneAdmin != address(0)) {
            zoneAdmins[zoneId] = zoneAdmin;
        }

        emit FiscalPolicyConfigured(zoneId, zoneTreasury, crossZoneTariffBps);
    }

    /// @notice Sets VAT rate for a specific product/service category in a Zone
    function setCategoryVat(uint256 zoneId, uint8 categoryId, uint16 vatBps) external {
        if (msg.sender != owner() && msg.sender != zoneAdmins[zoneId]) revert UnauthorizedZoneAdmin();
        if (vatBps > 3000) revert InvalidRate(); // Max 30% VAT

        ZoneFiscalPolicy storage policy = zonePolicies[zoneId];
        if (!policy.isActive) revert PolicyNotActive();

        policy.categoryVatBps[categoryId] = vatBps;
        emit CategoryVatUpdated(zoneId, categoryId, vatBps);
    }

    /*//////////////////////////////////////////////////////////////
                           TARIFF CALCULATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates the total applicable tariff (VAT + cross-zone tariff)
    function calculateTariff(
        uint256 zoneId,
        uint256 grossAmount,
        uint8 categoryId,
        bool isCrossZone
    ) public view returns (uint256 tariffAmount, uint256 netMerchantAmount) {
        ZoneFiscalPolicy storage policy = zonePolicies[zoneId];
        if (!policy.isActive || grossAmount == 0) {
            return (0, grossAmount);
        }

        uint256 totalRateBps = policy.categoryVatBps[categoryId];
        if (isCrossZone) {
            totalRateBps += policy.crossZoneTariffBps;
        }

        if (totalRateBps > 5000) totalRateBps = 5000; // Cap at 50% max

        tariffAmount = (grossAmount * totalRateBps) / BPS_DENOMINATOR;
        netMerchantAmount = grossAmount - tariffAmount;
    }

    /// @notice Collects and routes calculated tariff to the Zone treasury
    function collectTariff(
        uint256 zoneId,
        address token,
        address payer,
        address merchant,
        uint256 grossAmount,
        uint8 categoryId,
        bool isCrossZone
    ) external nonReentrant returns (uint256 tariffAmount, uint256 netMerchantAmount) {
        (tariffAmount, netMerchantAmount) = calculateTariff(zoneId, grossAmount, categoryId, isCrossZone);

        if (tariffAmount > 0) {
            address treasury = zonePolicies[zoneId].zoneTreasury;
            token.safeTransferFrom(msg.sender, treasury, tariffAmount);
        }

        emit TariffAssessed(zoneId, payer, merchant, categoryId, grossAmount, tariffAmount, netMerchantAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW GETTERS
    //////////////////////////////////////////////////////////////*/

    function getZonePolicy(uint256 zoneId, uint8 categoryId)
        external
        view
        returns (address zoneTreasury, uint16 crossZoneTariffBps, uint16 categoryVatBps, bool isActive)
    {
        ZoneFiscalPolicy storage policy = zonePolicies[zoneId];
        return (policy.zoneTreasury, policy.crossZoneTariffBps, policy.categoryVatBps[categoryId], policy.isActive);
    }
}
