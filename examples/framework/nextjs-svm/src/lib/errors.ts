/**
 * Error thrown when a user is not authenticated or their Sonar connection is invalid.
 * Consumers can check for this error type to trigger re-authentication.
 */
export class UnauthorizedError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "UnauthorizedError";
  }
}
