// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {L1BlobCommerceVerifier} from "../../src/crosschain/L1BlobCommerceVerifier.sol";

contract MockPointEvaluationPrecompile {
    fallback(bytes calldata) external returns (bytes memory) {
        // Return 64 bytes (FIELD_ELEMENTS_PER_BLOB + BLS_MODULUS)
        return abi.encode(uint256(4096), uint256(0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001));
    }
}

contract L1BlobCommerceVerifierTest is Test {
    L1BlobCommerceVerifier public verifier;
    MockPointEvaluationPrecompile public mockPrecompile;

    address public owner = address(0xAA);
    uint256 public epoch = 1;
    uint256 public projectId = 100;
    uint256 public volumeAmount = 50_000e18; // 50k sales volume on L2

    bytes32 public versionedHash = 0x0100000000000000000000000000000000000000000000000000000000000001;
    bytes32 public pointZ = bytes32(uint256(12345));
    bytes32 public valueY;
    bytes public commitment = new bytes(48);
    bytes public proof = new bytes(48);

    function setUp() public {
        mockPrecompile = new MockPointEvaluationPrecompile();

        vm.prank(owner);
        verifier = new L1BlobCommerceVerifier(address(mockPrecompile), owner);

        // ValueY is the commitment to (epoch, projectId, volumeAmount)
        valueY = keccak256(abi.encodePacked(epoch, projectId, volumeAmount));
    }

    function test_VerifyBlobCommerceBatch_AccumulatesVolume() public {
        bool verified = verifier.verifyBlobCommerceBatch(
            versionedHash, pointZ, valueY, commitment, proof, epoch, projectId, volumeAmount
        );

        assertTrue(verified);
        assertTrue(verifier.isBatchVerified(epoch, versionedHash));
        assertEq(verifier.verifiedProjectVolume(projectId), volumeAmount);
    }

    function test_RevertWhen_DoubleVerifyingSameBatch() public {
        verifier.verifyBlobCommerceBatch(
            versionedHash, pointZ, valueY, commitment, proof, epoch, projectId, volumeAmount
        );

        vm.expectRevert(L1BlobCommerceVerifier.BatchAlreadyVerified.selector);
        verifier.verifyBlobCommerceBatch(
            versionedHash, pointZ, valueY, commitment, proof, epoch, projectId, volumeAmount
        );
    }

    function test_RevertWhen_ValueMismatch() public {
        bytes32 wrongValueY = bytes32(uint256(999999));

        vm.expectRevert(L1BlobCommerceVerifier.ValueMismatch.selector);
        verifier.verifyBlobCommerceBatch(
            versionedHash, pointZ, wrongValueY, commitment, proof, epoch, projectId, volumeAmount
        );
    }
}
