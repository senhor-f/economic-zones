// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/// @title ZoneVault
/// @notice Autonomous ERC-4626 revenue vault for an Economic Zone.
/// @dev Accumulates commercial revenue, distributes yield, and routes protocol cuts to Core.
contract ZoneVault is ERC4626, Ownable {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event RevenueReceived(address indexed token, uint256 amount);
    event CoreDividendRouted(address indexed token, uint256 amount);
    event SplitConfigUpdated(uint256 coreCutBps);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidSplit();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address private immutable _underlyingAsset;
    address public coreTreasury;
    uint256 public coreCutBps = 2000; // 20% to Core $HNY buyback/burn

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address underlyingAsset_, address coreTreasury_, address initialOwner_) {
        if (underlyingAsset_ == address(0) || coreTreasury_ == address(0) || initialOwner_ == address(0)) {
            revert ZeroAddress();
        }

        _underlyingAsset = underlyingAsset_;
        coreTreasury = coreTreasury_;

        _initializeOwner(initialOwner_);
    }

    /*//////////////////////////////////////////////////////////////
                            METADATA & CONFIG
    //////////////////////////////////////////////////////////////*/

    function name() public pure override returns (string memory) {
        return "Zone Revenue Share";
    }

    function symbol() public pure override returns (string memory) {
        return "zSHARE";
    }

    function asset() public view override returns (address) {
        return _underlyingAsset;
    }

    /*//////////////////////////////////////////////////////////////
                           REVENUE ROUTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Ingests external revenue, splits Core dividend, and auto-compounds remainder
    /// @param amount Amount of underlying asset ingested
    function ingestRevenue(uint256 amount) external {
        if (amount == 0) return;

        _underlyingAsset.safeTransferFrom(msg.sender, address(this), amount);

        uint256 coreDividend = (amount * coreCutBps) / BPS_DENOMINATOR;
        if (coreDividend > 0) {
            _underlyingAsset.safeTransfer(coreTreasury, coreDividend);
            emit CoreDividendRouted(_underlyingAsset, coreDividend);
        }

        emit RevenueReceived(_underlyingAsset, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    function setCoreCutBps(uint256 _coreCutBps) external onlyOwner {
        if (_coreCutBps > 5000) revert InvalidSplit(); // Max 50%
        coreCutBps = _coreCutBps;
        emit SplitConfigUpdated(_coreCutBps);
    }

    function setCoreTreasury(address _coreTreasury) external onlyOwner {
        if (_coreTreasury == address(0)) revert ZeroAddress();
        coreTreasury = _coreTreasury;
    }
}
