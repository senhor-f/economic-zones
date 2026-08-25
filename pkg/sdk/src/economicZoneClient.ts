import {
  createPublicClient,
  createWalletClient,
  http,
  PublicClient,
  WalletClient,
  Account,
  formatUnits,
  parseUnits
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base, mainnet, arbitrum, baseSepolia } from 'viem/chains';
import {
  Address,
  Hex,
  ProtocolVersionInfo,
  SplitConfig,
  PayrollStreamConfig,
  BlobCommerceProof,
  LockPosition
} from './types.js';
import {
  token_HNYToken_HNYTokenAbi,
  token_StakedHNY_StakedHNYAbi,
  curve_AugmentedBondingCurve_AugmentedBondingCurveAbi,
  payments_ZonePaymentGateway_ZonePaymentGatewayAbi,
  payments_SwapPayRouter_SwapPayRouterAbi,
  payments_ZoneRevenueSplitter_ZoneRevenueSplitterAbi,
  payments_ContinuousPayrollStreamer_ContinuousPayrollStreamerAbi,
  zones_FloorLockedSavings_FloorLockedSavingsAbi,
  rebalancing_FloorDripper_FloorDripperAbi,
  crosschain_L1BlobCommerceVerifier_L1BlobCommerceVerifierAbi
} from './generatedAbis.js';
import { ZoneClient } from './client.js';

export interface ProtocolDeploymentAddresses {
  hnyToken?: Address;
  stakedHny?: Address;
  curve?: Address;
  paymentGateway?: Address;
  swapPayRouter?: Address;
  revenueSplitter?: Address;
  payrollStreamer?: Address;
  floorLockedSavings?: Address;
  floorDripper?: Address;
  blobVerifier?: Address;
}

export type SupportedChain = 'base' | 'ethereum' | 'arbitrum' | 'base-sepolia' | 'local';

export interface EconomicZoneClientConfig {
  chain?: SupportedChain;
  rpcUrl?: string;
  privateKey?: Hex;
  addresses?: ProtocolDeploymentAddresses;
  publicClient?: PublicClient;
  walletClient?: WalletClient;
}

export class EconomicZoneClient {
  public publicClient: PublicClient;
  public walletClient?: WalletClient;
  public account?: Account;
  public addresses: ProtocolDeploymentAddresses;

  constructor(config: EconomicZoneClientConfig = {}) {
    const chainConfig = config.chain === 'ethereum'
      ? mainnet
      : config.chain === 'arbitrum'
      ? arbitrum
      : config.chain === 'base-sepolia'
      ? baseSepolia
      : base;

    if (config.publicClient) {
      this.publicClient = config.publicClient;
    } else {
      this.publicClient = createPublicClient({
        chain: chainConfig,
        transport: http(config.rpcUrl)
      }) as PublicClient;
    }

    if (config.privateKey) {
      this.account = privateKeyToAccount(config.privateKey);
      this.walletClient = createWalletClient({
        account: this.account,
        chain: chainConfig,
        transport: http(config.rpcUrl)
      });
    } else if (config.walletClient) {
      this.walletClient = config.walletClient;
    }

    this.addresses = config.addresses ?? {};
  }

  /*//////////////////////////////////////////////////////////////
                           CURVE & FLOOR
  //////////////////////////////////////////////////////////////*/

