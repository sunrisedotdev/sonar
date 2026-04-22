"use client";

import { ConnectionProvider, WalletProvider } from "@solana/wallet-adapter-react";
import { WalletModalProvider } from "@solana/wallet-adapter-react-ui";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { SessionProvider } from "./hooks/use-session";
import { sonarConfig, RPC_URL } from "@/lib/config";
import { SonarProvider } from "@echoxyz/sonar-react";
import { useEffect } from "react";

const queryClient = new QueryClient();

export const Provider = ({ children }: { children: React.ReactNode }) => {
  useEffect(() => {
    if (!process.env.NEXT_PUBLIC_RPC_URL) {
      console.warn(
        '[sonar-example] No RPC URL configured. The app is using the public Solana devnet ' +
        'endpoint, which is rate-limited. Set NEXT_PUBLIC_RPC_URL in your .env file.'
      );
    }
  }, []);

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
