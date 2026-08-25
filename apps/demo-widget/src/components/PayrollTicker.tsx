import { useState, useEffect } from 'react';
import { Play, Pause, Activity, DollarSign } from 'lucide-react';
import { EconomicZoneClient } from '@economic-zone/checkout';

export const PayrollTicker: React.FC = () => {
  const [secondsElapsed, setSecondsElapsed] = useState<number>(12400);
  const [isRunning, setIsRunning] = useState<boolean>(true);

  const totalSalary = 6000n * 10n**18n; // 6000 HNY / month
  const durationSeconds = 30n * 86400n; // 30 days = 2,592,000 seconds
  const startTime = 0n;
  const stopTime = durationSeconds;

  useEffect(() => {
    if (!isRunning) return;
    const interval = setInterval(() => {
      setSecondsElapsed((prev) => prev + 1);
    }, 1000);
    return () => clearInterval(interval);
  }, [isRunning]);

  // SDK math helper
  const vestedGrossBigInt = EconomicZoneClient.math.calculateVestedSalary(
    startTime,
    stopTime,
    totalSalary,
    BigInt(secondsElapsed)
  );

  const vestedGross = Number(vestedGrossBigInt) / 1e18;
  const taxRate = 0.05; // 5% zone tax
  const taxWithheld = vestedGross * taxRate;
  const netVested = vestedGross - taxWithheld;
  const ratePerSecond = (Number(totalSalary) / 1e18) / Number(durationSeconds);

  return (
    <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 shadow-xl">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-blue-500/20 border border-blue-500/40 flex items-center justify-center text-blue-400">
            <Activity className="w-4 h-4" />
          </div>
          <div>
            <h3 className="font-semibold text-zinc-200">Continuous Payroll Live Ticker</h3>
            <p className="text-xs text-zinc-400">Streaming $HNY salary second-by-second with real-time tax deduction</p>
          </div>
        </div>

        <button
          onClick={() => setIsRunning(!isRunning)}
          className="p-2 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-zinc-300 transition-colors"
        >
          {isRunning ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4 text-emerald-400" />}
        </button>
      </div>

      <div className="text-center py-6 bg-zinc-950/80 rounded-xl border border-zinc-800 mb-6">
        <span className="text-xs text-zinc-500 block mb-1 uppercase tracking-wider">Accumulated Net Salary</span>
        <div className="text-4xl font-mono font-bold text-emerald-400 flex items-center justify-center gap-1">
          <DollarSign className="w-8 h-8 text-emerald-500" />
          <span>{netVested.toFixed(5)}</span>
          <span className="text-sm font-sans font-normal text-zinc-500 ml-1">HNY</span>
        </div>
        <span className="text-xs text-zinc-500 mt-2 block">
          Flowing at <span className="font-mono text-zinc-300">+{ratePerSecond.toFixed(5)} HNY/sec</span>
        </span>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div className="bg-zinc-950/50 p-3 rounded-lg border border-zinc-800/80">
          <span className="text-xs text-zinc-500 block">Gross Vested</span>
          <span className="text-sm font-mono font-semibold text-zinc-300">{vestedGross.toFixed(4)} HNY</span>
        </div>
        <div className="bg-zinc-950/50 p-3 rounded-lg border border-zinc-800/80">
          <span className="text-xs text-zinc-500 block">5% Zone Tax Withheld</span>
          <span className="text-sm font-mono font-semibold text-amber-400">-{taxWithheld.toFixed(4)} HNY</span>
        </div>
      </div>
    </div>
  );
};
