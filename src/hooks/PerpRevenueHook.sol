// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {HNYToken} from "../token/HNYToken.sol";
import {ContributionLedger} from "../payments/ContributionLedger.sol";

/// @title PerpRevenueHook
/// @notice Lightweight, universal fee capture and attribution hook connecting Perps & DEXes to the Economic Zone.
contract PerpRevenueHook is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PerpTradeRouted(
        uint256 indexed projectId,
        address indexed trader,
        uint256 notionalVolume,
        uint256 totalFee,
        uint256 buybackBurned,
        uint256 treasuryCut,
        uint256 traderCashback
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error InvalidSplit();
    error NotAuthorizedCaller();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    HNYToken public immutable hnyToken;
    ContributionLedger public immutable contributionLedger;
    address public treasuryVault;

    /// @notice Authorized perp execution routers / settlement engines
    mapping(address => bool) public isAuthorizedRouter;

    /// @notice Fee split configuration (e.g., 50% burn, 30% treasury floor, 20% trader cashback)
    uint256 public burnShareBps = 5000;
    uint256 public treasuryShareBps = 3000;
    uint256 public cashbackShareBps = 2000;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _hnyToken, address _contributionLedger, address _treasuryVault, address _owner) {
        if (
            _hnyToken == address(0) || _contributionLedger == address(0) || _treasuryVault == address(0)
                || _owner == address(0)
        ) revert ZeroAddress();

        hnyToken = HNYToken(_hnyToken);
        contributionLedger = ContributionLedger(_contributionLedger);
        treasuryVault = _treasuryVault;

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           FEE ROUTING HOOK
    //////////////////////////////////////////////////////////////*/

    /// @notice Hook called on trade execution by an authorized perp router
    /// @param projectId Project ID of the perp exchange
    /// @param trader Address of the trader
    /// @param notionalVolume Total trading volume executed
    /// @param feeAmount Total fee collected in $HNY
    function onPerpTradeExecuted(uint256 projectId, address trader, uint256 notionalVolume, uint256 feeAmount)
        external
        nonReentrant
        returns (uint256 burned, uint256 treasuryCut, uint256 cashback)
    {
        if (!isAuthorizedRouter[msg.sender]) revert NotAuthorizedCaller();
        if (feeAmount == 0) return (0, 0, 0);

        // 1. Pull fee from router
        address(hnyToken).safeTransferFrom(msg.sender, address(this), feeAmount);

        // 2. Calculate splits
        burned = (feeAmount * burnShareBps) / BPS_DENOMINATOR;
        cashback = (feeAmount * cashbackShareBps) / BPS_DENOMINATOR;
        treasuryCut = feeAmount - (burned + cashback);

        // 3. Execute burn
        if (burned > 0) {
            hnyToken.burn(burned);
        }

        // 4. Send treasury cut to support Floor
        if (treasuryCut > 0) {
            address(hnyToken).safeTransfer(treasuryVault, treasuryCut);
        }

        // 5. Send instant cashback to trader
        if (cashback > 0) {
            address(hnyToken).safeTransfer(trader, cashback);
        }

        // 6. Record in Contribution Ledger
        contributionLedger.recordContribution(projectId, trader, notionalVolume, treasuryCut, burned);

        emit PerpTradeRouted(projectId, trader, notionalVolume, feeAmount, burned, treasuryCut, cashback);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    function setAuthorizedRouter(address router, bool status) external onlyOwner {
        if (router == address(0)) revert ZeroAddress();
        isAuthorizedRouter[router] = status;
    }

    function setSplits(uint256 _burnShareBps, uint256 _treasuryShareBps, uint256 _cashbackShareBps) external onlyOwner {
        if (_burnShareBps + _treasuryShareBps + _cashbackShareBps != BPS_DENOMINATOR) {
            revert InvalidSplit();
        }
        burnShareBps = _burnShareBps;
        treasuryShareBps = _treasuryShareBps;
        cashbackShareBps = _cashbackShareBps;
    }

    function setTreasuryVault(address _treasuryVault) external onlyOwner {
        if (_treasuryVault == address(0)) revert ZeroAddress();
        treasuryVault = _treasuryVault;
    }
}
