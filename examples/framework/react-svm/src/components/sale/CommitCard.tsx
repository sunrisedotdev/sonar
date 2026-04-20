import { PrePurchaseFailureReason, GeneratePurchasePermitResponse, EntityID } from "@echoxyz/sonar-core";
import { useState, useEffect } from "react";
import { saleUUID } from "../../config";
import {
  useSonarPurchase,
  UseSonarPurchaseResultNotReadyToPurchase,
  UseSonarPurchaseResultReadyToPurchase,
} from "@echoxyz/sonar-react";
import { useSaleContract } from "../../hooks/use-sale-contract";

function readinessConfig(
  sonarPurchaser: UseSonarPurchaseResultReadyToPurchase | UseSonarPurchaseResultNotReadyToPurchase
) {
  const okConfig = (msg: string) => ({
    fgCol: "text-green-800",
    bgCol: "bg-green-200",
    description: msg,
  });

  const warningConfig = (msg: string) => ({
    fgCol: "text-amber-500",
    bgCol: "bg-amber-50",
    description: msg,
  });

  const errorConfig = (msg: string) => ({
    fgCol: "text-red-500",
    bgCol: "bg-red-50",
    description: msg,
  });

  if (sonarPurchaser.readyToPurchase) {
    return okConfig("You are ready to commit funds");
  }

  switch (sonarPurchaser.failureReason) {
    case PrePurchaseFailureReason.REQUIRES_LIVENESS:
      return okConfig("Complete a liveness check in order to commit funds.");
    case PrePurchaseFailureReason.WALLET_RISK:
      return warningConfig("The connected wallet is not eligible for this sale. Connect a different wallet.");
    case PrePurchaseFailureReason.MAX_WALLETS_USED:
      return warningConfig(
        "Maximum number of wallets reached — This entity can't use the connected wallet. Use a previous wallet."
      );
    case PrePurchaseFailureReason.WALLET_NOT_LINKED:
      return warningConfig(
        "Wallet not linked — The connected wallet is not linked to your entity. Please link it first."
      );
    case PrePurchaseFailureReason.SALE_NOT_ACTIVE:
      return errorConfig("The sale is not currently active.");
    default:
      return errorConfig("An unknown error occurred — Please try again or contact support.");
  }
}

