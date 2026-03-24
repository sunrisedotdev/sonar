"use client";

import { useState, useEffect, useCallback } from "react";
import { useSession } from "./use-session";
import { UnauthorizedError } from "@/lib/errors";

export type SonarQueryState<T> =
  | { loading: true; data: undefined; error: undefined }
  | { loading: false; data: T; error: undefined }
  | { loading: false; data: undefined; error: Error }
  | { loading: false; data: undefined; error: undefined }; // idle/skipped state

/**
 * Generic hook for Sonar server action queries with shared session/auth handling
 */
export function useSonarQuery<I, O>(action: (input: I) => Promise<O>, input: I): SonarQueryState<O> {
  const { authenticated, sonarConnected, refreshSession } = useSession();
  const [state, setState] = useState<SonarQueryState<O>>({
    loading: true,
    data: undefined,
    error: undefined,
  });

  // Serialize input for stable dependency comparison
  const serializedInput = JSON.stringify(input);

  const fetchData = useCallback(async () => {
    if (!authenticated || !sonarConnected) {
      setState({ loading: false, data: undefined, error: undefined });
      return;
    }

    setState({ loading: true, data: undefined, error: undefined });

    try {
      const data = await action(JSON.parse(serializedInput) as I);
      setState({ loading: false, data, error: undefined });
    } catch (err) {
      if (err instanceof UnauthorizedError) {
        await refreshSession();
        return;
      }
      setState({
        loading: false,
        data: undefined,
        error: err instanceof Error ? err : new Error(String(err)),
      });
    }
  }, [authenticated, sonarConnected, action, serializedInput, refreshSession]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  return state;
}
