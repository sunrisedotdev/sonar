/**
 * Token store interface for managing Sonar OAuth tokens.
 * This interface allows swapping between in-memory and persistent storage implementations.
 */
export interface SonarTokens {
  accessToken: string;
  refreshToken: string;
  expiresAt: number; // Unix timestamp in seconds
}

export interface TokenStore {
  /**
   * Store tokens for a user identifier
   */
  setTokens(userId: string, tokens: SonarTokens): void;

  /**
   * Retrieve tokens for a user identifier
   */
  getTokens(userId: string): SonarTokens | null;

  /**
   * Remove tokens for a user identifier
   */
  clearTokens(userId: string): void;
}

/**
 * In-memory token store implementation.
 * Tokens are stored in a Map and will be lost on server restart.
 * This can be easily swapped for a database-backed implementation.
 */
class InMemoryTokenStore implements TokenStore {
  private tokens: Map<string, SonarTokens> = new Map();

  setTokens(userId: string, tokens: SonarTokens): void {
    this.tokens.set(userId, tokens);
  }

  getTokens(userId: string): SonarTokens | null {
    return this.tokens.get(userId) || null;
  }

  clearTokens(userId: string): void {
    this.tokens.delete(userId);
  }
}

// Singleton instance - can be swapped for a different implementation
let tokenStoreInstance: TokenStore | null = null;

/**
 * Get the token store instance.
 * This factory function allows swapping implementations without changing call sites.
 */
export function getTokenStore(): TokenStore {
  if (!tokenStoreInstance) {
    tokenStoreInstance = new InMemoryTokenStore();
  }
  return tokenStoreInstance;
}

/**
 * Set a custom token store implementation.
 * Useful for swapping to a database-backed store.
 */
export function setTokenStore(store: TokenStore): void {
  tokenStoreInstance = store;
}
