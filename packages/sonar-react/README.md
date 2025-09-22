# @echoxyz/sonar-react

React provider and hooks for Echo’s Sonar APIs, built on `@echoxyz/sonar-core`.

- Framework/router agnostic (works with React Router, Next.js, etc.).
- Handles PKCE OAuth redirect flow and token storage for the browser.
- Exposes a ready-to-use API client bound to a single `saleUUID`.

## Install

```bash
pnpm add @echoxyz/sonar-react @echoxyz/sonar-core
```

Peer dependency: `react@>=18`.

## Quick start

1. Wrap your app with `SonarProvider`:

```tsx
import { SonarProvider } from "@echoxyz/sonar-react";

export function AppRoot({ children }: { children: React.ReactNode }) {
    return (
        <SonarProvider
            config={{
                saleUUID: "<your-sale-uuid>",
                clientUUID: "<your-oauth-client-id>",
                redirectURI: window.location.origin + "/oauth/callback",
                // Optional:
                // apiURL: "https://api.echo.xyz",
                // tokenStorageKey: "sonar:auth-token",
            }}
        >
            {children}
        </SonarProvider>
    );
}
```

2. Trigger login with PKCE + redirect:

```tsx
import { useSonarAuth } from "@echoxyz/sonar-react";

export function LoginButton() {
    const { login, authenticated } = useSonarAuth();
    if (authenticated()) {
        return null;
    }
    return <button onClick={() => login()}>Sign in with Echo</button>;
}
```

3. Complete OAuth on your callback route/page:

```tsx
import { useEffect } from "react";
import { useSonarAuth } from "@echoxyz/sonar-react";

export default function OAuthCallback() {
    const { completeOAuth } = useSonarAuth();

    useEffect(() => {
        const params = new URLSearchParams(window.location.search);
        const code = params.get("code");
        const state = params.get("state");
        if (!code || !state) {
            return;
        }
        completeOAuth({ code, state }).catch((err) => {
            console.error("OAuth completion failed", err);
        });
    }, [completeOAuth]);

    return <p>Completing sign-in…</p>;
}
```

4. Call APIs using the client-bound sale helpers:

```tsx
import { useEffect } from "react";
import { useSonarAuth, useSonarSale } from "@echoxyz/sonar-react";

export function Example() {
    const { authenticated } = useSonarAuth();
    const { listAvailableEntities, prePurchaseCheck, generatePurchasePermit, fetchAllocation } = useSonarSale();

    useEffect(() => {
        if (!authenticated()) {
            return;
        }

        (async () => {
            const entities = await listAvailableEntities();
            if (entities.length === 0) return;

            const entity = entities[0];
            const pre = await prePurchaseCheck({
                entityUUID: entity.EntityUUID,
                entityType: "user",
                walletAddress: "0x1234...abcd" as `0x${string}`,
            });

            if (pre.ReadyToPurchase) {
                const permit = await generatePurchasePermit({
                    entityUUID: entity.EntityUUID,
                    entityType: "user",
                    walletAddress: "0x1234...abcd" as `0x${string}`,
                });
                console.log(permit.Signature, permit.Permit);
            }

            const alloc = await fetchAllocation({ walletAddress: "0x1234...abcd" as `0x${string}` });
            console.log(alloc);
        })();
    }, [authenticated, listAvailableEntities, prePurchaseCheck, generatePurchasePermit, fetchAllocation]);

    return null;
}
```

## API

- `SonarProvider`
    - Props `config`:
        - `saleUUID: string` (required) – Sale to scope API calls against.
        - `clientUUID: string` (required) – Echo OAuth Client ID.
        - `redirectURI: string` (required) – Your OAuth callback URI.
        - `apiURL?: string` (default: `https://api.echo.xyz`) – API base URL.
        - `tokenStorageKey?: string` (default: `sonar:auth-token`) – Browser storage key for the access token.

- `useSonarAuth()` → `{ authenticated, token?, login(), completeOAuth(searchParams?), logout() }`
    - Router-agnostic: `completeOAuth(searchParams?)` accepts an optional `URLSearchParams`. If omitted, it uses `window.location.search`.

- `useSonarClient()` → low-level `SonarClient` instance.

- `useSonarSale()` → sale-scoped helpers:
    - `listAvailableEntities()`
    - `prePurchaseCheck({ entityUUID, entityType, walletAddress })`
    - `generatePurchasePermit({ entityUUID, entityType, walletAddress })`
    - `fetchAllocation({ walletAddress })`

## Notes

- Tokens are not auto-refreshed. On expiry, call `logout()` and re-run the OAuth flow.
- This package doesn’t depend on a specific router. Use it in Next.js, React Router, or any custom setup.
- Wallet addresses are typed as template literals `0x${string}`.
