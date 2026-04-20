"use client";

import { ListAvailableEntitiesResponse } from "@echoxyz/sonar-core";
import { saleUUID } from "@/lib/config";
import { useSonarQuery } from "./use-sonar-query";
import { getEntities } from "@/app/actions/sonar";

/**
 * Hook to fetch all Sonar entities for the authenticated user
 */
export function useSonarEntities() {
  const { loading, data, error } = useSonarQuery<{ saleUUID: string }, ListAvailableEntitiesResponse>(getEntities, {
    saleUUID,
  });

  return {
    loading,
    entities: data?.Entities,
    error,
  };
}
