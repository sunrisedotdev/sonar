import {
    APIError,
    EntityDetails,
    GeneratePurchasePermitResponse,
    PrePurchaseCheckResponse,
    SonarClient,
} from "@echoxyz/sonar-core";
import { useCallback, useContext, useEffect, useState } from "react";
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
    walletAddress?: string;
}): UseSonarPurchaseResult {
    const saleUUID = args.saleUUID;
    const entityUUID = args.entityUUID;
    const walletAddress = args.walletAddress;

    const client = useSonarClient();

    const [state, setState] = useState<{
        loading: boolean;
        value?: PrePurchaseCheckResponse;
        walletAddress?: string; // To track the wallet address of the fetched entity (rather than the wallet address that was passed in)
        error?: Error;
        hasFetched: boolean;
    }>({
        loading: false,
        hasFetched: false,
    });

    const refetch = useCallback(async () => {
        if (!entityUUID || !walletAddress) {
            return;
        }

        setState((s) => ({
            ...s,
            loading: true,
        }));

        try {
            const response = await client.prePurchaseCheck({
                saleUUID,
                entityUUID,
                walletAddress,
            });
            setState({
                loading: false,
                value: response,
                walletAddress: walletAddress,
                error: undefined,
                hasFetched: true,
            });
        } catch (err) {
            const error = err instanceof Error ? err : new Error(String(err));
            setState({
                loading: false,
                value: undefined,
                walletAddress: undefined,
                error: error,
                hasFetched: true,
            });
        }
    }, [client, saleUUID, entityUUID, walletAddress]);

    const reset = useCallback(() => {
        setState({
            loading: false,
            value: undefined,
            walletAddress: undefined,
            error: undefined,
            hasFetched: false,
        });
    }, []);

    useEffect(() => {
        if (!entityUUID || !walletAddress || state.walletAddress !== walletAddress) {
            reset();
        }
    }, [entityUUID, walletAddress, state.walletAddress, reset]);

    useEffect(() => {
        if (entityUUID && walletAddress && !state.loading) {
            refetch();
        }
    }, [entityUUID, walletAddress, refetch]);

    const generatePurchasePermit = useCallback(() => {
        if (!entityUUID || !walletAddress) {
            // Should never happen because this callback is returned as undefined if the pre-purchase check has not run
            throw new Error("entityUUID and walletAddress are required");
        }
        return client.generatePurchasePermit({
            saleUUID,
            entityUUID,
            walletAddress,
        });
    }, [client, saleUUID, entityUUID, walletAddress]);

    return {
        loading: state.loading,
        error: state.error,
        prePurchaseCheckResponse: state.value,
        generatePurchasePermit: state.value?.ReadyToPurchase ? generatePurchasePermit : undefined,
    };
}
