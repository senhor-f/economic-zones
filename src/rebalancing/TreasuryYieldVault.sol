// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {AugmentedBondingCurve} from "../curve/AugmentedBondingCurve.sol";

/// @title TreasuryYieldVault
/// @notice Institutional ERC-4626 vault with 100% principal protection for DAO treasuries + 20% Floor Dripper contribution.
contract TreasuryYieldVault is ERC4626, Ownable, ReentrancyGuard {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event YieldHarvested(uint256 grossYield, uint256 daoShare, uint256 floorShare);
    event FloorSplitUpdated(uint256 newFloorSplitBps);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error InvalidSplit();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable assetToken;
    AugmentedBondingCurve public immutable bondingCurve;

    uint256 public floorSplitBps = 2000; // 20% to $HNY Floor, 80% to DAO depositors
    uint256 public totalYieldHarvested;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _assetToken, address _bondingCurve, address _owner) {
        if (_assetToken == address(0) || _bondingCurve == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }

        assetToken = _assetToken;
        bondingCurve = AugmentedBondingCurve(_bondingCurve);

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           METADATA & ASSET
    //////////////////////////////////////////////////////////////*/

    function asset() public view override returns (address) {
        return assetToken;
    }

    function name() public pure override returns (string memory) {
        return "Treasury Protected Yield Vault";
    }

    function symbol() public pure override returns (string memory) {
        return "tUSDC";
    }

    /*//////////////////////////////////////////////////////////////
                            YIELD HARVESTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Ingests raw yield generated from external DeFi strategies (sUSDS, Morpho, Aave)
    function harvestYield(uint256 grossYield) external nonReentrant returns (uint256 daoCut, uint256 floorCut) {
        if (grossYield == 0) revert ZeroAmount();

        floorCut = (grossYield * floorSplitBps) / BPS_DENOMINATOR;
        daoCut = grossYield - floorCut;

        totalYieldHarvested += grossYield;

        // 1. Pull yield in asset token
        assetToken.safeTransferFrom(msg.sender, address(this), grossYield);

        // 2. Route 20% floor share to the bonding curve
        if (floorCut > 0) {
            assetToken.safeApprove(address(bondingCurve), floorCut);
            bondingCurve.depositFloorYield(floorCut);
        }

        // 3. The remaining 80% stays in the vault, increasing totalAssets and boosting DAO share value!
        emit YieldHarvested(grossYield, daoCut, floorCut);
    }

    function setFloorSplitBps(uint256 _newSplit) external onlyOwner {
        if (_newSplit > 5000) revert InvalidSplit(); // Max 50%
        floorSplitBps = _newSplit;
        emit FloorSplitUpdated(_newSplit);
    }
}
