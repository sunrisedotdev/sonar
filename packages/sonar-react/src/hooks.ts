import { APIError, EntityDetails, SonarClient } from "@echoxyz/sonar-core";
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

export type WalletConnection = {
    address?: string;
    isConnected: boolean;
};

export type UseSonarEntityResult = {
    authenticated: boolean;
    loading: boolean;
    entity?: EntityDetails;
    error?: Error;
};

export function useSonarEntity(args: { saleUUID: string; wallet: WalletConnection }): UseSonarEntityResult {
    const { authenticated, ready } = useSonarAuth();
    const client = useSonarClient();

    if (!args.saleUUID) {
        throw new Error("saleUUID is required");
    }

    const saleUUID = args.saleUUID;
    const activeWallet = args.wallet.address;
    const walletConnected = args.wallet.isConnected;

    const [state, setState] = useState<{
        loading: boolean;
        entity?: EntityDetails;
        error?: Error;
        hasFetched: boolean;
    }>({
        loading: false,
        hasFetched: false,
    });

    const fullyConnected = ready && authenticated && Boolean(activeWallet) && walletConnected;

    const refetch = useCallback(async () => {
        if (!saleUUID || !activeWallet || !fullyConnected) {
            return;
        }
        setState((s) => ({ ...s, loading: true }));
        try {
            const resp = await client.readEntity({
                saleUUID,
                walletAddress: activeWallet,
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
    }, [client, saleUUID, activeWallet, fullyConnected]);

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
        if (ready && (!authenticated || !walletConnected || !activeWallet)) {
            reset();
        }
    }, [ready, authenticated, walletConnected, activeWallet, reset]);

    return {
        authenticated,
        loading: state.loading,
        entity: state.entity,
        error: state.error,
    };
}
