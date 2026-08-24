// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "solady/auth/Ownable.sol";

/// @title ContributionLedger
/// @notice On-chain contribution and attribution ledger tracking revenue, volume, and engagement per project.
contract ContributionLedger is Ownable {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct ProjectMetrics {
        uint256 cumulativeVolume;
        uint256 cumulativeRevenue;
        uint256 hnyBurned;
        uint256 totalTransactions;
        uint256 uniqueUsers;
    }

    enum ProjectTier {
        BRONZE,
        SILVER,
        GOLD,
        PLATINUM
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ContributionRecorded(
        uint256 indexed projectId, address indexed user, uint256 volume, uint256 revenue, uint256 burnAmount
    );
    event ReporterStatusUpdated(address indexed reporter, bool indexed status);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotAuthorizedReporter();
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant WAD = 1e18;
    uint256 public constant SILVER_THRESHOLD = 10_000 * WAD;
    uint256 public constant GOLD_THRESHOLD = 100_000 * WAD;
    uint256 public constant PLATINUM_THRESHOLD = 1_000_000 * WAD;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorized reporters (Payment Gateway, Perp Hook, Bounty Escrow)
    mapping(address => bool) public isReporter;

    /// @notice Metrics per projectId
    mapping(uint256 => ProjectMetrics) public metrics;

    /// @notice Tracks user interaction history per project
    mapping(uint256 => mapping(address => bool)) public hasInteractedWithProject;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        _initializeOwner(initialOwner);
    }

    /*//////////////////////////////////////////////////////////////
                          RECORDING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Records transaction activity for a registered project
    /// @param projectId Target project ID
    /// @param user Address of the participating user
    /// @param volume Total gross volume of the transaction
    /// @param revenue Net revenue/fees routed to the protocol/treasury
    /// @param burnAmount Total $HNY burned in the transaction
    function recordContribution(uint256 projectId, address user, uint256 volume, uint256 revenue, uint256 burnAmount)
        external
    {
        if (!isReporter[msg.sender]) revert NotAuthorizedReporter();

        ProjectMetrics storage m = metrics[projectId];
        m.cumulativeVolume += volume;
        m.cumulativeRevenue += revenue;
        m.hnyBurned += burnAmount;
        m.totalTransactions += 1;

        if (!hasInteractedWithProject[projectId][user]) {
            hasInteractedWithProject[projectId][user] = true;
            m.uniqueUsers += 1;
        }

        emit ContributionRecorded(projectId, user, volume, revenue, burnAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            TIERS & DISCOUNTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Computes tier based on cumulative volume
    function getProjectTier(uint256 projectId) public view returns (ProjectTier) {
        uint256 vol = metrics[projectId].cumulativeVolume;
        if (vol >= PLATINUM_THRESHOLD) return ProjectTier.PLATINUM;
        if (vol >= GOLD_THRESHOLD) return ProjectTier.GOLD;
        if (vol >= SILVER_THRESHOLD) return ProjectTier.SILVER;
        return ProjectTier.BRONZE;
    }

    /// @notice Returns fee discount in basis points for a project based on its tier
    function getFeeDiscountBps(uint256 projectId) external view returns (uint256) {
        ProjectTier tier = getProjectTier(projectId);
        if (tier == ProjectTier.PLATINUM) return 100; // 1.0% discount
        if (tier == ProjectTier.GOLD) return 50; // 0.5% discount
        if (tier == ProjectTier.SILVER) return 25; // 0.25% discount
        return 0;
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    function setReporter(address reporter, bool status) external onlyOwner {
        if (reporter == address(0)) revert ZeroAddress();
        isReporter[reporter] = status;
        emit ReporterStatusUpdated(reporter, status);
    }
}
