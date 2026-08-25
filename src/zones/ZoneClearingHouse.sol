// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Versioned} from "../core/Versioned.sol";

/// @title ZoneClearingHouse
/// @notice Multi-zone clearing house and bilateral net settlement engine between sovereign economic zones.
contract ZoneClearingHouse is Ownable, ReentrancyGuard, Versioned {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CrossZoneTradeRecorded(
        uint256 indexed originZoneId,
        uint256 indexed targetZoneId,
        address indexed token,
        uint256 amount,
        int256 newNetBalance
    );
    event BilateralSettled(
        uint256 indexed debtorZoneId,
        uint256 indexed creditorZoneId,
        address indexed token,
        uint256 settledAmount
    );
    event SettlementVaultUpdated(uint256 indexed zoneId, address indexed vault);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error SameZone();
    error UnauthorizedRecorder();
    error NoSettlementRequired();
    error VaultNotConfigured();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorized trade recorders (e.g. ZonePaymentGateway, Routers)
    mapping(address => bool) public isAuthorizedRecorder;

    /// @notice Settlement vault per zone
    mapping(uint256 => address) public zoneSettlementVaults;

    /// @notice Net bilateral balances: zoneA => zoneB => net owed from zoneB to zoneA (positive = B owes A, negative = A owes B)
    mapping(uint256 => mapping(uint256 => int256)) public netBilateralBalances;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) Versioned("ClearingHouse") {
        if (_owner == address(0)) revert ZeroAddress();
        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           TRADE RECORDING
    //////////////////////////////////////////////////////////////*/

    /// @notice Records a cross-zone commercial obligation
    /// @param originZoneId Zone exporting the good/service (creditor)
    /// @param targetZoneId Zone importing the good/service (debtor)
    /// @param token Settlement currency
    /// @param amount Transaction amount
    function recordCrossZoneTrade(
        uint256 originZoneId,
        uint256 targetZoneId,
        address token,
        uint256 amount
    ) external nonReentrant returns (int256 netBalance) {
        if (!isAuthorizedRecorder[msg.sender] && msg.sender != owner()) revert UnauthorizedRecorder();
        if (originZoneId == targetZoneId) revert SameZone();
        if (amount == 0) revert ZeroAmount();

        int256 delta = int256(amount);
        netBilateralBalances[originZoneId][targetZoneId] += delta;
        netBilateralBalances[targetZoneId][originZoneId] -= delta;

        netBalance = netBilateralBalances[originZoneId][targetZoneId];

        emit CrossZoneTradeRecorded(originZoneId, targetZoneId, token, amount, netBalance);
    }

    /*//////////////////////////////////////////////////////////////
                           NET SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Settles net outstanding balance between two zones
    /// @param creditorZoneId Zone to receive payment
    /// @param debtorZoneId Zone owing payment
    /// @param token Settlement currency
    function settleNetBalance(
        uint256 creditorZoneId,
        uint256 debtorZoneId,
        address token
    ) external nonReentrant returns (uint256 settledAmount) {
        int256 balance = netBilateralBalances[creditorZoneId][debtorZoneId];
        if (balance <= 0) revert NoSettlementRequired();

        settledAmount = uint256(balance);

        address debtorVault = zoneSettlementVaults[debtorZoneId];
        address creditorVault = zoneSettlementVaults[creditorZoneId];

        if (debtorVault == address(0) || creditorVault == address(0)) revert VaultNotConfigured();

        // Clear balance
        netBilateralBalances[creditorZoneId][debtorZoneId] = 0;
        netBilateralBalances[debtorZoneId][creditorZoneId] = 0;

        // Transfer net owed from debtor vault directly to creditor vault
        token.safeTransferFrom(debtorVault, creditorVault, settledAmount);

        emit BilateralSettled(debtorZoneId, creditorZoneId, token, settledAmount);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    function setAuthorizedRecorder(address recorder, bool status) external onlyOwner {
        if (recorder == address(0)) revert ZeroAddress();
        isAuthorizedRecorder[recorder] = status;
    }

    function setZoneSettlementVault(uint256 zoneId, address vault) external onlyOwner {
        if (vault == address(0)) revert ZeroAddress();
        zoneSettlementVaults[zoneId] = vault;
        emit SettlementVaultUpdated(zoneId, vault);
    }
}
