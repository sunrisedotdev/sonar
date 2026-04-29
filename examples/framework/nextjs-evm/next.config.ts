import type { NextConfig } from "next";
import { PHASE_DEVELOPMENT_SERVER } from "next/constants";

export default function config(phase: string): NextConfig {
  if (phase === PHASE_DEVELOPMENT_SERVER && !process.env.NEXT_PUBLIC_BASE_RPC_URL) {
    console.warn(
      '[sonar-example] No RPC URL configured. The app is using the public Base Sepolia ' +
      'endpoint, which is rate-limited. Set NEXT_PUBLIC_BASE_RPC_URL in your .env file.'
    );
  }

  return {
    transpilePackages: ["@examples/ui"],
    webpack(config) {
      config.resolve.symlinks = false;
      return config;
    },
  };
}
