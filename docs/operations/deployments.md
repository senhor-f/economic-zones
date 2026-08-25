# Deployments & Operations

> **Production Deployment Orchestration & Network Addresses**

---

## 🚀 Automated Deployment Script ([`DeployProduction.s.sol`](../../script/DeployProduction.s.sol))

The deployment script sets up the full v2.1 suite in proper dependency order with access controls and initial liquidity minters.

### Execution Command:

```bash
# 1. Export Environment Variables
export PRIVATE_KEY="0x..."
export RPC_URL="https://mainnet.base.org"
export RESERVE_TOKEN="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913" # Base USDC
export TREASURY_VAULT="0xYourTreasuryMultisig..."

# 2. Run Forge Broadcast
forge script script/DeployProduction.s.sol:DeployProduction \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

---

## 📋 Deployed Contracts Checklist

| Contract | Role | Network |
| :--- | :--- | :--- |
| **`HNYToken`** | Native Zone Currency ($HNY) | Base / Mainnet |
| **`StakedHNY`** | Liquid Staking Vault ($sHNY ERC-4626) | Base / Mainnet |
| **`AugmentedBondingCurve`** | Central Reserve, Math Spot Price & Floor | Ethereum L1 / Base |
| **`ZonePaymentGateway`** | Drop-in Checkout & Instant Cashback | Base L2 |
| **`SwapPayRouter`** | 1-Click USDC/ETH Router | Base L2 |
| **`SubscriptionManager`** | Recurring SaaS Subscriptions | Base L2 |
| **`ZoneRevenueSplitter`** | Multi-recipient splits with auto-$sHNY stake | Base L2 |
| **`ContinuousPayrollStreamer`** | Second-by-second salary streaming | Base L2 |
| **`FloorLockedSavings`** | veHNY savings vault with boost & floor penalty | Base L2 |
| **`CustomTariffHook`** | Sovereign VAT & Cross-Zone Tariffs | Base L2 |
| **`ZoneClearingHouse`** | Multi-zone bilateral netting & settlement | Base L2 |
| **`x402Settler`** | AI Agent HTTP 402 Settlement | Base L2 |
| **`TreasuryYieldVault`** | 100% Principal-Protected ERC-4626 Vault | Ethereum L1 |
| **`FloorDripper`** | Continuous Yield Streaming to Reserve Floor | Ethereum L1 |
| **`POLManager`** | DEX Protocol-Owned Liquidity Fee Harvester | Ethereum L1 |
| **`L1BlobCommerceVerifier`** | EIP-4844 KZG Point Evaluation Verifier (0x0A) | Ethereum L1 |
| **`L2CommerceBatcher`** | Commerce Merkle Aggregator & Bridge Router | Base L2 |
| **`xHNYLockbox`** | ERC-7281 Sovereign Custody with Rate Limits | Ethereum L1 |
