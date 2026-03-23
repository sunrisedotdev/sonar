import { getSession } from "@/lib/session";
import { getTokenStore, SonarTokens } from "@/lib/token-store";
import { sonarConfig } from "@/lib/config";
import { createClient, SonarClient } from "@echoxyz/sonar-core";
import { UnauthorizedError } from "@/lib/errors";

// Re-export for backwards compatibility
export { UnauthorizedError } from "@/lib/errors";

/**
 * Create a SonarClient instance for a specific user
 * Sets the access token from our server-side token store
 */
export function createSonarClient(userId: string): SonarClient {
  // Create a new client instance
  const client = createClient({
    apiURL: sonarConfig.apiURL,
    onUnauthorized: () => {
      // Clear tokens on unauthorized
      getTokenStore().clearTokens(userId);
    },
  });

  // Set the token from our server-side store
  const tokens = getTokenStore().getTokens(userId);
  if (tokens?.accessToken) {
    client.setToken(tokens.accessToken);
  }

  return client;
}

// In-flight refresh promises by session ID - prevents concurrent refresh attempts
const refreshPromises = new Map<string, Promise<SonarTokens>>();

/**
 * Refresh Sonar access token using refresh token.
 * Uses promise coalescing to prevent concurrent refresh attempts for the same session.
 */
async function refreshSonarToken(sessionId: string, refreshToken: string): Promise<SonarTokens> {
  // If a refresh is already in-flight for this session, reuse it
  const existing = refreshPromises.get(sessionId);
  if (existing) {
    return existing;
  }

  const doRefresh = async (): Promise<SonarTokens> => {
    const client = createClient({ apiURL: sonarConfig.apiURL });

    const tokenData = await client.refreshToken({ refreshToken });
    const expiresAt = Math.floor(Date.now() / 1000) + tokenData.expires_in;

    return {
      accessToken: tokenData.access_token,
      refreshToken: tokenData.refresh_token || refreshToken,
      expiresAt,
    };
  };

  const promise = doRefresh();
  refreshPromises.set(sessionId, promise);

  try {
    const result = await promise;
    return result;
  } finally {
    refreshPromises.delete(sessionId);
  }
}

type ServerActionHandler<I, O> = (client: SonarClient, input: I) => Promise<O>;

/**
 * Creates a Sonar server action with authentication, token refresh, and error handling.
 * Throws on errors instead of returning error objects.
 */
export function createSonarServerAction<I, O>(handler: ServerActionHandler<I, O>): (input: I) => Promise<O> {
  return async (input: I) => {
    // Check session authentication
    const session = await getSession();
    if (!session) {
      throw new UnauthorizedError("Unauthorized");
    }

    // Get tokens from store
    let tokens = getTokenStore().getTokens(session.userId);
    if (!tokens) {
      throw new UnauthorizedError("Sonar account not connected");
    }

    // Check if token needs refresh (within 5 minutes of expiry)
    const now = Math.floor(Date.now() / 1000);
    if (tokens.expiresAt - now < 300) {
      try {
        tokens = await refreshSonarToken(session.userId, tokens.refreshToken);
        getTokenStore().setTokens(session.userId, tokens);
      } catch {
        throw new UnauthorizedError("Failed to refresh token");
      }
    }

    const client = createSonarClient(session.userId);
    return handler(client, input);
  };
}
