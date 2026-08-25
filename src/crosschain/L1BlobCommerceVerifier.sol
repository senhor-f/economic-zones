// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {Versioned} from "../core/Versioned.sol";

/// @title L1BlobCommerceVerifier
/// @notice Verifies L2 commercial sales volume on Ethereum L1 using EIP-4844 KZG Point Evaluation Precompile (0x0A).
/// @dev Enables zero-knowledge / trust-minimized Proof-of-Commerce attribution without expensive L1 calldata.
contract L1BlobCommerceVerifier is Ownable, ReentrancyGuard, Versioned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CommerceVolumeVerified(
        uint256 indexed epoch, uint256 indexed projectId, uint256 volumeAmount, bytes32 indexed versionedHash
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error InvalidKZGProof();
    error BatchAlreadyVerified();
    error InvalidInputLength();
    error ValueMismatch();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice EIP-4844 Point Evaluation Precompile address (default 0x0A)
    address public immutable pointEvaluationPrecompile;

    /// @notice Verified volume per project accumulated from L2 blobs: projectId => verifiedVolume
    mapping(uint256 => uint256) public verifiedProjectVolume;

    /// @notice Processed blob batches: epoch => versionedHash => bool
    mapping(uint256 => mapping(bytes32 => bool)) public isBatchVerified;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _precompile, address _owner) Versioned("BlobVerifier") {
        if (_owner == address(0)) revert ZeroAddress();
        pointEvaluationPrecompile = _precompile == address(0) ? address(0x0A) : _precompile;
        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           BLOB VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Verifies that an L2 commercial batch opening is committed in an EIP-4844 Blob
    /// @param versionedHash Versioned hash of the blob (from BLOBHASH)
    /// @param pointZ Evaluation point z (32 bytes)
    /// @param valueY Claimed polynomial opening value y at z (32 bytes)
    /// @param commitment KZG commitment (48 bytes)
    /// @param proof KZG proof (48 bytes)
    /// @param epoch L2 reporting epoch
    /// @param projectId Registered project ID in the Economic Zone
    /// @param volumeAmount Total verified sales volume in $HNY/USDC in this batch
    function verifyBlobCommerceBatch(
        bytes32 versionedHash,
        bytes32 pointZ,
        bytes32 valueY,
        bytes calldata commitment,
        bytes calldata proof,
        uint256 epoch,
        uint256 projectId,
        uint256 volumeAmount
    ) external nonReentrant returns (bool success) {
        if (commitment.length != 48 || proof.length != 48) revert InvalidInputLength();
        if (volumeAmount == 0) revert ZeroAmount();
        if (isBatchVerified[epoch][versionedHash]) revert BatchAlreadyVerified();

        // 1. Verify that valueY cryptographically commits to (epoch, projectId, volumeAmount)
        bytes32 expectedValueCommitment = keccak256(abi.encodePacked(epoch, projectId, volumeAmount));
        if (valueY != expectedValueCommitment) revert ValueMismatch();

        // 2. Prepare 192-byte input for EIP-4844 Point Evaluation Precompile (0x0A):
        // [0..31]    versioned_hash (32 bytes)
        // [32..63]   point z (32 bytes)
        // [64..95]   value y (32 bytes)
        // [96..143]  commitment (48 bytes)
        // [144..191] proof (48 bytes)
        bytes memory precompileInput = abi.encodePacked(versionedHash, pointZ, valueY, commitment, proof);

        // 3. Call Point Evaluation Precompile
        (bool callOk, bytes memory returnData) = pointEvaluationPrecompile.staticcall(precompileInput);
        if (!callOk || returnData.length != 64) revert InvalidKZGProof();

        // 4. Mark batch as verified and accumulate project volume
        isBatchVerified[epoch][versionedHash] = true;
        verifiedProjectVolume[projectId] += volumeAmount;

        emit CommerceVolumeVerified(epoch, projectId, volumeAmount, versionedHash);
        return true;
    }
}
