// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {DeluxeAssetRebalancer} from "./DeluxeAssetRebalancer.sol";

interface IAggregatorV3 {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function decimals() external view returns (uint8);
}

/// @title OracleCircuitBreaker
/// @notice Automated keeper-compatible depeg detector and circuit breaker protecting DAO reserves.
contract OracleCircuitBreaker is Ownable {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct AssetGuard {
        address token;
        address priceFeed;
        uint256 minPriceThresholdWad; // e.g. 0.985e18
        uint256 maxStaleness; // Max allowed heartbeat delay (e.g. 3600s)
        address safeHavenToken;
        bool isActive;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event AssetGuardConfigured(address indexed token, address priceFeed, uint256 minPriceThresholdWad);
    event DepegCircuitTriggered(address indexed token, uint256 observedPriceWad, uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error StalePriceFeed();
    error InvalidPrice();
    error GuardNotActive();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant WAD = 1e18;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    DeluxeAssetRebalancer public immutable rebalancer;
    mapping(address => AssetGuard) public assetGuards;
    address[] public guardedAssets;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _rebalancer, address _owner) {
        if (_rebalancer == address(0) || _owner == address(0)) revert ZeroAddress();
        rebalancer = DeluxeAssetRebalancer(_rebalancer);
        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           GUARD CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function setAssetGuard(
        address token,
        address priceFeed,
        uint256 minPriceThresholdWad,
        uint256 maxStaleness,
        address safeHavenToken
    ) external onlyOwner {
        if (token == address(0) || priceFeed == address(0) || safeHavenToken == address(0)) {
            revert ZeroAddress();
        }

        if (!assetGuards[token].isActive) {
            guardedAssets.push(token);
        }

        assetGuards[token] = AssetGuard({
            token: token,
            priceFeed: priceFeed,
            minPriceThresholdWad: minPriceThresholdWad,
            maxStaleness: maxStaleness,
            safeHavenToken: safeHavenToken,
            isActive: true
        });

        emit AssetGuardConfigured(token, priceFeed, minPriceThresholdWad);
    }

    /*//////////////////////////////////////////////////////////////
                           PRICE EVALUATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns current normalized price in WAD from Chainlink/Redstone
    function getNormalizedPrice(address token) public view returns (uint256) {
        AssetGuard storage guard = assetGuards[token];
        if (!guard.isActive) revert GuardNotActive();

        (, int256 price,, uint256 updatedAt,) = IAggregatorV3(guard.priceFeed).latestRoundData();
        if (price <= 0) revert InvalidPrice();
        if (block.timestamp - updatedAt > guard.maxStaleness) revert StalePriceFeed();

        uint8 feedDecimals = IAggregatorV3(guard.priceFeed).decimals();

        if (feedDecimals == 18) {
            return uint256(price);
        } else if (feedDecimals < 18) {
            return uint256(price) * (10 ** (18 - feedDecimals));
        } else {
            return uint256(price) / (10 ** (feedDecimals - 18));
        }
    }

    /// @notice Checks if an asset has depegged
    function isDepegged(address token) public view returns (bool, uint256) {
        AssetGuard storage guard = assetGuards[token];
        if (!guard.isActive) return (false, 0);

        uint256 currentPriceWad = getNormalizedPrice(token);
        if (currentPriceWad < guard.minPriceThresholdWad) {
            return (true, currentPriceWad);
        }
        return (false, currentPriceWad);
    }

    /*//////////////////////////////////////////////////////////////
                         KEEPER AUTOMATION UPKEEP
    //////////////////////////////////////////////////////////////*/

    /// @notice Chainlink / Gelato upkeep check
    function checkUpkeep() external view returns (bool upkeepNeeded, bytes memory performData) {
        for (uint256 i = 0; i < guardedAssets.length; i++) {
            address token = guardedAssets[i];
            (bool depegged,) = isDepegged(token);
            if (depegged) {
                return (true, abi.encode(token));
            }
        }
        return (false, "");
    }

    /// @notice Triggers emergency exit when depeg is detected
    function performUpkeep(bytes calldata performData) external {
        address token = abi.decode(performData, (address));
        (bool depegged, uint256 priceWad) = isDepegged(token);
        if (!depegged) return;

        AssetGuard storage guard = assetGuards[token];
        emit DepegCircuitTriggered(token, priceWad, block.timestamp);

        // Call emergency flight on rebalancer
        uint256 balance = token.balanceOf(rebalancer.treasuryVault());
        if (balance > 0) {
            rebalancer.triggerEmergencyFlight(token, guard.safeHavenToken, balance);
        }
    }
}
