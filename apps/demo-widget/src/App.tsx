import { useState } from 'react';
import { CheckoutWidget } from './components/CheckoutWidget';
import { FloorSimulator } from './components/FloorSimulator';
import { PayrollTicker } from './components/PayrollTicker';
import { ZoneClient } from '@economic-zone/checkout';
import { Coins, Sparkles, BookOpen, Shield } from 'lucide-react';

export function App() {
  const [versionInput, setVersionInput] = useState(
    '0x484e5932020100000068ac3d805374616b6564484e5900000000000000000000'
  );
  const [decodedVersion, setDecodedVersion] = useState<any>(null);

  const handleDecode = () => {
    try {
      const decoded = ZoneClient.decodeProtocolVersion(versionInput as any);
      setDecodedVersion(decoded);
    } catch (e: any) {
      alert(`Invalid version tag: ${e.message}`);
    }
  };

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100 flex flex-col">
      {/* Navbar */}
      <header className="border-b border-zinc-800/80 bg-zinc-950/80 backdrop-blur-md sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-amber-500/20 border border-amber-500/40 flex items-center justify-center text-amber-400 font-bold text-lg shadow-lg shadow-amber-500/10">
              🪙
            </div>
            <div>
              <span className="font-bold text-white tracking-tight">Economic Zones</span>
              <span className="text-xs px-2 py-0.5 ml-2 rounded-md bg-amber-500/20 text-amber-300 font-mono">
                $HNY v2.1
              </span>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <a
              href="/docs"
              target="_blank"
              rel="noreferrer"
              className="px-3.5 py-1.5 rounded-lg text-xs font-medium bg-zinc-900 border border-zinc-800 hover:border-zinc-700 text-zinc-300 transition-all flex items-center gap-1.5"
            >
              <BookOpen className="w-3.5 h-3.5" /> Docs
            </a>
            <div className="px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs font-medium flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
              Base L2 Live
            </div>
          </div>
        </div>
      </header>

      {/* Main Container */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-10">
        {/* Hero Banner */}
        <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-amber-500/10 via-zinc-900 to-zinc-950 border border-amber-500/20 p-8 shadow-2xl">
          <div className="max-w-2xl">
            <h1 className="text-3xl sm:text-4xl font-extrabold text-white tracking-tight">
              Sovereign On-Chain Economies with an{' '}
              <span className="bg-gradient-to-r from-amber-400 to-amber-200 bg-clip-text text-transparent">
                Unbreachable Floor Price
              </span>
            </h1>
            <p className="text-zinc-400 text-sm sm:text-base mt-3">
              Explore the 1-Click Drop-in Checkout widget with instant 1% cashback, second-by-second salary streaming, and the mathematical bonding curve simulator.
            </p>
          </div>
        </div>

        {/* Section 1: Drop-in Checkout & Live Salary Streaming */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-start">
          {/* Column A: Checkout Drop-in */}
          <div className="space-y-4">
            <h2 className="text-lg font-bold text-white flex items-center gap-2">
              <Coins className="w-5 h-5 text-amber-400" />
              1-Click Drop-in Checkout Widget
            </h2>
            <CheckoutWidget
              projectId={42}
              productName="AI Autonomous Agent Fleet (Monthly Pro)"
              priceUSDC={99.0}
            />
          </div>

          {/* Column B: Payroll Streaming Ticker */}
          <div className="space-y-4">
            <h2 className="text-lg font-bold text-white flex items-center gap-2">
              <Sparkles className="w-5 h-5 text-blue-400" />
              Continuous Salary Streaming
            </h2>
            <PayrollTicker />
          </div>
        </div>

        {/* Section 2: Mathematical Floor Dripper & veHNY Simulator */}
        <div className="space-y-4">
          <h2 className="text-lg font-bold text-white flex items-center gap-2">
            <Shield className="w-5 h-5 text-emerald-400" />
            Macro Economy & veHNY Simulator
          </h2>
          <FloorSimulator />
        </div>

        {/* Section 3: On-Chain Packed bytes32 Version Decoder */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 shadow-xl">
          <h3 className="font-semibold text-zinc-200 text-base mb-1">
            🔍 On-Chain `bytes32 PROTOCOL_VERSION` Inspector
          </h3>
          <p className="text-xs text-zinc-400 mb-4">
            Paste any on-chain 32-byte version tag to instantly decode protocol magic, SemVer, timestamp, and contract name.
          </p>

          <div className="flex flex-col sm:flex-row gap-3 mb-4">
            <input
              type="text"
              value={versionInput}
              onChange={(e) => setVersionInput(e.target.value)}
              placeholder="0x484e59..."
              className="flex-1 px-4 py-2.5 rounded-xl bg-zinc-950 border border-zinc-800 font-mono text-xs text-zinc-300 focus:outline-none focus:border-amber-500"
            />
            <button
              onClick={handleDecode}
              className="px-5 py-2.5 rounded-xl bg-amber-500 hover:bg-amber-400 text-zinc-950 font-bold text-xs transition-colors"
            >
              Decode Tag
            </button>
          </div>

          {decodedVersion && (
            <div className="bg-zinc-950/80 p-4 rounded-xl border border-amber-500/30 grid grid-cols-2 sm:grid-cols-5 gap-3 text-xs">
              <div>
                <span className="text-zinc-500 block">Magic Tag</span>
                <span className="font-mono font-bold text-amber-400">{decodedVersion.magic}</span>
              </div>
              <div>
                <span className="text-zinc-500 block">SemVer</span>
                <span className="font-mono font-bold text-zinc-200">
                  v{decodedVersion.major}.{decodedVersion.minor}.{decodedVersion.patch}
                </span>
              </div>
              <div>
                <span className="text-zinc-500 block">Contract</span>
                <span className="font-mono font-bold text-emerald-400">{decodedVersion.contractName}</span>
              </div>
              <div>
                <span className="text-zinc-500 block">Deployed At</span>
                <span className="font-mono text-zinc-300">
                  {new Date(decodedVersion.deployedAt * 1000).toLocaleDateString()}
                </span>
              </div>
              <div>
                <span className="text-zinc-500 block">Storage Cost</span>
                <span className="font-mono font-bold text-purple-400">0 Gas (Immutable)</span>
              </div>
            </div>
          )}
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-zinc-800/60 py-6 text-center text-xs text-zinc-500">
        Economic Zones Protocol ($HNY v2.1) — Autonomous Sovereign Financial Matrix
      </footer>
    </div>
  );
}

export default App;
