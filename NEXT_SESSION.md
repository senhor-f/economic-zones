# Economic Zones Protocol ($HNY v2) — Handover & Next Session Guide

> **Current State**: Advanced Sovereign Economic Zone Modules added on `dev`.  
> **Test Status**: **53/53 tests passing across 37 suites** (Foundry Unit, Fuzzing Invariants, Bank Runs, Flash Loans, Live Base Fork).

---

## 🏛️ What Was Built in This Session

### 1. Liquid Staking & ve-Savings (Floor Boost)
- [`StakedHNY.sol`](src/token/StakedHNY.sol): ERC-4626 Liquid Staking vault ($sHNY) autocompounding yields from exit tributes, POL fee harvesting, and floor yield drippers.
- [`FloorLockedSavings.sol`](src/zones/FloorLockedSavings.sol): Time-locked veHNY savings vault providing up to 4x boosted voting power for Conviction Voting, cashback boosts up to +100 bps, and early-exit penalties routed directly into the floor reserve.

### 2. Commerce Splits & Continuous Payroll
- [`ZoneRevenueSplitter.sol`](src/payments/ZoneRevenueSplitter.sol): Modular multi-recipient payout splitter with automatic conversion of a configured % into $sHNY (auto-stake) and treasury tax routing.
- [`ContinuousPayrollStreamer.sol`](src/payments/ContinuousPayrollStreamer.sol): Second-by-second continuous salary streaming in $HNY for zone citizens with real-time tax withholding for zone public goods.

### 3. Fiscal Sovereignty & Multi-Zone Clearing
- [`CustomTariffHook.sol`](src/hooks/CustomTariffHook.sol): Category VAT and cross-zone customs tariffs configured per zone and routed to local treasuries.
- [`ZoneClearingHouse.sol`](src/zones/ZoneClearingHouse.sol): Bilateral net clearing house and settlement engine between sovereign economic zones.

### 4. Core Commerce & Rebalancing (Previously Completed)
- [`SwapPayRouter.sol`](src/payments/SwapPayRouter.sol): 1-click checkout for USDC/ETH holders with automatic curve purchase and 1% instant cashback.
- [`SubscriptionManager.sol`](src/payments/SubscriptionManager.sol): Automated recurring SaaS billing on-chain.
- [`x402Settler.sol`](src/payments/x402Settler.sol): Machine-to-machine HTTP 402 payment settlement for AI agents with EIP-712.
- [`TreasuryYieldVault.sol`](src/rebalancing/TreasuryYieldVault.sol): Institutional ERC-4626 vault with 100% principal protection 1:1 in USDC.
- [`FloorDripper.sol`](src/rebalancing/FloorDripper.sol): Continuous linear yield streaming into bonding curve reserve.

---

## 🚀 Tooling & Testing

- Makefile commands:
  ```bash
  make test          # Runs all 53 test suites
  make test-unit     # Unit tests only
  make test-invariant# Invariant fuzzing (32,768 calls/inv)
  ```

---

## 🎯 Next Steps / Backlog for Next Session

1. **Testnet / Mainnet Deployment**:
   - Run [`DeployProduction.s.sol`](script/DeployProduction.s.sol) on Base Sepolia or Base Mainnet.
2. **Interactive Demo Frontend**:
   - Build a lightweight React/Next.js demo showcasing:
     - 1-Click Checkout widget.
     - Live Floor Price tracker with Floor Dripper simulation.
     - Liquid Staking & ve-Locker dashboard.
3. **Indexation Pipeline**:
   - (Optional) Configure Ponder/Envio indexer for sub-second GraphQL event queries.
