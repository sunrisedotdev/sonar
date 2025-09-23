const DEFAULT_FRONTEND_URL = "https://app.echo.xyz";

export type BuildAuthorizationUrlArgs = {
    saleUUID: string;
    clientUUID: string;
    redirectURI: string;
    state: string;
    codeChallenge: string;
    frontendURL?: string;
};

export function buildAuthorizationUrl({
    saleUUID,
    clientUUID,
    redirectURI,
    state,
    codeChallenge,
    frontendURL = DEFAULT_FRONTEND_URL,
}: BuildAuthorizationUrlArgs): URL {
    const url = new URL("/oauth/authorize", frontendURL);
    url.searchParams.set("client_id", clientUUID);
    url.searchParams.set("redirect_uri", redirectURI);
    url.searchParams.set("response_type", "code");
    url.searchParams.set("state", state);
    url.searchParams.set("code_challenge", codeChallenge);
    url.searchParams.set("saleUUID", saleUUID);
    return url;
}
