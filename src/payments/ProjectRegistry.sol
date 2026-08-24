// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "solady/auth/Ownable.sol";

/// @title ProjectRegistry
/// @notice Canonical registry for commercial and public goods ventures connected to the Economic Zone.
contract ProjectRegistry is Ownable {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Project {
        address owner;
        address payoutAddress;
        string metadataURI;
        uint8 category; // 0 = SaaS/AI, 1 = DeFi/Perps, 2 = Infrastructure, 3 = RWA/Physical, 4 = Public Goods
        bool isActive;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ProjectRegistered(
        uint256 indexed projectId,
        address indexed owner,
        address indexed payoutAddress,
        uint8 category,
        string metadataURI
    );
    event ProjectUpdated(uint256 indexed projectId, address indexed payoutAddress, string metadataURI, bool isActive);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error NotProjectOwner();
    error ProjectNotFound();
    error ProjectInactive();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public projectCount;
    mapping(uint256 => Project) public projects;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        _initializeOwner(initialOwner);
    }

    /*//////////////////////////////////////////////////////////////
                           REGISTRATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers a new project in the Economic Zone
    /// @param payoutAddress Address receiving revenue payments
    /// @param metadataURI IPFS/Arweave URI containing project info
    /// @param category Category identifier
    function registerProject(address payoutAddress, string calldata metadataURI, uint8 category)
        external
        returns (uint256 projectId)
    {
        if (payoutAddress == address(0)) revert ZeroAddress();

        projectId = ++projectCount;
        projects[projectId] = Project({
            owner: msg.sender,
            payoutAddress: payoutAddress,
            metadataURI: metadataURI,
            category: category,
            isActive: true
        });

        emit ProjectRegistered(projectId, msg.sender, payoutAddress, category, metadataURI);
    }

    /// @notice Updates project settings. Only callable by the project owner.
    function updateProject(uint256 projectId, address newPayoutAddress, string calldata newMetadataURI, bool isActive)
        external
    {
        Project storage proj = projects[projectId];
        if (proj.owner == address(0)) revert ProjectNotFound();
        if (proj.owner != msg.sender && msg.sender != owner()) revert NotProjectOwner();
        if (newPayoutAddress == address(0)) revert ZeroAddress();

        proj.payoutAddress = newPayoutAddress;
        proj.metadataURI = newMetadataURI;
        proj.isActive = isActive;

        emit ProjectUpdated(projectId, newPayoutAddress, newMetadataURI, isActive);
    }

    /// @notice Returns active project payout address
    function getPayoutAddress(uint256 projectId) external view returns (address) {
        Project storage proj = projects[projectId];
        if (!proj.isActive) revert ProjectInactive();
        return proj.payoutAddress;
    }
}