function CommitSection({
  saleSpecificEntityID,
  generatePurchasePermit,
}: {
  saleSpecificEntityID: string;
  generatePurchasePermit: () => Promise<GeneratePurchasePermitResponse>;
}) {
  const {
    commitWithPermit,
    currentTotalRaw,
    currentTotalHumanReadableStr,
    entityStateError,
    awaitingTxReceipt,
    confirmed,
  } = useSaleContract(saleSpecificEntityID);

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | undefined>(undefined);
  const [humanReadableIncrementAmount, setHumanReadableIncrementAmount] = useState<string>("1");

  const parsedIncrementAmount = parseFloat(humanReadableIncrementAmount);
  const isIncrementAmountValid = humanReadableIncrementAmount !== "" && !isNaN(parsedIncrementAmount) && parsedIncrementAmount > 0;
  const incrementRaw = isIncrementAmountValid ? BigInt(Math.floor(parsedIncrementAmount * 1e6)) : 0n;
  const newTotalRaw = currentTotalRaw + incrementRaw;
  const newTotalFormatted = (Number(newTotalRaw) / 1e6).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

  const isFirstCommit = currentTotalRaw === 0n;

  const [showInput, setShowInput] = useState(true);

  useEffect(() => {
    if (confirmed) {
      setShowInput(false);
    }
  }, [confirmed]);

  const purchase = async () => {
    setLoading(true);
    setError(undefined);
    try {
      const purchasePermitResp = await generatePurchasePermit();
      const increment = BigInt(Math.floor(parseFloat(humanReadableIncrementAmount) * 1e6));
      // Note: The current commitment raw could be stale if there is a concurrent commitment from this entity.
      const newTotal = currentTotalRaw + increment;
      await commitWithPermit({
        purchasePermitResp,
        commitmentAmount: newTotal,
        commitmentAmountIncrement: increment,
      });
    } catch (err) {
      setError(err as Error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col gap-4 items-center">
      <div className="flex flex-col gap-2">
        {!isFirstCommit && (
          <p className="text-sm text-gray-600">
            Current commitment:{" "}
            <span className="font-semibold text-gray-900">{currentTotalHumanReadableStr} USDC</span>
          </p>
        )}
        {showInput ? (
          <>
            <div className="flex flex-col gap-1">
              <label htmlFor="commitAmount" className="text-sm text-gray-700">
                {isFirstCommit ? "USDC to commit" : "Additional USDC to commit"}
              </label>
              <input
                id="commitAmount"
                type="number"
                min="0"
                value={humanReadableIncrementAmount}
                onChange={(e) => setHumanReadableIncrementAmount(e.target.value)}
                disabled={loading || awaitingTxReceipt}
                className="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-gray-900"
                placeholder="Enter amount"
              />
              {!isFirstCommit && isIncrementAmountValid && (
                <p className="text-sm text-gray-500">
                  New total: <span className="font-semibold text-gray-700">{newTotalFormatted} USDC</span>
                </p>
              )}
            </div>
            <button
              disabled={loading || awaitingTxReceipt || !isIncrementAmountValid}
              className="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              onClick={purchase}
            >
              <p className="text-gray-100">{loading || awaitingTxReceipt ? "Loading..." : "Commit"}</p>
            </button>
            {awaitingTxReceipt && !confirmed && <p className="text-gray-900">Waiting for confirmation...</p>}
            {error && <p className="text-red-500 wrap-anywhere">{error.message}</p>}
            {entityStateError && <p className="text-red-500 wrap-anywhere">{entityStateError.message}</p>}
          </>
        ) : (
          <button
            className="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded-lg transition-colors w-fit"
            onClick={() => {
              setHumanReadableIncrementAmount("1");
              setShowInput(true);
            }}
          >
            <p className="text-gray-100">Commit more</p>
          </button>
        )}
      </div>
    </div>
  );
}

function CommitCard({
  entityID,
  saleSpecificEntityID,
  walletAddress,
}: {
  entityID: EntityID;
  saleSpecificEntityID: string;
  walletAddress: string;
}) {
  const sonarPurchaser = useSonarPurchase({
    saleUUID,
    entityID,
    walletAddress,
  });

  if (sonarPurchaser.loading) {
    return <p>Loading...</p>;
  }

  if (sonarPurchaser.error) {
    return <p>Error: {sonarPurchaser.error.message}</p>;
  }

  const readinessCfg = readinessConfig(sonarPurchaser);

  return (
    <div className="flex flex-col gap-4 p-4 bg-linear-to-r from-indigo-50 to-blue-50 rounded-lg border border-indigo-200">
      <div className={`${readinessCfg.bgCol} p-2 rounded-md w-full`}>
        <p className={`${readinessCfg.fgCol} w-full`}>{readinessCfg.description}</p>
      </div>

      {sonarPurchaser.readyToPurchase && (
        <CommitSection
          saleSpecificEntityID={saleSpecificEntityID}
          generatePurchasePermit={sonarPurchaser.generatePurchasePermit}
        />
      )}

      {!sonarPurchaser.readyToPurchase &&
        sonarPurchaser.failureReason === PrePurchaseFailureReason.REQUIRES_LIVENESS && (
          <button
            className="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded-lg transition-colors w-fit"
            onClick={() => {
              window.open(sonarPurchaser.livenessCheckURL, "_blank");
            }}
          >
            <p className="text-gray-100">Complete liveness check to purchase</p>
          </button>
        )}
    </div>
  );
}

export default CommitCard;
