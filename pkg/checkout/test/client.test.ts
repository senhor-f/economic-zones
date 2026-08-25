import { describe, expect, it } from 'bun:test';
import { ZoneCheckoutClient, ZoneClient } from '../src/client';

describe('@senhor-f/checkout SDK', () => {
  const routerAddress = '0x1111111111111111111111111111111111111111' as const;
  const client = new ZoneCheckoutClient(routerAddress);

  it('prepares 1-click checkout payment payload', () => {
    const payload = client.prepare1ClickPayment(
      1n,
      100_000000n, // 100 USDC (6 decimals or 18)
      50_000000000000000000n, // 50 HNY
      100n // 1.0% slippage
    );

    expect(payload.address).toBe(routerAddress);
    expect(payload.functionName).toBe('swapAndPay');
    expect(payload.args[0]).toBe(1n);
    expect(payload.args[1]).toBe(100_000000n);
    expect(payload.args[2]).toBe(50_000000000000000000n);
    expect(payload.args[3]).toBe((50_000000000000000000n * 9900n) / 10000n);
  });

  it('decodes on-chain bytes32 PROTOCOL_VERSION metadata tag', () => {
    // Encode a sample tag: Magic HNY2 (0x484e5932), Major 2, Minor 1, Patch 0, timestamp 1756118400 (0x000068ac3d80), "StakedHNY"
    const sampleTag = '0x484e5932020100000068ac3d805374616b6564484e5900000000000000000000' as const;
    const info = ZoneClient.decodeProtocolVersion(sampleTag);

    expect(info.magic).toBe('HNY2');
    expect(info.major).toBe(2);
    expect(info.minor).toBe(1);
    expect(info.patch).toBe(0);
    expect(info.deployedAt).toBe(1756118400);
    expect(info.contractName).toBe('StakedHNY');
  });

  it('prepares automated split config payload', () => {
    const splitter = '0x2222222222222222222222222222222222222222' as const;
    const payload = ZoneClient.prepareSplitConfig(splitter, 10n, {
      primaryBeneficiary: '0x3333333333333333333333333333333333333333' as const,
      autoStakeShareBps: 1000,
      treasuryTaxBps: 500,
      recipients: [
        { recipient: '0x4444444444444444444444444444444444444444' as const, shareBps: 8500 }
      ]
    });

    expect(payload.address).toBe(splitter);
    expect(payload.functionName).toBe('setSplitConfig');
    expect(payload.args[0]).toBe(10n);
    expect(payload.args[2]).toBe(1000);
  });

  it('prepares payroll stream payload', () => {
    const streamer = '0x5555555555555555555555555555555555555555' as const;
    const payload = ZoneClient.preparePayrollStream(streamer, {
      recipient: '0x6666666666666666666666666666666666666666' as const,
      token: '0x7777777777777777777777777777777777777777' as const,
      depositAmount: 1000n,
      durationSeconds: 86400n,
      taxRateBps: 500,
      taxCollector: '0x8888888888888888888888888888888888888888' as const
    });

    expect(payload.address).toBe(streamer);
    expect(payload.functionName).toBe('createStream');
    expect(payload.args[2]).toBe(1000n);
  });
});
