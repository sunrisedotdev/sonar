"use server";

import { createSonarServerAction } from "@/lib/sonar";
import {
  ListAvailableEntitiesResponse,
  PrePurchaseCheckResponse,
  GeneratePurchasePermitResponse,
} from "@echoxyz/sonar-core";

type ListAvailableEntitiesInput = { saleUUID: string };

/**
 * Fetch all entities for the authenticated user
 */
export const getEntities = createSonarServerAction<ListAvailableEntitiesInput, ListAvailableEntitiesResponse>(
  async (client, { saleUUID }) => {
    if (!saleUUID) {
      throw new Error("Missing saleUUID");
    }
    return client.listAvailableEntities({ saleUUID });
  }
);

type PrePurchaseCheckInput = { saleUUID: string; entityID: string; walletAddress: string };

/**
 * Perform pre-purchase check for an entity
 */
export const prePurchaseCheck = createSonarServerAction<PrePurchaseCheckInput, PrePurchaseCheckResponse>(
  async (client, { saleUUID, entityID, walletAddress }) => {
    if (!saleUUID || !entityID || !walletAddress) {
      throw new Error("Missing required parameters");
    }
    return client.prePurchaseCheck({ saleUUID, entityID, walletAddress });
  }
);

type GeneratePurchasePermitInput = { saleUUID: string; entityID: string; walletAddress: string };

/**
 * Generate a purchase permit for an entity
 */
export const generatePurchasePermit = createSonarServerAction<
  GeneratePurchasePermitInput,
  GeneratePurchasePermitResponse
>(async (client, { saleUUID, entityID, walletAddress }) => {
  if (!saleUUID || !entityID || !walletAddress) {
    throw new Error("Missing required parameters");
  }
  return client.generatePurchasePermit({ saleUUID, entityID, walletAddress });
});
