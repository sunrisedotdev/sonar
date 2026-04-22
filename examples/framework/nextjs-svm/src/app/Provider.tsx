"use client";

import { ConnectionProvider, WalletProvider } from "@solana/wallet-adapter-react";
import { WalletModalProvider } from "@solana/wallet-adapter-react-ui";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { SessionProvider } from "./hooks/use-session";
import { sonarConfig, RPC_URL } from "@/lib/config";
import { SonarProvider } from "@echoxyz/sonar-react";

const queryClient = new QueryClient();

export const Provider = ({ children }: { children: React.ReactNode }) => {
  return (
    <SessionProvider>
      {/* Only required for un-authenticated requests direct from the frontend (e.g. to read sale commitment data) */}
      <SonarProvider config={sonarConfig}>
        <ConnectionProvider endpoint={RPC_URL}>
          <WalletProvider wallets={[]} autoConnect>
            <WalletModalProvider>
              <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
            </WalletModalProvider>
          </WalletProvider>
        </ConnectionProvider>
      </SonarProvider>
    </SessionProvider>
  );
};
