// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Versioned} from "../core/Versioned.sol";

/// @title L2CommerceBatcher
/// @notice Aggregates high-frequency L2 commerce volume and routes collected taxes/tributes to L1 Floor Dripper.
contract L2CommerceBatcher is Ownable, ReentrancyGuard, Versioned {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct EpochBatch {
        uint256 epoch;
        bytes32 batchRoot;
        uint256 totalVolume;
        uint256 totalTaxCollected;
        uint256 projectCount;
        uint256 closedAt;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event BatchFinalized(uint256 indexed epoch, bytes32 indexed batchRoot, uint256 totalVolume, uint256 totalTaxCollected);
    event FundsBridgedToL1(address indexed token, address indexed l1Receiver, uint256 amount);
    event SequencerAuthorized(address indexed sequencer, bool status);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error UnauthorizedSequencer();
    error EpochAlreadyClosed();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable usdcToken;
    address public l1BridgeReceiver;

    uint256 public currentEpoch;
    mapping(uint256 => EpochBatch) public epochBatches;
    mapping(address => bool) public isAuthorizedSequencer;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _usdcToken, address _l1BridgeReceiver, address _owner) Versioned("L2Batcher") {
        if (_usdcToken == address(0) || _owner == address(0)) revert ZeroAddress();

        usdcToken = _usdcToken;
        l1BridgeReceiver = _l1BridgeReceiver;
        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                            BATCH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Finalizes an L2 commercial epoch batch for inclusion in an EIP-4844 Blob
    /// @param epoch Epoch identifier
    /// @param batchRoot Merkle root or polynomial commitment of all transaction receipts in the epoch
    /// @param totalVolume Total volume processed in the epoch
    /// @param totalTaxCollected Total zone tax/tributes collected in USDC
    /// @param projectCount Number of active merchant projects included
    function finalizeEpochBatch(
        uint256 epoch,
        bytes32 batchRoot,
        uint256 totalVolume,
        uint256 totalTaxCollected,
        uint256 projectCount
    ) external nonReentrant {
        if (!isAuthorizedSequencer[msg.sender] && msg.sender != owner()) revert UnauthorizedSequencer();
        if (epochBatches[epoch].closedAt != 0) revert EpochAlreadyClosed();

        epochBatches[epoch] = EpochBatch({
            epoch: epoch,
            batchRoot: batchRoot,
            totalVolume: totalVolume,
            totalTaxCollected: totalTaxCollected,
            projectCount: projectCount,
            closedAt: block.timestamp
        });

        currentEpoch = epoch;

        emit BatchFinalized(epoch, batchRoot, totalVolume, totalTaxCollected);
    }

    /// @notice Bridges collected zone taxes/tributes to L1 Floor Dripper
    /// @param amount Amount of USDC to bridge
    /// @param bridgeAdapter Address of canonical L2-to-L1 bridge contract
    function bridgeTributesToL1(uint256 amount, address bridgeAdapter) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (bridgeAdapter == address(0)) revert ZeroAddress();

        usdcToken.safeTransfer(bridgeAdapter, amount);

        emit FundsBridgedToL1(usdcToken, l1BridgeReceiver, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    function setSequencer(address sequencer, bool status) external onlyOwner {
        if (sequencer == address(0)) revert ZeroAddress();
        isAuthorizedSequencer[sequencer] = status;
        emit SequencerAuthorized(sequencer, status);
    }

    function setL1BridgeReceiver(address _l1BridgeReceiver) external onlyOwner {
        if (_l1BridgeReceiver == address(0)) revert ZeroAddress();
        l1BridgeReceiver = _l1BridgeReceiver;
    }
}
