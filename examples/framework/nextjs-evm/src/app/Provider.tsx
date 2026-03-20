"use client";

import { WagmiProvider, createConfig, http } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ConnectKitProvider, getDefaultConfig } from "connectkit";
import { baseSepolia } from "wagmi/chains";
import { SessionProvider } from "./hooks/use-session";
import { sonarConfig } from "@/lib/config";
import { SonarProvider } from "@echoxyz/sonar-react";

const config = createConfig(
  getDefaultConfig({
    chains: [baseSepolia],
    transports: {
      [baseSepolia.id]: http(),
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
