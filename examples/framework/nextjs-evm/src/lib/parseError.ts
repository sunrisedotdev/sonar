import { messages } from "@/lib/messages";

const abiErrors = messages.contractErrors.abiErrors;

function unwrapCause(err: unknown): unknown[] {
  const chain: unknown[] = [err];
  let current = err;
  while (current instanceof Error && (current as { cause?: unknown }).cause) {
    current = (current as { cause: unknown }).cause;
    chain.push(current);
  }
  return chain;
}

export function parsePermitError(err: unknown): string {
  if (!(err instanceof Error)) return messages.errors.permitFailed;
  if (/failed to fetch|network error|networkerror|econnrefused/i.test(err.message) || err.name === "TypeError") {
    return messages.errors.networkError;
  }
  return err.message || messages.errors.permitFailed;
}

export function parseEVMError(err: unknown): string {
  for (const e of unwrapCause(err)) {
    if (!(e instanceof Error)) continue;

    if (
      e.name === "UserRejectedRequestError" ||
      /user rejected|request declined|user denied|rejected by user/i.test(e.message)
    ) {
      return messages.contractErrors.userRejected;
    }

    if (e.name === "ContractFunctionRevertedError") {
      const errorName = (e as unknown as { data?: { errorName?: string } }).data?.errorName;
      if (errorName && errorName in abiErrors) {
        return abiErrors[errorName as keyof typeof abiErrors];
      }
      return `${messages.errors.unexpectedError} ${messages.errors.contactSupport}`;
    }

    if (/failed to fetch|network error|networkerror|econnrefused/i.test(e.message) || e.name === "TypeError") {
      return messages.errors.networkError;
    }
  }

  return err instanceof Error ? err.message : messages.errors.unexpectedError;
}
