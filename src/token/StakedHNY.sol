// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Versioned} from "../core/Versioned.sol";
import {HNYToken} from "./HNYToken.sol";

/// @title StakedHNY ($sHNY)
/// @notice Liquid Staking ERC-4626 vault for $HNY.
/// @dev Autocompounds rewards from exit tributes, POL fee harvesting, and yield distributions.
contract StakedHNY is ERC4626, Ownable, ReentrancyGuard, Versioned {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event RewardsDistributed(address indexed distributor, uint256 amount, uint256 newExchangeRate);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable underlyingHny;
    uint256 public totalRewardsIngested;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _hny Address of the $HNY token
    /// @param _owner Initial owner / governance timelock
    constructor(address _hny, address _owner) Versioned("StakedHNY") {
        if (_hny == address(0) || _owner == address(0)) revert ZeroAddress();
        underlyingHny = _hny;
        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                            METADATA & ASSET
    //////////////////////////////////////////////////////////////*/

    function asset() public view override returns (address) {
        return underlyingHny;
    }

    function name() public pure override returns (string memory) {
        return "Staked Honey";
    }

    function symbol() public pure override returns (string memory) {
        return "sHNY";
    }

    /*//////////////////////////////////////////////////////////////
                           REWARD INGESTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Ingests external rewards ($HNY) into the vault, appreciating $sHNY value for all stakers.
    /// @param amount Amount of $HNY to distribute
    function distributeRewards(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        totalRewardsIngested += amount;
        underlyingHny.safeTransferFrom(msg.sender, address(this), amount);

        emit RewardsDistributed(msg.sender, amount, getHNYPerShare());
    }

    /*//////////////////////////////////////////////////////////////
                           EXCHANGE RATE HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the amount of $HNY backed by 1 full $sHNY token (1e18 shares)
    /// @return hnyPerShare Exchange rate scaled to 1e18
    function getHNYPerShare() public view returns (uint256 hnyPerShare) {
        uint256 supply = totalSupply();
        if (supply == 0) return 1e18; // 1:1 at genesis

        uint256 assets = totalAssets();
        assembly {
            // (assets * 1e18) / supply
            hnyPerShare := div(mul(assets, 1000000000000000000), supply)
        }
    }
}