  public readonly curve = {
    getFloorPrice: async (): Promise<bigint> => {
      this._requireAddress('curve');
      return (await this.publicClient.readContract({
        address: this.addresses.curve!,
        abi: curve_AugmentedBondingCurve_AugmentedBondingCurveAbi,
        functionName: 'getFloorPrice'
      })) as bigint;
    },

    getSpotPrice: async (): Promise<bigint> => {
      this._requireAddress('curve');
      return (await this.publicClient.readContract({
        address: this.addresses.curve!,
        abi: curve_AugmentedBondingCurve_AugmentedBondingCurveAbi,
        functionName: 'getSpotPrice'
      })) as bigint;
    },

    previewBuy: async (reserveAmountIn: bigint): Promise<{ hnyOut: bigint; tribute: bigint }> => {
      this._requireAddress('curve');
      const res = (await this.publicClient.readContract({
        address: this.addresses.curve!,
        abi: curve_AugmentedBondingCurve_AugmentedBondingCurveAbi,
        functionName: 'previewBuy',
        args: [reserveAmountIn]
      })) as [bigint, bigint];
      return { hnyOut: res[0], tribute: res[1] };
    },

    previewSell: async (hnyAmountIn: bigint): Promise<{ reserveOut: bigint; tribute: bigint }> => {
      this._requireAddress('curve');
      const res = (await this.publicClient.readContract({
        address: this.addresses.curve!,
        abi: curve_AugmentedBondingCurve_AugmentedBondingCurveAbi,
        functionName: 'previewSell',
        args: [hnyAmountIn]
      })) as [bigint, bigint];
      return { reserveOut: res[0], tribute: res[1] };
    }
  };

  /*//////////////////////////////////////////////////////////////
                             CHECKOUT
  //////////////////////////////////////////////////////////////*/

  public readonly checkout = {
    prepare1ClickPayment: (
      projectId: bigint,
      reserveAmountIn: bigint,
      hnyRequired: bigint,
      slippageToleranceBps: bigint = 50n
    ) => {
      this._requireAddress('swapPayRouter');
      const minHnyBought = (hnyRequired * (10000n - slippageToleranceBps)) / 10000n;
      return {
        address: this.addresses.swapPayRouter!,
        abi: payments_SwapPayRouter_SwapPayRouterAbi,
        functionName: 'swapAndPay' as const,
        args: [projectId, reserveAmountIn, hnyRequired, minHnyBought] as const
      };
    }
  };

  /*//////////////////////////////////////////////////////////////
                          LIQUID STAKING
  //////////////////////////////////////////////////////////////*/

  public readonly staking = {
    getTotalAssets: async (): Promise<bigint> => {
      this._requireAddress('stakedHny');
      return (await this.publicClient.readContract({
        address: this.addresses.stakedHny!,
        abi: token_StakedHNY_StakedHNYAbi,
        functionName: 'totalAssets'
      })) as bigint;
    },

    convertToShares: async (assets: bigint): Promise<bigint> => {
      this._requireAddress('stakedHny');
      return (await this.publicClient.readContract({
        address: this.addresses.stakedHny!,
        abi: token_StakedHNY_StakedHNYAbi,
        functionName: 'convertToShares',
        args: [assets]
      })) as bigint;
    },

    convertToAssets: async (shares: bigint): Promise<bigint> => {
      this._requireAddress('stakedHny');
      return (await this.publicClient.readContract({
        address: this.addresses.stakedHny!,
        abi: token_StakedHNY_StakedHNYAbi,
        functionName: 'convertToAssets',
        args: [shares]
      })) as bigint;
    }
  };

  /*//////////////////////////////////////////////////////////////
                        PAYROLL STREAMING
  //////////////////////////////////////////////////////////////*/

