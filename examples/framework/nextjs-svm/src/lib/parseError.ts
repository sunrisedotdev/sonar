import { messages } from "@/lib/messages";
import settlementSaleIdl from "@/app/idl/settlement_sale.json";

const { programErrors } = messages.contractErrors;

// Full code -> msg map from the IDL — fallback for any error not in programErrors.
const IDL_ERROR_MAP = new Map<number, string>(
  settlementSaleIdl.errors.map((e) => [e.code, e.msg])
);

// Derive code -> friendly message by matching IDL error names against programErrors.
const FRIENDLY_OVERRIDE_MAP = new Map<number, string>(
  settlementSaleIdl.errors
    .filter((e) => e.name in programErrors)
    .map((e) => [e.code, programErrors[e.name as keyof typeof programErrors]])
);

function extractAnchorErrorCode(err: unknown): number | null {
  const sources: string[] = [];

  if (err instanceof Error) sources.push(err.message);

  const logs = (err as Record<string, unknown>).logs;
  if (Array.isArray(logs)) {
    for (const log of logs) {
      if (typeof log === "string") sources.push(log);
    }
  }

  for (const source of sources) {
    const hexMatch = source.match(/custom program error: 0x([0-9a-fA-F]+)/);
    if (hexMatch) return parseInt(hexMatch[1], 16);

    const numMatch = source.match(/Error Number: (\d+)/);
    if (numMatch) return parseInt(numMatch[1]);
  }

  return null;
}

export function parsePermitError(err: unknown): string {
  if (!(err instanceof Error)) return messages.errors.permitFailed;
  if (/failed to fetch|network error|networkerror|econnrefused/i.test(err.message) || err.name === "TypeError") {
    return messages.errors.networkError;
  }
  return err.message || messages.errors.permitFailed;
}

export function parseSVMError(err: unknown): string {
  const message = err instanceof Error ? err.message : String(err);

  if (
    /user rejected|request declined|user denied|rejected by user|user disapproved/i.test(message) ||
    /transaction cancelled/i.test(message)
  ) {
    return messages.contractErrors.userRejected;
  }

  if (message === "Wallet not connected") {
    return messages.contractErrors.walletNotConnected;
  }

  if (
    err instanceof Error &&
    (err.name === "TransactionExpiredBlockheightExceededError" ||
      /blockhash.*expired|expired.*blockhash|block height exceeded/i.test(message))
  ) {
    return messages.contractErrors.transactionExpired;
  }

  if (/failed to fetch|network error|networkerror|econnrefused/i.test(message)) {
    return messages.errors.networkError;
  }

  const code = extractAnchorErrorCode(err);
  if (code !== null) {
    return FRIENDLY_OVERRIDE_MAP.get(code) ?? IDL_ERROR_MAP.get(code) ?? message;
  }

  return err instanceof Error ? err.message : messages.errors.unexpectedError;
}
