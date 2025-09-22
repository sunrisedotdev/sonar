import { AuthSession } from "./auth";
import { SonarClient } from "./client";
import { createJsonFetcher, FetchLike } from "./fetcher";
import { createWebStorage } from "./storage";

export * from "./types";
export * from "./pkce";
export * from "./oauth";
export * from "./client";

const DEFAULT_API_URL = "https://api.echo.xyz";

export function createClient(args: {
    apiURL: string;
    saleUUID: string;
    auth?: AuthSession;
    fetch?: FetchLike;
}): SonarClient {
    return new SonarClient({
        apiURL: args.apiURL,
        saleUUID: args.saleUUID,
        opts: { auth: args.auth, fetch: args.fetch },
    });
}

export function createDefaultClient(args: { saleUUID: string }): SonarClient {
    const storage = createWebStorage();
    const authSession = new AuthSession({ storage });
    authSession.onTokenChange((token) => {
        if (token) {
            localStorage.setItem("sonar:auth-token", token);
            return;
        }
        localStorage.removeItem("sonar:auth-token");
    });

    return createClient({
        apiURL: DEFAULT_API_URL,
        saleUUID: args.saleUUID,
        auth: authSession,
        fetch: createJsonFetcher(),
    });
}
