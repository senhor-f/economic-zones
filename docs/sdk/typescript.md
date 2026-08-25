# TypeScript SDKs Guide

> **Official Developer SDKs & Viem Clients for Economic Zones Protocol ($HNY v2)**

The protocol publishes two distinct TypeScript packages:
1. **`@senhor-f/sdk`**: Universal protocol SDK (Bonding Curves, Treasury Vaults, Continuous Payroll, Subscriptions, AI Micropayments, and EIP-4844 KZG Blobs).
2. **`@senhor-f/checkout`**: Drop-in 1-click checkout client & merchant payment helpers.

---

## 1. Universal Protocol SDK (`@senhor-f/sdk`)

### Installation

```bash
bun add @senhor-f/sdk viem
# or
npm install @senhor-f/sdk viem
```

### Basic Usage with `createEconomicZoneClient`

```ts
import { createEconomicZoneClient, EconomicZoneClient } from '@senhor-f/sdk';

const client = createEconomicZoneClient({
  chain: 'base',
  rpcUrl: 'https://mainnet.base.org',
  addresses: {
    curve: '0xAugmentedBondingCurveAddress...',
    stakedHny: '0xStakedHNYAddress...',
    swapPayRouter: '0xSwapPayRouterAddress...',
    payrollStreamer: '0xContinuousPayrollStreamerAddress...'
  }
});

// 1. Read Curve Floor Price
const floorPrice = await client.curve.getFloorPrice();
console.log(`Current Floor: ${floorPrice.toString()} USDC`);

// 2. Simulate Token Purchase
const { hnyOut, tribute } = await client.curve.previewBuy(100_000000n); // 100 USDC
console.log(`Expected HNY: ${hnyOut}, Tribute: ${tribute}`);

// 3. Inspect On-Chain Contract Version
const metadata = await client.version.getMetadata("0xTargetContractAddress...");
console.log(`Contract: ${metadata.contractName} (v${metadata.major}.${metadata.minor}.${metadata.patch})`);
```

### Pure Mathematical Utilities

```ts
import { EconomicZoneClient } from '@senhor-f/sdk';

// 1. Calculate Floor Price Growth given $10,000 dripped yield
const growth = EconomicZoneClient.math.calculateFloorGrowth(
  100_000n * 10n**18n, // 100k USDC reserve
  100_000n * 10n**18n, // 100k HNY supply
  10_000n * 10n**18n   // 10k USDC dripped yield
);
console.log(`Growth: +${growth.growthBps / 100}%`); // +10%

// 2. Calculate voting boost for a 4-year lock
const boostBps = EconomicZoneClient.math.calculateLockMultiplierBps(4n * 365n * 86400n);
console.log(`Multiplier: ${boostBps / 10000}x`); // 4.0x
```

---

## 2. Drop-in Checkout Client (`@senhor-f/checkout`)

### Installation

```bash
bun add @senhor-f/checkout viem
# or
npm install @senhor-f/checkout viem
```

### 1-Click Payment Preparation

```ts
import { ZoneCheckoutClient } from '@senhor-f/checkout';

const checkoutClient = new ZoneCheckoutClient('0xSwapPayRouterAddress...');

// Prepare transaction payload for 1-click checkout
const payload = checkoutClient.prepare1ClickPayment(
  1n,                     // Project ID
  100_000000n,            // 100 USDC in
  50_000000000000000000n, // 50 HNY required
  50n                     // 0.5% max slippage (50 bps)
);

console.log('Contract Calldata:', payload.data);
```
