// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Versioned} from "../core/Versioned.sol";
import {HNYToken} from "../token/HNYToken.sol";
import {StakedHNY} from "../token/StakedHNY.sol";
import {ProjectRegistry} from "./ProjectRegistry.sol";

/// @title ZoneRevenueSplitter
/// @notice Automated on-chain revenue distribution engine for merchants with auto-staking into $sHNY.
contract ZoneRevenueSplitter is Ownable, ReentrancyGuard, Versioned {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct SplitRecipient {
        address recipient;
        uint16 shareBps;
    }

    struct SplitConfig {
        address primaryBeneficiary;
        uint16 autoStakeShareBps;
        uint16 treasuryTaxBps;
        bool isActive;
        SplitRecipient[] recipients;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event SplitConfigUpdated(uint256 indexed projectId, address indexed primaryBeneficiary, uint256 recipientCount);
    event RevenueSplitExecuted(
        uint256 indexed projectId,
        address indexed token,
        uint256 totalAmount,
        uint256 autoStakedAmount,
        uint256 treasuryTaxAmount
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error InvalidSplitBps();
    error SplitConfigNotFound();
    error NotProjectOwner();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    HNYToken public immutable hnyToken;
    StakedHNY public immutable stakedHny;
    ProjectRegistry public immutable projectRegistry;
    address public treasuryVault;

    mapping(uint256 => SplitConfig) internal projectSplits;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _hnyToken,
        address _stakedHny,
        address _projectRegistry,
        address _treasuryVault,
        address _owner
    ) Versioned("ZoneRevenueSplit") {
        if (
            _hnyToken == address(0) || _stakedHny == address(0) || _projectRegistry == address(0)
                || _treasuryVault == address(0) || _owner == address(0)
        ) revert ZeroAddress();

        hnyToken = HNYToken(_hnyToken);
        stakedHny = StakedHNY(_stakedHny);
        projectRegistry = ProjectRegistry(_projectRegistry);
        treasuryVault = _treasuryVault;

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           SPLIT CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets or updates the revenue split configuration for a project
    /// @param projectId Registered project ID
    /// @param primaryBeneficiary Address to receive auto-staked $sHNY
    /// @param autoStakeBps Basis points to automatically convert to $sHNY (e.g. 1000 = 10%)
    /// @param treasuryTaxBps Basis points to route to Zone treasury (e.g. 500 = 5%)
    /// @param recipients Array of additional recipients with their percentage shares
    function setSplitConfig(
        uint256 projectId,
        address primaryBeneficiary,
        uint16 autoStakeBps,
        uint16 treasuryTaxBps,
        SplitRecipient[] calldata recipients
    ) external {
        (address projectOwner,,,,) = projectRegistry.projects(projectId);
        if (projectOwner == address(0)) revert SplitConfigNotFound();
        if (msg.sender != projectOwner && msg.sender != owner()) revert NotProjectOwner();
        if (primaryBeneficiary == address(0)) revert ZeroAddress();

        uint256 totalBps = uint256(autoStakeBps) + uint256(treasuryTaxBps);
        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i].recipient == address(0)) revert ZeroAddress();
            totalBps += recipients[i].shareBps;
        }

        if (totalBps != BPS_DENOMINATOR) revert InvalidSplitBps();

        SplitConfig storage config = projectSplits[projectId];
        config.primaryBeneficiary = primaryBeneficiary;
        config.autoStakeShareBps = autoStakeBps;
        config.treasuryTaxBps = treasuryTaxBps;
        config.isActive = true;

        delete config.recipients;
        for (uint256 i = 0; i < recipients.length; i++) {
            config.recipients.push(recipients[i]);
        }

        emit SplitConfigUpdated(projectId, primaryBeneficiary, recipients.length);
    }

    /*//////////////////////////////////////////////////////////////
                           EXECUTION ENGINE
    //////////////////////////////////////////////////////////////*/

    /// @notice Splits revenue according to project's configuration
    /// @param projectId Project ID
    /// @param token Token to distribute ($HNY, USDC, etc.)
    /// @param amount Amount to distribute
    function splitRevenue(uint256 projectId, address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        SplitConfig storage config = projectSplits[projectId];
        if (!config.isActive) revert SplitConfigNotFound();

        // 1. Pull tokens from caller
        token.safeTransferFrom(msg.sender, address(this), amount);

        uint256 autoStakeAmount = (amount * config.autoStakeShareBps) / BPS_DENOMINATOR;
        uint256 treasuryAmount = (amount * config.treasuryTaxBps) / BPS_DENOMINATOR;

        // 2. Handle Auto-Staking into $sHNY (if paying in $HNY)
        if (autoStakeAmount > 0) {
            if (token == address(hnyToken)) {
                token.safeApprove(address(stakedHny), autoStakeAmount);
                stakedHny.deposit(autoStakeAmount, config.primaryBeneficiary);
            } else {
                // If not HNY, transfer token directly to primary beneficiary
                token.safeTransfer(config.primaryBeneficiary, autoStakeAmount);
            }
        }

        // 3. Route treasury tax
        if (treasuryAmount > 0) {
            token.safeTransfer(treasuryVault, treasuryAmount);
        }

        // 4. Distribute to recipients
        uint256 len = config.recipients.length;
        for (uint256 i = 0; i < len; i++) {
            SplitRecipient memory r = config.recipients[i];
            uint256 rAmount = (amount * r.shareBps) / BPS_DENOMINATOR;
            if (rAmount > 0) {
                token.safeTransfer(r.recipient, rAmount);
            }
        }

        emit RevenueSplitExecuted(projectId, token, amount, autoStakeAmount, treasuryAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSplitConfig(uint256 projectId)
        external
        view
        returns (
            address primaryBeneficiary,
            uint16 autoStakeShareBps,
            uint16 treasuryTaxBps,
            bool isActive,
            SplitRecipient[] memory recipients
        )
    {
        SplitConfig storage config = projectSplits[projectId];
        return (
            config.primaryBeneficiary,
            config.autoStakeShareBps,
            config.treasuryTaxBps,
            config.isActive,
            config.recipients
        );
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    function setTreasuryVault(address _treasuryVault) external onlyOwner {
        if (_treasuryVault == address(0)) revert ZeroAddress();
        treasuryVault = _treasuryVault;
    }
}
