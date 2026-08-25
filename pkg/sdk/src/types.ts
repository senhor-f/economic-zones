export type Address = `0x${string}`;
export type Hex = `0x${string}`;

export interface ProtocolVersionInfo {
  magic: string;
  major: number;
  minor: number;
  patch: number;
  deployedAt: number;
  contractName: string;
  raw: Hex;
}

export interface CheckoutSession {
  id: string;
  projectId: bigint;
  amount: bigint;
  currency: string;
  recipient: Address;
  metadata?: Record<string, unknown>;
}

export interface PaymentReceipt {
  txHash: Hex;
  projectId: bigint;
  payer: Address;
  grossAmount: bigint;
  netProjectAmount: bigint;
  cashbackAmount: bigint;
}

export interface WebhookPayload {
  event: 'payment.success' | 'subscription.billed' | 'payroll.vested' | 'lock.created';
  timestamp: number;
  data: Record<string, unknown>;
}

export interface SplitRecipient {
  recipient: Address;
  shareBps: number;
}

export interface SplitConfig {
  primaryBeneficiary: Address;
  autoStakeShareBps: number;
  treasuryTaxBps: number;
  recipients: SplitRecipient[];
}

export interface PayrollStreamConfig {
  recipient: Address;
  token: Address;
  depositAmount: bigint;
  durationSeconds: bigint;
  taxRateBps: number;
  taxCollector: Address;
}

export interface LockPosition {
  lockId: bigint;
  owner: Address;
  amount: bigint;
  startTime: bigint;
  unlockTime: bigint;
  boostedAmount: bigint;
  isUnlocked: boolean;
}

export interface BlobCommerceProof {
  versionedHash: Hex;
  pointZ: Hex;
  valueY: Hex;
  commitment: Hex;
  proof: Hex;
  epoch: bigint;
  projectId: bigint;
  volumeAmount: bigint;
}
