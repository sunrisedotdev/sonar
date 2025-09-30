import { buildAuthorizationUrl, createClient, generatePKCEParams, type SonarClient } from "@echoxyz/sonar-core";
import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";

type SonarProviderProps = {
    children: React.ReactNode;
    config: SonarProviderConfig;
};

export type SonarProviderConfig = {
    saleUUID: string;
    clientUUID: string;
    redirectURI: string;
    apiURL?: string;
    frontendURL?: string;
    tokenStorageKey?: string; // default: "sonar:auth-token"
};

export type AuthContextValue = {
    authenticated: boolean;
    ready: boolean;
    token?: string;
    login: () => Promise<void>;
    completeOAuth: (args: { code: string; state: string }) => Promise<void>;
    logout: () => void;
};

export type ClientContextValue = {
    client: SonarClient;
};

export const AuthContext = createContext<AuthContextValue | undefined>(undefined);
export const ClientContext = createContext<ClientContextValue | undefined>(undefined);

export function SonarProvider({ children, config }: SonarProviderProps) {
    const [authState, setAuthState] = useState<{ token?: string; ready: boolean }>({ token: undefined, ready: false });

    const client = useMemo(() => {
        return createClient({
            saleUUID: config.saleUUID,
            apiURL: config.apiURL,
            tokenKey: config.tokenStorageKey,
            onTokenChange: (nextToken?: string) => {
                setAuthState({ token: nextToken ?? undefined, ready: true });
            },
        });
    }, [config.apiURL, config.saleUUID, config.tokenStorageKey]);

    useEffect(() => {
        setAuthState({ token: client.getToken() ?? undefined, ready: true });
    }, [client]);

    const login = useCallback(async () => {
        const { codeVerifier, codeChallenge, state } = await generatePKCEParams();
        if (typeof window === "undefined") {
            throw new Error("window is not available for OAuth flow");
        }
        window.sessionStorage.setItem("sonar:oauth:state", state);
        window.sessionStorage.setItem("sonar:oauth:verifier", codeVerifier);

        const url = buildAuthorizationUrl({
            saleUUID: config.saleUUID,
            clientUUID: config.clientUUID,
            redirectURI: config.redirectURI,
            state,
            codeChallenge,
            frontendURL: config.frontendURL,
        });
        window.location.href = url.toString();
    }, [config.saleUUID, config.clientUUID, config.redirectURI, config.frontendURL]);

    const completeOAuth = useCallback(
        async ({ code, state }: { code: string; state: string }) => {
            if (typeof window === "undefined") {
                throw new Error("window is not available for OAuth verification");
            }
            const expectedState = window.sessionStorage.getItem("sonar:oauth:state");
            const codeVerifier = window.sessionStorage.getItem("sonar:oauth:verifier");
            if (state !== expectedState || !codeVerifier) {
                throw new Error("Invalid OAuth state or missing verifier");
            }

            const { token } = await client.exchangeAuthorizationCode({
                code,
                codeVerifier,
                redirectURI: config.redirectURI,
            });

            client.setToken(token);
            window.sessionStorage.removeItem("sonar:oauth:state");
            window.sessionStorage.removeItem("sonar:oauth:verifier");
        },
        [client, config.redirectURI],
    );

    const logout = useCallback(() => {
        client.clear();
    }, [client]);

    const authValue = useMemo(
        () => ({
            login,
            logout,
            authenticated: Boolean(authState.token),
            ready: authState.ready,
            token: authState.token,
            completeOAuth,
        }),
        [authState, login, completeOAuth, logout],
    );

    const clientValue = useMemo<ClientContextValue>(() => ({ client }), [client]);

    return (
        <AuthContext.Provider value={authValue}>
            <ClientContext.Provider value={clientValue}>{children}</ClientContext.Provider>
        </AuthContext.Provider>
    );
}
