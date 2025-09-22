const DEFAULT_FRONTEND_URL = "https://app.echo.xyz";

function buildAuthorizationUrl(args: {
    saleUUID: string;
    clientUUID: string;
    frontendURL: string;
    redirectURI: string;
    state: string;
    codeChallenge: string;
}): URL {
    const url = new URL("/oauth/authorize", args.frontendURL);
    url.searchParams.set("client_id", args.clientUUID);
    url.searchParams.set("redirect_uri", args.redirectURI);
    url.searchParams.set("response_type", "code");
    url.searchParams.set("state", args.state);
    url.searchParams.set("code_challenge", args.codeChallenge);
    url.searchParams.set("saleUUID", args.saleUUID);
    return url;
}

export function buildDefaultAuthorizationUrl(args: {
    saleUUID: string;
    clientUUID: string;
    redirectURI: string;
    state: string;
    codeChallenge: string;
}): URL {
    return buildAuthorizationUrl({ ...args, frontendURL: DEFAULT_FRONTEND_URL });
}
