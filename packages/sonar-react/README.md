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
    const { login, authenticated, ready } = useSonarAuth();
    if (!ready || authenticated) {
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

4. Load the Sonar entity associated with the user's wallet

```tsx
import { useSonarEntity } from "./hooks/useSonarEntity";
import { useAccount } from "wagmi";

const ExampleEntityPanel = () => {
    const { address, isConnected } = useAccount();
    const { authenticated, loading, entity, error } = useSonarEntity({
        saleUUID: "<your-sale-uuid>",
        wallet: { address, isConnected },
    });

    if (!isConnected || !authenticated) {
        return <p>Connect your wallet and Sonar account to continue</p>;
    }

    if (loading) {
        return <p>Loading...</p>;
    }

    if (error) {
        return <p>Error: {error.message}</p>;
    }

    if (!entity) {
        return <p>No entity found for this wallet. Please link your wallet on Sonar to continue.</p>;
    }

    return (
        <div>
            <span>entity.Label</span>
            <span>entity.EntitySetupState</span>
            <span>entity.EntitySaleEligibility</span>
        </div>
    );
};

```

5. Call APIs using the low-level client:

```tsx
import { useEffect } from "react";
import { useSonarEntity } from "./hooks/useSonarEntity";
import { useAccount } from "wagmi";
import { EntityType } from "@echoxyz/sonar-core";

export function Example() {
    const { address, isConnected } = useAccount();
    // Would normally need to handle loading and error states like above
    const { entity } = useSonarEntity({
        saleUUID: "<your-sale-uuid>",
        wallet: { address, isConnected },
    });
    const client = useSonarClient();

    useEffect(() => {
        if (!entity) {
            return;
        }

        (async () => {
            const pre = await client.prePurchaseCheck({
                saleUUID: "<your-sale-uuid>",
                entityUUID: entity.EntityUUID,
                entityType: EntityType.USER,
                walletAddress: "0x1234...abcd" as `0x${string}`,
            });

            if (pre.ReadyToPurchase) {
                const permit = await client.generatePurchasePermit({
                    saleUUID: "<your-sale-uuid>",
                    entityUUID: entity.EntityUUID,
                    entityType: EntityType.USER,
                    walletAddress: "0x1234...abcd" as `0x${string}`,
                });
                console.log(permit.Signature, permit.Permit);
            }

            const alloc = await client.fetchAllocation({
                saleUUID: "<your-sale-uuid>",
                walletAddress,
            });
            console.log(alloc);
        })();
    }, [entity]);

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

- `useSonarAuth()` → `{ authenticated, ready, token?, login(), completeOAuth({ code, state }), logout() }`

- `useSonarClient()` → low-level `SonarClient` instance.
  
- `useSonarEntity()` → `{ authenticated, loading, entity?, error? }` high-level convenience hook for fetching a Sonar entity by wallet address.

## Notes

- Tokens are not auto-refreshed. On expiry, call `logout()` and re-run the OAuth flow.
- This package doesn’t depend on a specific router. Use it in Next.js, React Router, or any custom setup.
- Wallet addresses are typed as template literals `0x${string}`.
