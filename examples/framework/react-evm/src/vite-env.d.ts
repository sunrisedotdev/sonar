/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_WALLETCONNECT_PROJECT_ID: string;
  readonly VITE_OAUTH_CLIENT_UUID: string;
  readonly VITE_OAUTH_CLIENT_REDIRECT_URI: string;
  readonly VITE_ECHO_FRONTEND_URL: string;
  readonly VITE_ECHO_API_URL: string;
  readonly VITE_SALE_UUID: string;
  readonly VITE_SALE_CONTRACT_ADDRESS: string;
}
