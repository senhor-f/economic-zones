# Architecture Overview

> **A Sovereign Hub-and-Spoke Topology for Web3 Economies**

The **Economic Zones Protocol** decouples high-value monetary reserves from high-frequency commercial execution, creating a zero-compromise architecture where capital security is anchored to Ethereum L1 while frictionless commerce thrives on Layer 2 rollups (Base / OP Stack).

```mermaid
flowchart TB
    subgraph L1["Ethereum L1 — Central Settlement & Capital Hub"]
        ABC["AugmentedBondingCurve.sol<br/>($HNY Central Reserve)"]
        TYV["TreasuryYieldVault.sol<br/>(100% Principal Protected ERC-4626)"]
        FD["FloorDripper.sol<br/>(Continuous Yield Streaming)"]
        LBV["L1BlobCommerceVerifier.sol<br/>(KZG Precompile 0x0A)"]
        XLOCK["xHNYLockbox.sol<br/>(ERC-7281 Sovereign Rate Limiting)"]
    end

    subgraph L2["Base L2 — High-Velocity Commerce & Execution Spoke"]
        ZPG["ZonePaymentGateway.sol<br/>(Universal Drop-in Checkout)"]
        SPR["SwapPayRouter.sol<br/>(1-Click USDC/ETH with 1% Cashback)"]
        ZRS["ZoneRevenueSplitter.sol<br/>(Multi-recipient Auto-Staker)"]
        CPS["ContinuousPayrollStreamer.sol<br/>(Salary Streaming by Second)"]
        X402["x402Settler.sol<br/>(AI Agent Micropayments EIP-712)"]
        FLS["FloorLockedSavings.sol<br/>(veHNY Boosted Lockers)"]
        SHNY["StakedHNY.sol<br/>(Liquid Staking Vault)"]
        BATCH["L2CommerceBatcher.sol<br/>(Epoch Receipt Merkle Aggregator)"]
    end

    XLOCK <===>|"xERC20 Bridge (Lock & Mint)"| ZPG
    ZPG & SPR & ZRS & CPS & X402 -->|Tributes & Invoices| BATCH
    BATCH -->|"EIP-4844 Blob (Data Availability)"| LBV
    BATCH -->|"Bridged USDC (Tributes & Taxes)"| FD
    FD -->|"Linear Dripping (USDC)"| ABC
    TYV -->|"Harvested Yield (20% Cut)"| FD
```

---

## 🏛️ The Three Pillars of Sovereign Zones

### 1. Capital Security & Guaranteed Solvency (Ethereum L1)
All foundational monetary parameters, bonding curve reserves, and institutional treasury assets live on Ethereum L1. Even under total L2 sequencer outages, zero institutional capital is at risk.

### 2. High-Frequency Real Commerce (Base L2)
Sub-cent transactions enable:
- **Instant 1-Click Payments** with automatic customer cashback.
- **Continuous Second-by-Second Payroll** with embedded municipal tax withholding.
- **Machine-to-Machine API Settlements** for autonomous AI agents without human intervention.

### 3. Asymmetric Value Accrual
Every transaction occurring across the spoke networks captures a $1\%$ exit tribute or zone tax in USDC. These funds are bridged to L1 and dripped continuously into the Bonding Curve, **permanently pushing the Floor Price of all $HNY$ holders upward**.
