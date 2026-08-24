// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "solady/auth/Ownable.sol";
import {CitizenTierManager} from "./CitizenTierManager.sol";

interface IEAS {
    struct AttestationRequestData {
        address recipient;
        uint64 expirationTime;
        bool revocable;
        bytes32 refUID;
        bytes data;
        uint256 value;
    }

    struct AttestationRequest {
        bytes32 schema;
        AttestationRequestData data;
    }

    function attest(AttestationRequest calldata request) external payable returns (bytes32);
}

/// @title CitizenAttestor
/// @notice Issues portable on-chain Ethereum Attestation Service (EAS) badges for Citizen Tier achievements.
contract CitizenAttestor is Ownable {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CitizenAttested(
        address indexed citizen,
        bytes32 indexed attestationUID,
        uint8 tier,
        uint256 points
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroTier();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    IEAS public immutable eas;
    CitizenTierManager public immutable tierManager;
    bytes32 public schemaUID;

    mapping(address => bytes32) public latestAttestationUID;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _eas,
        address _tierManager,
        bytes32 _schemaUID,
        address _owner
    ) {
        if (_eas == address(0) || _tierManager == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }
        eas = IEAS(_eas);
        tierManager = CitizenTierManager(_tierManager);
        schemaUID = _schemaUID;

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           ATTESTATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Issues or updates an EAS attestation badge for a citizen based on their on-chain ecosystem tier
    function attestCitizenTier(address citizen) external payable returns (bytes32 uid) {
        if (citizen == address(0)) revert ZeroAddress();

        CitizenTierManager.CitizenTier tier = tierManager.getCitizenTier(citizen);
        if (tier == CitizenTierManager.CitizenTier.NOVICE) revert ZeroTier();

        uint256 points = tierManager.citizenPoints(citizen);
        bytes memory encodedData = abi.encode(citizen, uint8(tier), points, block.timestamp);

        IEAS.AttestationRequest memory request = IEAS.AttestationRequest({
            schema: schemaUID,
            data: IEAS.AttestationRequestData({
                recipient: citizen,
                expirationTime: 0, // No expiration
                revocable: true,
                refUID: latestAttestationUID[citizen],
                data: encodedData,
                value: msg.value
            })
        });

        uid = eas.attest{value: msg.value}(request);
        latestAttestationUID[citizen] = uid;

        emit CitizenAttested(citizen, uid, uint8(tier), points);
    }

    function setSchemaUID(bytes32 _schemaUID) external onlyOwner {
        schemaUID = _schemaUID;
    }
}
