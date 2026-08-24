// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {ProjectRegistry} from "../payments/ProjectRegistry.sol";

/// @title RetroPGFPool
/// @notice Retroactive Public Goods Funding rounds with Quadratic Voting for Economic Zone contributors.
contract RetroPGFPool is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Round {
        address fundingToken;
        uint256 budget;
        uint256 startTime;
        uint256 endTime;
        bool isFinalized;
        uint256 totalQuadraticScore;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event RoundCreated(uint256 indexed roundId, address fundingToken, uint256 budget, uint256 endTime);
    event VoteCast(uint256 indexed roundId, uint256 indexed projectId, address indexed voter, uint256 votes);
    event RoundFinalized(uint256 indexed roundId, uint256 totalDistributed);
    event RetroRewardClaimed(uint256 indexed roundId, uint256 indexed projectId, address recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error RoundNotActive();
    error RoundAlreadyFinalized();
    error NotBadgeholder();
    error ProjectAlreadyClaimed();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ProjectRegistry public immutable projectRegistry;

    uint256 public roundCount;
    mapping(uint256 => Round) public rounds;

    /// @notice project quadratic score per round: roundId => projectId => quadraticScore
    mapping(uint256 => mapping(uint256 => uint256)) public projectSqrtSum;

    /// @notice tracks voter points spent per round: roundId => voter => bool
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    /// @notice tracks badgeholder whitelist
    mapping(address => bool) public isBadgeholder;

    /// @notice tracks claims: roundId => projectId => bool
    mapping(uint256 => mapping(uint256 => bool)) public hasClaimed;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _projectRegistry, address _owner) {
        if (_projectRegistry == address(0) || _owner == address(0)) revert ZeroAddress();
        projectRegistry = ProjectRegistry(_projectRegistry);
        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           ROUND LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Launches a new RetroPGF funding round
    function createRound(address fundingToken, uint256 budget, uint256 duration)
        external
        onlyOwner
        returns (uint256 roundId)
    {
        if (fundingToken == address(0)) revert ZeroAddress();
        if (budget == 0 || duration == 0) revert ZeroAmount();

        roundId = ++roundCount;
        rounds[roundId] = Round({
            fundingToken: fundingToken,
            budget: budget,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            isFinalized: false,
            totalQuadraticScore: 0
        });

        // Pull budget to pool
        fundingToken.safeTransferFrom(msg.sender, address(this), budget);

        emit RoundCreated(roundId, fundingToken, budget, block.timestamp + duration);
    }

    /// @notice Badgeholders cast votes for a project
    function vote(uint256 roundId, uint256 projectId, uint256 voteWeight) external {
        Round storage r = rounds[roundId];
        if (block.timestamp > r.endTime || r.isFinalized) revert RoundNotActive();
        if (!isBadgeholder[msg.sender]) revert NotBadgeholder();
        if (voteWeight == 0) revert ZeroAmount();

        // Quadratic component: adds sqrt(voteWeight)
        uint256 sqrtWeight = FixedPointMathLib.sqrt(voteWeight * 1e18);
        projectSqrtSum[roundId][projectId] += sqrtWeight;

        emit VoteCast(roundId, projectId, msg.sender, voteWeight);
    }

    /// @notice Finalizes round and calculates total quadratic scores
    function finalizeRound(uint256 roundId, uint256[] calldata projectIds) external onlyOwner {
        Round storage r = rounds[roundId];
        if (block.timestamp <= r.endTime) revert RoundNotActive();
        if (r.isFinalized) revert RoundAlreadyFinalized();

        uint256 totalScore = 0;
        for (uint256 i = 0; i < projectIds.length; i++) {
            uint256 sumSqrt = projectSqrtSum[roundId][projectIds[i]];
            // (sum of sqrts)^2 = quadratic total
            uint256 quadraticScore = (sumSqrt * sumSqrt) / 1e18;
            totalScore += quadraticScore;
        }

        r.totalQuadraticScore = totalScore;
        r.isFinalized = true;

        emit RoundFinalized(roundId, r.budget);
    }

    /// @notice Project claims its retroactive reward
    function claimReward(uint256 roundId, uint256 projectId) external nonReentrant returns (uint256 reward) {
        Round storage r = rounds[roundId];
        if (!r.isFinalized) revert RoundNotActive();
        if (hasClaimed[roundId][projectId]) revert ProjectAlreadyClaimed();

        uint256 sumSqrt = projectSqrtSum[roundId][projectId];
        uint256 quadraticScore = (sumSqrt * sumSqrt) / 1e18;
        if (quadraticScore == 0 || r.totalQuadraticScore == 0) return 0;

        reward = (r.budget * quadraticScore) / r.totalQuadraticScore;
        hasClaimed[roundId][projectId] = true;

        address payout = projectRegistry.getPayoutAddress(projectId);
        r.fundingToken.safeTransfer(payout, reward);

        emit RetroRewardClaimed(roundId, projectId, payout, reward);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    function setBadgeholder(address voter, bool status) external onlyOwner {
        if (voter == address(0)) revert ZeroAddress();
        isBadgeholder[voter] = status;
    }
}
