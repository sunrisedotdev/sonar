import { PrePurchaseFailureReason, GeneratePurchasePermitResponse, EntityID } from "@echoxyz/sonar-core";
import { UseSonarPurchaseResultNotReadyToPurchase, UseSonarPurchaseResultReadyToPurchase, useSonarPurchase } from "@echoxyz/sonar-react";
import { useState } from "react";

export interface ChainAdapterResult {
  commitWithPermit: (params: { purchasePermitResp: GeneratePurchasePermitResponse; amount: bigint }) => Promise<void>;
  entityCurrentAmount: bigint | undefined;
  entityStateError: Error | null;
  pending: boolean;
  confirmed: boolean;
  txId: string | null;
  pendingError: Error | null;
  isWrongChain: boolean;
}

function readinessConfig(
  sonarPurchaser: UseSonarPurchaseResultReadyToPurchase | UseSonarPurchaseResultNotReadyToPurchase
) {
  const okConfig = (msg: string) => ({ fgCol: "text-green-800", bgCol: "bg-green-200", description: msg });
  const warningConfig = (msg: string) => ({ fgCol: "text-amber-500", bgCol: "bg-amber-50", description: msg });
  const errorConfig = (msg: string) => ({ fgCol: "text-red-500", bgCol: "bg-red-50", description: msg });

  if (sonarPurchaser.readyToPurchase) return okConfig("You are ready to commit funds");

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
  adapter,
  generatePurchasePermit,
}: {
  adapter: ChainAdapterResult;
  generatePurchasePermit: () => Promise<GeneratePurchasePermitResponse>;
}) {
  const { commitWithPermit, entityCurrentAmount, entityStateError, pending, confirmed, txId, pendingError, isWrongChain } = adapter;

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | undefined>(undefined);
  const [humanReadableAmount, setHumanReadableAmount] = useState<string>("1");

  const purchase = async () => {
    setLoading(true);
    setError(undefined);
    try {
      const purchasePermitResp = await generatePurchasePermit();
      const amount = BigInt(Math.floor(parseFloat(humanReadableAmount) * 1e6));
      await commitWithPermit({ purchasePermitResp, amount });
    } catch (err) {
      setError(err as Error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col gap-4 items-center">
      {isWrongChain && (
        <div className="bg-amber-50 border border-amber-300 rounded-md p-3 w-full text-center">
          <p className="text-amber-700 text-sm font-medium">
            Wrong network — clicking Commit will prompt your wallet to switch to Base Sepolia.
          </p>
        </div>
      )}
      <div className="flex flex-col gap-2">
        <div className="flex flex-col gap-1">
          <label htmlFor="commitAmount" className="text-sm text-gray-700">
            USDC to commit (replaces existing commitment)
          </label>
          <input
            id="commitAmount"
            type="number"
            min="0"
            value={humanReadableAmount}
            onChange={(e) => setHumanReadableAmount(e.target.value)}
            disabled={loading || pending}
            className="px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-gray-900"
            placeholder="Enter amount"
          />
        </div>
        <button
          disabled={loading || pending || !humanReadableAmount || parseFloat(humanReadableAmount) <= 0}
          className="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          onClick={purchase}
        >
          <p className="text-gray-100">{loading || pending ? "Loading..." : "Commit"}</p>
        </button>

        {pending && !confirmed && <p className="text-gray-900">Waiting for confirmation...</p>}
        {confirmed && txId && <p className="text-green-500">Commitment successful</p>}
        {error && <p className="text-red-500 wrap-anywhere">{error.message}</p>}
        {pendingError && <p className="text-red-500 wrap-anywhere">{pendingError.message}</p>}
        {entityStateError && <p className="text-red-500 wrap-anywhere">{entityStateError.message}</p>}
      </div>

      <div className="bg-white p-2 rounded-md w-fit">
        <p className="text-gray-900">
          Current committed amount:{" "}
          {entityCurrentAmount !== undefined ? `${Number(entityCurrentAmount) / 1e6} USDC` : "Loading..."}
        </p>
      </div>
    </div>
  );
}

export function CommitCard({
  entityID,
  walletAddress,
  saleUUID,
  adapter,
}: {
  entityID: EntityID;
  walletAddress: string;
  saleUUID: string;
  adapter: ChainAdapterResult;
}) {
  const sonarPurchaser = useSonarPurchase({
    saleUUID,
    entityID,
    walletAddress,
  });

  if (sonarPurchaser.loading) return <p>Loading...</p>;

  if ("error" in sonarPurchaser && sonarPurchaser.error) {
    return <p>Error: {sonarPurchaser.error.message}</p>;
  }

  const purchaser = sonarPurchaser as UseSonarPurchaseResultReadyToPurchase | UseSonarPurchaseResultNotReadyToPurchase;
  const readinessCfg = readinessConfig(purchaser);

  return (
    <div className="flex flex-col gap-4 p-4 bg-linear-to-r from-indigo-50 to-blue-50 rounded-lg border border-indigo-200">
      <div className={`${readinessCfg.bgCol} p-2 rounded-md w-full`}>
        <p className={`${readinessCfg.fgCol} w-full`}>{readinessCfg.description}</p>
      </div>

      {purchaser.readyToPurchase && (
        <CommitSection adapter={adapter} generatePurchasePermit={purchaser.generatePurchasePermit} />
      )}

      {!purchaser.readyToPurchase && purchaser.failureReason === PrePurchaseFailureReason.REQUIRES_LIVENESS && (
        <button
          className="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded-lg transition-colors w-fit"
          onClick={() => window.open(purchaser.livenessCheckURL, "_blank")}
        >
          <p className="text-gray-100">Complete liveness check to purchase</p>
        </button>
      )}
    </div>
  );
}

export default CommitCard;
