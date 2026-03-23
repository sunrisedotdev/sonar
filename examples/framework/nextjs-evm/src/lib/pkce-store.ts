/**
 * PKCE store interface for managing OAuth PKCE code verifiers.
 * This interface allows swapping between in-memory and persistent storage implementations.
 */
export interface PKCEEntry {
  sessionId: string;
  codeVerifier: string;
  expiresAt: number; // Unix timestamp in milliseconds
}

export interface PKCEStore {
  /**
   * Store PKCE verifier and session ID for a state token
   */
  setEntry(state: string, entry: PKCEEntry): void;

  /**
   * Retrieve PKCE entry for a state token
   */
  getEntry(state: string): PKCEEntry | null;

  /**
   * Remove PKCE entry for a state token
   */
  clearEntry(state: string): void;
}

/**
 * In-memory PKCE store implementation.
 * Entries are stored in a Map and will be lost on server restart.
 * This can be easily swapped for a database-backed implementation.
 */
class InMemoryPKCEStore implements PKCEStore {
  private entries: Map<string, PKCEEntry> = new Map();

  setEntry(state: string, entry: PKCEEntry): void {
    this.entries.set(state, entry);
  }

  getEntry(state: string): PKCEEntry | null {
    return this.entries.get(state) || null;
  }

  clearEntry(state: string): void {
    this.entries.delete(state);
  }
}

// Singleton instance - can be swapped for a different implementation
let pkceStoreInstance: PKCEStore | null = null;

/**
 * Get the PKCE store instance.
 * This factory function allows swapping implementations without changing call sites.
 */
export function getPKCEStore(): PKCEStore {
  if (!pkceStoreInstance) {
    pkceStoreInstance = new InMemoryPKCEStore();
  }
  return pkceStoreInstance;
}

/**
 * Set a custom PKCE store implementation.
 * Useful for swapping to a database-backed store.
 */
export function setPKCEStore(store: PKCEStore): void {
  pkceStoreInstance = store;
}

const PKCE_TTL_MS = 10 * 60 * 1000; // 10 minutes

/**
 * Store PKCE verifier and session ID linked to a state token
 */
export function setPKCEVerifier(state: string, sessionId: string, codeVerifier: string): void {
  getPKCEStore().setEntry(state, {
    sessionId,
    codeVerifier,
    expiresAt: Date.now() + PKCE_TTL_MS,
  });
}

/**
 * Get PKCE verifier and session ID for a state token
 */
export function getPKCEVerifier(state: string): { userId: string; codeVerifier: string } | null {
  const entry = getPKCEStore().getEntry(state);

  if (!entry) {
    return null;
  }

  // Check if expired
  if (entry.expiresAt < Date.now()) {
    getPKCEStore().clearEntry(state);
    return null;
  }

  return {
    userId: entry.sessionId,
    codeVerifier: entry.codeVerifier,
  };
}

/**
 * Clear state entry (called after successful token exchange)
 */
export function clearPKCEVerifier(state: string): void {
  getPKCEStore().clearEntry(state);
}
