// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Versioned} from "../core/Versioned.sol";
import {HNYToken} from "../token/HNYToken.sol";
import {AugmentedBondingCurve} from "../curve/AugmentedBondingCurve.sol";

/// @title FloorLockedSavings (veHNY / Savings Lockers)
/// @notice Time-locked savings vault providing boosted voting power (veHNY) and cashback multipliers.
/// @dev Features early exit penalties routed directly to the Floor Price reserve to guarantee monotonic growth.
contract FloorLockedSavings is Ownable, ReentrancyGuard, Versioned {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Lock {
        uint256 id;
        address owner;
        uint256 amount;
        uint256 startTime;
        uint256 unlockTime;
        uint256 boostedAmount;
        bool isUnlocked;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LockCreated(
        uint256 indexed lockId, address indexed owner, uint256 amount, uint256 unlockTime, uint256 boostedAmount
    );
    event LockExtended(uint256 indexed lockId, uint256 newUnlockTime, uint256 newBoostedAmount);
    event LockAmountIncreased(uint256 indexed lockId, uint256 addedAmount, uint256 newBoostedAmount);
    event LockWithdrawn(uint256 indexed lockId, address indexed owner, uint256 amount);
    event EarlyExitExecuted(uint256 indexed lockId, address indexed owner, uint256 payoutAmount, uint256 penaltyAmount);
    event EarlyExitPenaltyUpdated(uint256 newPenaltyBps);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error InvalidDuration();
    error LockNotFound();
    error NotLockOwner();
    error LockStillActive();
    error LockAlreadyUnlocked();
    error LockExpired();
    error InvalidPenalty();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MIN_LOCK_DURATION = 7 days;
    uint256 public constant MAX_LOCK_DURATION = 365 days;
    uint256 public constant BASE_MULTIPLIER_BPS = 10_000; // 1.0x
    uint256 public constant MAX_ADDITIONAL_BOOST_BPS = 30_000; // +3.0x -> max 4.0x total

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    HNYToken public immutable hnyToken;
    AugmentedBondingCurve public immutable bondingCurve;

    uint256 public lockCount;
    uint256 public earlyExitPenaltyBps = 1500; // 15% penalty on emergency early exit

    mapping(uint256 => Lock) public locks;
    mapping(address => uint256[]) public userLockIds;
    mapping(address => uint256) public userActiveVotingPower;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _hnyToken, address _bondingCurve, address _owner) Versioned("FloorLockedSavings") {
        if (_hnyToken == address(0) || _bondingCurve == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }

        hnyToken = HNYToken(_hnyToken);
        bondingCurve = AugmentedBondingCurve(_bondingCurve);
        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                             LOCK OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new time-lock for $HNY
    /// @param amount Amount of $HNY to lock
    /// @param duration Lock duration in seconds (between 7 days and 365 days)
    function createLock(uint256 amount, uint256 duration) external nonReentrant returns (uint256 lockId) {
        if (amount == 0) revert ZeroAmount();
        if (duration < MIN_LOCK_DURATION || duration > MAX_LOCK_DURATION) revert InvalidDuration();

        uint256 boosted = calculateBoostedAmount(amount, duration);
        uint256 unlockTime = block.timestamp + duration;

        lockId = ++lockCount;
        locks[lockId] = Lock({
            id: lockId,
            owner: msg.sender,
            amount: amount,
            startTime: block.timestamp,
            unlockTime: unlockTime,
            boostedAmount: boosted,
            isUnlocked: false
        });

        userLockIds[msg.sender].push(lockId);
        userActiveVotingPower[msg.sender] += boosted;

        // Pull tokens
        address(hnyToken).safeTransferFrom(msg.sender, address(this), amount);

        emit LockCreated(lockId, msg.sender, amount, unlockTime, boosted);
    }

    /// @notice Extends the duration of an active lock
    function extendLock(uint256 lockId, uint256 extraDuration) external nonReentrant {
        Lock storage lock = locks[lockId];
        if (lock.owner != msg.sender) revert NotLockOwner();
        if (lock.isUnlocked) revert LockAlreadyUnlocked();

        uint256 remaining = lock.unlockTime > block.timestamp ? lock.unlockTime - block.timestamp : 0;
        uint256 newTotalDuration = remaining + extraDuration;
        if (newTotalDuration > MAX_LOCK_DURATION || extraDuration == 0) revert InvalidDuration();

        userActiveVotingPower[msg.sender] -= lock.boostedAmount;

        uint256 newUnlockTime = lock.unlockTime + extraDuration;
        uint256 newBoosted = calculateBoostedAmount(lock.amount, newTotalDuration);

        lock.unlockTime = newUnlockTime;
        lock.boostedAmount = newBoosted;
        userActiveVotingPower[msg.sender] += newBoosted;

        emit LockExtended(lockId, newUnlockTime, newBoosted);
    }

    /// @notice Increases the amount of tokens in an active lock
    function increaseLockAmount(uint256 lockId, uint256 addAmount) external nonReentrant {
        if (addAmount == 0) revert ZeroAmount();
        Lock storage lock = locks[lockId];
        if (lock.owner != msg.sender) revert NotLockOwner();
        if (lock.isUnlocked) revert LockAlreadyUnlocked();
        if (block.timestamp >= lock.unlockTime) revert LockExpired();

        uint256 remainingDuration = lock.unlockTime - block.timestamp;
        userActiveVotingPower[msg.sender] -= lock.boostedAmount;

        lock.amount += addAmount;
        uint256 newBoosted = calculateBoostedAmount(lock.amount, remainingDuration);
        lock.boostedAmount = newBoosted;
        userActiveVotingPower[msg.sender] += newBoosted;

        address(hnyToken).safeTransferFrom(msg.sender, address(this), addAmount);

        emit LockAmountIncreased(lockId, addAmount, newBoosted);
    }

    /// @notice Unlocks principal tokens after duration expiry
    function unlock(uint256 lockId) external nonReentrant {
        Lock storage lock = locks[lockId];
        if (lock.owner != msg.sender) revert NotLockOwner();
        if (lock.isUnlocked) revert LockAlreadyUnlocked();
        if (block.timestamp < lock.unlockTime) revert LockStillActive();

        lock.isUnlocked = true;
        userActiveVotingPower[msg.sender] -= lock.boostedAmount;

        address(hnyToken).safeTransfer(msg.sender, lock.amount);

        emit LockWithdrawn(lockId, msg.sender, lock.amount);
    }

    /// @notice Emergency early exit with penalty routed to Floor price
    function earlyExit(uint256 lockId) external nonReentrant returns (uint256 payoutAmount, uint256 penaltyAmount) {
        Lock storage lock = locks[lockId];
        if (lock.owner != msg.sender) revert NotLockOwner();
        if (lock.isUnlocked) revert LockAlreadyUnlocked();

        lock.isUnlocked = true;
        userActiveVotingPower[msg.sender] -= lock.boostedAmount;

        uint256 principal = lock.amount;
        penaltyAmount = (principal * earlyExitPenaltyBps) / BPS_DENOMINATOR;
        payoutAmount = principal - penaltyAmount;

        // 1. Send payout to user
        address(hnyToken).safeTransfer(msg.sender, payoutAmount);

        // 2. Route penalty to bonding curve floor / burn to boost remaining holders
        if (penaltyAmount > 0) {
            address(hnyToken).safeTransfer(address(bondingCurve), penaltyAmount);
        }

        emit EarlyExitExecuted(lockId, msg.sender, payoutAmount, penaltyAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW COMPUTATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates boosted weight based on lock duration
    function calculateBoostedAmount(uint256 amount, uint256 duration) public pure returns (uint256 boosted) {
        if (duration > MAX_LOCK_DURATION) duration = MAX_LOCK_DURATION;
        // boostBps = 10_000 + (duration * 30_000) / MAX_LOCK_DURATION
        uint256 boostBps = BASE_MULTIPLIER_BPS + (duration * MAX_ADDITIONAL_BOOST_BPS) / MAX_LOCK_DURATION;
        assembly {
            boosted := div(mul(amount, boostBps), 10000)
        }
    }

    /// @notice Returns active lock IDs for a user
    function getUserLocks(address user) external view returns (uint256[] memory) {
        return userLockIds[user];
    }

    /// @notice Calculates extra cashback bonus basis points based on locked position (up to +100 bps = 1.0%)
    function getUserCashbackBonusBps(address user) external view returns (uint256 bonusBps) {
        uint256 power = userActiveVotingPower[user];
        if (power >= 100_000e18) return 100; // +1.0% bonus for Whales
        if (power >= 25_000e18) return 50; // +0.5% bonus for Citizens
        if (power >= 5_000e18) return 25; // +0.25% bonus for Supporters
        return 0;
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    function setEarlyExitPenaltyBps(uint256 newPenaltyBps) external onlyOwner {
        if (newPenaltyBps > 5000) revert InvalidPenalty(); // Max 50%
        earlyExitPenaltyBps = newPenaltyBps;
        emit EarlyExitPenaltyUpdated(newPenaltyBps);
    }
}
