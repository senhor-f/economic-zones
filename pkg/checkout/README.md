# @economic-zone/checkout

> 1-Click Crypto Checkout Widget & Webhooks for dApps, SaaS, and Merchants with instant customer cashback in $HNY.

## 🚀 Quickstart

### 1. Installation
```bash
npm install @economic-zone/checkout viem
```

### 2. Frontend Payment Button (React / Next.js)
```tsx
import { ZoneCheckoutClient } from '@economic-zone/checkout';
import { useWriteContract } from 'wagmi';

const checkout = new ZoneCheckoutClient("0xRouterAddress...");

export function PayButton({ projectId, amountUSDC }: { projectId: bigint; amountUSDC: bigint }) {
  const { writeContract } = useWriteContract();

  const handlePay = () => {
    const tx = checkout.prepare1ClickPayment(projectId, amountUSDC, amountUSDC);
    writeContract(tx);
  };

  return (
    <button onClick={handlePay} className="btn-primary">
      Pay with 1-Click (Get 1% Cashback in $HNY)
    </button>
  );
}
```

### 3. Server Webhook Verification (Node.js / Express)
```typescript
import { ZoneCheckoutClient, WebhookPayload } from '@economic-zone/checkout';

app.post('/api/webhooks/zone', (req, res) => {
  const signature = req.headers['x-zone-signature'] as string;
  const payload = req.body as WebhookPayload;

  const isValid = ZoneCheckoutClient.verifyWebhookSignature(
    signature,
    payload,
    process.env.ZONE_WEBHOOK_SECRET!
  );

  if (!isValid) return res.status(401).send('Invalid signature');

  console.log(`Payment confirmed: ${payload.receipt.grossAmount} from ${payload.receipt.customerAddress}`);
  res.status(200).json({ received: true });
});
```
