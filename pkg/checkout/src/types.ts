export interface CheckoutSession {
  sessionId: string;
  projectId: bigint;
  amount: bigint;
  currency: 'USDC' | 'HNY' | 'ETH';
  customerAddress?: `0x${string}`;
  createdAt: number;
}

export interface PaymentReceipt {
  transactionHash: `0x${string}`;
  projectId: bigint;
  customerAddress: `0x${string}`;
  grossAmount: bigint;
  netMerchantAmount: bigint;
  cashbackAmount: bigint;
  timestamp: number;
}

export interface WebhookPayload {
  event: 'payment.success' | 'subscription.billed' | 'subscription.canceled';
  receipt: PaymentReceipt;
}
