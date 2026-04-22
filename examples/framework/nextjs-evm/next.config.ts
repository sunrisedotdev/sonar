import type { NextConfig } from "next";

if (!process.env.NEXT_PUBLIC_BASE_RPC_URL) {
  console.warn(
    '[sonar-example] No RPC URL configured. The app is using the public Base Sepolia ' +
    'endpoint, which is rate-limited. Set NEXT_PUBLIC_BASE_RPC_URL in your .env file.'
  );
}

const nextConfig: NextConfig = {
  /* config options here */
};

export default nextConfig;
