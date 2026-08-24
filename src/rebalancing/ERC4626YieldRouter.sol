// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Ownable} from "solady/auth/Ownable.sol";

interface IERC4626Minimal {
    function asset() external view returns (address);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function balanceOf(address account) external view returns (uint256);
}

/// @title ERC4626YieldRouter
/// @notice Multi-protocol yield router managing allocations across Sky (sUSDS/sDAI), Morpho Blue, and Aave.
contract ERC4626YieldRouter is Ownable {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Strategy {
        address vault;
        uint256 maxAllocationCap;
        uint256 principalDeposited;
        bool isActive;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event StrategyAdded(address indexed vault, uint256 maxAllocationCap);
    event StrategyDeposited(address indexed vault, uint256 assets, uint256 shares);
    event StrategyRedeemed(address indexed vault, uint256 shares, uint256 assets);
    event YieldHarvested(address indexed vault, uint256 yieldAmount, address recipient);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error StrategyNotFound();
    error CapExceeded();
    error InsufficientYield();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable baseAsset;
    address public immutable floorHarvestRecipient;

    address[] public strategyList;
    mapping(address => Strategy) public strategies;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _baseAsset, address _floorHarvestRecipient, address _owner) {
        if (_baseAsset == address(0) || _floorHarvestRecipient == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }

        baseAsset = _baseAsset;
        floorHarvestRecipient = _floorHarvestRecipient;

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           STRATEGY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function addStrategy(address vault, uint256 maxCap) external onlyOwner {
        if (vault == address(0)) revert ZeroAddress();
        if (strategies[vault].vault == address(0)) {
            strategyList.push(vault);
        }
        strategies[vault] = Strategy({
            vault: vault,
            maxAllocationCap: maxCap,
            principalDeposited: strategies[vault].principalDeposited,
            isActive: true
        });

        emit StrategyAdded(vault, maxCap);
    }

    /*//////////////////////////////////////////////////////////////
                           DEPOSIT & REDEEM
    //////////////////////////////////////////////////////////////*/

    function depositToStrategy(address vault, uint256 amount) external onlyOwner {
        Strategy storage strat = strategies[vault];
        if (!strat.isActive) revert StrategyNotFound();
        if (strat.principalDeposited + amount > strat.maxAllocationCap) revert CapExceeded();

        baseAsset.safeTransferFrom(msg.sender, address(this), amount);
        baseAsset.safeApprove(vault, amount);

        uint256 shares = IERC4626Minimal(vault).deposit(amount, address(this));
        strat.principalDeposited += amount;

        emit StrategyDeposited(vault, amount, shares);
    }

    function redeemFromStrategy(address vault, uint256 shares) external onlyOwner returns (uint256 assets) {
        Strategy storage strat = strategies[vault];
        if (strat.vault == address(0)) revert StrategyNotFound();

        assets = IERC4626Minimal(vault).redeem(shares, msg.sender, address(this));
        if (assets >= strat.principalDeposited) {
            strat.principalDeposited = 0;
        } else {
            strat.principalDeposited -= assets;
        }

        emit StrategyRedeemed(vault, shares, assets);
    }

    /*//////////////////////////////////////////////////////////////
                            YIELD HARVESTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Skims excess yield above principal and routes it for $HNY buyback & burn
    function harvestYield(address vault) external returns (uint256 yieldAssets) {
        Strategy storage strat = strategies[vault];
        if (strat.vault == address(0)) revert StrategyNotFound();

        uint256 totalShares = IERC4626Minimal(vault).balanceOf(address(this));
        uint256 totalAssetValue = IERC4626Minimal(vault).convertToAssets(totalShares);

        if (totalAssetValue <= strat.principalDeposited) revert InsufficientYield();

        yieldAssets = totalAssetValue - strat.principalDeposited;
        uint256 sharesToRedeem = (totalShares * yieldAssets) / totalAssetValue;

        if (sharesToRedeem > 0) {
            IERC4626Minimal(vault).redeem(sharesToRedeem, floorHarvestRecipient, address(this));
            emit YieldHarvested(vault, yieldAssets, floorHarvestRecipient);
        }
    }
}
