// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {HNYToken} from "../token/HNYToken.sol";
import {AugmentedBondingCurve} from "../curve/AugmentedBondingCurve.sol";
import {ZonePaymentGateway} from "./ZonePaymentGateway.sol";

/// @title SwapPayRouter
/// @notice 1-click Swap-and-Pay router: users pay in reserve token (USDC/WETH) and settle natively in $HNY.
/// @dev Atomically buys $HNY on the bonding curve, executes checkout payment, and returns all cashbacks + change to user.
contract SwapPayRouter is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event SwapAndPayExecuted(
        uint256 indexed projectId,
        address indexed payer,
        uint256 reserveSpent,
        uint256 hnyBought,
        uint256 hnyPaid,
        uint256 cashbackReceived
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientHnyMinted();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    HNYToken public immutable hnyToken;
    address public immutable reserveToken;
    AugmentedBondingCurve public immutable bondingCurve;
    ZonePaymentGateway public immutable paymentGateway;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _hnyToken,
        address _reserveToken,
        address _bondingCurve,
        address _paymentGateway,
        address _owner
    ) {
        if (
            _hnyToken == address(0) || _reserveToken == address(0) || _bondingCurve == address(0)
                || _paymentGateway == address(0) || _owner == address(0)
        ) revert ZeroAddress();

        hnyToken = HNYToken(_hnyToken);
        reserveToken = _reserveToken;
        bondingCurve = AugmentedBondingCurve(_bondingCurve);
        paymentGateway = ZonePaymentGateway(_paymentGateway);

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           SWAP & PAY LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice 1-click execution: pays with reserve token, swaps to $HNY, and routes payment
    /// @param projectId Target project receiving payment
    /// @param reserveIn Amount of reserve token (e.g. USDC) to spend
    /// @param hnyRequired Amount of $HNY required by the project checkout
    /// @param minHnyBought Minimum acceptable $HNY minted from the curve (slippage protection)
    function swapAndPay(uint256 projectId, uint256 reserveIn, uint256 hnyRequired, uint256 minHnyBought)
        external
        nonReentrant
        returns (uint256 netProjectAmount, uint256 cashback)
    {
        if (reserveIn == 0 || hnyRequired == 0) revert ZeroAmount();

        // 1. Pull reserve token from user
        reserveToken.safeTransferFrom(msg.sender, address(this), reserveIn);

        // 2. Approve bonding curve and buy $HNY to this router
        reserveToken.safeApprove(address(bondingCurve), reserveIn);
        uint256 hnyBought = bondingCurve.buy(reserveIn, minHnyBought, address(this));
        if (hnyBought < hnyRequired) revert InsufficientHnyMinted();

        // 3. Approve payment gateway and execute payment
        address(hnyToken).safeApprove(address(paymentGateway), hnyRequired);
        (netProjectAmount, cashback) = paymentGateway.pay(projectId, hnyRequired);

        // 4. Refund any surplus $HNY bought from the curve + cashback back to user
        uint256 surplusHny = hnyBought - hnyRequired;
        uint256 totalHnyRefund = surplusHny + cashback;
        if (totalHnyRefund > 0) {
            address(hnyToken).safeTransfer(msg.sender, totalHnyRefund);
        }

        emit SwapAndPayExecuted(projectId, msg.sender, reserveIn, hnyBought, hnyRequired, cashback);
    }
}
