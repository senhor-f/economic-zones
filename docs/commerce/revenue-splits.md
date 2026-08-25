# Merchant Revenue Splits & Auto-Staking

> **Multi-Party Income Routing with Automated Liquid Staking in $sHNY**

[`ZoneRevenueSplitter.sol`](../../src/payments/ZoneRevenueSplitter.sol) eliminates manual bookkeeping and payroll distributions for businesses, DAO working groups, and merchant collectives.

---

## Automated Split Architecture

When a payment of 1,000 $HNY arrives for a registered project:

```mermaid
pie title 1,000 $HNY Revenue Distribution Example
    "Founder / Primary Payout (60%)" : 600
    "Supplier / Contractor A (20%)" : 200
    "Supplier / Contractor B (5%)" : 50
    "Auto-Staked into sHNY Vault (10%)" : 100
    "Zone Treasury Tax (5%)" : 50
```

---

## The Auto-Staking Advantage

Rather than letting working capital sit idle in an operating account:
- Merchants can configure `autoStakeShareBps` (e.g. $10\% = 1000\text{ bps}$).
- The contract automatically deposits that fraction into [`StakedHNY.sol`](../../src/token/StakedHNY.sol).
- The merchant receives autocompounding yield in **$sHNY** generated from protocol exit tributes and POL fee harvests.
