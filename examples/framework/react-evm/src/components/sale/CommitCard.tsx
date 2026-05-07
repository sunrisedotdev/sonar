import { PrePurchaseFailureReason, GeneratePurchasePermitResponse, EntityID, Hex } from "@echoxyz/sonar-core";
import { useState, useEffect, useCallback } from "react";
import { paymentTokenAddress, saleUUID } from "../../config";
import { messages } from "../../messages";
import {
  useSonarPurchase,
  UseSonarPurchaseResultNotReadyToPurchase,
  UseSonarPurchaseResultReadyToPurchase,
} from "@echoxyz/sonar-react";
import { useSaleContract } from "../../hooks";
import { ErrorToast } from "../ui/Toast";
import { parseEVMError, parsePermitError } from "../../utils/parseError";

const COMMITMENT_STAGE = 1;

function readinessConfig(
  sonarPurchaser: UseSonarPurchaseResultReadyToPurchase | UseSonarPurchaseResultNotReadyToPurchase,
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
    return okConfig(messages.purchaseReadiness.ready);
  }

  switch (sonarPurchaser.failureReason) {
    case PrePurchaseFailureReason.REQUIRES_LIVENESS:
      return okConfig(messages.purchaseReadiness.requiresLiveness);
    case PrePurchaseFailureReason.WALLET_RISK:
      return warningConfig(messages.purchaseReadiness.walletRisk);
    case PrePurchaseFailureReason.MAX_WALLETS_USED:
      return warningConfig(messages.purchaseReadiness.maxWalletsUsed);
    case PrePurchaseFailureReason.WALLET_NOT_LINKED:
      return warningConfig(messages.purchaseReadiness.walletNotLinked);
    case PrePurchaseFailureReason.SALE_NOT_ACTIVE:
      return errorConfig(messages.purchaseReadiness.saleNotActive);
    case PrePurchaseFailureReason.OUTSIDE_TIME_WINDOW:
      return errorConfig(messages.purchaseReadiness.outsideTimeWindow);
    default:
      return errorConfig(messages.purchaseReadiness.unknown);
  }
}

