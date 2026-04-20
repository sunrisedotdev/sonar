"use client";

import { Hex } from "@echoxyz/sonar-core";
import { useState } from "react";
import { useSaleContract } from "../../hooks/use-sale-contract";

const CANCELLATION_STAGE = 2;

function CancelSection({ saleSpecificEntityID }: { saleSpecificEntityID: Hex }) {
  const { cancelBid, contractStage, entityState, entityStateError, awaitingTxReceipt, txReceipt, awaitingTxReceiptError } =
    useSaleContract(saleSpecificEntityID);

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | undefined>(undefined);

  const isCancellationStage = contractStage === CANCELLATION_STAGE;

  const cancel = async () => {
    setLoading(true);
    setError(undefined);
    try {
      await cancelBid();
    } catch (err) {
      setError(err as Error);
    } finally {
      setLoading(false);
    }
  };

  const committedAmount = entityState?.currentBid?.amount;
  const hasCommitment = committedAmount !== undefined && committedAmount > BigInt(0);

  return (
    <div className="flex flex-col gap-4 items-center">
      <div className="bg-white p-2 rounded-md w-full">
        {entityStateError ? (
          <p className="text-red-500 wrap-anywhere">{entityStateError.message}</p>
        ) : (
          <p className="text-gray-900">
            Current committed amount:{" "}
            {committedAmount !== undefined ? `${Number(committedAmount) / 1e6} USDC` : "Loading..."}
          </p>
        )}
      </div>

      {committedAmount !== undefined && !hasCommitment ? (
        <div className="bg-gray-50 border border-gray-200 p-3 rounded-md w-full">
          <p className="text-gray-600 text-sm">No active commitment to cancel.</p>
        </div>
      ) : (
        <>
          {!isCancellationStage && (
            <div className="bg-amber-50 border border-amber-200 p-3 rounded-md w-full">
              <p className="text-amber-800 text-sm font-medium">Contract not in Cancellation stage</p>
              <p className="text-amber-700 text-sm mt-1">
                The &quot;Cancel Bid&quot; button is only active when the contract is in the Cancellation stage (stage
                2). To test this feature, deploy your own contract and call{" "}
                <code className="font-mono bg-amber-100 px-1 rounded">unsafeSetStage(2)</code> to move it to the
                Cancellation state.
              </p>
            </div>
          )}

          <button
            disabled={loading || awaitingTxReceipt || !isCancellationStage}
            className="bg-red-600 hover:bg-red-700 text-white font-medium py-2 px-6 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed w-full"
            onClick={cancel}
          >
            <p className="text-gray-100">{loading || awaitingTxReceipt ? "Loading..." : "Cancel Bid"}</p>
          </button>
        </>
      )}

      {awaitingTxReceipt && !txReceipt && <p className="text-gray-900">Waiting for transaction receipt...</p>}
      {txReceipt?.status === "success" && (
        <p className="text-green-500">Cancellation successful — your funds have been refunded</p>
      )}
      {txReceipt?.status === "reverted" && <p className="text-red-500">Cancellation reverted</p>}
      {error && <p className="text-red-500 wrap-anywhere">{error.message}</p>}
      {awaitingTxReceiptError && <p className="text-red-500 wrap-anywhere">{awaitingTxReceiptError.message}</p>}
    </div>
  );
}

function CancelCard({ saleSpecificEntityID }: { saleSpecificEntityID: Hex }) {
  return (
    <div className="flex flex-col gap-4 p-4 bg-linear-to-r from-red-50 to-orange-50 rounded-lg border border-red-200">
      <CancelSection saleSpecificEntityID={saleSpecificEntityID} />
    </div>
  );
}

export default CancelCard;
