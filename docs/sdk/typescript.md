# TypeScript SDK Guide

> **Official `@senhor-f/checkout` SDK & Viem Client Documentation**

---

## Installation

```bash
bun add @senhor-f/checkout viem
# or
npm install @senhor-f/checkout viem
```

---

## Basic Usage with `createEconomicZoneClient`

```ts
import { createEconomicZoneClient } from '@senhor-f/checkout';

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

---

## Pure Mathematical Utilities

```ts
import { EconomicZoneClient } from '@senhor-f/checkout';

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
