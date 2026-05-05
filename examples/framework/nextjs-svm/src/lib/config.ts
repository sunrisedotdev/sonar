import { SonarProviderConfig } from "@echoxyz/sonar-react";
import { SETTLEMENT_SALE_PROGRAM_ID } from "@/app/idl/settlement_sale";

function requireEnv(name: string, value: string | undefined): string {
  if (!value) {
    throw new Error(
      `Missing required env var ${name}. Copy .env.example to .env and fill in the values for your sale.`,
    );
  }
  return value;
}

export const sonarConfig: SonarProviderConfig & { apiURL: string } = {
  clientUUID: requireEnv("NEXT_PUBLIC_OAUTH_CLIENT_UUID", process.env.NEXT_PUBLIC_OAUTH_CLIENT_UUID),
  redirectURI: requireEnv("NEXT_PUBLIC_OAUTH_CLIENT_REDIRECT_URI", process.env.NEXT_PUBLIC_OAUTH_CLIENT_REDIRECT_URI),
  frontendURL: process.env.NEXT_PUBLIC_ECHO_FRONTEND_URL ?? "https://app.echo.xyz",
  apiURL: process.env.NEXT_PUBLIC_ECHO_API_URL ?? "https://api.echo.xyz",
};

export const saleUUID = requireEnv("NEXT_PUBLIC_SALE_UUID", process.env.NEXT_PUBLIC_SALE_UUID);
export const PROGRAM_ID = process.env.NEXT_PUBLIC_PROGRAM_ID ?? SETTLEMENT_SALE_PROGRAM_ID;
export const PAYMENT_TOKEN_MINT = requireEnv("NEXT_PUBLIC_PAYMENT_TOKEN_MINT", process.env.NEXT_PUBLIC_PAYMENT_TOKEN_MINT);
export const RPC_URL = process.env.NEXT_PUBLIC_RPC_URL ?? "https://api.devnet.solana.com";
export const sonarHomeURL = new URL(`/sonar/${saleUUID}/home`, sonarConfig.frontendURL);
