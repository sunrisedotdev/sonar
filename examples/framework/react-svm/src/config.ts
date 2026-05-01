import { SonarProviderConfig } from "@echoxyz/sonar-react";
import { SETTLEMENT_SALE_PROGRAM_ID } from "./idl/settlement_sale";

function requireEnv(name: string, value: string | undefined): string {
  if (!value) {
    throw new Error(
      `Missing required env var ${name}. Copy .env.example to .env and fill in the values for your sale.`,
    );
  }
  return value;
}

export const sonarConfig = {
  clientUUID: requireEnv("VITE_OAUTH_CLIENT_UUID", import.meta.env.VITE_OAUTH_CLIENT_UUID),
  redirectURI: requireEnv("VITE_OAUTH_CLIENT_REDIRECT_URI", import.meta.env.VITE_OAUTH_CLIENT_REDIRECT_URI),
  frontendURL: import.meta.env.VITE_ECHO_FRONTEND_URL ?? "https://app.echo.xyz",
  apiURL: import.meta.env.VITE_ECHO_API_URL ?? "https://api.echo.xyz",
} as SonarProviderConfig;

export const saleUUID = requireEnv("VITE_SALE_UUID", import.meta.env.VITE_SALE_UUID);
export const PROGRAM_ID = import.meta.env.VITE_PROGRAM_ID ?? SETTLEMENT_SALE_PROGRAM_ID;
export const PAYMENT_TOKEN_MINT = requireEnv("VITE_PAYMENT_TOKEN_MINT", import.meta.env.VITE_PAYMENT_TOKEN_MINT);
export const RPC_URL = import.meta.env.VITE_RPC_URL ?? "https://api.devnet.solana.com";
export const sonarHomeURL = new URL(`/sonar/${saleUUID}/home`, sonarConfig.frontendURL);
