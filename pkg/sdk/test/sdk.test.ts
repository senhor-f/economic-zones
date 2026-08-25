import { describe, expect, it } from 'bun:test';
import { createEconomicZoneClient, EconomicZoneClient } from '../src/economicZoneClient.js';

describe('EconomicZoneClient Deluxe SDK', () => {
  it('instantiates client with custom chain and addresses', () => {
    const client = createEconomicZoneClient({
      chain: 'base',
      addresses: {
        curve: '0x1111111111111111111111111111111111111111',
        stakedHny: '0x2222222222222222222222222222222222222222',
        swapPayRouter: '0x3333333333333333333333333333333333333333'
      }
    });

    expect(client.addresses.curve).toBe('0x1111111111111111111111111111111111111111');
    expect(client.publicClient).toBeDefined();
  });

  describe('Math Helpers', () => {
    it('calculates monotonic floor price growth', () => {
      const currentReserve = 100_000n * 10n**18n; // 100k USDC
      const currentSupply = 100_000n * 10n**18n;  // 100k HNY (Floor = 1.0)
      const drippedYield = 10_000n * 10n**18n;    // +10k USDC yield dripped

      const { previousFloor, newFloor, growthBps } = EconomicZoneClient.math.calculateFloorGrowth(
        currentReserve,
        currentSupply,
        drippedYield
      );

      expect(previousFloor).toBe(10n**18n); // 1.0 USDC
      expect(newFloor).toBe(11n * 10n**17n); // 1.1 USDC
      expect(growthBps).toBe(1000); // +10.0% (1000 bps)
    });

    it('calculates lock voting boost multiplier', () => {
      const minLock = 30n * 86400n; // 30 days
      const maxLock = 365n * 86400n * 4n; // 4 years

      expect(EconomicZoneClient.math.calculateLockMultiplierBps(minLock)).toBe(10000); // 1.0x (10000 bps)
      expect(EconomicZoneClient.math.calculateLockMultiplierBps(maxLock)).toBe(40000); // 4.0x (40000 bps)
    });

    it('calculates real-time vested salary streaming', () => {
      const startTime = 1000n;
      const stopTime = 2000n;
      const totalDeposit = 5000n * 10n**18n;

      // At half-time: 50% vested
      const halfTime = 1500n;
      const vestedHalf = EconomicZoneClient.math.calculateVestedSalary(
        startTime,
        stopTime,
        totalDeposit,
        halfTime
      );
      expect(vestedHalf).toBe(2500n * 10n**18n);

      // Before start: 0% vested
      expect(EconomicZoneClient.math.calculateVestedSalary(startTime, stopTime, totalDeposit, 900n)).toBe(0n);

      // After stop: 100% vested
      expect(EconomicZoneClient.math.calculateVestedSalary(startTime, stopTime, totalDeposit, 2500n)).toBe(totalDeposit);
    });
  });
});
