# @echoxyz/sonar-core

Headless core client for interacting with Echo’s Sonar APIs. Router-agnostic, framework-agnostic.

## Install

```bash
pnpm add @echoxyz/sonar-core
```

## Quick start (default settings)

The default client targets Echo’s hosted API and reads the auth token from `localStorage` under the `sonar:auth-token` key.

```ts
import { createClient, buildAuthorizationUrl, generatePKCEParams } from "@echoxyz/sonar-core";

// Configure once at app startup
const saleUUID = "<your-sale-uuid>";
const clientUUID = "<your-oauth-client-id>";
const redirectURI = window.location.origin + "/oauth/callback";

const client = createClient();

// Start OAuth login (e.g. on a button click)
export async function login() {
    const { codeVerifier, codeChallenge, state } = await generatePKCEParams();

    sessionStorage.setItem("sonar:oauth:state", state);
    sessionStorage.setItem("sonar:oauth:verifier", codeVerifier);

    const url = buildAuthorizationUrl({
        clientUUID,
        redirectURI,
        state,
        codeChallenge,
    });

    window.location.href = url.toString();
}

// Complete OAuth on your callback route/page
export async function completeOAuthFromCallback() {
    const params = new URLSearchParams(window.location.search);
    const code = params.get("code");
    const state = params.get("state");
    if (!code || !state) {
        throw new Error("Missing OAuth params");
    }

    const expectedState = sessionStorage.getItem("sonar:oauth:state");
    const codeVerifier = sessionStorage.getItem("sonar:oauth:verifier");
    if (state !== expectedState || !codeVerifier) {
        throw new Error("Invalid OAuth state or missing verifier");
    }

    const { token } = await client.exchangeAuthorizationCode({
        code,
        codeVerifier,
        redirectURI,
    });

    // Persist through the client (wired to default storage)
    client.setToken(token);

    // Clean up temp params
    sessionStorage.removeItem("sonar:oauth:state");
    sessionStorage.removeItem("sonar:oauth:verifier");
}

// Call APIs (after token is set)
export async function exampleCalls() {
    const { walletAddress } = useWallet(); // User's connected wallet.
    // List entities available to this user for the configured sale
    const { Entity } = await client.readEntity({ saleUUID, walletAddress });

    // Run a pre-purchase check
    const pre = await client.prePurchaseCheck({
        saleUUID,
        entityID: Entity.EntityID,
        walletAddress: "0x1234...abcd" as `0x${string}`,
    });

    if (pre.ReadyToPurchase) {
        // Generate a purchase permit
        const permit = await client.generatePurchasePermit({
            saleUUID,
            entityID: Entity.EntityID,
            walletAddress: "0x1234...abcd" as `0x${string}`,
        });
        console.log(permit.Signature, permit.Permit);
    }

    // Fetch allocation
    const alloc = await client.fetchAllocation({ saleUUID, walletAddress });
    console.log(alloc);
}
```

## Customizing the client

`createClient` accepts options so you can swap out pieces as needed:

```ts
import { AuthSession, buildAuthorizationUrl, createClient, createMemoryStorage } from "@echoxyz/sonar-core";

const client = createClient({
    apiURL: "https://api.echo.xyz",
    fetch: customFetchImplementation,
    auth: new AuthSession({
        storage: createMemoryStorage(),
        tokenKey: "custom-token-key",
    }),
});

// or let the factory create the session but tweak defaults
const clientWithCallbacks = createClient({
    onTokenChange: (token) => console.log("token updated", token),
    onExpire: () => console.log("session expired"),
});

const oauthURL = buildAuthorizationUrl({
    clientUUID: "<client-id>",
    redirectURI: "https://example.com/oauth/callback",
    state: "opaque-state",
    codeChallenge: "pkce-challenge",
    frontendURL: "https://custom.echo.xyz", // optional override
});
```

## Notes

- Tokens are not auto-refreshed. When they expire, clear `sonar:auth-token` and re-run the OAuth flow.
- This package is headless and router-agnostic. You can integrate with any router or framework.