  public readonly payroll = {
    getStream: async (streamId: bigint) => {
      this._requireAddress('payrollStreamer');
      const res = (await this.publicClient.readContract({
        address: this.addresses.payrollStreamer!,
        abi: payments_ContinuousPayrollStreamer_ContinuousPayrollStreamerAbi,
        functionName: 'streams',
        args: [streamId]
      })) as unknown as [
        bigint, // id
        Address, // payer
        Address, // recipient
        Address, // token
        bigint, // depositAmount
        bigint, // withdrawnAmount
        bigint, // startTime
        bigint, // stopTime
        bigint, // ratePerSecond
        number, // taxRateBps
        Address, // taxCollector
        boolean, // isPaused
        boolean  // isCanceled
      ];
      return {
        id: res[0],
        payer: res[1],
        recipient: res[2],
        token: res[3],
        depositAmount: res[4],
        withdrawnAmount: res[5],
        startTime: res[6],
        stopTime: res[7],
        ratePerSecond: res[8],
        taxRateBps: res[9],
        taxCollector: res[10],
        isPaused: res[11],
        isCanceled: res[12]
      };
    },

    vestedAmountOf: async (streamId: bigint): Promise<bigint> => {
      this._requireAddress('payrollStreamer');
      return (await this.publicClient.readContract({
        address: this.addresses.payrollStreamer!,
        abi: payments_ContinuousPayrollStreamer_ContinuousPayrollStreamerAbi,
        functionName: 'vestedAmountOf',
        args: [streamId]
      })) as bigint;
    }
  };

  /*//////////////////////////////////////////////////////////////
                        PROTOCOL VERSIONING
  //////////////////////////////////////////////////////////////*/

  public readonly version = {
    getMetadata: async (targetContract: Address): Promise<ProtocolVersionInfo> => {
      const rawTag = (await this.publicClient.readContract({
        address: targetContract,
        abi: [
          {
            name: 'PROTOCOL_VERSION',
            type: 'function',
            stateMutability: 'view',
            inputs: [],
            outputs: [{ name: '', type: 'bytes32' }]
          }
        ],
        functionName: 'PROTOCOL_VERSION'
      })) as Hex;

      return ZoneClient.decodeProtocolVersion(rawTag);
    }
  };

  /*//////////////////////////////////////////////////////////////
                           MATH HELPERS
  //////////////////////////////////////////////////////////////*/

  public static readonly math = {
    /**
     * Calculates new Floor Price given additional dripped yield
     */
    calculateFloorGrowth: (
      currentReserve: bigint,
      currentSupply: bigint,
      drippedYield: bigint
    ): { previousFloor: bigint; newFloor: bigint; growthBps: number } => {
      if (currentSupply === 0n) return { previousFloor: 0n, newFloor: 0n, growthBps: 0 };
      const previousFloor = (currentReserve * 10n**18n) / currentSupply;
      const newFloor = ((currentReserve + drippedYield) * 10n**18n) / currentSupply;
      const growthBps = previousFloor > 0n ? Number(((newFloor - previousFloor) * 10000n) / previousFloor) : 0;
      return { previousFloor, newFloor, growthBps };
    },

    /**
     * Calculates linear voting boost multiplier (1.0x to 4.0x) for veHNY lock durations
     */
    calculateLockMultiplierBps: (durationSeconds: bigint): number => {
      const minLock = 30n * 86400n; // 30 days
      const maxLock = 365n * 86400n * 4n; // 4 years
      if (durationSeconds <= minLock) return 10000; // 1.0x
      if (durationSeconds >= maxLock) return 40000; // 4.0x
      const elapsed = durationSeconds - minLock;
      const span = maxLock - minLock;
      return 10000 + Number((elapsed * 30000n) / span);
    },

    /**
     * Calculates real-time vested salary stream balance
     */
    calculateVestedSalary: (
      startTime: bigint,
      stopTime: bigint,
      totalDeposit: bigint,
      currentTimestamp: bigint
    ): bigint => {
      if (currentTimestamp <= startTime) return 0n;
      if (currentTimestamp >= stopTime) return totalDeposit;
      const duration = stopTime - startTime;
      const elapsed = currentTimestamp - startTime;
      return (totalDeposit * elapsed) / duration;
    }
  };

  private _requireAddress(name: keyof ProtocolDeploymentAddresses) {
    if (!this.addresses[name]) {
      throw new Error(`EconomicZoneClient: contract address '${name}' is not configured.`);
    }
  }
}

export function createEconomicZoneClient(config: EconomicZoneClientConfig = {}): EconomicZoneClient {
  return new EconomicZoneClient(config);
}
