# Economic Zones Protocol ($HNY v2)

The **Economic Zones Protocol** is a modular, high-assurance on-chain economic system upgrading the legacy 1Hive/Gardens model into a self-sustaining sovereign digital economy on Ethereum Mainnet and high-throughput L2s (Arbitrum, Base, Optimism).

## 🚀 Key Mechanisms & Innovations

### 1. Augmented Bonding Curve (ABC) & Mathematical Floor Backing
* **Dynamic Graduated Tributes**: Starts at low friction during bootstrap (0.5% entry / 1.0% exit) and scales dynamically with TVL/volume.
* **Unbreachable Floor Price**: Every $HNY$ in circulation is backed by the Treasury Reserve:
  $$\text{Floor Price} = \frac{\text{Treasury Reserve Balance}}{\text{Circulating } HNY \text{ Supply}}$$
* **Direct Floor Redemption**: Any user can redeem $HNY$ directly at the mathematical Floor price via `redeemAtFloor()` at zero tribute, guaranteeing asymptotic downside protection.

### 2. Universal Medium of Exchange & Instant Cashback
* **Zone Payment Gateway (`ZonePaymentGateway.sol`)**: All commercial ventures, AI agents, SaaS APIs, and physical goods settle natively in $HNY$.
* **Instant User Cashback**: 50% of the protocol fee is returned immediately to the user as cashback in $HNY$.
* **Lucky Draw Gamification**: Configurable probability for users to win 100% full transaction refunds from the incentive pool.

### 3. On-Chain Contribution & Attribution Ledger
* **`ContributionLedger.sol`**: Tracks historical gross volume, net treasury revenue, and burns per project.
* **Fee Tiering**: Projects that drive high volume unlock up to 100 bps in fee discounts and priority RetroPGF grant allocations.

### 4. Perpetual & DEX Fee Capture Hook
* **`PerpRevenueHook.sol`**: Connects directly to high-volume Perp exchanges (settlement routers, GMX/Hyperliquid forks) to capture trading fees, burn $HNY$, route funds to the Floor Treasury, and give traders instant fee cashbacks.

### 5. Deluxe Treasury Rebalancing & Yield Matrix
* **`DeluxeAssetRebalancer.sol`**: Runs gradual Dutch auctions filled by solvers to eliminate MEV sandwich attacks on treasury rebalancing.
* **`ERC4626YieldRouter.sol`**: Allocates stablecoin reserves across institutional yield destinations (Sky `sUSDS`/`sDAI`, Morpho Blue, Aave v3) and auto-skims excess yield to market-buy and burn $HNY$.

---

## 🏗️ Repository Architecture

```
src/
├── token/
│   ├── HNYToken.sol                 # ERC20 with Solady, EIP-2612 Permit, controlled minters & burns
│   └── HNYMigrator.sol              # 1:1 (+ early bonus) migration from legacy HNY v1
├── curve/
│   └── AugmentedBondingCurve.sol    # Linear ABC with dynamic tributes & floor redemption
├── payments/
│   ├── ProjectRegistry.sol          # Canonical on-chain registry of connected projects
│   ├── ContributionLedger.sol       # Volume, revenue, user footprint & tier discounts
│   └── ZonePaymentGateway.sol       # Checkout router with instant cashbacks & lucky draw
├── zones/
│   └── ZoneVault.sol                # Autonomous ERC-4626 revenue vault with Core dividends
├── rebalancing/
│   ├── DeluxeAssetRebalancer.sol    # Anti-MEV Dutch auction rebalancer & circuit breaker
│   └── ERC4626YieldRouter.sol       # Multi-protocol yield management & floor harvest hook
└── hooks/
    └── PerpRevenueHook.sol          # Fee capture, buyback & burn hook for Perps & DEXes
```

---

## 🧪 Testing & Verification (Foundry 2026 Standards)

The test suite incorporates stateful fuzzing and invariant testing using Handlers:

* **Unit Tests**: Full functional verification across tokens, curve, gateways, vaults, and hooks.
* **Invariant Testing**: Stateful fuzz testing with `CurveHandler` (over 32,000 fuzzed calls per invariant):
  - `invariant_Solvency`: Physical reserve in contract $\ge$ tracked internal reserve.
  - `invariant_SupplyConservation`: $HNY$ total supply $\equiv$ Ghost Minted - Ghost Burned.
  - `invariant_FloorPricePositive`: Floor price is mathematically strictly positive.

### Running Tests

```bash
# Run all unit and invariant tests
make test

# Run unit tests only
make test-unit

# Run invariant tests only
make test-invariant
```
