"use client";

import {
  EntityID,
  GeneratePurchasePermitResponse,
  PrePurchaseCheckResponse,
  PrePurchaseFailureReason,
} from "@echoxyz/sonar-core";
import { UseSonarPurchaseResult } from "@echoxyz/sonar-react";
import { useSession } from "./use-session";
import { useCallback } from "react";
import { useSonarQuery } from "./use-sonar-query";
import { prePurchaseCheck, generatePurchasePermit as generatePurchasePermitAction } from "@/app/actions/sonar";

/**
 * Hook for Sonar purchase flow
 */
export function useSonarPurchase(args: {
  saleUUID: string;
  entityID: EntityID;
  walletAddress: string;
}): UseSonarPurchaseResult {
  const { authenticated } = useSession();

  const { loading, data, error } = useSonarQuery<
    { saleUUID: string; entityID: string; walletAddress: string },
    PrePurchaseCheckResponse
  >(prePurchaseCheck, {
    saleUUID: args.saleUUID,
    entityID: args.entityID,
    walletAddress: args.walletAddress,
  });

  const generatePurchasePermit = useCallback(async (): Promise<GeneratePurchasePermitResponse> => {
    if (!authenticated) {
      throw new Error("Not authenticated");
    }

    return generatePurchasePermitAction({
      saleUUID: args.saleUUID,
      entityID: args.entityID,
      walletAddress: args.walletAddress,
    });
  }, [authenticated, args.saleUUID, args.entityID, args.walletAddress]);

  if (loading) {
    return { loading: true, readyToPurchase: false, error: undefined };
  }

  if (error || !data) {
    return { loading: false, readyToPurchase: false, error: error ?? new Error("No data") };
  }

  if (data.ReadyToPurchase) {
    return { loading: false, readyToPurchase: true, error: undefined, generatePurchasePermit };
  }

  return {
    loading: false,
    readyToPurchase: false,
    error: undefined,
    failureReason: data.FailureReason as PrePurchaseFailureReason,
    livenessCheckURL: data.LivenessCheckURL,
  };
}
