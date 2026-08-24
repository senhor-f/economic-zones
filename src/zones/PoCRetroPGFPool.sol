// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {ContributionLedger} from "../payments/ContributionLedger.sol";

/// @title PoCRetroPGFPool
/// @notice Proof-of-Commerce weighted Quadratic Funding pool rewarding projects based on verified economic throughput.
contract PoCRetroPGFPool is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct ProjectProposal {
        uint256 projectId;
        address payout;
        uint256 sumOfSqrtVotes;
        uint256 directDonations;
        bool isClaimed;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event RoundCreated(uint256 indexed roundId, uint256 matchingPoolAmount, uint256 duration);
    event Voted(uint256 indexed roundId, uint256 indexed projectId, address indexed voter, uint256 amount);
    event MatchingClaimed(uint256 indexed roundId, uint256 indexed projectId, uint256 totalPayout);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error RoundActive();
    error RoundEnded();
    error AlreadyClaimed();
    error NoProjects();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant WAD = 1e18;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable fundingToken;
    ContributionLedger public immutable ledger;

    uint256 public roundCount;
    uint256 public matchingPool;
    uint256 public roundEndTime;

    uint256[] public roundProjectIds;
    mapping(uint256 => ProjectProposal) public proposals;
    mapping(uint256 => mapping(address => uint256)) public userVotes;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _fundingToken, address _ledger, address _owner) {
        if (_fundingToken == address(0) || _ledger == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }

        fundingToken = _fundingToken;
        ledger = ContributionLedger(_ledger);

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                             ROUND LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Starts a new Proof-of-Commerce RetroPGF round
    function startRound(uint256 poolAmount, uint256 duration, uint256[] calldata projectIds, address[] calldata payouts)
        external
        onlyOwner
        nonReentrant
    {
        if (block.timestamp < roundEndTime) revert RoundActive();
        if (projectIds.length == 0 || projectIds.length != payouts.length) revert NoProjects();

        roundCount++;
        matchingPool = poolAmount;
        roundEndTime = block.timestamp + duration;

        delete roundProjectIds;

        for (uint256 i = 0; i < projectIds.length; i++) {
            uint256 pid = projectIds[i];
            roundProjectIds.push(pid);
            proposals[pid] = ProjectProposal({
                projectId: pid, payout: payouts[i], sumOfSqrtVotes: 0, directDonations: 0, isClaimed: false
            });
        }

        fundingToken.safeTransferFrom(msg.sender, address(this), poolAmount);
        emit RoundCreated(roundCount, poolAmount, duration);
    }

    /// @notice Casts a quadratic vote for a project with direct funding token donation
    function vote(uint256 projectId, uint256 amount) external nonReentrant {
        if (block.timestamp > roundEndTime) revert RoundEnded();
        if (amount == 0) revert ZeroAmount();

        ProjectProposal storage prop = proposals[projectId];
        if (prop.payout == address(0)) revert ZeroAddress();

        fundingToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 sqrtAmount = FixedPointMathLib.sqrt(amount * WAD);
        prop.sumOfSqrtVotes += sqrtAmount;
        prop.directDonations += amount;
        userVotes[projectId][msg.sender] += amount;

        emit Voted(roundCount, projectId, msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                       PROOF OF COMMERCE MATCHING
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the Commerce Multiplier for a project based on its on-chain active volume & metrics
    function getCommerceMultiplierBps(uint256 projectId) public view returns (uint256) {
        ContributionLedger.ProjectTier tier = ledger.getProjectTier(projectId);

        if (tier == ContributionLedger.ProjectTier.PLATINUM) return 20000; // 2.0x boost
        if (tier == ContributionLedger.ProjectTier.GOLD) return 15000; // 1.5x boost
        if (tier == ContributionLedger.ProjectTier.SILVER) return 12500; // 1.25x boost
        return 10000; // 1.0x baseline
    }

    /// @notice Computes effective commerce-weighted quadratic score for a project
    function getEffectiveScore(uint256 projectId) public view returns (uint256) {
        ProjectProposal storage prop = proposals[projectId];
        uint256 baseQuadratic = (prop.sumOfSqrtVotes * prop.sumOfSqrtVotes) / WAD;
        uint256 multiplierBps = getCommerceMultiplierBps(projectId);
        return (baseQuadratic * multiplierBps) / BPS_DENOMINATOR;
    }

    /// @notice Returns total effective score across all projects in the round
    function getTotalEffectiveScore() public view returns (uint256 totalScore) {
        for (uint256 i = 0; i < roundProjectIds.length; i++) {
            totalScore += getEffectiveScore(roundProjectIds[i]);
        }
    }

    /// @notice Claims direct donations + matching grant payout for a project
    function claimPayout(uint256 projectId) external nonReentrant returns (uint256 totalPayout) {
        if (block.timestamp <= roundEndTime) revert RoundActive();

        ProjectProposal storage prop = proposals[projectId];
        if (prop.isClaimed) revert AlreadyClaimed();
        prop.isClaimed = true;

        uint256 matchingShare = 0;
        uint256 totalScore = getTotalEffectiveScore();

        if (totalScore > 0) {
            uint256 projectScore = getEffectiveScore(projectId);
            matchingShare = (matchingPool * projectScore) / totalScore;
        }

        totalPayout = prop.directDonations + matchingShare;
        if (totalPayout > 0) {
            fundingToken.safeTransfer(prop.payout, totalPayout);
        }

        emit MatchingClaimed(roundCount, projectId, totalPayout);
    }
}
