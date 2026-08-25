import { useState } from 'react';
import { ShoppingBag, Sparkles, CheckCircle2, ShieldCheck, ArrowRight } from 'lucide-react';

interface CheckoutWidgetProps {
  projectId: number;
  productName: string;
  priceUSDC: number;
}

export const CheckoutWidget: React.FC<CheckoutWidgetProps> = ({
  projectId,
  productName,
  priceUSDC
}) => {
  const [selectedToken, setSelectedToken] = useState<'USDC' | 'ETH' | 'HNY'>('USDC');
  const [isProcessing, setIsProcessing] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);

  // Math simulation via SDK
  const cashbackHNY = (priceUSDC * 0.01).toFixed(2);
  const floorBoostUSDC = (priceUSDC * 0.01 * 0.5).toFixed(4);

  const handle1ClickPay = () => {
    setIsProcessing(true);
    setTimeout(() => {
      setIsProcessing(false);
      setIsSuccess(true);
    }, 1200);
  };

  return (
    <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 shadow-2xl max-w-md w-full relative overflow-hidden">
      {/* Glow highlight */}
      <div className="absolute top-0 right-0 w-32 h-32 bg-amber-500/10 rounded-full blur-2xl -mr-10 -mt-10 pointer-events-none" />

      {/* Header */}
      <div className="flex items-center justify-between pb-4 border-b border-zinc-800">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-amber-500/20 border border-amber-500/40 flex items-center justify-center text-amber-400">
            <ShoppingBag className="w-4 h-4" />
          </div>
          <div>
            <h3 className="font-semibold text-sm text-zinc-200">1-Click Zone Checkout</h3>
            <p className="text-xs text-zinc-400">Project #{projectId}</p>
          </div>
        </div>
        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-amber-500/10 text-amber-400 border border-amber-500/20">
          <Sparkles className="w-3 h-3" /> +1% Cashback
        </span>
      </div>

      {/* Product Summary */}
      <div className="py-5">
        <div className="flex justify-between items-baseline mb-1">
          <span className="text-zinc-300 font-medium">{productName}</span>
          <span className="text-2xl font-bold text-white">${priceUSDC.toFixed(2)}</span>
        </div>
        <p className="text-xs text-zinc-500">Includes instant on-chain settlement on Base L2</p>

        {/* Currency selection */}
        <div className="mt-4 grid grid-cols-3 gap-2">
          {(['USDC', 'ETH', 'HNY'] as const).map((token) => (
            <button
              key={token}
              onClick={() => setSelectedToken(token)}
              className={`py-2 px-3 rounded-xl text-xs font-semibold border transition-all ${
                selectedToken === token
                  ? 'bg-amber-500/20 border-amber-500 text-amber-300 shadow-sm shadow-amber-500/10'
                  : 'bg-zinc-950/60 border-zinc-800 text-zinc-400 hover:border-zinc-700'
              }`}
            >
              Pay with {token}
            </button>
          ))}
        </div>
      </div>

      {/* Incentive Breakdown */}
      <div className="bg-zinc-950/80 rounded-xl p-3.5 border border-zinc-800/80 space-y-2 mb-5">
        <div className="flex justify-between text-xs">
          <span className="text-zinc-400 flex items-center gap-1">
            <Sparkles className="w-3.5 h-3.5 text-amber-400" /> Instant $HNY Cashback:
          </span>
          <span className="font-semibold text-amber-400">+{cashbackHNY} HNY (${cashbackHNY})</span>
        </div>
        <div className="flex justify-between text-xs">
          <span className="text-zinc-400 flex items-center gap-1">
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" /> Floor Price Monotonic Boost:
          </span>
          <span className="font-medium text-emerald-400">+{floorBoostUSDC} USDC</span>
        </div>
      </div>

      {/* Action Button */}
      {isSuccess ? (
        <div className="bg-emerald-950/40 border border-emerald-500/40 rounded-xl p-4 text-center text-emerald-300 text-sm flex items-center justify-center gap-2">
          <CheckCircle2 className="w-5 h-5 text-emerald-400" />
          <span>Payment Successful! Received {cashbackHNY} $HNY</span>
        </div>
      ) : (
        <button
          onClick={handle1ClickPay}
          disabled={isProcessing}
          className="w-full py-3.5 px-4 rounded-xl bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-400 hover:to-amber-500 text-zinc-950 font-bold text-sm shadow-lg shadow-amber-500/20 transition-all flex items-center justify-center gap-2 disabled:opacity-50"
        >
          {isProcessing ? (
            <span className="inline-block w-4 h-4 border-2 border-zinc-950 border-t-transparent rounded-full animate-spin" />
          ) : (
            <>
              <span>Pay ${priceUSDC.toFixed(2)} with 1-Click</span>
              <ArrowRight className="w-4 h-4" />
            </>
          )}
        </button>
      )}
    </div>
  );
};
