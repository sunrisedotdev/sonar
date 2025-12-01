import {
    APIError,
    EntityDetails,
    EntityID,
    GeneratePurchasePermitResponse,
    PrePurchaseFailureReason,
    SonarClient,
} from "@echoxyz/sonar-core";
import { useCallback, useContext, useEffect, useState } from "react";
import { AuthContext, AuthContextValue, ClientContext } from "./provider";

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
        walletAddress?: string; // To track the wallet address of the fetched entity (rather than the wallet address that was passed in)
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
                walletAddress: walletAddress,
                error: undefined,
                hasFetched: true,
            });
        } catch (err) {
            if (err instanceof APIError && err.status === 404) {
                // Return undefined entity if it doesn't exist
                setState({
                    loading: false,
                    entity: undefined,
                    walletAddress: undefined,
                    error: undefined,
                    hasFetched: true,
                });
                return;
            }
            const error = err instanceof Error ? err : new Error(String(err));
            setState({ loading: false, entity: undefined, walletAddress: undefined, error, hasFetched: true });
        }
    }, [client, saleUUID, walletAddress, fullyConnected]);

    const reset = useCallback(() => {
        setState({
            loading: false,
            hasFetched: false,
            entity: undefined,
            walletAddress: undefined,
            error: undefined,
        });
    }, []);

    useEffect(() => {
        if (fullyConnected && state.walletAddress !== walletAddress) {
            refetch();
        }
    }, [fullyConnected, state.walletAddress, walletAddress, refetch]);

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

export type UseSonarEntitiesResult = {
    authenticated: boolean;
    loading: boolean;
    entities?: EntityDetails[];
    error?: Error;
};

export function useSonarEntities(args: { saleUUID: string; walletAddress?: string }): UseSonarEntitiesResult {
    const { authenticated, ready } = useSonarAuth();
    const client = useSonarClient();

    if (!args.saleUUID) {
        throw new Error("saleUUID is required");
    }

    const saleUUID = args.saleUUID;

    const [state, setState] = useState<{
        loading: boolean;
        entities?: EntityDetails[];
        error?: Error;
        hasFetched: boolean;
    }>({
        loading: false,
        hasFetched: false,
    });

    const fullyConnected = ready && authenticated;

    const refetch = useCallback(async () => {
        if (!fullyConnected) {
            return;
        }
        setState((s) => ({ ...s, loading: true }));
        try {
            const resp = await client.listAvailableEntities({
                saleUUID,
            });
            setState({
                loading: false,
                entities: resp.Entities,
                error: undefined,
                hasFetched: true,
            });
        } catch (err) {
            const error = err instanceof Error ? err : new Error(String(err));
            setState({ loading: false, entities: undefined, error, hasFetched: true });
        }
    }, [client, saleUUID, fullyConnected]);

    const reset = useCallback(() => {
        setState({
            loading: false,
            hasFetched: false,
            entities: undefined,
            error: undefined,
        });
    }, []);

    useEffect(() => {
        if (fullyConnected) {
            refetch();
        }
    }, [fullyConnected, refetch]);

    useEffect(() => {
        if (ready && !authenticated) {
            reset();
        }
    }, [ready, authenticated, reset]);

    return {
        authenticated,
        loading: state.loading,
        entities: state.entities,
        error: state.error,
    };
}

export type UseSonarPurchaseResultReadyToPurchase = {
    loading: false;
    readyToPurchase: true;
    error: undefined;
    generatePurchasePermit: () => Promise<GeneratePurchasePermitResponse>;
};

export type UseSonarPurchaseResultNotReadyToPurchase = {
    loading: false;
    readyToPurchase: false;
    error: undefined;
    failureReason: PrePurchaseFailureReason;
    livenessCheckURL: string;
};

export type UseSonarPurchaseResultError = {
    loading: false;
    readyToPurchase: false;
    error: Error;
};

export type UseSonarPurchaseResultLoading = {
    loading: true;
    readyToPurchase: false;
    error: undefined;
};

export type UseSonarPurchaseResult =
    | UseSonarPurchaseResultLoading
    | UseSonarPurchaseResultReadyToPurchase
    | UseSonarPurchaseResultNotReadyToPurchase
    | UseSonarPurchaseResultError;

export function useSonarPurchase(args: {
    saleUUID: string;
    entityID: EntityID;
    walletAddress: string;
}): UseSonarPurchaseResult {
    const saleUUID = args.saleUUID;
    const entityID = args.entityID;
    const walletAddress = args.walletAddress;

    const client = useSonarClient();

    const [state, setState] = useState<UseSonarPurchaseResult>({
        loading: true,
        readyToPurchase: false,
        error: undefined,
    });

    const generatePurchasePermit = useCallback(() => {
        return client.generatePurchasePermit({
            saleUUID,
            entityID,
            walletAddress,
        });
    }, [client, saleUUID, entityID, walletAddress]);

    useEffect(() => {
        const fetchPurchaseData = async () => {
            setState({
                loading: true,
                readyToPurchase: false,
                error: undefined,
            });

            try {
                const response = await client.prePurchaseCheck({
                    saleUUID,
                    entityID,
                    walletAddress,
                });
                if (response.ReadyToPurchase) {
                    setState({
                        loading: false,
                        readyToPurchase: true,
                        generatePurchasePermit,
                        error: undefined,
                    });
                } else {
                    setState({
                        loading: false,
                        readyToPurchase: false,
                        failureReason: response.FailureReason as PrePurchaseFailureReason,
                        livenessCheckURL: response.LivenessCheckURL,
                        error: undefined,
                    });
                }
            } catch (err) {
                const error = err instanceof Error ? err : new Error(String(err));
                setState({
                    loading: false,
                    readyToPurchase: false,
                    error: error,
                });
            }
        };

        fetchPurchaseData();
    }, [saleUUID, entityID, walletAddress, client, generatePurchasePermit]);

    return state;
}
