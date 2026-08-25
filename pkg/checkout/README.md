# @economic-zone/checkout

> **Comprehensive TypeScript SDK & 1-Click Checkout Client for Economic Zones Protocol ($HNY v2)**  
> Supports 1-Click Drop-in Payments with Instant Cashback, Continuous Payroll Streaming, Revenue Splits with Auto-Stake, veHNY Lockers, EIP-4844 Blob Proofs, and On-Chain Version Decoding.

---

## 📦 Installation

```bash
bun add @economic-zone/checkout viem
# or
npm install @economic-zone/checkout viem
```

---

## ⚡ Quickstart

### 1. 1-Click Drop-in Checkout (React / Wagmi / Viem)
```tsx
import { ZoneCheckoutClient } from '@economic-zone/checkout';
import { useWriteContract } from 'wagmi';

const checkout = new ZoneCheckoutClient("0xSwapPayRouterAddress...");

export function PayButton({ projectId, amountUSDC }: { projectId: bigint; amountUSDC: bigint }) {
  const { writeContract } = useWriteContract();

  const handlePay = () => {
    const tx = checkout.prepare1ClickPayment(
      projectId,
      amountUSDC,
      amountUSDC, // hnyRequired
      50n         // 0.5% max slippage
    );
    writeContract(tx);
  };

  return (
    <button onClick={handlePay} className="btn-primary">
      Pay with 1-Click (Get 1% Cashback in $HNY)
    </button>
  );
}
```

---

### 2. Multi-Party Revenue Splits with Auto-Stake in $sHNY
```ts
import { ZoneClient } from '@economic-zone/checkout';

const txPayload = ZoneClient.prepareSplitConfig(
  "0xZoneRevenueSplitterAddress...",
  10n, // projectId
  {
    primaryBeneficiary: "0xMerchant...",
    autoStakeShareBps: 1000, // 10% auto-stake in $sHNY
    treasuryTaxBps: 500,     // 5% zone treasury tax
    recipients: [
      { recipient: "0xSupplierA...", shareBps: 6000 },
      { recipient: "0xSupplierB...", shareBps: 2500 }
    ]
  }
);
```

---

### 3. Continuous Second-by-Second Payroll Streaming
```ts
import { ZoneClient } from '@economic-zone/checkout';

const streamPayload = ZoneClient.preparePayrollStream(
  "0xContinuousPayrollStreamerAddress...",
  {
    recipient: "0xWorker...",
    token: "0xHNYTokenAddress...",
    depositAmount: 5000n * 10n**18n, // 5000 HNY
    durationSeconds: 30n * 86400n,   // 30 days
    taxRateBps: 500,                 // 5% withholding for zone public goods
    taxCollector: "0xTreasuryVault..."
  }
);
```

---

### 4. Decode On-Chain `bytes32 PROTOCOL_VERSION` Metadata
```ts
import { ZoneClient } from '@economic-zone/checkout';

const versionTag = "0x484e5932020100000068ac3d805374616b6564484e5900000000000000000000";
const info = ZoneClient.decodeProtocolVersion(versionTag);

console.log(`Contract: ${info.contractName}`); // "StakedHNY"
console.log(`Version: v${info.major}.${info.minor}.${info.patch}`); // "v2.1.0"
console.log(`Deployed At: ${new Date(info.deployedAt * 1000).toISOString()}`);
```

---

### 5. Type-Safe Viem Contract ABIs
```ts
import {
  payments_SwapPayRouter_SwapPayRouterAbi,
  token_StakedHNY_StakedHNYAbi,
  zones_FloorLockedSavings_FloorLockedSavingsAbi
} from '@economic-zone/checkout';
```
