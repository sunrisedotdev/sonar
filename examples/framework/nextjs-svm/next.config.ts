import type { NextConfig } from "next";

if (!process.env.NEXT_PUBLIC_RPC_URL) {
  console.warn(
    '[sonar-example] No RPC URL configured. The app is using the public Solana devnet ' +
    'endpoint, which is rate-limited. Set NEXT_PUBLIC_RPC_URL in your .env file.'
  );
}

const nextConfig: NextConfig = {
  webpack: (config) => {
    config.resolve.fallback = {
      ...config.resolve.fallback,
      fs: false,
      os: false,
      path: false,
    };
    // Some Solana dependencies pull in optional Node.js-only packages
    config.externals.push("pino-pretty", "encoding");
    return config;
  },
};

export default nextConfig;
