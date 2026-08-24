// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ContributionLedger} from "./ContributionLedger.sol";
import {ProjectRegistry} from "./ProjectRegistry.sol";

/// @title ProjectCollateral
/// @notice Manages project registration collateral deposits, slashing for inactivity/evasion, and cooldown withdrawals.
contract ProjectCollateral is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct CollateralRecord {
        uint256 amount;
        uint256 lockedAt;
        uint256 unlockRequestedAt;
        bool isSlashed;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(uint256 indexed projectId, address indexed depositor, uint256 amount);
    event CollateralSlashed(uint256 indexed projectId, uint256 amountSlashed, address indexed treasuryRecipient);
    event UnlockRequested(uint256 indexed projectId, uint256 releaseTime);
    event CollateralWithdrawn(uint256 indexed projectId, address indexed recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientCollateral();
    error NotProjectPayout();
    error ProjectAlreadySlashed();
    error UnlockNotRequested();
    error CooldownNotElapsed();
    error ProjectActiveCannotSlash();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant COOLDOWN_PERIOD = 14 days;
    uint256 public constant MAX_INACTIVE_EPOCHS = 3;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable collateralToken;
    ContributionLedger public immutable ledger;
    ProjectRegistry public immutable registry;
    address public treasuryVault;

    uint256 public minCollateralAmount;
    mapping(uint256 => CollateralRecord) public projectCollaterals;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _collateralToken,
        address _ledger,
        address _registry,
        address _treasuryVault,
        uint256 _minCollateral,
        address _owner
    ) {
        if (
            _collateralToken == address(0) ||
            _ledger == address(0) ||
            _registry == address(0) ||
            _treasuryVault == address(0) ||
            _owner == address(0)
        ) revert ZeroAddress();

        collateralToken = _collateralToken;
        ledger = ContributionLedger(_ledger);
        registry = ProjectRegistry(_registry);
        treasuryVault = _treasuryVault;
        minCollateralAmount = _minCollateral;

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                          DEPOSIT & STAKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits required collateral for a registered project
    function depositCollateral(uint256 projectId, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        address payout = registry.getPayoutAddress(projectId);
        if (msg.sender != payout && msg.sender != owner()) revert NotProjectPayout();

        CollateralRecord storage record = projectCollaterals[projectId];
        if (record.isSlashed) revert ProjectAlreadySlashed();

        record.amount += amount;
        record.lockedAt = block.timestamp;
        record.unlockRequestedAt = 0; // reset any pending unlock

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(projectId, msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          SLASHING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Slashes collateral of inactive projects (> 3 epochs without activity) or fee evaders
    function slashInactiveProject(uint256 projectId) external nonReentrant returns (uint256 slashedAmount) {
        CollateralRecord storage record = projectCollaterals[projectId];
        if (record.isSlashed) revert ProjectAlreadySlashed();
        if (record.amount == 0) revert InsufficientCollateral();

        (,,,,,, uint256 lastEpoch) = ledger.metrics(projectId);
        uint256 currentEpoch = ledger.currentEpoch();

        // Project is active if within MAX_INACTIVE_EPOCHS
        if (currentEpoch <= lastEpoch + MAX_INACTIVE_EPOCHS && lastEpoch != 0) {
            revert ProjectActiveCannotSlash();
        }

        slashedAmount = record.amount;
        record.amount = 0;
        record.isSlashed = true;

        collateralToken.safeTransfer(treasuryVault, slashedAmount);

        emit CollateralSlashed(projectId, slashedAmount, treasuryVault);
    }

    /*//////////////////////////////////////////////////////////////
                         WITHDRAWAL COOLDOWN
    //////////////////////////////////////////////////////////////*/

    /// @notice Initiates unlock cooldown for withdrawing collateral
    function requestUnlock(uint256 projectId) external {
        address payout = registry.getPayoutAddress(projectId);
        if (msg.sender != payout) revert NotProjectPayout();

        CollateralRecord storage record = projectCollaterals[projectId];
        if (record.isSlashed) revert ProjectAlreadySlashed();
        if (record.amount == 0) revert InsufficientCollateral();

        record.unlockRequestedAt = block.timestamp;
        emit UnlockRequested(projectId, block.timestamp + COOLDOWN_PERIOD);
    }

    /// @notice Completes collateral withdrawal after cooldown
    function withdrawCollateral(uint256 projectId) external nonReentrant returns (uint256 amount) {
        address payout = registry.getPayoutAddress(projectId);
        if (msg.sender != payout) revert NotProjectPayout();

        CollateralRecord storage record = projectCollaterals[projectId];
        if (record.isSlashed) revert ProjectAlreadySlashed();
        if (record.unlockRequestedAt == 0) revert UnlockNotRequested();
        if (block.timestamp < record.unlockRequestedAt + COOLDOWN_PERIOD) revert CooldownNotElapsed();

        amount = record.amount;
        record.amount = 0;
        record.unlockRequestedAt = 0;

        collateralToken.safeTransfer(payout, amount);

        emit CollateralWithdrawn(projectId, payout, amount);
    }
}
