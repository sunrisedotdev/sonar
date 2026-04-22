import { ConnectionProvider, WalletProvider } from "@solana/wallet-adapter-react";
import { WalletModalProvider } from "@solana/wallet-adapter-react-ui";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { SonarProvider } from "@echoxyz/sonar-react";
import { sonarConfig, RPC_URL } from "./config";

const queryClient = new QueryClient();

export function Provider({ children }: { children: React.ReactNode }) {
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
