import { useState } from "react";
import { useSaleContract } from "../../hooks/use-sale-contract";

const CANCELLATION_STAGE = 2;

function CancelSection({ saleSpecificEntityID }: { saleSpecificEntityID: string }) {
  const { cancelBid, contractStage, committedAmount, entityStateError, awaitingTxReceipt } =
    useSaleContract(saleSpecificEntityID);

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | undefined>(undefined);
  const [cancelSuccess, setCancelSuccess] = useState(false);

  const isCancellationStage = contractStage === CANCELLATION_STAGE;
  const hasCommitment = committedAmount !== undefined && committedAmount > 0n;

  const cancel = async () => {
    setLoading(true);
    setError(undefined);
    try {
      await cancelBid();
      setCancelSuccess(true);
    } catch (err) {
      setError(err as Error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col gap-4 items-center">
      {entityStateError ? (
        <div className="bg-white p-2 rounded-md w-full">
          <p className="text-red-500 wrap-anywhere">{entityStateError.message}</p>
        </div>
      ) : hasCommitment ? (
        <>
          <div className="bg-white p-2 rounded-md w-full">
            <p className="text-gray-900">Current committed amount: {`${Number(committedAmount) / 1e6} USDC`}</p>
          </div>

          {!isCancellationStage && (
            <div className="bg-amber-50 border border-amber-200 p-3 rounded-md w-full">
              <p className="text-amber-800 text-sm font-medium">Contract not in Cancellation stage</p>
              <p className="text-amber-700 text-sm mt-1">
                The &quot;Cancel Bid&quot; button is only active when the contract is in the Cancellation stage. To test
                this feature, use the founder&apos;s dashboard to open the cancellation state (
                <code className="font-mono bg-amber-100 px-1 rounded">openCancellation</code>). See the{" "}
                <a
                  href="https://docs.echo.xyz/sonar/reference/contracts/settlement-sale"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="underline"
                >
                  contract docs
                </a>
                .
              </p>
            </div>
          )}

          <button
            disabled={loading || awaitingTxReceipt || !isCancellationStage}
            className="bg-gray-700 hover:bg-gray-800 text-white font-medium py-2 px-6 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed w-full"
            onClick={cancel}
          >
            <p className="text-gray-100">{loading || awaitingTxReceipt ? "Loading..." : "Cancel Bid"}</p>
          </button>
        </>
      ) : committedAmount !== undefined ? (
        <div className="bg-gray-50 border border-gray-200 p-3 rounded-md w-full">
          <p className="text-gray-600 text-sm">No active commitment to cancel.</p>
        </div>
      ) : (
        <div className="bg-white p-2 rounded-md w-full">
          <p className="text-gray-500 text-sm">Loading...</p>
        </div>
      )}

      {awaitingTxReceipt && <p className="text-gray-900">Waiting for transaction confirmation...</p>}
      {cancelSuccess && <p className="text-green-500">Cancellation successful — your funds have been refunded</p>}
      {error && <p className="text-red-500 wrap-anywhere">{error.message}</p>}
    </div>
  );
}

function CancelCard({ saleSpecificEntityID }: { saleSpecificEntityID: string }) {
  return (
    <div className="flex flex-col gap-4 p-4 bg-linear-to-r from-indigo-50 to-blue-50 rounded-lg border border-indigo-200">
      <CancelSection saleSpecificEntityID={saleSpecificEntityID} />
    </div>
  );
}

export default CancelCard;
