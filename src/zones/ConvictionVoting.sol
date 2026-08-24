// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {HNYToken} from "../token/HNYToken.sol";

/// @title ConvictionVoting
/// @notice Continuous conviction voting with strict anti-double-voting validation across multiple proposals.
contract ConvictionVoting is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Proposal {
        address beneficiary;
        address fundingToken;
        uint256 requestedAmount;
        string metadataURI;
        uint256 convictionLast;
        uint256 blockLast;
        uint256 stakedTokens;
        bool isExecuted;
        bool isCanceled;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed beneficiary,
        address indexed fundingToken,
        uint256 requestedAmount,
        string metadataURI
    );
    event StakeChanged(uint256 indexed proposalId, address indexed voter, uint256 newStake);
    event ProposalExecuted(uint256 indexed proposalId, uint256 amountPaid);
    event ProposalCanceled(uint256 indexed proposalId);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error ProposalNotActive();
    error ThresholdNotReached();
    error InsufficientBalance();
    error MaxFundingExceeded();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant WAD = 1e18;
    uint256 public constant ALPHA = 9e17; // 0.90 decay factor per block

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    HNYToken public immutable hnyToken;
    address public treasuryVault;

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => uint256)) public userStake;
    mapping(address => uint256) public totalUserStakedAcrossProposals;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _hnyToken, address _treasuryVault, address _owner) {
        if (_hnyToken == address(0) || _treasuryVault == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }
        hnyToken = HNYToken(_hnyToken);
        treasuryVault = _treasuryVault;
        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           PROPOSAL LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new funding proposal in the Zone
    function createProposal(
        address beneficiary,
        address fundingToken,
        uint256 requestedAmount,
        string calldata metadataURI
    ) external returns (uint256 proposalId) {
        if (beneficiary == address(0) || fundingToken == address(0)) revert ZeroAddress();
        if (requestedAmount == 0) revert ZeroAmount();

        proposalId = ++proposalCount;
        proposals[proposalId] = Proposal({
            beneficiary: beneficiary,
            fundingToken: fundingToken,
            requestedAmount: requestedAmount,
            metadataURI: metadataURI,
            convictionLast: 0,
            blockLast: block.number,
            stakedTokens: 0,
            isExecuted: false,
            isCanceled: false
        });

        emit ProposalCreated(proposalId, beneficiary, fundingToken, requestedAmount, metadataURI);
    }

    /// @notice Signals voting weight for a proposal. Prevents double-voting across concurrent proposals.
    function stake(uint256 proposalId, uint256 amount) external {
        Proposal storage prop = proposals[proposalId];
        if (prop.isExecuted || prop.isCanceled) revert ProposalNotActive();

        _updateConviction(proposalId);

        uint256 prevStake = userStake[proposalId][msg.sender];
        uint256 currentBalance = hnyToken.balanceOf(msg.sender);

        uint256 newTotalStake = totalUserStakedAcrossProposals[msg.sender] - prevStake + amount;
        if (newTotalStake > currentBalance) revert InsufficientBalance();

        totalUserStakedAcrossProposals[msg.sender] = newTotalStake;

        if (amount > prevStake) {
            prop.stakedTokens += (amount - prevStake);
        } else {
            prop.stakedTokens -= (prevStake - amount);
        }

        userStake[proposalId][msg.sender] = amount;
        emit StakeChanged(proposalId, msg.sender, amount);
    }

    /// @notice Computes dynamic conviction threshold required for execution
    function calculateThreshold(uint256 proposalId) public view returns (uint256) {
        Proposal storage prop = proposals[proposalId];
        uint256 totalWeight = hnyToken.totalSupply();
        if (totalWeight == 0) return type(uint256).max;

        return (totalWeight * prop.requestedAmount) / (prop.requestedAmount + 10_000e18);
    }

    /// @notice Returns current real-time accumulated conviction
    function getConviction(uint256 proposalId) public view returns (uint256) {
        Proposal storage prop = proposals[proposalId];
        if (prop.blockLast == 0) return 0;

        uint256 blockDelta = block.number - prop.blockLast;
        if (blockDelta == 0) return prop.convictionLast;

        uint256 alphaDecay = FixedPointMathLib.rpow(ALPHA, blockDelta, WAD);
        return (prop.convictionLast * alphaDecay) / WAD + prop.stakedTokens * (WAD - alphaDecay) / WAD;
    }

    function _updateConviction(uint256 proposalId) internal {
        Proposal storage prop = proposals[proposalId];
        prop.convictionLast = getConviction(proposalId);
        prop.blockLast = block.number;
    }

    /// @notice Executes an approved proposal once conviction threshold is reached
    function executeProposal(uint256 proposalId) external nonReentrant {
        Proposal storage prop = proposals[proposalId];
        if (prop.isExecuted || prop.isCanceled) revert ProposalNotActive();

        _updateConviction(proposalId);

        uint256 threshold = calculateThreshold(proposalId);
        if (prop.convictionLast < threshold) revert ThresholdNotReached();

        prop.isExecuted = true;

        // Release funding from Treasury
        prop.fundingToken.safeTransferFrom(treasuryVault, prop.beneficiary, prop.requestedAmount);

        emit ProposalExecuted(proposalId, prop.requestedAmount);
    }

    /// @notice Cancels a proposal
    function cancelProposal(uint256 proposalId) external onlyOwner {
        Proposal storage prop = proposals[proposalId];
        prop.isCanceled = true;
        emit ProposalCanceled(proposalId);
    }
}
