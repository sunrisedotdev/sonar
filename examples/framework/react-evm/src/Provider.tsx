import { WagmiProvider, createConfig, http } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ConnectKitProvider, getDefaultConfig } from "connectkit";
import { SonarProvider } from "@echoxyz/sonar-react";
import { sonarConfig, baseRPCURL } from "./config";
import { baseSepolia } from "wagmi/chains";
import { useEffect } from "react";

const config = createConfig(
  getDefaultConfig({
    chains: [baseSepolia],
    transports: {
      [baseSepolia.id]: http(baseRPCURL),
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
  useEffect(() => {
    if (!baseRPCURL) {
      console.warn(
        '[sonar-example] No RPC URL configured. The app is using the public Base Sepolia ' +
        'endpoint, which is rate-limited. Set VITE_BASE_RPC_URL in your .env file.'
      );
    }
  }, []);

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
