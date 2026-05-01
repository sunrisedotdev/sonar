# sonar-example-nextjs-svm

A **backend-focused** example Next.js app showing how to integrate with the Sonar API on Solana.

There is an integration guide for the Sonar libraries [here](https://docs.echo.xyz/sonar/integration-guides/react).

This example implements a backend OAuth flow where tokens are stored server-side and all Sonar API requests are proxied through the backend. For a simpler frontend-only approach where tokens are managed client-side, see [sonar-example-react-svm](https://github.com/sunrisedotdev/sonar-example-react-svm).

## Why Use the Backend Approach?

This approach is more secure than a frontend-only approach since the access tokens stay on the server and do not need to be sent to the client at all.

However it does increase the complexity, which might not be worth it if you already have a frontend-only single page app.

## Running the App Locally

Copy the env template and fill in the values for your sale:

```sh
cp .env.example .env
```

Edit `.env` and set `NEXT_PUBLIC_SALE_UUID`, `NEXT_PUBLIC_OAUTH_CLIENT_UUID`, and `NEXT_PUBLIC_PAYMENT_TOKEN_MINT`. You can find these values for your sale on the [Echo founder dashboard](https://app.echo.xyz/founder).

The app will throw at startup if any of the required vars are missing.

```sh
pnpm i
pnpm dev
```

The example uses a [SettlementSale](https://github.com/sunrisedotdev/sunrise/tree/main/solana/programs/settlement-sale) program on Solana devnet.

In order to test committing funds, you will need to have USDC to commit and SOL to pay for the gas.

Faucets:

- USDC: <https://faucet.circle.com/>
- SOL: <https://faucet.solana.com/>

### RPC Configuration

By default, the app uses the public Solana devnet RPC endpoint, which is *rate-limited and not suitable for production use*.

For production or any meaningful testing, set the env var `NEXT_PUBLIC_RPC_URL` to your private RPC endpoint from [Helius](https://www.helius.dev/), [QuickNode](https://www.quicknode.com/), [Alchemy](https://www.alchemy.com/), or similar.

**Be careful!** Exposing an RPC URL on the frontend allows anyone to extract and use your private RPC keys.
Only use scoped and rate-limited API keys, never expose your master private keys.

## What This Example Demonstrates

- **OAuth authentication with Sonar** via a secure backend flow with PKCE
- **Token management** — server-side storage with automatic refresh
- **Entity state display** — prior to sale, list all user entities; during sale, show linked entity status
- **Pre-purchase checks** — validate eligibility before transactions
- **Purchase transactions** — generate permits, build Ed25519 verify instruction, and submit to the settlement sale program

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
│   ├── actions/
│   │   ├── auth.ts               # Session management & OAuth flow
│   │   └── sonar.ts              # Proxied Sonar API server actions
│   ├── components/
│   │   ├── auth/                 # Login/logout UI
│   │   ├── entity/               # Entity display components
│   │   ├── registration/         # Pre-sale entity list & eligibility
│   │   └── sale/                 # Purchase flow UI
│   ├── hooks/
│   │   ├── use-place-bid.ts      # Solana place_bid transaction hook
│   │   ├── use-session.tsx       # Session state context & hook
│   │   └── use-sonar-*.ts        # React hooks for Sonar API calls
│   ├── idl/
│   │   └── settlement_sale.ts    # Anchor IDL for the settlement sale program
│   ├── oauth/callback/           # OAuth callback page (frontend)
│   ├── page.tsx                  # Main page
│   └── Provider.tsx              # App providers setup
└── lib/
    ├── config.ts                 # Environment configuration
    ├── session.ts                # Cookie-based session management
    ├── token-store.ts            # In-memory token storage (swap for DB in production)
    ├── pkce-store.ts             # PKCE verifier storage for OAuth
    ├── sonar.ts                  # SonarClient factory & server action helper
    └── errors.ts                 # Shared error types
```
