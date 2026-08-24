// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ECDSA} from "solady/utils/ECDSA.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {HNYToken} from "../token/HNYToken.sol";
import {ZonePaymentGateway} from "./ZonePaymentGateway.sol";

/// @title x402Settler
/// @notice Machine-to-machine HTTP 402 payment settler for autonomous AI agents paying in $HNY.
contract x402Settler is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct PaymentAuthorization {
        address agent;
        uint256 projectId;
        uint256 amount;
        bytes32 nonce;
        uint256 deadline;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event x402PaymentSettled(
        address indexed agent,
        uint256 indexed projectId,
        uint256 amount,
        bytes32 indexed nonce,
        uint256 netProjectAmount,
        uint256 cashback
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error SignatureExpired();
    error NonceAlreadyUsed();
    error InvalidSignature();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant TYPEHASH = keccak256(
        "PaymentAuthorization(address agent,uint256 projectId,uint256 amount,bytes32 nonce,uint256 deadline)"
    );

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    HNYToken public immutable hnyToken;
    ZonePaymentGateway public immutable paymentGateway;
    bytes32 public immutable DOMAIN_SEPARATOR;

    mapping(address => mapping(bytes32 => bool)) public usedNonces;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _hnyToken,
        address _paymentGateway,
        address _owner
    ) {
        if (_hnyToken == address(0) || _paymentGateway == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }

        hnyToken = HNYToken(_hnyToken);
        paymentGateway = ZonePaymentGateway(_paymentGateway);

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("EconomicZone-x402")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           x402 SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Settles an HTTP 402 challenge using a signed EIP-712 PaymentAuthorization
    function settlePayment(
        PaymentAuthorization calldata auth,
        bytes calldata signature
    ) external nonReentrant returns (uint256 netProjectAmount, uint256 cashback) {
        if (auth.agent == address(0)) revert ZeroAddress();
        if (auth.amount == 0) revert ZeroAmount();
        if (block.timestamp > auth.deadline) revert SignatureExpired();
        if (usedNonces[auth.agent][auth.nonce]) revert NonceAlreadyUsed();

        // 1. Verify EIP-712 Signature
        bytes32 structHash = keccak256(
            abi.encode(
                TYPEHASH,
                auth.agent,
                auth.projectId,
                auth.amount,
                auth.nonce,
                auth.deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        address signer = digest.recover(signature);
        if (signer != auth.agent) revert InvalidSignature();

        usedNonces[auth.agent][auth.nonce] = true;

        // 2. Pull $HNY from Agent to this Settler
        address(hnyToken).safeTransferFrom(auth.agent, address(this), auth.amount);

        // 3. Approve payment gateway and route payment
        address(hnyToken).safeApprove(address(paymentGateway), auth.amount);
        (netProjectAmount, cashback) = paymentGateway.pay(auth.projectId, auth.amount);

        // 4. Return cashback to agent wallet
        if (cashback > 0) {
            address(hnyToken).safeTransfer(auth.agent, cashback);
        }

        emit x402PaymentSettled(
            auth.agent,
            auth.projectId,
            auth.amount,
            auth.nonce,
            netProjectAmount,
            cashback
        );
    }
}
