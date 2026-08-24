// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "solady/auth/Ownable.sol";
import {HNYToken} from "../token/HNYToken.sol";

/// @title CitizenTierManager
/// @notice Unified reputation & tier manager connecting Economic Zone, xB77, and SuperLoops.
contract CitizenTierManager is Ownable {
    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    enum CitizenTier {
        NOVICE,
        BRONZE,
        SILVER,
        GOLD,
        DIAMOND
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CitizenPointsAdded(address indexed citizen, uint256 points, uint256 totalPoints);
    event ExternalIntegrationUpdated(address indexed adapter, bool indexed status);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error NotAuthorizedAdapter();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BRONZE_POINTS = 100;
    uint256 public constant SILVER_POINTS = 500;
    uint256 public constant GOLD_POINTS = 2000;
    uint256 public constant DIAMOND_POINTS = 10000;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    HNYToken public immutable hnyToken;

    mapping(address => uint256) public citizenPoints;
    mapping(address => bool) public isAuthorizedAdapter;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _hnyToken, address _owner) {
        if (_hnyToken == address(0) || _owner == address(0)) revert ZeroAddress();
        hnyToken = HNYToken(_hnyToken);
        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           POINTS MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds reputation points to a citizen (callable by PaymentGateway, xB77 guards, or SuperLoops)
    function addPoints(address citizen, uint256 points) external {
        if (!isAuthorizedAdapter[msg.sender] && msg.sender != owner()) revert NotAuthorizedAdapter();
        if (citizen == address(0)) revert ZeroAddress();

        citizenPoints[citizen] += points;
        emit CitizenPointsAdded(citizen, points, citizenPoints[citizen]);
    }

    /// @notice Computes dynamic Citizen Tier based on points + $HNY balance
    function getCitizenTier(address citizen) public view returns (CitizenTier) {
        uint256 points = citizenPoints[citizen];
        uint256 hnyBalance = hnyToken.balanceOf(citizen);

        // $HNY balance also adds virtual points (1 HNY = 1 point)
        uint256 totalScore = points + (hnyBalance / 1e18);

        if (totalScore >= DIAMOND_POINTS) return CitizenTier.DIAMOND;
        if (totalScore >= GOLD_POINTS) return CitizenTier.GOLD;
        if (totalScore >= SILVER_POINTS) return CitizenTier.SILVER;
        if (totalScore >= BRONZE_POINTS) return CitizenTier.BRONZE;
        return CitizenTier.NOVICE;
    }

    /// @notice Returns voting multiplier in basis points (10000 = 1.0x)
    function getVotingMultiplierBps(address citizen) external view returns (uint256) {
        CitizenTier tier = getCitizenTier(citizen);
        if (tier == CitizenTier.DIAMOND) return 20000; // 2.0x
        if (tier == CitizenTier.GOLD) return 15000; // 1.5x
        if (tier == CitizenTier.SILVER) return 12500; // 1.25x
        if (tier == CitizenTier.BRONZE) return 11000; // 1.1x
        return 10000; // 1.0x
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    function setAuthorizedAdapter(address adapter, bool status) external onlyOwner {
        if (adapter == address(0)) revert ZeroAddress();
        isAuthorizedAdapter[adapter] = status;
        emit ExternalIntegrationUpdated(adapter, status);
    }
}
