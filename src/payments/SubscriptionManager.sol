// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {HNYToken} from "../token/HNYToken.sol";
import {ProjectRegistry} from "./ProjectRegistry.sol";
import {ZonePaymentGateway} from "./ZonePaymentGateway.sol";

/// @title SubscriptionManager
/// @notice On-chain recurring subscription and billing engine with instant cashback for subscribers.
contract SubscriptionManager is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Plan {
        uint256 projectId;
        uint256 pricePerPeriod; // Price in $HNY wei
        uint256 periodDuration; // Seconds per billing cycle (e.g. 30 days)
        bool isActive;
    }

    struct Subscription {
        uint256 planId;
        address subscriber;
        uint256 startedAt;
        uint256 lastBilledAt;
        uint256 nextBillingTime;
        uint256 periodsBilled;
        uint256 maxPeriods; // 0 = indefinite until canceled
        bool isActive;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PlanCreated(uint256 indexed planId, uint256 indexed projectId, uint256 pricePerPeriod, uint256 periodDuration);
    event PlanStatusUpdated(uint256 indexed planId, bool isActive);
    event Subscribed(uint256 indexed subscriptionId, uint256 indexed planId, address indexed subscriber);
    event SubscriptionCanceled(uint256 indexed subscriptionId, address indexed subscriber);
    event BillingProcessed(
        uint256 indexed subscriptionId,
        uint256 indexed planId,
        address indexed subscriber,
        uint256 periodIndex,
        uint256 amountPaid,
        uint256 cashbackReceived
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error PlanNotActive();
    error SubscriptionNotActive();
    error BillingNotDue();
    error NotProjectPayout();
    error NotSubscriber();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    HNYToken public immutable hnyToken;
    ProjectRegistry public immutable projectRegistry;
    ZonePaymentGateway public immutable paymentGateway;

    uint256 public planCount;
    uint256 public subscriptionCount;

    mapping(uint256 => Plan) public plans;
    mapping(uint256 => Subscription) public subscriptions;
    mapping(address => uint256[]) public userSubscriptions;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _hnyToken,
        address _projectRegistry,
        address _paymentGateway,
        address _owner
    ) {
        if (
            _hnyToken == address(0) ||
            _projectRegistry == address(0) ||
            _paymentGateway == address(0) ||
            _owner == address(0)
        ) revert ZeroAddress();

        hnyToken = HNYToken(_hnyToken);
        projectRegistry = ProjectRegistry(_projectRegistry);
        paymentGateway = ZonePaymentGateway(_paymentGateway);

        _initializeOwner(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                             PLAN MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new subscription tier for a registered project
    function createPlan(
        uint256 projectId,
        uint256 pricePerPeriod,
        uint256 periodDuration
    ) external returns (uint256 planId) {
        if (pricePerPeriod == 0 || periodDuration == 0) revert ZeroAmount();

        address payout = projectRegistry.getPayoutAddress(projectId);
        if (msg.sender != payout && msg.sender != owner()) revert NotProjectPayout();

        planId = ++planCount;
        plans[planId] = Plan({
            projectId: projectId,
            pricePerPeriod: pricePerPeriod,
            periodDuration: periodDuration,
            isActive: true
        });

        emit PlanCreated(planId, projectId, pricePerPeriod, periodDuration);
    }

    function setPlanStatus(uint256 planId, bool isActive) external {
        Plan storage plan = plans[planId];
        address payout = projectRegistry.getPayoutAddress(plan.projectId);
        if (msg.sender != payout && msg.sender != owner()) revert NotProjectPayout();

        plan.isActive = isActive;
        emit PlanStatusUpdated(planId, isActive);
    }

    /*//////////////////////////////////////////////////////////////
                           SUBSCRIPTION LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Subscribes user to a recurring plan and executes initial period billing
    function subscribe(uint256 planId, uint256 maxPeriods) external nonReentrant returns (uint256 subId) {
        Plan storage plan = plans[planId];
        if (!plan.isActive) revert PlanNotActive();

        subId = ++subscriptionCount;
        subscriptions[subId] = Subscription({
            planId: planId,
            subscriber: msg.sender,
            startedAt: block.timestamp,
            lastBilledAt: block.timestamp,
            nextBillingTime: block.timestamp + plan.periodDuration,
            periodsBilled: 1,
            maxPeriods: maxPeriods,
            isActive: true
        });

        userSubscriptions[msg.sender].push(subId);
        emit Subscribed(subId, planId, msg.sender);

        // Execute initial first-period payment
        _executePayment(subId, plan, msg.sender);
    }

    /// @notice Executes recurring billing once period duration has elapsed (callable by merchant, keeper, or user)
    function processBilling(uint256 subId) external nonReentrant returns (uint256 netProject, uint256 cashback) {
        Subscription storage sub = subscriptions[subId];
        if (!sub.isActive) revert SubscriptionNotActive();
        if (block.timestamp < sub.nextBillingTime) revert BillingNotDue();

        Plan storage plan = plans[sub.planId];
        if (!plan.isActive) revert PlanNotActive();

        sub.periodsBilled += 1;
        sub.lastBilledAt = block.timestamp;
        sub.nextBillingTime = block.timestamp + plan.periodDuration;

        if (sub.maxPeriods > 0 && sub.periodsBilled >= sub.maxPeriods) {
            sub.isActive = false;
        }

        (netProject, cashback) = _executePayment(subId, plan, sub.subscriber);
    }

    /// @notice Cancels an active subscription
    function cancelSubscription(uint256 subId) external {
        Subscription storage sub = subscriptions[subId];
        if (msg.sender != sub.subscriber && msg.sender != owner()) revert NotSubscriber();

        sub.isActive = false;
        emit SubscriptionCanceled(subId, sub.subscriber);
    }

    function _executePayment(
        uint256 subId,
        Plan storage plan,
        address subscriber
    ) internal returns (uint256 netProject, uint256 cashback) {
        uint256 amount = plan.pricePerPeriod;

        // 1. Pull payment from subscriber
        address(hnyToken).safeTransferFrom(subscriber, address(this), amount);

        // 2. Approve and route through Zone Payment Gateway
        address(hnyToken).safeApprove(address(paymentGateway), amount);
        (netProject, cashback) = paymentGateway.pay(plan.projectId, amount);

        // 3. Return instant cashback to subscriber
        if (cashback > 0) {
            address(hnyToken).safeTransfer(subscriber, cashback);
        }

        emit BillingProcessed(
            subId,
            subscriptions[subId].planId,
            subscriber,
            subscriptions[subId].periodsBilled,
            amount,
            cashback
        );
    }
}
