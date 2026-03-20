"use client";

import { useSession } from "@/app/hooks/use-session";
import { getSonarAuthorizationUrl, disconnectSonar } from "@/app/actions/auth";

export function AuthenticationSection() {
  const { authenticated, sonarConnected, loading, login, logout } = useSession();

  const handleConnectSonar = async () => {
    try {
      const url = await getSonarAuthorizationUrl();
      window.location.href = url;
    } catch (error) {
      console.error("Failed to get Sonar authorization URL:", error);
    }
  };

  const handleDisconnectSonar = async () => {
    try {
      await disconnectSonar();
      window.location.reload();
    } catch (error) {
      console.error("Failed to disconnect Sonar:", error);
    }
  };

  if (loading) {
    return (
      <div className="p-6 bg-blue-50 rounded-lg border border-blue-200">
        <p className="text-gray-600">Loading...</p>
      </div>
    );
  }

  if (!authenticated) {
    return (
      <div className="p-6 bg-blue-50 rounded-lg border border-blue-200">
        <div className="flex flex-col gap-3">
          <p className="text-gray-600">Login to continue.</p>
          <button
            onClick={login}
            className="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded-lg transition-colors w-fit"
          >
            Login
          </button>
        </div>
      </div>
    );
  }

  if (!sonarConnected) {
    return (
      <div className="p-6 bg-blue-50 rounded-lg border border-blue-200">
        <div className="flex flex-col gap-3">
          <div className="flex flex-row justify-between items-center gap-4">
            <p className="text-gray-600">Connect your Sonar account to check your eligibility status.</p>
            <button onClick={logout} className="text-sm text-gray-500 hover:text-gray-700 underline">
              Logout
            </button>
          </div>
          <button
            onClick={handleConnectSonar}
            className="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded-lg transition-colors w-fit"
          >
            Connect with Sonar
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 bg-blue-50 rounded-lg border border-blue-200">
      <div className="flex flex-row justify-between items-center flex-wrap gap-2">
        <p className="text-green-600 font-medium">✓ Sonar Connected</p>
        <div className="flex gap-4">
          <button onClick={handleDisconnectSonar} className="text-sm text-gray-500 hover:text-gray-700 underline">
            Disconnect Sonar
          </button>
          <button onClick={logout} className="text-sm text-gray-500 hover:text-gray-700 underline">
            Logout
          </button>
        </div>
      </div>
    </div>
  );
}
