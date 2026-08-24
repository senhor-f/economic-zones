// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {HNYToken} from "./HNYToken.sol";

/// @title GenesisPool
/// @notice Time-limited genesis bootstrap pool funding the Treasury, initial POL, and early distribution.
contract GenesisPool is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event GenesisDeposited(address indexed user, uint256 reserveDeposited, uint256 hnyMinted);
    event GenesisFinalized(uint256 totalRaised, uint256 treasuryAmount, uint256 polAmount, uint256 curveAmount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error GenesisEnded();
    error GenesisStillActive();
    error HardCapExceeded();
    error AlreadyFinalized();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant WAD = 1e18;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    HNYToken public immutable hnyToken;
    address public immutable reserveToken;
    address public treasuryVault;
    address public polManager;
    address public bondingCurve;

    uint256 public immutable hardCap;
    uint256 public immutable genesisPrice; // Reserve per HNY (in WAD, e.g. 0.8e18)
    uint256 public immutable deadline;

    uint256 public totalRaised;
    bool public isFinalized;

    // Splits in basis points
    uint256 public treasurySplitBps = 2000; // 20%
    uint256 public polSplitBps = 1500; // 15%
    uint256 public curveSplitBps = 6500; // 65%

    mapping(address => uint256) public userDeposited;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _hnyToken,
        address _reserveToken,
        address _treasuryVault,
        address _polManager,
        address _bondingCurve,
        address _owner,
        uint256 _hardCap,
        uint256 _genesisPrice,
        uint256 _duration
    ) {
        if (
            _hnyToken == address(0) || _reserveToken == address(0) || _treasuryVault == address(0)
                || _polManager == address(0) || _bondingCurve == address(0) || _owner == address(0)
        ) revert ZeroAddress();

        hnyToken = HNYToken(_hnyToken);
        reserveToken = _reserveToken;
        treasuryVault = _treasuryVault;
        polManager = _polManager;
        bondingCurve = _bondingCurve;
        hardCap = _hardCap;
        genesisPrice = _genesisPrice;
        deadline = block.timestamp + _duration;

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           GENESIS PARTICIPATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits reserve tokens to purchase discounted genesis $HNY
    function deposit(uint256 reserveAmount) external nonReentrant returns (uint256 hnyMinted) {
        if (block.timestamp > deadline) revert GenesisEnded();
        if (reserveAmount == 0) revert ZeroAmount();
        if (totalRaised + reserveAmount > hardCap) revert HardCapExceeded();

        totalRaised += reserveAmount;
        userDeposited[msg.sender] += reserveAmount;

        // Calculate HNY to mint: (reserveAmount * WAD) / genesisPrice
        hnyMinted = (reserveAmount * WAD) / genesisPrice;

        // 1. Pull reserve from user
        reserveToken.safeTransferFrom(msg.sender, address(this), reserveAmount);

        // 2. Mint HNY to user
        hnyToken.mint(msg.sender, hnyMinted);

        emit GenesisDeposited(msg.sender, reserveAmount, hnyMinted);
    }

    /// @notice Finalizes Genesis pool and distributes funds to Treasury, POL Manager, and Bonding Curve
    function finalize() external nonReentrant {
        if (block.timestamp <= deadline && totalRaised < hardCap) revert GenesisStillActive();
        if (isFinalized) revert AlreadyFinalized();

        isFinalized = true;

        uint256 treasuryCut = (totalRaised * treasurySplitBps) / BPS_DENOMINATOR;
        uint256 polCut = (totalRaised * polSplitBps) / BPS_DENOMINATOR;
        uint256 curveCut = totalRaised - (treasuryCut + polCut);

        // Route funds
        if (treasuryCut > 0) reserveToken.safeTransfer(treasuryVault, treasuryCut);
        if (polCut > 0) reserveToken.safeTransfer(polManager, polCut);
        if (curveCut > 0) reserveToken.safeTransfer(bondingCurve, curveCut);

        emit GenesisFinalized(totalRaised, treasuryCut, polCut, curveCut);
    }
}
