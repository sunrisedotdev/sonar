import { Hex } from "@echoxyz/sonar-core";
import { SonarProviderConfig } from "@echoxyz/sonar-react";

export const sonarConfig: SonarProviderConfig & { apiURL: string } = {
  clientUUID: process.env.NEXT_PUBLIC_OAUTH_CLIENT_UUID ?? "",
  redirectURI: process.env.NEXT_PUBLIC_OAUTH_CLIENT_REDIRECT_URI ?? "",
  frontendURL: process.env.NEXT_PUBLIC_ECHO_FRONTEND_URL ?? "https://app.echo.xyz",
  apiURL: process.env.NEXT_PUBLIC_ECHO_API_URL ?? "https://api.echo.xyz",
};

export const saleUUID = process.env.NEXT_PUBLIC_SALE_UUID ?? "";
export const saleContract =
  (process.env.NEXT_PUBLIC_SALE_CONTRACT_ADDRESS as Hex) ?? "0x0000000000000000000000000000000000000000";
export const paymentTokenAddress =
  (process.env.NEXT_PUBLIC_PAYMENT_TOKEN_ADDRESS as Hex) ?? "0x0000000000000000000000000000000000000000";
export const sonarHomeURL = new URL(`/sonar/${saleUUID}/home`, sonarConfig.frontendURL);
