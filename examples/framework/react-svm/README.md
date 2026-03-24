# sonar-example-react-svm

A Vite + React example app showing how to integrate with the Sonar API for a Solana token sale using the `@echoxyz/sonar-react` and `@echoxyz/sonar-core` libraries with `@coral-xyz/anchor` and `@solana/wallet-adapter`.

## Setup

1. Copy `.env.local` and fill in your values:
   - `VITE_SALE_UUID` and `VITE_OAUTH_CLIENT_UUID` from your Sonar sale dashboard
   - `VITE_PROGRAM_ID` — the on-chain settlement sale program ID
   - `VITE_PAYMENT_TOKEN_MINT` — SPL token mint for the payment token
   - `VITE_RPC_URL` — Solana RPC endpoint

2. Install dependencies:

```bash
pnpm install
```

3. Run the dev server:

```bash
pnpm dev
```

## How it works

- The app uses `@solana/wallet-adapter-react` with Wallet Standard for wallet connection
- `useSonarAuth` from `@echoxyz/sonar-react` handles OAuth with the Sonar API
- `usePlaceBid` builds and sends a `place_bid` transaction to the on-chain settlement sale program
  - Gets a purchase permit from the Sonar API (`generatePurchasePermit`)
  - Prepends an Ed25519 verify instruction for the permit signature (required by the program)
  - Calls `program.methods.placeBid(...)` via `@coral-xyz/anchor`
