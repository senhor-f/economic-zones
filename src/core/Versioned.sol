// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ProtocolVersion} from "./ProtocolVersion.sol";

/// @title Versioned
/// @notice Abstract contract giving every protocol contract an immutable 32-byte packed version metadata tag.
abstract contract Versioned {
    bytes32 public immutable PROTOCOL_VERSION;

    constructor(bytes19 contractName) {
        PROTOCOL_VERSION = ProtocolVersion.pack(contractName);
    }

    /// @notice Unpacks the immutable protocol version metadata
    function getVersionMetadata()
        external
        view
        returns (bytes4 magic, uint8 major, uint8 minor, uint8 patch, uint48 deployedAt, bytes19 contractName)
    {
        return ProtocolVersion.unpack(PROTOCOL_VERSION);
    }
}
