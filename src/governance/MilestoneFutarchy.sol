// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/// @title MilestoneFutarchy
/// @notice Algorithmic milestone grant escrow unlocked by predictive market consensus.
contract MilestoneFutarchy is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Milestone {
        uint256 grantId;
        uint256 trancheIndex;
        uint256 trancheAmount;
        address beneficiary;
        address fundingToken;
        uint256 evaluationDeadline;
        uint256 yesPool;
        uint256 noPool;
        bool isResolved;
        bool isPassed;
        bool isClaimed;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event MilestoneCreated(
        uint256 indexed milestoneId,
        uint256 indexed grantId,
        address indexed beneficiary,
        uint256 trancheAmount,
        uint256 evaluationDeadline
    );
    event PredictionPlaced(uint256 indexed milestoneId, address indexed predictor, bool isYes, uint256 amount);
    event MilestoneResolved(uint256 indexed milestoneId, bool isPassed, uint256 yesPool, uint256 noPool);
    event TrancheReleased(uint256 indexed milestoneId, address indexed beneficiary, uint256 amount);
    event EscrowRefunded(uint256 indexed milestoneId, address indexed treasury, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error DeadlinePassed();
    error DeadlineNotPassed();
    error AlreadyResolved();
    error AlreadyClaimed();
    error NotPassed();
    error NoStake();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant PASSING_THRESHOLD_BPS = 5_000; // 50% YES probability

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable bettingToken; // Token used for betting (USDC or HNY)
    address public treasuryVault;

    uint256 public milestoneCount;
    mapping(uint256 => Milestone) public milestones;
    mapping(uint256 => mapping(address => uint256)) public userYesStake;
    mapping(uint256 => mapping(address => uint256)) public userNoStake;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _bettingToken, address _treasuryVault, address _owner) {
        if (_bettingToken == address(0) || _treasuryVault == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }
        bettingToken = _bettingToken;
        treasuryVault = _treasuryVault;
        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           MILESTONE LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new predictive milestone in escrow funded by the DAO
    function createMilestone(
        uint256 grantId,
        uint256 trancheIndex,
        uint256 trancheAmount,
        address beneficiary,
        address fundingToken,
        uint256 votingDuration
    ) external nonReentrant returns (uint256 milestoneId) {
        if (beneficiary == address(0) || fundingToken == address(0)) revert ZeroAddress();
        if (trancheAmount == 0) revert ZeroAmount();

        milestoneId = ++milestoneCount;
        milestones[milestoneId] = Milestone({
            grantId: grantId,
            trancheIndex: trancheIndex,
            trancheAmount: trancheAmount,
            beneficiary: beneficiary,
            fundingToken: fundingToken,
            evaluationDeadline: block.timestamp + votingDuration,
            yesPool: 0,
            noPool: 0,
            isResolved: false,
            isPassed: false,
            isClaimed: false
        });

        // Pull grant funds into escrow from caller/Treasury
        fundingToken.safeTransferFrom(msg.sender, address(this), trancheAmount);

        emit MilestoneCreated(milestoneId, grantId, beneficiary, trancheAmount, block.timestamp + votingDuration);
    }

    /// @notice Predicts whether the milestone will be successfully delivered (YES or NO)
    function predict(uint256 milestoneId, bool isYes, uint256 amount) external nonReentrant {
        Milestone storage m = milestones[milestoneId];
        if (block.timestamp > m.evaluationDeadline) revert DeadlinePassed();
        if (amount == 0) revert ZeroAmount();

        bettingToken.safeTransferFrom(msg.sender, address(this), amount);

        if (isYes) {
            m.yesPool += amount;
            userYesStake[milestoneId][msg.sender] += amount;
        } else {
            m.noPool += amount;
            userNoStake[milestoneId][msg.sender] += amount;
        }

        emit PredictionPlaced(milestoneId, msg.sender, isYes, amount);
    }

    /// @notice Resolves milestone after deadline based on predictive market consensus
    function resolveMilestone(uint256 milestoneId) external nonReentrant {
        Milestone storage m = milestones[milestoneId];
        if (block.timestamp <= m.evaluationDeadline) revert DeadlineNotPassed();
        if (m.isResolved) revert AlreadyResolved();

        m.isResolved = true;

        uint256 totalPool = m.yesPool + m.noPool;
        if (totalPool == 0) {
            // Default pass if no negative bets placed
            m.isPassed = true;
        } else {
            uint256 yesProbBps = (m.yesPool * BPS_DENOMINATOR) / totalPool;
            m.isPassed = (yesProbBps >= PASSING_THRESHOLD_BPS);
        }

        emit MilestoneResolved(milestoneId, m.isPassed, m.yesPool, m.noPool);

        // If passed, release grant tranche to beneficiary; if failed, refund to Treasury
        if (m.isPassed) {
            m.isClaimed = true;
            m.fundingToken.safeTransfer(m.beneficiary, m.trancheAmount);
            emit TrancheReleased(milestoneId, m.beneficiary, m.trancheAmount);
        } else {
            m.isClaimed = true;
            m.fundingToken.safeTransfer(treasuryVault, m.trancheAmount);
            emit EscrowRefunded(milestoneId, treasuryVault, m.trancheAmount);
        }
    }

    /// @notice Allows winning predictors to claim their share of the prediction pool
    function claimPredictionReward(uint256 milestoneId) external nonReentrant returns (uint256 reward) {
        Milestone storage m = milestones[milestoneId];
        if (!m.isResolved) revert DeadlineNotPassed();

        uint256 totalPool = m.yesPool + m.noPool;
        if (totalPool == 0) revert NoStake();

        if (m.isPassed) {
            uint256 userStake = userYesStake[milestoneId][msg.sender];
            if (userStake == 0) revert NoStake();
            userYesStake[milestoneId][msg.sender] = 0;

            reward = (userStake * totalPool) / m.yesPool;
        } else {
            uint256 userStake = userNoStake[milestoneId][msg.sender];
            if (userStake == 0) revert NoStake();
            userNoStake[milestoneId][msg.sender] = 0;

            reward = (userStake * totalPool) / m.noPool;
        }

        bettingToken.safeTransfer(msg.sender, reward);
    }
}
