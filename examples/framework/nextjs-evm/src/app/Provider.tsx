"use client";

import { WagmiProvider, createConfig, http } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ConnectKitProvider, getDefaultConfig } from "connectkit";
import { baseSepolia } from "wagmi/chains";
import { SessionProvider } from "./hooks/use-session";
import { sonarConfig, baseRPCURL } from "@/lib/config";
import { SonarProvider } from "@echoxyz/sonar-react";
import { useEffect } from "react";

const config = createConfig(
  getDefaultConfig({
    chains: [baseSepolia],
    transports: {
      [baseSepolia.id]: http(baseRPCURL),
    },

    // Required API Keys
    walletConnectProjectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID ?? "",

    // Required App Info
    appName: "Sonar Next.js example app",
    appDescription: "Next.js app showing how to integrate with the Sonar API via backend OAuth.",
  })
);

const queryClient = new QueryClient();

export const Provider = ({ children }: { children: React.ReactNode }) => {
  useEffect(() => {
    if (!baseRPCURL) {
      console.warn(
        '[sonar-example] No RPC URL configured. The app is using the public Base Sepolia ' +
        'endpoint, which is rate-limited. Set NEXT_PUBLIC_BASE_RPC_URL in your .env file. ' +
        'See .env.example for details.'
      );
    }
  }, []);

  return (
    <SessionProvider>
      {/* Only required for un-authenticated requests direct from the frontend (e.g. to read sale commitment data) */}
      <SonarProvider config={sonarConfig}>
        <WagmiProvider config={config}>
          <QueryClientProvider client={queryClient}>
            <ConnectKitProvider>{children}</ConnectKitProvider>
          </QueryClientProvider>
        </WagmiProvider>
      </SonarProvider>
    </SessionProvider>
  );
};
