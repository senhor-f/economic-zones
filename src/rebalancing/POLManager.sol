// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {HNYToken} from "../token/HNYToken.sol";

/// @title POLManager
/// @notice Protocol-Owned Liquidity (POL) manager holding DEX positions and routing LP trading fees.
contract POLManager is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LiquidityDeployed(address indexed pool, uint256 reserveAmount, uint256 hnyAmount);
    event FeesHarvested(address indexed pool, uint256 reserveFee, uint256 hnyFee);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    HNYToken public immutable hnyToken;
    address public immutable reserveToken;
    address public treasuryVault;

    mapping(address => bool) public isAuthorizedDexPool;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _hnyToken, address _reserveToken, address _treasuryVault, address _owner) {
        if (
            _hnyToken == address(0) || _reserveToken == address(0) || _treasuryVault == address(0)
                || _owner == address(0)
        ) revert ZeroAddress();

        hnyToken = HNYToken(_hnyToken);
        reserveToken = _reserveToken;
        treasuryVault = _treasuryVault;

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           LIQUIDITY OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Records deployment of protocol-owned liquidity to a verified DEX pool
    function recordLiquidityDeployment(address pool, uint256 reserveAmount, uint256 hnyAmount) external onlyOwner {
        if (pool == address(0)) revert ZeroAddress();
        isAuthorizedDexPool[pool] = true;
        emit LiquidityDeployed(pool, reserveAmount, hnyAmount);
    }

    /// @notice Harvests trading fees earned from the POL position and routes to Treasury & Burn
    function harvestFees(address pool, uint256 reserveFee, uint256 hnyFee)
        external
        nonReentrant
        returns (uint256 hnyBurned)
    {
        if (pool == address(0)) revert ZeroAddress();

        if (reserveFee > 0) {
            reserveToken.safeTransferFrom(msg.sender, treasuryVault, reserveFee);
        }

        if (hnyFee > 0) {
            address(hnyToken).safeTransferFrom(msg.sender, address(this), hnyFee);
            hnyToken.burn(hnyFee);
            hnyBurned = hnyFee;
        }

        emit FeesHarvested(pool, reserveFee, hnyFee);
    }

    function setTreasuryVault(address _treasuryVault) external onlyOwner {
        if (_treasuryVault == address(0)) revert ZeroAddress();
        treasuryVault = _treasuryVault;
    }
}
