import { ConnectionProvider, WalletProvider } from "@solana/wallet-adapter-react";
import { WalletModalProvider } from "@solana/wallet-adapter-react-ui";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { SonarProvider } from "@echoxyz/sonar-react";
import { sonarConfig, RPC_URL } from "./config";
import { useEffect } from "react";

const queryClient = new QueryClient();

export function Provider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    if (!import.meta.env.VITE_RPC_URL) {
      console.warn(
        '[sonar-example] No RPC URL configured. The app is using the public Solana devnet ' +
        'endpoint, which is rate-limited. Set VITE_RPC_URL in your .env file.'
      );
    }
  }, []);

  return (
    <SonarProvider config={sonarConfig}>
      <ConnectionProvider endpoint={RPC_URL}>
        <WalletProvider wallets={[]} autoConnect>
          <WalletModalProvider>
            <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
          </WalletModalProvider>
        </WalletProvider>
      </ConnectionProvider>
    </SonarProvider>
  );
}
