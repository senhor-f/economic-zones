import { useState } from 'react';
import { TrendingUp, Droplets, Lock, Clock } from 'lucide-react';
import { EconomicZoneClient } from '@senhor-f/checkout';

export const FloorSimulator: React.FC = () => {
  const [drippedYieldUSDC, setDrippedYieldUSDC] = useState<number>(25000);
  const [lockMonths, setLockMonths] = useState<number>(24);

  // Baseline protocol state
  const baseReserve = 100_000n * 10n**18n;
  const baseSupply = 100_000n * 10n**18n;
  const drippedBigInt = BigInt(drippedYieldUSDC) * 10n**18n;

  // Real-time calculations using SDK math
  const { previousFloor, newFloor, growthBps } = EconomicZoneClient.math.calculateFloorGrowth(
    baseReserve,
    baseSupply,
    drippedBigInt
  );

  const prevFloorNum = Number(previousFloor) / 1e18;
  const newFloorNum = Number(newFloor) / 1e18;

  // veHNY lock calculations
  const durationSeconds = BigInt(lockMonths) * 30n * 86400n;
  const multiplierBps = EconomicZoneClient.math.calculateLockMultiplierBps(durationSeconds);
  const multiplierFloat = (multiplierBps / 10000).toFixed(2);
  const cashbackBoostBps = Math.min(100, Math.floor((lockMonths / 48) * 100));

  return (
    <div className="space-y-6">
      {/* 1. Floor & Dripper Simulator */}
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 shadow-xl">
        <div className="flex items-center gap-2 mb-4">
          <div className="w-8 h-8 rounded-lg bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center text-emerald-400">
            <TrendingUp className="w-4 h-4" />
          </div>
          <div>
            <h3 className="font-semibold text-zinc-200">Floor Dripper Real-time Simulation</h3>
            <p className="text-xs text-zinc-400">Model how harvested treasury yields increase the redeemable floor price</p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div className="bg-zinc-950/80 p-4 rounded-xl border border-zinc-800">
            <span className="text-xs text-zinc-500 block mb-1">Current Reserve Floor</span>
            <span className="text-xl font-bold text-zinc-200">${prevFloorNum.toFixed(4)} USDC</span>
          </div>

          <div className="bg-zinc-950/80 p-4 rounded-xl border border-emerald-500/30">
            <span className="text-xs text-emerald-400 block mb-1">New Projected Floor</span>
            <span className="text-xl font-bold text-emerald-400">${newFloorNum.toFixed(4)} USDC</span>
          </div>

          <div className="bg-zinc-950/80 p-4 rounded-xl border border-amber-500/30">
            <span className="text-xs text-amber-400 block mb-1">Floor Monotonic Growth</span>
            <span className="text-xl font-bold text-amber-400">+{(growthBps / 100).toFixed(2)}%</span>
          </div>
        </div>

        <div className="space-y-2">
          <div className="flex justify-between text-xs text-zinc-400">
            <span className="flex items-center gap-1">
              <Droplets className="w-3.5 h-3.5 text-blue-400" /> Dripped Treasury Yield
            </span>
            <span className="font-semibold text-white">${drippedYieldUSDC.toLocaleString()} USDC</span>
          </div>
          <input
            type="range"
            min="0"
            max="100000"
            step="1000"
            value={drippedYieldUSDC}
            onChange={(e) => setDrippedYieldUSDC(Number(e.target.value))}
            className="w-full h-2 bg-zinc-800 rounded-lg appearance-none cursor-pointer accent-emerald-500"
          />
        </div>
      </div>

      {/* 2. veHNY Lock Calculator */}
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 shadow-xl">
        <div className="flex items-center gap-2 mb-4">
          <div className="w-8 h-8 rounded-lg bg-purple-500/20 border border-purple-500/40 flex items-center justify-center text-purple-400">
            <Lock className="w-4 h-4" />
          </div>
          <div>
            <h3 className="font-semibold text-zinc-200">veHNY Time-Locked Savings Calculator</h3>
            <p className="text-xs text-zinc-400">Simulate boosted governance voting power and checkout cashback</p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
          <div className="bg-zinc-950/80 p-4 rounded-xl border border-purple-500/30">
            <span className="text-xs text-purple-400 block mb-1">Conviction Voting Boost</span>
            <span className="text-2xl font-bold text-purple-300">{multiplierFloat}x Multiplier</span>
          </div>

          <div className="bg-zinc-950/80 p-4 rounded-xl border border-amber-500/30">
            <span className="text-xs text-amber-400 block mb-1">Checkout Cashback Boost</span>
            <span className="text-2xl font-bold text-amber-400">+{cashbackBoostBps} bps (+{(cashbackBoostBps / 100).toFixed(2)}%)</span>
          </div>
        </div>

        <div className="space-y-2">
          <div className="flex justify-between text-xs text-zinc-400">
            <span className="flex items-center gap-1">
              <Clock className="w-3.5 h-3.5 text-purple-400" /> Lock Duration
            </span>
            <span className="font-semibold text-white">{lockMonths} Months</span>
          </div>
          <input
            type="range"
            min="1"
            max="48"
            step="1"
            value={lockMonths}
            onChange={(e) => setLockMonths(Number(e.target.value))}
            className="w-full h-2 bg-zinc-800 rounded-lg appearance-none cursor-pointer accent-purple-500"
          />
        </div>
      </div>
    </div>
  );
};
