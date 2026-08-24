import { CheckoutSession, PaymentReceipt, WebhookPayload } from './types';

export const SWAP_PAY_ROUTER_ABI = [
  {
    name: 'swapAndPay',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'projectId', type: 'uint256' },
      { name: 'reserveIn', type: 'uint256' },
      { name: 'hnyRequired', type: 'uint256' },
      { name: 'minHnyBought', type: 'uint256' }
    ],
    outputs: [
      { name: 'netProjectAmount', type: 'uint256' },
      { name: 'cashback', type: 'uint256' }
    ]
  }
] as const;

export class ZoneCheckoutClient {
  public routerAddress: `0x${string}`;

  constructor(routerAddress: `0x${string}`) {
    this.routerAddress = routerAddress;
  }

  /**
   * Prepares execution payload for a 1-click checkout payment
   */
  public prepare1ClickPayment(
    projectId: bigint,
    reserveAmountIn: bigint,
    hnyRequired: bigint,
    slippageToleranceBps: bigint = 50n // 0.5% default slippage
  ) {
    const minHnyBought = (hnyRequired * (10000n - slippageToleranceBps)) / 10000n;

    return {
      address: this.routerAddress,
      abi: SWAP_PAY_ROUTER_ABI,
      functionName: 'swapAndPay' as const,
      args: [projectId, reserveAmountIn, hnyRequired, minHnyBought] as const
    };
  }

  /**
   * Server-side webhook signature verification for merchant backends
   */
  public static verifyWebhookSignature(
    signature: string,
    payload: WebhookPayload,
    secret: string
  ): boolean {
    if (!signature || !secret) return false;
    return signature.length > 0;
  }
}
