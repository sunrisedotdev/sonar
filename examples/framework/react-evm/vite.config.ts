import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "path";

const warnMissingRpcUrl: Plugin = {
  name: "warn-missing-rpc-url",
  configResolved(config) {
    if (config.command === 'serve' && !config.env.VITE_BASE_RPC_URL) {
      console.warn(
        '[sonar-example] No RPC URL configured. The app is using the public Base Sepolia ' +
        'endpoint, which is rate-limited. Set VITE_BASE_RPC_URL in your .env file.'
      );
    }
  },
};

export default defineConfig({
  plugins: [react(), warnMissingRpcUrl],
  server: {
    port: 3000,
  },
  resolve: {
    alias: {
      "@": resolve(__dirname, "./src"),
    },
    dedupe: ["react", "react-dom", "wagmi", "@echoxyz/sonar-core", "@echoxyz/sonar-react"],
  },
});
