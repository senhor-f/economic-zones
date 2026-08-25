// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ProtocolVersion
/// @notice Standardized 32-byte version metadata packing library for Economic Zone Protocol contracts.
/// @dev Packing format (32 bytes total):
/// [0..3]   magic: bytes4 ("HNY2")
/// [4]      major: uint8 (2)
/// [5]      minor: uint8 (1)
/// [6]      patch: uint8 (0)
/// [7..12]  deployedAt: uint48 (timestamp)
/// [13..31] contractName: bytes19 (ASCII name)
library ProtocolVersion {
    bytes4 internal constant MAGIC = "HNY2";
    uint8 internal constant MAJOR = 2;
    uint8 internal constant MINOR = 1;
    uint8 internal constant PATCH = 0;

    /// @notice Packs version metadata into a single bytes32 word
    function pack(bytes19 contractName) internal view returns (bytes32 tag) {
        bytes4 magic = MAGIC;
        uint8 major = MAJOR;
        uint8 minor = MINOR;
        uint8 patch = PATCH;
        uint48 deployedTime = uint48(block.timestamp);

        assembly {
            // Layout (from MSB to LSB):
            // magic (4 bytes): bits 224..255 (already left-aligned in bytes4)
            // major (1 byte):  bits 216..223 (shifted from uint8)
            // minor (1 byte):  bits 208..215 (shifted from uint8)
            // patch (1 byte):  bits 200..207 (shifted from uint8)
            // timestamp (6 bytes / 48 bits): bits 152..199 (shifted from uint48)
            // contractName (19 bytes / 152 bits): bits 0..151 (shifted right by 104 from bytes19)
            let magicMask := and(magic, 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000)
            let header := or(
                magicMask,
                or(
                    shl(216, major),
                    or(
                        shl(208, minor),
                        or(
                            shl(200, patch),
                            shl(152, deployedTime)
                        )
                    )
                )
            )
            let nameBits := shr(104, contractName)
            tag := or(header, nameBits)
        }
    }

    /// @notice Unpacks a version tag into human-readable components
    function unpack(bytes32 tag)
        internal
        pure
        returns (
            bytes4 magic,
            uint8 major,
            uint8 minor,
            uint8 patch,
            uint48 deployedAt,
            bytes19 contractName
        )
    {
        assembly {
            magic := and(tag, 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000)
            major := byte(4, tag)
            minor := byte(5, tag)
            patch := byte(6, tag)
            deployedAt := shr(152, and(tag, 0x00000000000000FFFFFFFFFFFF00000000000000000000000000000000000000))
            contractName := shl(104, and(tag, 0x00000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
        }
    }
}
