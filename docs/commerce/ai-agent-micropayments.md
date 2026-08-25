# Autonomous AI Agent Micropayments (HTTP 402)

> **Machine-to-Machine Microtransactions for Coinbase AgentKit and Claude MCP**

The protocol natively implements the `HTTP 402 Payment Required` standard via [`x402Settler.sol`](../../src/payments/x402Settler.sol), allowing autonomous AI agents to query APIs, purchase compute, and settle micro-services using off-chain **EIP-712 cryptographic signatures**.

---

## 🤖 The M2M Settlement Flow

```mermaid
sequenceDiagram
    autonumber
    actor Bot as AI Agent (MCP / AgentKit)
    participant Server as Paywalled AI API
    participant Settler as x402Settler.sol
    participant Gateway as ZonePaymentGateway.sol

    Bot->>Server: GET /api/v1/inference
    Server-->>Bot: HTTP 402 (Price: 0.05 HNY, PayTo: Project #42)
    Bot->>Bot: Sign EIP-712 Permit (amount, nonce, deadline)
    Bot->>Server: POST /api/v1/inference with EIP-712 Signature
    Server->>Settler: settleWithPermit(signature, 0.05 HNY)
    Settler->>Gateway: processPayment(...)
    Gateway->>Server: Instant Settlement
    Server-->>Bot: HTTP 200 OK (Inference Data Delivered)
```

---

## 🔒 EIP-712 Type Definition

```solidity
struct AgentPaymentPermit {
    address agent;
    uint256 projectId;
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
}
```

Because agents sign authorization messages off-chain and the API server submits the settlement transaction, **agents do not need to manage gas balances or execute complex blockchain transactions directly**.
