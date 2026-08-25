# Governance, veHNY Savings & Sovereign Fiscality

> **Prediction Markets, Time-Preference Staking, and Inter-Zone Net Settlement**

---

## 1. Milestone Futarchy ([`MilestoneFutarchy.sol`](../../src/governance/MilestoneFutarchy.sol))

Rather than traditional "one-token-one-vote" governance that suffers from plutocracy and low voter turnout, high-stakes grant tranches are governed by **Milestone Futarchy**:
- Prediction markets (PASS vs FAIL tokens) open on proposal milestones.
- If the market predicts success (price above threshold), the tranche is released.
- Speculators with skin-in-the-game price the true probability of delivery.

---

## 2. veHNY Floor-Locked Savings ([`FloorLockedSavings.sol`](../../src/zones/FloorLockedSavings.sol))

Users who lock $HNY$ for 1 to 48 months receive **veHNY** positions with tiered economic and governance benefits:

| Lock Duration | Voting Power Multiplier | Checkout Cashback Boost | Early Exit Penalty |
| :--- | :--- | :--- | :--- |
| **1 Month** | $1.0x$ (10,000 bps) | $+0\text{ bps}$ | $10\%$ |
| **1 Year** | $1.75x$ (17,500 bps) | $+25\text{ bps}$ ($+0.25\%$) | $25\%$ |
| **2 Years** | $2.5x$ (25,000 bps) | $+50\text{ bps}$ ($+0.50\%$) | $35\%$ |
| **4 Years** | **$4.0x$ (40,000 bps)** | **$+100\text{ bps}$ ($+1.00\%$)** | $50\%$ |

*Early Exit Penalties are routed $100\%$ into the Bonding Curve Reserve Floor, permanently benefiting remaining loyal savers.*

---

## 3. Custom Tariffs & Multi-Zone Clearing ([`ZoneClearingHouse.sol`](../../src/zones/ZoneClearingHouse.sol))

Sovereign Economic Zones can establish bilateral trade agreements:
- **Category VAT & Tariffs** via [`CustomTariffHook.sol`](../../src/hooks/CustomTariffHook.sol).
- **Net Bilateral Clearing**: Instead of settling every cross-zone trade individually with high gas fees, the `ZoneClearingHouse` maintains a continuous net ledger and settles net debt periodically between zone settlement vaults.
