import { WagmiProvider, createConfig, http } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ConnectKitProvider, getDefaultConfig } from "connectkit";
import { SonarProvider } from "@echoxyz/sonar-react";
import { sonarConfig } from "./config";
import { baseSepolia } from "wagmi/chains";

const config = createConfig(
  getDefaultConfig({
    chains: [baseSepolia],
    transports: {
      [baseSepolia.id]: http(),
    },

    // Required API Keys
    walletConnectProjectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID ?? "",

    // Required App Info
    appName: "Sonar React example app",
    appDescription:
      "React app showing how to integrate with the Sonar API via the sonar-react and sonar-core libraries.",
  })
);

const queryClient = new QueryClient();

export function Provider({ children }: { children: React.ReactNode }) {
  return (
    <SonarProvider config={sonarConfig}>
      <WagmiProvider config={config}>
        <QueryClientProvider client={queryClient}>
          <ConnectKitProvider>{children}</ConnectKitProvider>
        </QueryClientProvider>
      </WagmiProvider>
    </SonarProvider>
  );
}
