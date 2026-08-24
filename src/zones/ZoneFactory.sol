// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "solady/auth/Ownable.sol";
import {ZoneVault} from "./ZoneVault.sol";
import {ConvictionVoting} from "./ConvictionVoting.sol";
import {RetroPGFPool} from "./RetroPGFPool.sol";
import {ProjectRegistry} from "../payments/ProjectRegistry.sol";

/// @title ZoneFactory
/// @notice Factory for launching sovereign, modular Economic Zones connected to Core $HNY.
contract ZoneFactory is Ownable {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct EconomicZoneInstance {
        address vault;
        address convictionVoting;
        address retroPGFPool;
        address zoneAdmin;
        string zoneName;
        bool isActive;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ZoneCreated(
        uint256 indexed zoneId,
        string zoneName,
        address indexed zoneAdmin,
        address vault,
        address convictionVoting,
        address retroPGFPool
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable hnyToken;
    address public immutable coreTreasury;
    ProjectRegistry public immutable projectRegistry;

    uint256 public zoneCount;
    mapping(uint256 => EconomicZoneInstance) public zones;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _hnyToken, address _coreTreasury, address _projectRegistry, address _owner) {
        if (
            _hnyToken == address(0) || _coreTreasury == address(0) || _projectRegistry == address(0)
                || _owner == address(0)
        ) revert ZeroAddress();

        hnyToken = _hnyToken;
        coreTreasury = _coreTreasury;
        projectRegistry = ProjectRegistry(_projectRegistry);

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           ZONE DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Launches a complete new Economic Zone
    /// @param zoneName Human-readable name of the Zone
    /// @param zoneAdmin Admin / Governor for the local Zone
    /// @param underlyingAsset Base currency for the Zone Vault (e.g. USDC/WETH/sUSDS)
    function createZone(string calldata zoneName, address zoneAdmin, address underlyingAsset)
        external
        returns (uint256 zoneId, address vault, address voting, address rpgf)
    {
        if (zoneAdmin == address(0) || underlyingAsset == address(0)) revert ZeroAddress();

        zoneId = ++zoneCount;

        // 1. Deploy Zone Vault
        ZoneVault zoneVault = new ZoneVault(underlyingAsset, coreTreasury, zoneAdmin);
        vault = address(zoneVault);

        // 2. Deploy Conviction Voting instance
        ConvictionVoting convVoting = new ConvictionVoting(hnyToken, vault, zoneAdmin);
        voting = address(convVoting);

        // 3. Deploy RetroPGF instance
        RetroPGFPool retroPool = new RetroPGFPool(address(projectRegistry), zoneAdmin);
        rpgf = address(retroPool);

        zones[zoneId] = EconomicZoneInstance({
            vault: vault,
            convictionVoting: voting,
            retroPGFPool: rpgf,
            zoneAdmin: zoneAdmin,
            zoneName: zoneName,
            isActive: true
        });

        emit ZoneCreated(zoneId, zoneName, zoneAdmin, vault, voting, rpgf);
    }
}
