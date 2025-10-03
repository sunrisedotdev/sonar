import {
    APIError,
    EntityDetails,
    EntityType,
    GeneratePurchasePermitResponse,
    PrePurchaseCheckResponse,
    SonarClient,
} from "@echoxyz/sonar-core";
import { useCallback, useContext, useEffect, useRef, useState } from "react";
import { AuthContext, ClientContext, AuthContextValue } from "./provider";

export function useSonarAuth(): AuthContextValue {
    const ctx = useContext(AuthContext);
    if (!ctx) {
        throw new Error("useSonarAuth must be used within a SonarProvider");
    }
    return ctx;
}

export function useSonarClient(): SonarClient {
    const ctx = useContext(ClientContext);
    if (!ctx) {
        throw new Error("useSonarClient must be used within a SonarProvider");
    }
    return ctx.client;
}

export type UseSonarEntityResult = {
    authenticated: boolean;
    loading: boolean;
    entity?: EntityDetails;
    error?: Error;
};

export function useSonarEntity(args: { saleUUID: string; walletAddress?: string }): UseSonarEntityResult {
    const { authenticated, ready } = useSonarAuth();
    const client = useSonarClient();

    if (!args.saleUUID) {
        throw new Error("saleUUID is required");
    }

    const saleUUID = args.saleUUID;
    const walletAddress = args.walletAddress;

    const [state, setState] = useState<{
        loading: boolean;
        entity?: EntityDetails;
        error?: Error;
        hasFetched: boolean;
    }>({
        loading: false,
        hasFetched: false,
    });

    const fullyConnected = ready && authenticated && Boolean(walletAddress);

    const refetch = useCallback(async () => {
        if (!walletAddress || !fullyConnected) {
            return;
        }
        setState((s) => ({ ...s, loading: true }));
        try {
            const resp = await client.readEntity({
                saleUUID,
                walletAddress,
            });
            setState({
                loading: false,
                entity: resp.Entity,
                error: undefined,
                hasFetched: true,
            });
        } catch (err) {
            if (err instanceof APIError && err.status === 404) {
                // Return undefined entity if it doesn't exist
                setState({
                    loading: false,
                    entity: undefined,
                    error: undefined,
                    hasFetched: true,
                });
                return;
            }
            const error = err instanceof Error ? err : new Error(String(err));
            setState({ loading: false, entity: undefined, error, hasFetched: true });
        }
    }, [client, saleUUID, walletAddress, fullyConnected]);

    const reset = useCallback(() => {
        setState({
            loading: false,
            hasFetched: false,
            entity: undefined,
            error: undefined,
        });
    }, []);

    useEffect(() => {
        if (fullyConnected) {
            if (!state.hasFetched && !state.loading) {
                refetch();
            }
        }
    }, [fullyConnected, state.hasFetched, state.loading, refetch]);

    useEffect(() => {
        if (ready && (!authenticated || !walletAddress)) {
            reset();
        }
    }, [ready, authenticated, walletAddress, reset]);

    return {
        authenticated,
        loading: state.loading,
        entity: state.entity,
        error: state.error,
    };
}

export type UseSonarPurchaseResult = {
    loading: boolean;
    prePurchaseCheckResponse?: PrePurchaseCheckResponse;
    generatePurchasePermit?: () => Promise<GeneratePurchasePermitResponse>;
    error?: Error;
};

export function useSonarPurchase(args: {
    saleUUID: string;
    entityUUID?: string;
    entityType?: EntityType;
    walletAddress?: string;
}): UseSonarPurchaseResult {
    const saleUUID = args.saleUUID;
    const entityUUID = args.entityUUID;
    const entityType = args.entityType;
    const walletAddress = args.walletAddress;

    const client = useSonarClient();

    const [state, setState] = useState<{
        loading: boolean;
        value?: PrePurchaseCheckResponse;
        error?: Error;
        hasFetched: boolean;
    }>({
        loading: false,
        hasFetched: false,
    });

    const prevParamsRef = useRef<{
        entityUUID?: string;
        entityType?: EntityType;
        walletAddress?: string;
    }>({ entityUUID, entityType, walletAddress });

    const refetch = useCallback(async () => {
        if (!entityType || !entityUUID || !walletAddress) {
            return;
        }

        setState((prev) => ({
            ...prev,
            loading: true,
            error: undefined,
        }));

        try {
            const response = await client.prePurchaseCheck({
                saleUUID,
                entityType,
                entityUUID,
                walletAddress,
            });
            setState({
                loading: false,
                value: response,
                hasFetched: true,
            });
        } catch (error) {
            setState({
                loading: false,
                error: error instanceof Error ? error : new Error(String(error)),
                hasFetched: true,
            });
        }
    }, [client, saleUUID, entityType, entityUUID, walletAddress]);

    const reset = useCallback(() => {
        setState({
            loading: false,
            value: undefined,
            error: undefined,
            hasFetched: false,
        });
    }, []);

    useEffect(() => {
        const prevParams = prevParamsRef.current;
        const currentParams = { entityUUID, entityType, walletAddress };
        
        // Check if parameters have changed OR if this is the initial fetch
        const paramsChanged = 
            prevParams.entityUUID !== currentParams.entityUUID ||
            prevParams.entityType !== currentParams.entityType ||
            prevParams.walletAddress !== currentParams.walletAddress;
        const isInitialFetch = !state.hasFetched && !state.loading;
        
        if ((paramsChanged || isInitialFetch) && entityUUID && entityType && walletAddress && !state.loading) {
            refetch();
        }
        
        // Update the ref with current parameters
        prevParamsRef.current = currentParams;
    }, [entityUUID, entityType, walletAddress, state.hasFetched, state.loading]);

    useEffect(() => {
        if (!entityUUID || !entityType || !walletAddress) {
            reset();
        }
    }, [entityUUID, entityType, walletAddress, reset]);

    const generatePurchasePermit =
        entityUUID && entityType && walletAddress && state.value?.ReadyToPurchase
            ? () => {
                  return client.generatePurchasePermit({
                      saleUUID,
                      entityUUID,
                      entityType,
                      walletAddress,
                  });
              }
            : undefined;

    return {
        loading: state.loading,
        error: state.error,
        prePurchaseCheckResponse: state.value,
        generatePurchasePermit,
    };
}
