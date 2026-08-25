# @senhor-f/sdk

> Universal TypeScript SDK and Viem client for the **Economic Zones Protocol ($HNY v2)**.

---

## Features

- **Universal Protocol Client (`EconomicZoneClient`)**: Single entry point for all on-chain modules.
- **Augmented Bonding Curve (`curve`)**: Buy, sell, floor redemption, preview simulation, and price impact estimation.
- **Treasury Vaults & Floor Dripper (`treasury`)**: ERC-4626 bóvedas, principal protection tracking, yield distribution to floor.
- **Continuous Payroll Streaming (`payroll`)**: Stream rates, second-by-second vested claims, and municipal tax withholdings.
- **Automated Revenue Splits (`splits`)**: Multi-recipient disbursement and automated staking into $sHNY.
- **On-Chain SaaS Subscriptions (`subscriptions`)**: Recurring billing cycles, plan creation, automated cancellations.
- **AI Agent Micropayments (`agentPay`)**: EIP-712 typed signing for x402 HTTP micropayments (Coinbase AgentKit & Claude MCP).
- **KZG Blob Verification (`blobs`)**: Cancun EIP-4844 Point Evaluation precompile (0x0A) submission and batch verification.
- **Pure Math Helpers (`EconomicZoneClient.math`)**: Exact BigInt floor growth, lock voting boost multipliers, streaming amortization.
- **Complete Type-Safe ABIs**: 42 protocol contract ABIs typed natively for `viem`.

---

## Installation

```bash
bun add @senhor-f/sdk viem
# or
npm install @senhor-f/sdk viem
```

---

## Quickstart

```ts
import { createEconomicZoneClient, EconomicZoneClient } from '@senhor-f/sdk';

const client = createEconomicZoneClient({
  chain: 'base',
  rpcUrl: 'https://mainnet.base.org',
  addresses: {
    curve: '0x1111111111111111111111111111111111111111',
    stakedHny: '0x2222222222222222222222222222222222222222',
    swapPayRouter: '0x3333333333333333333333333333333333333333',
    payrollStreamer: '0x4444444444444444444444444444444444444444'
  }
});

// Calculate floor price growth after yield injection
const growth = EconomicZoneClient.math.calculateFloorGrowth(
  1_000_000n * 10n**18n, // 1M USDC reserve
  500_000n * 10n**18n,   // 500k HNY supply
  50_000n * 10n**18n     // 50k USDC yield dripped
);

console.log(`New Floor: $${Number(growth.newFloorPrice) / 1e18} (+${growth.growthBps / 100}%)`);
```

---

## License

MIT - Senhor F
