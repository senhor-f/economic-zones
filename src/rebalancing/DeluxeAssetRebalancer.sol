// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/// @title DeluxeAssetRebalancer
/// @notice Intent-based Dutch Auction rebalancer and circuit breaker for DAO treasury assets.
/// @dev Eliminates MEV sandwich attacks by running gradual Dutch auctions filled by solvers.
contract DeluxeAssetRebalancer is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct TargetAllocation {
        address token;
        uint256 targetWeightBps; // In basis points (e.g. 5000 = 50%)
        bool isActive;
    }

    struct DutchAuction {
        address sellToken;
        address buyToken;
        uint256 sellAmount;
        uint256 startPriceWad; // Initial price in WAD (e.g. 1.05e18)
        uint256 minPriceWad; // Reserve floor price in WAD (e.g. 0.98e18)
        uint256 startTime;
        uint256 duration;
        bool isCompleted;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event AllocationConfigured(address indexed token, uint256 targetWeightBps);
    event AuctionStarted(
        uint256 indexed auctionId,
        address indexed sellToken,
        address indexed buyToken,
        uint256 sellAmount,
        uint256 startPriceWad,
        uint256 minPriceWad,
        uint256 duration
    );
    event AuctionFilled(
        uint256 indexed auctionId,
        address indexed solver,
        uint256 sellAmount,
        uint256 buyAmountReceived,
        uint256 executionPriceWad
    );
    event EmergencyFlightTriggered(address indexed depeggedToken, address indexed safeHavenToken, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error InvalidAllocation();
    error AuctionNotActive();
    error AuctionExpired();
    error SlippageExceeded();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant WAD = 1e18;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public treasuryVault;
    uint256 public auctionCount;

    mapping(uint256 => DutchAuction) public auctions;
    mapping(address => TargetAllocation) public allocations;
    address[] public managedTokens;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _treasuryVault, address _owner) {
        if (_treasuryVault == address(0) || _owner == address(0)) revert ZeroAddress();
        treasuryVault = _treasuryVault;
        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                          ALLOCATION CONFIG
    //////////////////////////////////////////////////////////////*/

    function setTargetAllocation(address token, uint256 targetWeightBps) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (targetWeightBps > BPS_DENOMINATOR) revert InvalidAllocation();

        if (!allocations[token].isActive) {
            managedTokens.push(token);
        }

        allocations[token] = TargetAllocation({token: token, targetWeightBps: targetWeightBps, isActive: true});

        emit AllocationConfigured(token, targetWeightBps);
    }

    /*//////////////////////////////////////////////////////////////
                           DUTCH AUCTION ENGINE
    //////////////////////////////////////////////////////////////*/

    /// @notice Launches a gradual Dutch auction to rebalance treasury tokens without MEV leakage
    function startAuction(
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        uint256 startPriceWad,
        uint256 minPriceWad,
        uint256 duration
    ) external onlyOwner returns (uint256 auctionId) {
        if (sellToken == address(0) || buyToken == address(0)) revert ZeroAddress();
        if (sellAmount == 0 || startPriceWad < minPriceWad || duration == 0) revert ZeroAmount();

        sellToken.safeTransferFrom(msg.sender, address(this), sellAmount);

        auctionId = ++auctionCount;
        auctions[auctionId] = DutchAuction({
            sellToken: sellToken,
            buyToken: buyToken,
            sellAmount: sellAmount,
            startPriceWad: startPriceWad,
            minPriceWad: minPriceWad,
            startTime: block.timestamp,
            duration: duration,
            isCompleted: false
        });

        emit AuctionStarted(auctionId, sellToken, buyToken, sellAmount, startPriceWad, minPriceWad, duration);
    }

    /// @notice Returns current decaying auction price
    function getCurrentPrice(uint256 auctionId) public view returns (uint256) {
        DutchAuction storage auc = auctions[auctionId];
        if (auc.isCompleted) return 0;

        uint256 elapsed = block.timestamp - auc.startTime;
        if (elapsed >= auc.duration) {
            return auc.minPriceWad;
        }

        uint256 priceDrop = ((auc.startPriceWad - auc.minPriceWad) * elapsed) / auc.duration;
        return auc.startPriceWad - priceDrop;
    }

    /// @notice Solver fills the auction at the current Dutch auction price
    function fillAuction(uint256 auctionId, uint256 maxBuyTokenIn)
        external
        nonReentrant
        returns (uint256 buyTokenCost)
    {
        DutchAuction storage auc = auctions[auctionId];
        if (auc.isCompleted) revert AuctionNotActive();

        uint256 currentPriceWad = getCurrentPrice(auctionId);
        buyTokenCost = (auc.sellAmount * currentPriceWad) / WAD;
        if (buyTokenCost > maxBuyTokenIn) revert SlippageExceeded();

        auc.isCompleted = true;

        // 1. Pull buyToken from solver to treasury
        auc.buyToken.safeTransferFrom(msg.sender, treasuryVault, buyTokenCost);

        // 2. Deliver sellToken to solver
        auc.sellToken.safeTransfer(msg.sender, auc.sellAmount);

        emit AuctionFilled(auctionId, msg.sender, auc.sellAmount, buyTokenCost, currentPriceWad);
    }

    /*//////////////////////////////////////////////////////////////
                           CIRCUIT BREAKER
    //////////////////////////////////////////////////////////////*/

    /// @notice Emergency exit for a depegging asset
    function triggerEmergencyFlight(address depeggedToken, address safeHavenToken, uint256 amount) external onlyOwner {
        if (depeggedToken == address(0) || safeHavenToken == address(0)) revert ZeroAddress();
        depeggedToken.safeTransferFrom(treasuryVault, address(this), amount);
        // Emits alert for keeper / solver integration
        emit EmergencyFlightTriggered(depeggedToken, safeHavenToken, amount);
    }
}
