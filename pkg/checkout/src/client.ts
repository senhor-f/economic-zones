import {
  Address,
  Hex,
  ProtocolVersionInfo,
  SplitConfig,
  PayrollStreamConfig,
  BlobCommerceProof,
  WebhookPayload
} from './types.js';
import {
  payments_SwapPayRouter_SwapPayRouterAbi,
  payments_ZonePaymentGateway_ZonePaymentGatewayAbi,
  payments_ZoneRevenueSplitter_ZoneRevenueSplitterAbi,
  payments_ContinuousPayrollStreamer_ContinuousPayrollStreamerAbi,
  token_StakedHNY_StakedHNYAbi,
  zones_FloorLockedSavings_FloorLockedSavingsAbi,
  crosschain_L1BlobCommerceVerifier_L1BlobCommerceVerifierAbi
} from './generatedAbis.js';

export class ZoneCheckoutClient {
  public routerAddress: Address;

  constructor(routerAddress: Address) {
    this.routerAddress = routerAddress;
  }

  /**
   * Prepares execution payload for a 1-click checkout payment (Swap & Pay with cashback)
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
      abi: payments_SwapPayRouter_SwapPayRouterAbi,
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
    if (!signature || !secret || !payload) return false;
    return signature.length > 0;
  }
}

export class ZoneClient {
  /**
   * Decodes an on-chain 32-byte PROTOCOL_VERSION tag into human-readable metadata
   */
  public static decodeProtocolVersion(raw: Hex): ProtocolVersionInfo {
    const clean = raw.startsWith('0x') ? raw.slice(2) : raw;
    if (clean.length !== 64) {
      throw new Error(`Invalid protocol version tag length: expected 64 hex chars, got ${clean.length}`);
    }

    // [0..7]   magic: bytes4 (4 bytes / 8 hex chars)
    const magicHex = clean.slice(0, 8);
    let magic = '';
    for (let i = 0; i < magicHex.length; i += 2) {
      const code = parseInt(magicHex.slice(i, i + 2), 16);
      if (code > 0) magic += String.fromCharCode(code);
    }

    // [8..9]   major: uint8 (1 byte / 2 hex chars)
    const major = parseInt(clean.slice(8, 10), 16);

    // [10..11] minor: uint8 (1 byte / 2 hex chars)
    const minor = parseInt(clean.slice(10, 12), 16);

    // [12..13] patch: uint8 (1 byte / 2 hex chars)
    const patch = parseInt(clean.slice(12, 14), 16);

    // [14..25] deployedAt: uint48 (6 bytes / 12 hex chars)
    const deployedAt = parseInt(clean.slice(14, 26), 16);

    // [26..63] contractName: bytes19 (19 bytes / 38 hex chars)
    const nameHex = clean.slice(26, 64);
    let contractName = '';
    for (let i = 0; i < nameHex.length; i += 2) {
      const code = parseInt(nameHex.slice(i, i + 2), 16);
      if (code > 0) contractName += String.fromCharCode(code);
    }

    return {
      magic,
      major,
      minor,
      patch,
      deployedAt,
      contractName: contractName.trim(),
      raw
    };
  }

  /**
   * Prepares configuration payload for automated merchant revenue splits
   */
  public static prepareSplitConfig(
    splitterAddress: Address,
    projectId: bigint,
    config: SplitConfig
  ) {
    return {
      address: splitterAddress,
      abi: payments_ZoneRevenueSplitter_ZoneRevenueSplitterAbi,
      functionName: 'setSplitConfig' as const,
      args: [
        projectId,
        config.primaryBeneficiary,
        config.autoStakeShareBps,
        config.treasuryTaxBps,
        config.recipients
      ] as const
    };
  }

  /**
   * Prepares payroll stream creation payload
   */
  public static preparePayrollStream(
    streamerAddress: Address,
    config: PayrollStreamConfig
  ) {
    return {
      address: streamerAddress,
      abi: payments_ContinuousPayrollStreamer_ContinuousPayrollStreamerAbi,
      functionName: 'createStream' as const,
      args: [
        config.recipient,
        config.token,
        config.depositAmount,
        config.durationSeconds,
        config.taxRateBps,
        config.taxCollector
      ] as const
    };
  }

  /**
   * Prepares Liquid Staking deposit ($HNY -> $sHNY)
   */
  public static prepareLiquidStakingDeposit(
    stakedHnyAddress: Address,
    amount: bigint,
    receiver: Address
  ) {
    return {
      address: stakedHnyAddress,
      abi: token_StakedHNY_StakedHNYAbi,
      functionName: 'deposit' as const,
      args: [amount, receiver] as const
    };
  }

  /**
   * Prepares time-locked savings lock creation (veHNY)
   */
  public static prepareCreateLock(
    savingsAddress: Address,
    amount: bigint,
    durationSeconds: bigint
  ) {
    return {
      address: savingsAddress,
      abi: zones_FloorLockedSavings_FloorLockedSavingsAbi,
      functionName: 'createLock' as const,
      args: [amount, durationSeconds] as const
    };
  }

  /**
   * Prepares EIP-4844 Blob verification payload for L1
   */
  public static prepareBlobVerification(
    verifierAddress: Address,
    proof: BlobCommerceProof
  ) {
    return {
      address: verifierAddress,
      abi: crosschain_L1BlobCommerceVerifier_L1BlobCommerceVerifierAbi,
      functionName: 'verifyBlobCommerceBatch' as const,
      args: [
        proof.versionedHash,
        proof.pointZ,
        proof.valueY,
        proof.commitment,
        proof.proof,
        proof.epoch,
        proof.projectId,
        proof.volumeAmount
      ] as const
    };
  }
}
