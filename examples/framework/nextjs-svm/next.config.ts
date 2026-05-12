import type { NextConfig } from "next";
import { PHASE_DEVELOPMENT_SERVER } from "next/constants";
import { resolve } from "path";

export default function config(phase: string): NextConfig {
  if (phase === PHASE_DEVELOPMENT_SERVER && !process.env.NEXT_PUBLIC_RPC_URL) {
    console.warn(
      '[sonar-example] No RPC URL configured. The app is using the public Solana devnet ' +
      'endpoint, which is rate-limited. Set NEXT_PUBLIC_RPC_URL in your .env file.'
    );
  }

  return {
    webpack: (config) => {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
        os: false,
        path: false,
      };
      config.resolve.alias = {
        ...config.resolve.alias,
        "@coral-xyz/anchor": resolve(__dirname, "node_modules/@coral-xyz/anchor"),
      };
      // Some Solana dependencies pull in optional Node.js-only packages
      config.externals.push("pino-pretty", "encoding");
      return config;
    },
  };
}
