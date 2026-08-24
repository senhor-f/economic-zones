// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {HNYToken} from "../token/HNYToken.sol";
import {ProjectRegistry} from "./ProjectRegistry.sol";
import {ContributionLedger} from "./ContributionLedger.sol";

/// @title ZonePaymentGateway
/// @notice Universal checkout and medium of exchange gateway with instant & lucky cashbacks for users.
contract ZonePaymentGateway is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PaymentProcessed(
        uint256 indexed projectId,
        address indexed payer,
        address indexed payoutAddress,
        uint256 grossAmount,
        uint256 netProjectAmount,
        uint256 feeAmount,
        uint256 cashbackAmount
    );
    event LuckyDrawWon(uint256 indexed projectId, address indexed payer, uint256 jackpotAmount);
    event IncentivePoolFunded(address indexed funder, uint256 amount);
    event GatewayConfigUpdated(
        uint256 baseFeeBps, uint256 cashbackShareBps, bool luckyDrawActive, uint256 luckyDrawChanceBps
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error InvalidFeeConfig();
    error InsufficientIncentivePool();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BPS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    HNYToken public immutable hnyToken;
    ProjectRegistry public immutable projectRegistry;
    ContributionLedger public immutable contributionLedger;

    address public treasuryVault;

    /// @notice Standard base fee for payments (e.g. 200 bps = 2.0%)
    uint256 public baseFeeBps = 200;

    /// @notice Share of the fee that goes to user cashback (e.g. 5000 bps = 50% of fee)
    uint256 public cashbackShareBps = 5000;

    /// @notice Gamified Lucky Draw switch
    bool public luckyDrawEnabled = true;

    /// @notice Probability of winning 100% full cashback (e.g. 50 = 0.5% chance)
    uint256 public luckyDrawChanceBps = 50;

    /// @notice Balance of funds dedicated to lucky draw payouts
    uint256 public incentivePoolBalance;

    /// @notice Nonce for pseudo-random entropy
    uint256 private entropyNonce;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _hnyToken,
        address _projectRegistry,
        address _contributionLedger,
        address _treasuryVault,
        address _owner
    ) {
        if (
            _hnyToken == address(0) || _projectRegistry == address(0) || _contributionLedger == address(0)
                || _treasuryVault == address(0) || _owner == address(0)
        ) revert ZeroAddress();

        hnyToken = HNYToken(_hnyToken);
        projectRegistry = ProjectRegistry(_projectRegistry);
        contributionLedger = ContributionLedger(_contributionLedger);
        treasuryVault = _treasuryVault;

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           PAYMENT EXECUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Executes a payment for a product, API, or service in the Economic Zone
    /// @param projectId Registered project receiving payment
    /// @param grossAmount Amount in $HNY to pay
    function pay(uint256 projectId, uint256 grossAmount)
        external
        nonReentrant
        returns (uint256 netProjectAmount, uint256 userCashback)
    {
        if (grossAmount == 0) revert ZeroAmount();

        address payout = projectRegistry.getPayoutAddress(projectId);

        // 1. Calculate fee with project tier discount (Yul optimized)
        uint256 discountBps = contributionLedger.getFeeDiscountBps(projectId);
        uint256 totalFee;
        uint256 treasuryShare;
        uint256 baseFee = baseFeeBps;
        uint256 cashbackShare = cashbackShareBps;

        assembly {
            let effectiveFee := 0
            if gt(baseFee, discountBps) {
                effectiveFee := sub(baseFee, discountBps)
            }
            totalFee := div(mul(grossAmount, effectiveFee), 10000)
            netProjectAmount := sub(grossAmount, totalFee)
            userCashback := div(mul(totalFee, cashbackShare), 10000)
            treasuryShare := sub(totalFee, userCashback)
        }

        // 2. Pull gross $HNY from user
        address(hnyToken).safeTransferFrom(msg.sender, address(this), grossAmount);

        // 4. Pay project net amount
        address(hnyToken).safeTransfer(payout, netProjectAmount);

        // 5. Send treasury share to Treasury Vault / Floor
        if (treasuryShare > 0) {
            address(hnyToken).safeTransfer(treasuryVault, treasuryShare);
        }

        // 6. Send instant user cashback
        if (userCashback > 0) {
            address(hnyToken).safeTransfer(msg.sender, userCashback);
        }

        // 7. Evaluate Lucky Draw Jackpot
        _evaluateLuckyDraw(projectId, msg.sender, grossAmount);

        // 8. Record in Contribution Ledger
        contributionLedger.recordContribution(
            projectId,
            msg.sender,
            grossAmount,
            treasuryShare,
            0 // burn amount (if any)
        );

        emit PaymentProcessed(projectId, msg.sender, payout, grossAmount, netProjectAmount, totalFee, userCashback);
    }

    /// @notice Executes payment with EIP-2612 Permit in a single transaction
    function payWithPermit(uint256 projectId, uint256 grossAmount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        returns (uint256 netProjectAmount, uint256 userCashback)
    {
        hnyToken.permit(msg.sender, address(this), grossAmount, deadline, v, r, s);
        return this.pay(projectId, grossAmount);
    }

    /*//////////////////////////////////////////////////////////////
                           LUCKY DRAW LOGIC
    //////////////////////////////////////////////////////////////*/

    function _evaluateLuckyDraw(uint256 projectId, address payer, uint256 grossAmount) internal {
        if (!luckyDrawEnabled || incentivePoolBalance < grossAmount) return;

        entropyNonce++;
        uint256 seed =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, payer, entropyNonce, grossAmount)));

        if ((seed % BPS_DENOMINATOR) < luckyDrawChanceBps) {
            // User won 100% full cashback!
            incentivePoolBalance -= grossAmount;
            address(hnyToken).safeTransfer(payer, grossAmount);
            emit LuckyDrawWon(projectId, payer, grossAmount);
        }
    }

    /// @notice Funds the incentive pool for Lucky Draw rewards
    function fundIncentivePool(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        incentivePoolBalance += amount;
        address(hnyToken).safeTransferFrom(msg.sender, address(this), amount);
        emit IncentivePoolFunded(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN PRIVILEGES
    //////////////////////////////////////////////////////////////*/

    function setFeeConfig(
        uint256 _baseFeeBps,
        uint256 _cashbackShareBps,
        bool _luckyDrawEnabled,
        uint256 _luckyDrawChanceBps
    ) external onlyOwner {
        if (_baseFeeBps > 1000 || _cashbackShareBps > BPS_DENOMINATOR || _luckyDrawChanceBps > 1000) {
            revert InvalidFeeConfig();
        }
        baseFeeBps = _baseFeeBps;
        cashbackShareBps = _cashbackShareBps;
        luckyDrawEnabled = _luckyDrawEnabled;
        luckyDrawChanceBps = _luckyDrawChanceBps;

        emit GatewayConfigUpdated(_baseFeeBps, _cashbackShareBps, _luckyDrawEnabled, _luckyDrawChanceBps);
    }

    function setTreasuryVault(address _treasuryVault) external onlyOwner {
        if (_treasuryVault == address(0)) revert ZeroAddress();
        treasuryVault = _treasuryVault;
    }
}
