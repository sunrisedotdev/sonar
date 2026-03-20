import { Hex } from "@echoxyz/sonar-core";
import { SonarProviderConfig } from "@echoxyz/sonar-react";

export const sonarConfig = {
  clientUUID: import.meta.env.VITE_OAUTH_CLIENT_UUID ?? "",
  redirectURI: import.meta.env.VITE_OAUTH_CLIENT_REDIRECT_URI ?? "",
  frontendURL: import.meta.env.VITE_ECHO_FRONTEND_URL ?? "https://app.echo.xyz",
  apiURL: import.meta.env.VITE_ECHO_API_URL ?? "https://api.echo.xyz",
} as SonarProviderConfig;

export const saleUUID = import.meta.env.VITE_SALE_UUID ?? "";
export const saleContract =
  (import.meta.env.VITE_SALE_CONTRACT_ADDRESS as Hex) ?? "0x0000000000000000000000000000000000000000";
export const paymentTokenAddress =
  (import.meta.env.VITE_PAYMENT_TOKEN_ADDRESS as Hex) ?? "0x0000000000000000000000000000000000000000";
export const sonarHomeURL = new URL(`/sonar/${saleUUID}/home`, sonarConfig.frontendURL);
