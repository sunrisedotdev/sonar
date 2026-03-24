import type { NextConfig } from "next";

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
