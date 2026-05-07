import { Hex } from "@echoxyz/sonar-core";
import { SonarProviderConfig } from "@echoxyz/sonar-react";

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
export const saleContract = requireEnv(
  "NEXT_PUBLIC_SALE_CONTRACT_ADDRESS",
  process.env.NEXT_PUBLIC_SALE_CONTRACT_ADDRESS,
) as Hex;
export const paymentTokenAddress = requireEnv(
  "NEXT_PUBLIC_PAYMENT_TOKEN_ADDRESS",
  process.env.NEXT_PUBLIC_PAYMENT_TOKEN_ADDRESS,
) as Hex;
export const sonarHomeURL = new URL(`/sonar/${saleUUID}/home`, sonarConfig.frontendURL);
export const rpcURL = process.env.NEXT_PUBLIC_RPC_URL || undefined;
