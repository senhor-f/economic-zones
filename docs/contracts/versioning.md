# Immutable Contract Versioning (Packed `bytes32`)

> **Zero Storage Cost Protocol Metadata with Sub-Word Bit-Masking**

Every contract across the Economic Zones Protocol inherits from [`Versioned.sol`](../../src/core/Versioned.sol) and exposes an immutable 32-byte identifier:

```solidity
bytes32 public immutable PROTOCOL_VERSION;
```

---

## 📦 32-Byte Bitpacking Layout

```
 0               4       5       6       7                  13                            31
┌───────────────┬───────┬───────┬───────┬──────────────────┬─────────────────────────────┐
│  Magic (4B)   │ Major │ Minor │ Patch │ Timestamp (6B)   │  Contract Name Tag (19B)    │
│    "HNY2"     │ uint8 │ uint8 │ uint8 │ uint48 (deploy)  │   ASCII identifier          │
└───────────────┴───────┴───────┴───────┴──────────────────┴─────────────────────────────┘
```

| Field | Type | Offset (Bits) | Size | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Magic Tag** | `bytes4` | `224..255` | 4 Bytes | Standard protocol identifier (`"HNY2"` = `0x484e5932`) |
| **Major** | `uint8` | `216..223` | 1 Byte | Major breaking revision (`2`) |
| **Minor** | `uint8` | `208..215` | 1 Byte | Feature addition (`1`) |
| **Patch** | `uint8` | `200..207` | 1 Byte | Maintenance patch (`0`) |
| **DeployedAt** | `uint48` | `152..199` | 6 Bytes | Exact Unix timestamp of deployment |
| **ContractName**| `bytes19`| `0..151` | 19 Bytes | ASCII human-readable contract name |

---

## 🔍 Decoding via TypeScript SDK

```ts
import { ZoneClient } from '@economic-zone/checkout';

const tag = "0x484e5932020100000068ac3d805374616b6564484e5900000000000000000000";
const info = ZoneClient.decodeProtocolVersion(tag);

console.log(info);
/*
{
  magic: "HNY2",
  major: 2,
  minor: 1,
  patch: 0,
  deployedAt: 1756118400,
  contractName: "StakedHNY",
  raw: "0x484e59..."
}
*/
```
