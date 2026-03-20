# sonar-example-nextjs

A **backend-focused** example Next.js app showing how to integrate with the Sonar API.

There is an integration guide for the Sonar libraries [here](https://docs.echo.xyz/sonar/integration-guides/react).

This example implements a backend OAuth flow where tokens are stored server-side and all Sonar API requests are proxied through the backend. For a simpler frontend-only approach where tokens are managed client-side, see [sonar-example-react](https://github.com/sunrisedotdev/sonar-example-react).

## Why Use the Backend Approach?

This approach is more secure than a frontend-only approach since the access tokens stay on the server and do not need to be sent to the client at all.

However it does increase the complexity, which might not be worth it if you already have a frontend-only single page app.

## Running the App Locally

Set the required env vars listed in `src/app/config.ts` (or update that file).
You can find the values for your sale on the [Echo founder dashboard](https://app.echo.xyz/founder).

```sh
pnpm i
pnpm dev
```

The example uses a [SettlementSale](https://github.com/sunrisedotdev/sonar/blob/main/contracts/src/SettlementSale.sol) contract on Base Sepolia.

In order to test committing funds, you will need to have USDC to commit and ETH to pay for the gas.

Faucets:

- USDC: <https://faucet.circle.com/>
- ETH: <https://docs.base.org/base-chain/tools/network-faucets>

## What This Example Demonstrates

- **OAuth authentication with Sonar** via a secure backend flow with PKCE
- **Token management** — server-side storage with automatic refresh
- **Entity state display** — prior to sale, list all user entities; during sale, show linked entity status
- **Pre-purchase checks** — validate eligibility before transactions
- **Purchase transactions** — generate permits and submit to the sale contract

## Authentication Architecture

For demonstration purposes, this example uses a minimal session system:

- **Login** backend creates a random session ID stored in an HTTP-only cookie (no authentication required)
- **Logout** clears the session and any associated Sonar tokens

### OAuth Flow

The backend handles the complete OAuth flow, storing tokens securely server-side:

```
┌─────────┐                   ┌─────────┐                   ┌─────────┐
│ Browser │                   │ Next.js │                   │  Echo   │
│         │                   │ Backend │                   │  OAuth  │
└────┬────┘                   └────┬────┘                   └────┬────┘
     │                             │                             │
     │ 1. Click "Connect"          │                             │
     ├────────────────────────────>│                             │
     │                             │                             │
     │                             │ 2. Generate PKCE            │
     │                             │    params & store           │
     │                             │    verifier                 │
     │                             │                             │
     │ 3. Return redirect          │                             │
     │    URL                      │                             │
     │<────────────────────────────│                             │
     │                             │                             │
     │ 4. Navigate to Echo OAuth   │                             │
     ├──────────────────────────────────────────────────────────>│
     │                             │                             │
     │ 5. User authenticates & authorizes                        │
     │    (interactive session)    │                             │
     │                             │                             │
     │ 6. Redirect to callback with auth code                    │
     │<──────────────────────────────────────────────────────────│
     │                             │                             │
     │ 7. Send auth code           │                             │
     │    to backend               │                             │
     ├────────────────────────────>│                             │
     │                             │                             │
     │                             │ 8. Exchange code            │
     │                             │    for tokens               │
     │                             ├────────────────────────────>│
     │                             │                             │
     │                             │ 9. Return tokens            │
     │                             │<────────────────────────────│
     │                             │                             │
     │                             │ 10. Store tokens            │
     │                             │     server-side             │
     │                             │                             │
     │ 11. Success                 │                             │
     │     response                │                             │
     │<────────────────────────────│                             │
     │                             │                             │
```

### Token Refresh

Access tokens expire after a set time. The backend automatically refreshes them:

- Before each Sonar API call, the backend checks if the token expires within 5 minutes
- If so, it uses `SonarClient.refreshToken()` to get new tokens
- Refreshed tokens are stored back in the token store
- **Concurrent request handling**: If multiple requests need to refresh simultaneously, promise coalescing ensures only one refresh API call is made

### Proxied API Requests

Once authenticated, all Sonar API calls go through the backend, which handles token refresh automatically:

```
┌─────────┐                   ┌─────────┐                   ┌─────────┐
│ Browser │                   │ Next.js │                   │  Sonar  │
│         │                   │ Backend │                   │   API   │
└────┬────┘                   └────┬────┘                   └────┬────┘
     │                             │                             │
     │ 1. POST /api/sonar/entities │                             │
     │    { saleUUID: "..." }      │                             │
     ├────────────────────────────>│                             │
     │                             │                             │
     │                             │ 2. Verify session           │
     │                             │    & get tokens             │
     │                             │                             │
     │                             │ 3. Refresh token            │
     │                             │    if expiring              │
     │                             │                             │
     │                             │ 4. GET /entities            │
     │                             │    Authorization: Bearer... │
     │                             ├────────────────────────────>│
     │                             │                             │
     │                             │ 5. Response                 │
     │                             │<────────────────────────────│
     │                             │                             │
     │ 6. Forward response         │                             │
     │<────────────────────────────│                             │
     │                             │                             │
```

## Project Structure

```
src/
├── app/
│   ├── api/
│   │   ├── auth/                 # Minimal session management
│   │   └── sonar/                # Proxied Sonar API routes (entities, pre-purchase, etc.)
│   ├── components/
│   │   ├── auth/                 # Login/logout UI
│   │   ├── entity/               # Entity display components
│   │   ├── registration/         # Pre-sale entity list & eligibility
│   │   └── sale/                 # Purchase flow UI
│   ├── hooks/
│   │   ├── use-session.tsx       # Session state context & hook
│   │   └── use-sonar-*.ts        # React hooks for Sonar API calls
│   ├── oauth/callback/           # OAuth callback page (frontend)
│   ├── config.ts                 # Environment configuration
│   ├── page.tsx                  # Main page
│   └── Provider.tsx              # App providers setup
└── lib/
    ├── session.ts                # Cookie-based session management
    ├── token-store.ts            # In-memory token storage (swap for DB in production)
    ├── pkce-store.ts             # PKCE verifier storage for OAuth
    ├── sonar-client.ts           # SonarClient factory
    └── sonar-route-handler.ts    # Authenticated route handler with token refresh
```