function CommitSection({
  saleSpecificEntityID,
  generatePurchasePermit,
}: {
  saleSpecificEntityID: Hex;
  generatePurchasePermit: () => Promise<GeneratePurchasePermitResponse>;
}) {
  const {
    commitWithPermit,
    isEntityStateLoaded,
    currentTotalRaw,
    currentTotalReadableStr,
    entityStateError,
    awaitingTxReceipt,
    txReceipt,
    awaitingTxReceiptError,
    isWrongChain,
    usdcBalance,
    contractStage,
  } = useSaleContract(saleSpecificEntityID);

  const [loading, setLoading] = useState<"idle" | "permit" | "submitting">("idle");
  const [toastError, setToastError] = useState<string | undefined>(undefined);
  const [incrementReadableStr, setIncrementReadableStr] = useState<string>("1");

  const dismissToast = useCallback(() => setToastError(undefined), []);

  const incrementReadable = parseFloat(incrementReadableStr);
  const isIncrementAmountValid = incrementReadableStr !== "" && !isNaN(incrementReadable) && incrementReadable > 0;
  const incrementRaw = isIncrementAmountValid ? BigInt(Math.floor(incrementReadable * 1e6)) : 0n;
  const newTotalRaw = currentTotalRaw + incrementRaw;
  const newTotalReadableStr = (Number(newTotalRaw) / 1e6).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

  const hasExistingCommitment = isEntityStateLoaded && currentTotalRaw > 0n;
  const hasInsufficientBalance = usdcBalance != null && isIncrementAmountValid && incrementRaw > usdcBalance;
  const notInCommitmentStage = contractStage !== undefined && contractStage !== COMMITMENT_STAGE;

  const [showInput, setShowInput] = useState(true);

  useEffect(() => {
    if (txReceipt?.status === "success") {
      setShowInput(false);
    }
  }, [txReceipt]);

  useEffect(() => {
    if (txReceipt?.status === "reverted") {
      setToastError(messages.errors.txReverted);
    }
  }, [txReceipt]);

  useEffect(() => {
    if (awaitingTxReceiptError) {
      setToastError(messages.contractErrors.awaitingReceiptFailed);
    }
  }, [awaitingTxReceiptError]);

  const purchase = async () => {
    setLoading("permit");
    setToastError(undefined);
    let purchasePermitResp: GeneratePurchasePermitResponse;
    try {
      purchasePermitResp = await generatePurchasePermit();
    } catch (err) {
      setToastError(parsePermitError(err));
      setLoading("idle");
      return;
    }
    setLoading("submitting");
    try {
      // Note: The current commitment raw could be stale if there is a concurrent commitment from this entity.
      await commitWithPermit({
        purchasePermitResp,
        token: paymentTokenAddress,
        newTotalRaw,
        incrementRaw,
      });
    } catch (err) {
      setToastError(parseEVMError(err));
    } finally {
      setLoading("idle");
    }
  };

  return (
    <div className="flex flex-col gap-4 items-center">
      {toastError && <ErrorToast message={toastError} onDismiss={dismissToast} />}
      {isWrongChain && (
        <div className="bg-amber-50 border border-amber-300 rounded-md p-3 w-full text-center">
          <p className="text-amber-700 text-sm font-medium">{messages.commitSection.wrongNetwork}</p>
        </div>
      )}
      {entityStateError && (
        <div className="bg-red-50 border border-red-300 rounded-md p-3 w-full">
          <p className="text-red-800 text-sm font-semibold">{messages.errors.dataLoadFailed}</p>
          <p className="text-red-700 text-sm mt-1">{messages.errors.contactSupport}</p>
        </div>
      )}
      <div className="flex flex-col gap-2">
        {hasExistingCommitment && (
          <p className="text-sm text-gray-600">
            Current commitment: <span className="font-semibold text-gray-900">{currentTotalReadableStr} USDC</span>
          </p>
        )}
        {notInCommitmentStage && (
          <div className="bg-amber-50 border border-amber-200 p-3 rounded-md w-full">
            <p className="text-amber-800 text-sm font-medium">Contract not in Commitment stage</p>
            <p className="text-amber-700 text-sm mt-1">
              The Commit button is only active during the Commitment stage. Use the founder&apos;s dashboard to open the
              commitment period (<code className="font-mono bg-amber-100 px-1 rounded">openCommitment</code>). See the{" "}
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
        {showInput ? (
          <>
            <div className="flex flex-col gap-1">
              <label htmlFor="commitAmount" className="text-sm text-gray-700">
                {hasExistingCommitment
                  ? "Additional USDC to commit"
                  : "USDC to commit"}
              </label>
              <input
                id="commitAmount"
                type="number"
                min="0"
                value={incrementReadableStr}
                onChange={(e) => setIncrementReadableStr(e.target.value)}
                disabled={loading !== "idle" || awaitingTxReceipt}
                className="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-gray-900"
                placeholder="Enter amount"
              />
              {hasExistingCommitment && isIncrementAmountValid && (
                <p className="text-sm text-gray-500">
                  New total:{" "}
                  <span className="font-semibold text-gray-700">{newTotalReadableStr} USDC</span>
                </p>
              )}
            </div>
            <button
              disabled={loading !== "idle" || awaitingTxReceipt || !isIncrementAmountValid || hasInsufficientBalance || isWrongChain || notInCommitmentStage}
              className="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              onClick={purchase}
            >
              <p className="text-gray-100">
                {loading === "permit"
                  ? "Generating permit..."
                  : loading === "submitting"
                  ? "Submitting..."
                  : awaitingTxReceipt
                  ? "Loading..."
                  : "Commit"}
              </p>
            </button>
            {hasInsufficientBalance && <p className="text-red-500">{messages.commitSection.insufficientBalance}</p>}
            {awaitingTxReceipt && !txReceipt && (
              <p className="text-gray-900">{messages.commitSection.awaitingReceipt}</p>
            )}
          </>
        ) : (
          <button
            className="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded-lg transition-colors w-fit"
            onClick={() => {
              setIncrementReadableStr("1");
              setToastError(undefined);
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
  saleSpecificEntityID: Hex;
  walletAddress: `0x${string}`;
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
    return (
      <div className="bg-red-50 border border-red-300 rounded-lg p-4">
        <p className="text-red-800 font-semibold">{messages.errors.purchaseInfoFailed}</p>
        <p className="text-red-700 text-sm mt-1">{messages.errors.contactSupport}</p>
      </div>
    );
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
