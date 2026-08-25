# On-Chain SaaS Subscriptions

> **Automated Recurring Billing with Continuous Customer Rewards**

[`SubscriptionManager.sol`](../../src/payments/SubscriptionManager.sol) provides non-custodial recurring subscription billing for software tools, AI API tiers, media memberships, and creator communities.

---

## 🔄 Subscription Mechanics

1. **Plan Creation**: Merchants define plans with `planId`, `periodSeconds` (e.g. 30 days), and `amountHNY`.
2. **User Authorization**: Subscribers approve the `SubscriptionManager` once via standard ERC-20 permit or approval.
3. **Automated Billing**: Any permissionless keeper or cron bot can call `billSubscription(subscriptionId)` once the billing period elapses.
4. **Recurring Cashback**: With every monthly billing event, the subscriber receives their proportional cashback in $HNY$, increasing long-term user retention.

```mermaid
sequenceDiagram
    autonumber
    actor User as Subscriber
    participant SubMgr as SubscriptionManager.sol
    participant Gateway as ZonePaymentGateway.sol
    actor Merchant as SaaS Merchant

    User->>SubMgr: createSubscription(planId)
    Note over SubMgr: Initial Cycle Billed Immediately
    SubMgr->>Gateway: processPayment(...)
    Gateway->>Merchant: Payout Net Amount
    Gateway->>User: 1% Monthly Cashback

    Note over SubMgr: 30 Days Elapsed
    actor Keeper as Automated Keeper
    Keeper->>SubMgr: billSubscription(subId)
    SubMgr->>Gateway: processPayment(...)
    Gateway->>Merchant: Payout Next Cycle
    Gateway->>User: 1% Cashback Awarded
```
