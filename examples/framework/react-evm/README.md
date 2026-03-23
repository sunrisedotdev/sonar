# sonar-example-react

A **frontend-focused** React example app demonstrating integration with the Sonar API using `@echoxyz/sonar-react` and `@echoxyz/sonar-core` libraries.

There is an integration guide for these libraries [here](https://docs.echo.xyz/sonar/integration-guides/react).

This example implements a client-side OAuth flow where tokens are managed entirely in the browser by the `@echoxyz/sonar-react` library. For a more secure backend approach where tokens are stored server-side, see [sonar-example-nextjs](https://github.com/sunrisedotdev/sonar-example-nextjs).

## Why Use the Frontend Approach?

This approach is simpler to implement and can can be used by single-page applications (SPAs) that don't already have a backend. All authentication and API calls are handled client-side using React hooks.

However, since tokens are stored in the browser, this approach is less secure than a backend flow (as implemented in [sonar-example-nextjs](https://github.com/sunrisedotdev/sonar-example-nextjs)).

## Running the App Locally

By default this app is configured to use a test Sonar sale and contract and should work out of the box. If you want to point it at a different sale or contract, you can modify the env vars in `.env.local`. You can find the values for your sale on the [Echo founder dashboard](https://app.echo.xyz/founder).

```sh
pnpm i
pnpm dev
```

The app will be available at `http://localhost:3000`.

The example uses a [SettlementSale](https://github.com/sunrisedotdev/sonar/blob/main/contracts/src/SettlementSale.sol) contract on Base Sepolia.

In order to test committing funds, you will need to have USDC to commit and ETH to pay for the gas.

Faucets:

- USDC: <https://faucet.circle.com/>
- ETH: <https://docs.base.org/base-chain/tools/network-faucets>

## What This Example Demonstrates

- **Provider setup** — configuring `SonarProvider` with wagmi and React Query
- **OAuth authentication with Sonar** — client-side flow using `useSonarAuth()` hook
- **Token management** — handled automatically by `@echoxyz/sonar-react` in browser storage
- **Entity state display** — prior to sale, list all user entities; during sale, show linked entity status
- **Pre-purchase checks** — validate eligibility before transactions using `useSonarPurchase()`
- **Purchase transactions** — generate permits and submit to the sale contract

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
├── hooks.ts                           # Custom hooks (useSaleContract)
├── Provider.tsx                       # SonarProvider, wagmi, React Query setup
└── main.tsx                           # App entry point
```
