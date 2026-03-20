import { useCommitmentData } from "@echoxyz/sonar-react";
import { Commitment, WalletTokenAmount } from "@echoxyz/sonar-core";

function formatAmount(amount: bigint, decimals: number): string {
  const divisor = BigInt(10 ** decimals);
  const integerPart = amount / divisor;
  return `$${integerPart.toLocaleString()}`;
}

function calculateCommitmentTotal(amounts: WalletTokenAmount[]): bigint {
  return amounts.reduce((sum, item) => sum + BigInt(item.Amount), BigInt(0));
}

// The timestamp is a string in ISO 8601 format
function formatTimestamp(timestamp: string ): string {
  const date = new Date(timestamp);
  return date.toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

interface CommitmentRowProps {
  commitment: Commitment;
  decimals: number;
}

function CommitmentRow({ commitment, decimals }: CommitmentRowProps) {
  // The commitment data gives the amount by wallet and payment token,
  // but for simplicity, we just show the total amount and the wallet with the most committed amount.
  const total = calculateCommitmentTotal(commitment.Amounts);

  return (
    <div className="flex justify-between items-center py-2 border-b border-gray-100 last:border-b-0">
      <div className="flex flex-col gap-0.5">
        <span className="text-sm font-medium text-gray-900">
          {formatAmount(total, decimals)}
        </span>
        <span className="text-xs text-gray-500">{commitment.SaleSpecificEntityID}</span>
      </div>
      <span className="text-xs text-gray-400">{formatTimestamp(commitment.CreatedAt)}</span>
    </div>
  );
}

export function CommitmentDataCard({ saleUUID }: { saleUUID: string }) {
  // Note: this is using a public API (no authentication required),
  // so it doesn't matter whether we call this from the frontend or the backend.
  const { loading, commitmentData, error } = useCommitmentData({ saleUUID, pollingIntervalMs: 10000 });

  // Only show loading placeholder when there's no existing data to display
  if (loading && !commitmentData) {
    return (
      <div className="flex flex-col gap-4 p-4 bg-gray-50 rounded-lg border border-gray-200">
        <p className="text-gray-600">Loading commitment data...</p>
      </div>
    );
  }

  if (error && !commitmentData) {
    return (
      <div className="flex flex-col gap-4 p-4 bg-red-50 rounded-lg border border-red-200">
        <p className="text-red-800 font-medium">Error loading commitment data</p>
        <p className="text-red-700 text-sm">{error.message}</p>
      </div>
    );
  }

  if (!commitmentData) {
    return null;
  }

  // Commitments are sorted by CreatedAt in descending order, so we can just slice the first 20
  const recentCommitments = commitmentData.Commitments.slice(0, 20);

  return (
    <div className="flex flex-col gap-4 p-4 bg-linear-to-r from-indigo-50 to-blue-50 rounded-lg border border-indigo-200">
      {/* Summary Stats */}
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-white p-3 rounded-lg">
          <p className="text-sm text-gray-500">Total Committers</p>
          <p className="text-2xl font-bold text-gray-900">
            {commitmentData.UniqueCommitmentCount.toLocaleString()}
          </p>
        </div>
        <div className="bg-white p-3 rounded-lg">
          <p className="text-sm text-gray-500">Total Committed</p>
          <p className="text-2xl font-bold text-gray-900">
            {formatAmount(BigInt(commitmentData.TotalCommitmentAmount), commitmentData.PaymentTokenDecimals)}
          </p>
        </div>
      </div>

      {/* Recent Commitments */}
      {recentCommitments.length > 0 && (
        <div className="flex flex-col gap-2">
          <h4 className="text-sm font-medium text-gray-700">Recent Commitments</h4>
          <div className="bg-white rounded-lg p-3 max-h-80 overflow-y-auto">
            {recentCommitments.map((commitment) => (
              <CommitmentRow
                key={commitment.CommitmentID}
                commitment={commitment}
                decimals={commitmentData.PaymentTokenDecimals}
              />
            ))}
          </div>
        </div>
      )}

      {recentCommitments.length === 0 && (
        <div className="bg-white rounded-lg p-4 text-center">
          <p className="text-gray-500">No commitments yet</p>
        </div>
      )}
    </div>
  );
}
