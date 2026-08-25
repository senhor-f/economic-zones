// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Versioned} from "../core/Versioned.sol";
import {HNYToken} from "../token/HNYToken.sol";

/// @title xHNYLockbox (ERC-7281 / xERC20 Sovereign Bridge Lockbox)
/// @notice Manages canonical $HNY$ custody on L1 with daily bridge rate-limiting to eliminate liquidity fragmentation.
contract xHNYLockbox is Ownable, ReentrancyGuard, Versioned {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct BridgeLimits {
        uint256 dailyLimit;
        uint256 currentDaySpent;
        uint256 lastResetTimestamp;
        bool isAuthorized;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokensLocked(address indexed user, address indexed bridge, uint256 amount);
    event TokensUnlocked(address indexed to, address indexed bridge, uint256 amount);
    event BridgeLimitsUpdated(address indexed bridge, uint256 dailyLimit, bool isAuthorized);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error UnauthorizedBridge();
    error RateLimitExceeded();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    HNYToken public immutable hnyToken;
    mapping(address => BridgeLimits) public bridgeLimits;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _hnyToken, address _owner) Versioned("xHNYLockbox") {
        if (_hnyToken == address(0) || _owner == address(0)) revert ZeroAddress();

        hnyToken = HNYToken(_hnyToken);
        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           LOCKBOX OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Locks canonical $HNY$ on L1 to be minted on L2 via authorized bridge
    /// @param bridge Target authorized bridge adapter
    /// @param amount Amount of $HNY$ to lock
    function lock(address bridge, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        BridgeLimits storage limits = bridgeLimits[bridge];
        if (!limits.isAuthorized) revert UnauthorizedBridge();

        _checkAndUpdateRateLimit(limits, amount);

        address(hnyToken).safeTransferFrom(msg.sender, address(this), amount);

        emit TokensLocked(msg.sender, bridge, amount);
    }

    /// @notice Unlocks canonical $HNY$ on L1 after burn on L2. Called by authorized bridge adapter.
    /// @param to Recipient address on L1
    /// @param amount Amount of $HNY$ to unlock
    function unlock(address to, uint256 amount) external nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        BridgeLimits storage limits = bridgeLimits[msg.sender];
        if (!limits.isAuthorized) revert UnauthorizedBridge();

        _checkAndUpdateRateLimit(limits, amount);

        address(hnyToken).safeTransfer(to, amount);

        emit TokensUnlocked(to, msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           RATE LIMIT ENGINE
    //////////////////////////////////////////////////////////////*/

    function _checkAndUpdateRateLimit(BridgeLimits storage limits, uint256 amount) internal {
        if (block.timestamp >= limits.lastResetTimestamp + 1 days) {
            limits.currentDaySpent = 0;
            limits.lastResetTimestamp = block.timestamp;
        }

        if (limits.currentDaySpent + amount > limits.dailyLimit) revert RateLimitExceeded();
        limits.currentDaySpent += amount;
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    function setBridgeLimits(address bridge, uint256 dailyLimit, bool isAuthorized) external onlyOwner {
        if (bridge == address(0)) revert ZeroAddress();

        bridgeLimits[bridge] = BridgeLimits({
            dailyLimit: dailyLimit, currentDaySpent: 0, lastResetTimestamp: block.timestamp, isAuthorized: isAuthorized
        });

        emit BridgeLimitsUpdated(bridge, dailyLimit, isAuthorized);
    }
}
