// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {AugmentedBondingCurve} from "../curve/AugmentedBondingCurve.sol";

/// @title FloorDripper
/// @notice Continuously drips yield into the Augmented Bonding Curve reserve to ensure linear monotonic Floor Price growth.
contract FloorDripper is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event YieldFunded(address indexed funder, uint256 amount);
    event YieldDripped(uint256 amountDripped, uint256 newFloorPrice, uint256 remainingBufferedYield);
    event DripRateUpdated(uint256 newRatePerSecond);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable reserveToken;
    AugmentedBondingCurve public immutable bondingCurve;

    uint256 public dripRatePerSecond; // Reserve token wei per second
    uint256 public lastDripTimestamp;
    uint256 public bufferedYield;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _reserveToken, address _bondingCurve, uint256 _initialDripRatePerSecond, address _owner) {
        if (_reserveToken == address(0) || _bondingCurve == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }

        reserveToken = _reserveToken;
        bondingCurve = AugmentedBondingCurve(_bondingCurve);
        dripRatePerSecond = _initialDripRatePerSecond;
        lastDripTimestamp = block.timestamp;

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                            YIELD FUNDING
    //////////////////////////////////////////////////////////////*/

    /// @notice Funds the dripper buffer with yield harvested from DeFi protocols
    function fundYield(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        // 1. Drip pending yield before adding new buffer
        _drip();

        bufferedYield += amount;
        reserveToken.safeTransferFrom(msg.sender, address(this), amount);

        emit YieldFunded(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                             DRIP EXECUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Triggers yield drip to the bonding curve floor
    function drip() external nonReentrant returns (uint256 drippedAmount) {
        return _drip();
    }

    function _drip() internal returns (uint256 toDrip) {
        uint256 elapsed = block.timestamp - lastDripTimestamp;
        if (elapsed == 0 || bufferedYield == 0 || dripRatePerSecond == 0) {
            lastDripTimestamp = block.timestamp;
            return 0;
        }

        uint256 potentialDrip = elapsed * dripRatePerSecond;
        toDrip = potentialDrip > bufferedYield ? bufferedYield : potentialDrip;

        bufferedYield -= toDrip;
        lastDripTimestamp = block.timestamp;

        if (toDrip > 0) {
            reserveToken.safeApprove(address(bondingCurve), toDrip);
            bondingCurve.depositFloorYield(toDrip);
        }

        emit YieldDripped(toDrip, bondingCurve.getFloorPrice(), bufferedYield);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    function setDripRatePerSecond(uint256 _newRate) external onlyOwner {
        _drip();
        dripRatePerSecond = _newRate;
        emit DripRateUpdated(_newRate);
    }
}
