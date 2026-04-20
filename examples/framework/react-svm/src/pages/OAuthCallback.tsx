import { useEffect, useRef, useState } from "react";
import { useSonarAuth } from "@echoxyz/sonar-react";

export function OAuthCallback() {
  const { authenticated, completeOAuth, ready } = useSonarAuth();
  const oauthCompletionTriggered = useRef(false);
  const [oauthError, setOAuthError] = useState<string | null>(null);
  const [timedOut, setTimedOut] = useState(false);

  // complete the oauth flow and exchange the code for an access token
  useEffect(() => {
    const processOAuthCallback = async () => {
      const params = new URLSearchParams(window.location.search);
      const code = params.get("code");
      const state = params.get("state");

      // the user is already authenticated, nothing to do
      if (!ready || authenticated || !code || !state) {
        return;
      }

      // ensuring the oauth completion isn't called multiple times since subsequent ones are expected to fail
      if (oauthCompletionTriggered.current) {
        return;
      }
      oauthCompletionTriggered.current = true;

      try {
        await completeOAuth({ code, state });
      } catch (err) {
        setOAuthError(err instanceof Error ? err.message : null);
      }
    };

    processOAuthCallback();
  }, [authenticated, completeOAuth, ready]);

  // fetch the user's available entities after they've been authenticated
  useEffect(() => {
    if (!ready || !authenticated) {
      return;
    }

    // Redirect to the stored return path, or default to home
    const returnPath = localStorage.getItem("sonar_oauth_return_path");
    if (returnPath) {
      localStorage.removeItem("sonar_oauth_return_path");
      window.location.href = returnPath;
    } else {
      window.location.href = "/";
    }
  }, [authenticated, ready]);

  // set a timeout, so we don't keep the user waiting indefinitely in case of an unexpected issue
  useEffect(() => {
    setTimedOut(false);
    const timeoutId = setTimeout(() => setTimedOut(true), 20000);
    return () => clearTimeout(timeoutId);
  }, [setTimedOut]);

  if (timedOut) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <h2 className="text-xl font-semibold text-red-600 mb-2">Timed out</h2>
          <button
            onClick={() => (window.location.href = "/")}
            className="mt-4 px-4 py-2 bg-gray-50 text-gray-900 rounded-xl cursor-pointer"
          >
            Return to Login
          </button>
        </div>
      </div>
    );
  }

  if (oauthError) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <h2 className="text-xl font-semibold text-red-600 mb-2">{oauthError}</h2>
          <button
            onClick={() => (window.location.href = "/")}
            className="mt-4 px-4 py-2 bg-gray-50 text-gray-900 rounded-xl cursor-pointer"
          >
            Return to Login
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="text-center">
        <h2 className="text-xl font-semibold mb-4 text-white">Connecting to Echo</h2>
      </div>
    </div>
  );
}
