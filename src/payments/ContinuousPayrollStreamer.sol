// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Versioned} from "../core/Versioned.sol";

/// @title ContinuousPayrollStreamer
/// @notice Continuous second-by-second salary streaming for zone citizens with automated tax withholding.
contract ContinuousPayrollStreamer is Ownable, ReentrancyGuard, Versioned {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Stream {
        uint256 id;
        address payer;
        address recipient;
        address token;
        uint256 depositAmount;
        uint256 ratePerSecond;
        uint256 startTime;
        uint256 stopTime;
        uint256 withdrawnAmount;
        uint256 taxRateBps;
        address taxCollector;
        bool isPaused;
        bool isCanceled;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event StreamCreated(
        uint256 indexed streamId,
        address indexed payer,
        address indexed recipient,
        address token,
        uint256 depositAmount,
        uint256 startTime,
        uint256 stopTime,
        uint256 ratePerSecond
    );
    event TokensWithdrawn(uint256 indexed streamId, address indexed recipient, uint256 netAmount, uint256 taxAmount);
    event StreamCanceled(uint256 indexed streamId, address indexed payer, address indexed recipient, uint256 payerRefund, uint256 recipientVested);
    event StreamPaused(uint256 indexed streamId);
    event StreamResumed(uint256 indexed streamId);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error InvalidDuration();
    error InvalidTaxRate();
    error StreamNotFound();
    error NotStreamPayer();
    error NotStreamRecipient();
    error StreamIsPaused();
    error StreamIsCanceled();
    error AmountExceedsAvailable();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public streamCount;
    mapping(uint256 => Stream) public streams;
    mapping(address => uint256[]) internal payerStreamIds;
    mapping(address => uint256[]) internal recipientStreamIds;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) Versioned("PayrollStreamer") {
        if (_owner == address(0)) revert ZeroAddress();
        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                             STREAM CREATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new continuous payroll stream
    /// @param recipient Worker / citizen address
    /// @param token Currency token ($HNY / USDC)
    /// @param depositAmount Total tokens to stream
    /// @param duration Stream duration in seconds
    /// @param taxRateBps Tax withholding rate in BPS (e.g. 500 = 5%)
    /// @param taxCollector Address of the tax collection vault / treasury
    function createStream(
        address recipient,
        address token,
        uint256 depositAmount,
        uint256 duration,
        uint256 taxRateBps,
        address taxCollector
    ) external nonReentrant returns (uint256 streamId) {
        if (recipient == address(0) || token == address(0)) revert ZeroAddress();
        if (depositAmount == 0) revert ZeroAmount();
        if (duration == 0) revert InvalidDuration();
        if (taxRateBps > 3000) revert InvalidTaxRate(); // Max 30% tax
        if (taxRateBps > 0 && taxCollector == address(0)) revert ZeroAddress();

        uint256 rate = depositAmount / duration;
        if (rate == 0) revert ZeroAmount();

        // Adjust deposit to match exact rate * duration to prevent dust
        uint256 exactDeposit = rate * duration;
        uint256 startTime = block.timestamp;
        uint256 stopTime = startTime + duration;

        streamId = ++streamCount;
        streams[streamId] = Stream({
            id: streamId,
            payer: msg.sender,
            recipient: recipient,
            token: token,
            depositAmount: exactDeposit,
            ratePerSecond: rate,
            startTime: startTime,
            stopTime: stopTime,
            withdrawnAmount: 0,
            taxRateBps: taxRateBps,
            taxCollector: taxCollector,
            isPaused: false,
            isCanceled: false
        });

        payerStreamIds[msg.sender].push(streamId);
        recipientStreamIds[recipient].push(streamId);

        // Pull funds
        token.safeTransferFrom(msg.sender, address(this), exactDeposit);

        emit StreamCreated(streamId, msg.sender, recipient, token, exactDeposit, startTime, stopTime, rate);
    }

    /*//////////////////////////////////////////////////////////////
                           WITHDRAWAL & VESTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates the total vested amount up to the current block
    function vestedAmountOf(uint256 streamId) public view returns (uint256) {
        Stream storage stream = streams[streamId];
        if (stream.depositAmount == 0) return 0;
        if (block.timestamp <= stream.startTime) return 0;

        if (block.timestamp >= stream.stopTime) {
            return stream.depositAmount;
        }

        uint256 elapsed = block.timestamp - stream.startTime;
        return elapsed * stream.ratePerSecond;
    }

    /// @notice Returns the available claimable balance for the recipient
    function availableToWithdraw(uint256 streamId) public view returns (uint256) {
        Stream storage stream = streams[streamId];
        if (stream.isPaused) return 0;

        uint256 totalVested = vestedAmountOf(streamId);
        if (totalVested <= stream.withdrawnAmount) return 0;
        return totalVested - stream.withdrawnAmount;
    }

    /// @notice Withdraws vested salary tokens
    /// @param streamId Stream ID
    /// @param amount Amount to withdraw
    function withdrawFromStream(uint256 streamId, uint256 amount) external nonReentrant returns (uint256 netPaid, uint256 taxPaid) {
        Stream storage stream = streams[streamId];
        if (stream.recipient != msg.sender) revert NotStreamRecipient();
        if (stream.isPaused) revert StreamIsPaused();
        if (amount == 0) revert ZeroAmount();

        uint256 available = availableToWithdraw(streamId);
        if (amount > available) revert AmountExceedsAvailable();

        stream.withdrawnAmount += amount;

        taxPaid = (amount * stream.taxRateBps) / BPS_DENOMINATOR;
        netPaid = amount - taxPaid;

        // 1. Send net salary to recipient
        stream.token.safeTransfer(stream.recipient, netPaid);

        // 2. Route withholding tax to tax collector
        if (taxPaid > 0) {
            stream.token.safeTransfer(stream.taxCollector, taxPaid);
        }

        emit TokensWithdrawn(streamId, stream.recipient, netPaid, taxPaid);
    }

    /*//////////////////////////////////////////////////////////////
                            STREAM MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Cancels an active stream, returning unvested funds to the payer
    function cancelStream(uint256 streamId) external nonReentrant returns (uint256 payerRefund, uint256 recipientVested) {
        Stream storage stream = streams[streamId];
        if (msg.sender != stream.payer && msg.sender != owner()) revert NotStreamPayer();
        if (stream.isCanceled) revert StreamIsCanceled();

        uint256 totalVested = vestedAmountOf(streamId);
        stream.isCanceled = true;

        payerRefund = stream.depositAmount > totalVested ? stream.depositAmount - totalVested : 0;
        recipientVested = totalVested > stream.withdrawnAmount ? totalVested - stream.withdrawnAmount : 0;

        stream.stopTime = block.timestamp;
        stream.depositAmount = totalVested;

        // Refund unvested tokens to payer
        if (payerRefund > 0) {
            stream.token.safeTransfer(stream.payer, payerRefund);
        }

        // Payout remaining vested balance to recipient with tax
        if (recipientVested > 0) {
            stream.withdrawnAmount += recipientVested;
            uint256 tax = (recipientVested * stream.taxRateBps) / BPS_DENOMINATOR;
            uint256 net = recipientVested - tax;
            stream.token.safeTransfer(stream.recipient, net);
            if (tax > 0) {
                stream.token.safeTransfer(stream.taxCollector, tax);
            }
        }

        emit StreamCanceled(streamId, stream.payer, stream.recipient, payerRefund, recipientVested);
    }

    function pauseStream(uint256 streamId) external {
        Stream storage stream = streams[streamId];
        if (msg.sender != stream.payer && msg.sender != owner()) revert NotStreamPayer();
        stream.isPaused = true;
        emit StreamPaused(streamId);
    }

    function resumeStream(uint256 streamId) external {
        Stream storage stream = streams[streamId];
        if (msg.sender != stream.payer && msg.sender != owner()) revert NotStreamPayer();
        stream.isPaused = false;
        emit StreamResumed(streamId);
    }
}
