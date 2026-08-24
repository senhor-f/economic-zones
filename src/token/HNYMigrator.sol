// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {HNYToken} from "./HNYToken.sol";

/// @title HNYMigrator
/// @notice Trustless, fair 1:1 (+ early bird bonus) migration contract from legacy HNY (v1) to new $HNY (v2).
/// @dev Burns or locks legacy HNY on Gnosis/Mainnet and mints native $HNY v2.
contract HNYMigrator is Ownable {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Migrated(address indexed user, uint256 oldAmount, uint256 newAmount, uint256 bonusAmount);
    event BonusPeriodUpdated(uint256 bonusDeadline, uint256 bonusBps);
    event MigrationPausedUpdated(bool paused);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error MigrationPaused();
    error ZeroAmount();
    error InvalidBonus();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Legacy HNY token contract
    address public immutable oldHNY;

    /// @notice New HNY v2 token contract
    HNYToken public immutable newHNY;

    /// @notice Early bird bonus in basis points (e.g. 500 = 5%)
    uint256 public bonusBps;

    /// @notice Timestamp until which early bird bonus is active
    uint256 public bonusDeadline;

    /// @notice Pause switch for emergency
    bool public isPaused;

    /// @notice Total legacy HNY migrated
    uint256 public totalOldMigrated;

    /// @notice Total new HNY minted (including bonuses)
    uint256 public totalNewMinted;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _oldHNY, address _newHNY, address _owner, uint256 _bonusBps, uint256 _bonusDuration) {
        if (_oldHNY == address(0) || _newHNY == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }
        if (_bonusBps > 2000) revert InvalidBonus(); // Max 20% bonus

        oldHNY = _oldHNY;
        newHNY = HNYToken(_newHNY);
        bonusBps = _bonusBps;
        bonusDeadline = block.timestamp + _bonusDuration;

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           MIGRATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Migrates old HNY tokens to new $HNY tokens 1:1 + bonus if within bonus period.
    /// @param amount Amount of old HNY tokens to migrate
    function migrate(uint256 amount) external {
        if (isPaused) revert MigrationPaused();
        if (amount == 0) revert ZeroAmount();

        // 1. Pull old HNY to DEAD address (burn)
        oldHNY.safeTransferFrom(msg.sender, DEAD_ADDRESS, amount);

        // 2. Calculate bonus if applicable
        uint256 bonus = 0;
        if (block.timestamp <= bonusDeadline && bonusBps > 0) {
            bonus = (amount * bonusBps) / BPS_DENOMINATOR;
        }

        uint256 totalToMint = amount + bonus;

        totalOldMigrated += amount;
        totalNewMinted += totalToMint;

        // 3. Mint new $HNY to user
        newHNY.mint(msg.sender, totalToMint);

        emit Migrated(msg.sender, amount, totalToMint, bonus);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the early bird bonus configuration
    function setBonusConfig(uint256 _bonusDeadline, uint256 _bonusBps) external onlyOwner {
        if (_bonusBps > 2000) revert InvalidBonus();
        bonusDeadline = _bonusDeadline;
        bonusBps = _bonusBps;
        emit BonusPeriodUpdated(_bonusDeadline, _bonusBps);
    }

    /// @notice Pauses or unpauses migration
    function setPaused(bool _paused) external onlyOwner {
        isPaused = _paused;
        emit MigrationPausedUpdated(_paused);
    }
}
