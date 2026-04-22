# sonar-example-react-svm

A **frontend-focused** React example app demonstrating integration with the Sonar API using `@echoxyz/sonar-react` and `@echoxyz/sonar-core` libraries on Solana.

There is an integration guide for these libraries [here](https://docs.echo.xyz/sonar/integration-guides/react).

This example implements a client-side OAuth flow where tokens are managed entirely in the browser by the `@echoxyz/sonar-react` library. For a more secure backend approach where tokens are stored server-side, see [sonar-example-nextjs-svm](https://github.com/sunrisedotdev/sonar-example-nextjs-svm).

## Why Use the Frontend Approach?

This approach is simpler to implement and can can be used by single-page applications (SPAs) that don't already have a backend. All authentication and API calls are handled client-side using React hooks.

However, since tokens are stored in the browser, this approach is less secure than a backend flow (as implemented in [sonar-example-nextjs-svm](https://github.com/sunrisedotdev/sonar-example-nextjs-svm)).

## Running the App Locally

By default this app is configured to use a test Sonar sale and program and should work out of the box. If you want to point it at a different sale or program, you can modify the env vars in `.env.local`. You can find the values for your sale on the [Echo founder dashboard](https://app.echo.xyz/founder).

```sh
pnpm i
pnpm dev
```

The app will be available at `http://localhost:3000`.

The example uses a [SettlementSale](https://github.com/sunrisedotdev/sunrise/tree/main/solana/programs/settlement-sale) program on Solana devnet.

In order to test committing funds, you will need to have USDC to commit and SOL to pay for the gas.

Faucets:

- USDC: <https://faucet.circle.com/>
- SOL: <https://faucet.solana.com/>

### RPC Configuration

By default, the app uses the public Solana devnet RPC endpoint, which is *rate-limited and not suitable for production use*.

For production or any meaningful testing, set the env var `VITE_RPC_URL` to your RPC endpoint from [Helius](https://www.helius.dev/), [QuickNode](https://www.quicknode.com/), or [Alchemy](https://www.alchemy.com/).

**Be careful!** Exposing an RPC URL on the frontend allows anyone to extract and use your private RPC keys.
Only use scoped and rate-limited API keys, never expose your master private keys.

## What This Example Demonstrates

- **Provider setup** — configuring `SonarProvider` with the Solana wallet adapter and React Query
- **OAuth authentication with Sonar** — client-side flow using `useSonarAuth()` hook
- **Token management** — handled automatically by `@echoxyz/sonar-react` in browser storage
- **Entity state display** — prior to sale, list all user entities; during sale, show linked entity status
- **Pre-purchase checks** — validate eligibility before transactions using `useSonarPurchase()`
- **Purchase transactions** — generate permits, build Ed25519 verify + `place_bid` instructions, and submit

## Authentication Architecture

The `@echoxyz/sonar-react` library handles the complete OAuth flow client-side, storing tokens in browser storage:

### OAuth Flow

```
┌─────────┐                   ┌─────────┐                   ┌─────────┐
│ Browser │                   │  Sonar  │                   │  Echo   │
│  (React │                   │  React  │                   │  OAuth  │
│   App)  │                   │ Library │                   │         │
└────┬────┘                   └────┬────┘                   └────┬────┘
     │                             │                             │
     │ 1. User clicks              │                             │
     │    "Connect with Sonar"     │                             │
     ├────────────────────────────>│                             │
     │                             │                             │
     │                             │ 2. Generate PKCE            │
     │                             │    params & store           │
     │                             │    in sessionStorage        │
     │                             │                             │
     │                             │ 3. Redirect via             │
     │                             │    window.location          │
     │                             │                             │
     │ 4. Navigate to Echo OAuth   │                             │
     ├──────────────────────────────────────────────────────────>│
     │                             │                             │
     │ 5. User authenticates & authorizes                        │
     │    (interactive session)    │                             │
     │                             │                             │
     │ 6. Redirect to callback with auth code & state            │
     │<──────────────────────────────────────────────────────────│
     │                             │                             │
     │ 7. Callback page calls      │                             │
     │    completeOAuth()          │                             │
     ├────────────────────────────>│                             │
     │                             │                             │
     │                             │ 8. Exchange code +          │
     │                             │    verifier for tokens      │
     │                             ├────────────────────────────>│
     │                             │                             │
     │                             │ 9. Return tokens            │
     │                             │<────────────────────────────│
     │                             │                             │
     │                             │ 10. Store tokens            │
     │                             │     in browser storage      │
     │                             │                             │
     │ 11. authenticated = true    │                             │
     │<────────────────────────────│                             │
     │                             │                             │
```

### API Requests

Once authenticated, Sonar API calls are made directly from the client using React hooks:

```
┌─────────┐                   ┌─────────┐                   ┌─────────┐
│ Browser │                   │  Sonar  │                   │  Sonar  │
│  (React │                   │  React  │                   │   API   │
│   App)  │                   │ Library │                   │         │
└────┬────┘                   └────┬────┘                   └────┬────┘
     │                             │                             │
     │ 1. useSonarEntities()       │                             │
     │    hook renders             │                             │
     ├────────────────────────────>│                             │
     │                             │                             │
     │                             │ 2. Get token from           │
     │                             │    browser storage          │
     │                             │                             │
     │                             │ 3. GET /entities            │
     │                             │    Authorization: Bearer... │
     │                             ├────────────────────────────>│
     │                             │                             │
     │                             │ 4. Response                 │
     │                             │<────────────────────────────│
     │                             │                             │
     │ 5. Return entities          │                             │
     │    to component             │                             │
     │<────────────────────────────│                             │
     │                             │                             │
```

## Project Structure

```
src/
├── components/
│   ├── auth/                 # Login/logout UI
│   ├── entity/               # Entity display components
│   ├── registration/         # Pre-sale entity list & eligibility
│   └── sale/                 # Purchase flow UI
├── pages/
│   ├── Home.tsx                       # Main page (pre-sale & sale views)
│   └── OAuthCallback.tsx              # OAuth callback handler
├── config.ts                          # Environment configuration
├── hooks/
│   └── use-place-bid.ts               # Custom hook (usePlaceBid)
├── idl/
│   └── settlement_sale.ts             # Anchor IDL for the settlement sale program
├── Provider.tsx                       # SonarProvider, wallet adapter, React Query setup
└── main.tsx                           # App entry point
```
