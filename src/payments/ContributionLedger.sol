// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "solady/auth/Ownable.sol";

/// @title ContributionLedger
/// @notice On-chain contribution ledger with temporal epoch decay preventing permanent stale tier gaming.
contract ContributionLedger is Ownable {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct ProjectMetrics {
        uint256 cumulativeVolume;
        uint256 currentEpochVolume;
        uint256 cumulativeRevenue;
        uint256 hnyBurned;
        uint256 totalTransactions;
        uint256 uniqueUsers;
        uint256 lastActiveEpoch;
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
    event EpochRolled(uint256 indexed newEpoch, uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotAuthorizedReporter();
    error ZeroAddress();
    error EpochNotEnded();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant WAD = 1e18;

    uint256 public constant SILVER_THRESHOLD = 10_000 * WAD;
    uint256 public constant GOLD_THRESHOLD = 100_000 * WAD;
    uint256 public constant PLATINUM_THRESHOLD = 1_000_000 * WAD;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => bool) public isReporter;
    mapping(uint256 => ProjectMetrics) public metrics;
    mapping(uint256 => mapping(address => bool)) public hasInteractedWithProject;

    uint256 public currentEpoch = 1;
    uint256 public epochStartTime;
    uint256 public epochDuration = 30 days;
    uint256 public decayFactorBps = 5000; // 50% decay per epoch

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        epochStartTime = block.timestamp;
        _initializeOwner(initialOwner);
    }

    /*//////////////////////////////////////////////////////////////
                          RECORDING LOGIC
    //////////////////////////////////////////////////////////////*/

    function recordContribution(uint256 projectId, address user, uint256 volume, uint256 revenue, uint256 burnAmount)
        external
    {
        if (!isReporter[msg.sender]) revert NotAuthorizedReporter();

        ProjectMetrics storage m = metrics[projectId];
        m.cumulativeVolume += volume;
        m.currentEpochVolume += volume;
        m.cumulativeRevenue += revenue;
        m.hnyBurned += burnAmount;
        m.totalTransactions += 1;
        m.lastActiveEpoch = currentEpoch;

        if (!hasInteractedWithProject[projectId][user]) {
            hasInteractedWithProject[projectId][user] = true;
            m.uniqueUsers += 1;
        }

        emit ContributionRecorded(projectId, user, volume, revenue, burnAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            TEMPORAL DECAY
    //////////////////////////////////////////////////////////////*/

    /// @notice Advances epoch after duration elapsed (supports multi-epoch jumps)
    function rollEpoch() external {
        if (block.timestamp < epochStartTime + epochDuration) revert EpochNotEnded();

        uint256 epochsToAdvance = (block.timestamp - epochStartTime) / epochDuration;
        currentEpoch += epochsToAdvance;
        epochStartTime += epochsToAdvance * epochDuration;

        emit EpochRolled(currentEpoch, block.timestamp);
    }

    /// @notice Returns active volume considering temporal decay
    function getActiveVolume(uint256 projectId) public view returns (uint256) {
        ProjectMetrics storage m = metrics[projectId];
        if (m.lastActiveEpoch == 0) return 0;

        uint256 epochsPassed = currentEpoch - m.lastActiveEpoch;
        if (epochsPassed == 0) {
            return m.currentEpochVolume;
        }

        // Apply decay
        uint256 decayed = m.currentEpochVolume;
        for (uint256 i = 0; i < epochsPassed && decayed > 0; i++) {
            decayed = (decayed * decayFactorBps) / BPS_DENOMINATOR;
        }
        return decayed;
    }

    /// @notice Computes tier based on active decayed volume
    function getProjectTier(uint256 projectId) public view returns (ProjectTier) {
        uint256 vol = getActiveVolume(projectId);
        if (vol >= PLATINUM_THRESHOLD) return ProjectTier.PLATINUM;
        if (vol >= GOLD_THRESHOLD) return ProjectTier.GOLD;
        if (vol >= SILVER_THRESHOLD) return ProjectTier.SILVER;
        return ProjectTier.BRONZE;
    }

    function getFeeDiscountBps(uint256 projectId) external view returns (uint256) {
        ProjectTier tier = getProjectTier(projectId);
        if (tier == ProjectTier.PLATINUM) return 100;
        if (tier == ProjectTier.GOLD) return 50;
        if (tier == ProjectTier.SILVER) return 25;
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
