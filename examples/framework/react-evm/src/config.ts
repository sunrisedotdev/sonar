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

export const sonarConfig = {
  clientUUID: requireEnv("VITE_OAUTH_CLIENT_UUID", import.meta.env.VITE_OAUTH_CLIENT_UUID),
  redirectURI: requireEnv("VITE_OAUTH_CLIENT_REDIRECT_URI", import.meta.env.VITE_OAUTH_CLIENT_REDIRECT_URI),
  frontendURL: import.meta.env.VITE_ECHO_FRONTEND_URL ?? "https://app.echo.xyz",
  apiURL: import.meta.env.VITE_ECHO_API_URL ?? "https://api.echo.xyz",
} as SonarProviderConfig;

export const saleUUID = requireEnv("VITE_SALE_UUID", import.meta.env.VITE_SALE_UUID);
export const saleContract = requireEnv(
  "VITE_SALE_CONTRACT_ADDRESS",
  import.meta.env.VITE_SALE_CONTRACT_ADDRESS,
) as Hex;
export const paymentTokenAddress = requireEnv(
  "VITE_PAYMENT_TOKEN_ADDRESS",
  import.meta.env.VITE_PAYMENT_TOKEN_ADDRESS,
) as Hex;
export const sonarHomeURL = new URL(`/sonar/${saleUUID}/home`, sonarConfig.frontendURL);
export const baseRPCURL = import.meta.env.VITE_BASE_RPC_URL || undefined;
