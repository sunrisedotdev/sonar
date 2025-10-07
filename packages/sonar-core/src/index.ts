import { AuthSession } from "./auth";
import { SonarClient, type FetchLike } from "./client";
import { createWebStorage } from "./storage";

export * from "./client";
export * from "./oauth";
export * from "./pkce";
export * from "./storage";
export * from "./types";

const DEFAULT_API_URL = "https://api.echo.xyz";

export type CreateClientOptions = {
    saleUUID: string; // TODO: remove this
    apiURL?: string;
    auth?: AuthSession;
    fetch?: FetchLike;
    tokenKey?: string;
    onExpire?: () => void;
    onTokenChange?: (token?: string) => void;
};

export function createClient(options: CreateClientOptions): SonarClient {
    const { apiURL = DEFAULT_API_URL, auth, fetch, tokenKey, onExpire, onTokenChange } = options;

    const authSession =
        auth ??
        new AuthSession({
            storage: createWebStorage(),
            tokenKey,
            onExpire,
        });

    if (onTokenChange) {
        authSession.onTokenChange(onTokenChange);
    }

    return new SonarClient({
        apiURL,
        opts: { auth: authSession, fetch, onUnauthorized: () => authSession.clear() },
    });
}
