import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";
import { nodePolyfills } from "vite-plugin-node-polyfills";
import { fileURLToPath } from "url";
import { dirname, resolve } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));

const warnMissingRpcUrl: Plugin = {
  name: "warn-missing-rpc-url",
  configResolved(config) {
    if (config.command === 'serve' && !config.env.VITE_RPC_URL) {
      console.warn(
        '[sonar-example] No RPC URL configured. The app is using the public Solana devnet ' +
        'endpoint, which is rate-limited. Set VITE_RPC_URL in your .env file.'
      );
    }
  },
};

export default defineConfig({
  plugins: [react(), nodePolyfills(), warnMissingRpcUrl],
  server: {
    port: 3000,
  },
  resolve: {
    alias: {
      "@": "/src",
      "@shared": resolve(__dirname, "../../shared"),
    },
  },
});
