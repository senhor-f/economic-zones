---
layout: home

hero:
  name: "Economic Zones Protocol"
  text: "Autonomous Sovereign Economies ($HNY v2)"
  tagline: "Unbreachable Floor Price, AI Agent Micropayments (x402), SaaS Subscriptions, Liquid Staking, and Yield-Backed Treasury Bóvedas."
  actions:
    - theme: brand
      text: Get Started
      link: /architecture/
    - theme: alt
      text: TypeScript SDK
      link: /sdk/typescript
    - theme: alt
      text: GitHub Repo
      link: https://github.com/senhor-f/economic-zones

features:
  - title: Unbreachable Floor Price
    details: Every $HNY is backed by USDC reserve. Any holder can redeem their exact proportional share at any time with 0% exit tribute.
  - title: 1-Click Drop-in Checkout
    details: Pay with USDC or ETH in a single click. The customer receives an instant 1% cashback in $HNY and captures 1% for the floor.
  - title: AI Agent Micropayments (x402)
    details: Native EIP-712 support for Coinbase AgentKit and Claude MCP to settle machine-to-machine HTTP 402 API queries.
  - title: EIP-4844 KZG Blob Verification
    details: L2 commerce batches verified on Ethereum L1 using Cancun's Point Evaluation Precompile (0x0A) with zero trusted oracles.
  - title: Streaming Payroll and Splits
    details: Second-by-second salary streaming with automatic municipal tax withholding and revenue splits with auto-staking into sHNY.
  - title: Principal-Protected Treasury Vaults
    details: Institutional ERC-4626 bóvedas with principal protection 1:1 in USDC and yield streaming directly to the floor.
---

## Executive Summary

The **Economic Zones Protocol** is a sovereign on-chain financial operating system designed for high-velocity dApps, decentralized communities, and autonomous AI agents.

```mermaid
graph TD
    A["Ethereum L1 Hub<br/>• Central Reserve ($HNY)<br/>• Unbreachable Floor Price<br/>• Treasury Yield Vaults<br/>• EIP-4844 Blob Verifier"] -->|xERC20 Canonical Bridge| B["Base L2 Commerce Spoke<br/>• 1-Click Checkout & Cashback<br/>• Recurring SaaS Subscriptions<br/>• Continuous Payroll Streaming<br/>• AI Agent x402 Micropayments"]
    B -->|Tributes & Volume Receipts| C["L2 Commerce Batcher"]
    C -->|EIP-4844 Blobs & Bridged USDC| A
```

---

## Key Performance Indicators

- **Foundry Test Suite**: 60/60 tests passing across 41 suites (Unit, 32k calls invariant fuzzing, bank run simulations, Base mainnet fork).
- **Security & Solvency Invariant**: $\text{Reserve USDC} \ge \text{Total Supply} \times \text{Floor Price}$ (Strictly preserved under all attack vectors).
- **Execution Speed**: High-velocity sub-cent commerce on Base L2 anchored to Ethereum L1 institutional security.
