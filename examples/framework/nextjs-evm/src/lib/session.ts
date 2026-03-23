/**
 * Simple session management using cookies.
 * Sessions are just random UUIDs - no authentication required.
 */
import { cookies } from "next/headers";
import { getTokenStore } from "./token-store";

const SESSION_COOKIE_NAME = "sonar_example_session_id";
const SESSION_COOKIE_MAX_AGE = 60 * 60 * 24 * 7; // 7 days

export interface Session {
  id: string;
  /** User identifier - in this example app, the same as the session ID */
  userId: string;
}

export async function getSession(): Promise<Session | null> {
  const cookieStore = await cookies();
  const sessionId = cookieStore.get(SESSION_COOKIE_NAME)?.value;

  if (!sessionId) {
    return null;
  }

  return { id: sessionId, userId: sessionId };
}

export async function createSession(): Promise<Session> {
  const cookieStore = await cookies();
  const sessionId = crypto.randomUUID();

  cookieStore.set(SESSION_COOKIE_NAME, sessionId, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "strict",
    maxAge: SESSION_COOKIE_MAX_AGE,
    path: "/",
  });

  return { id: sessionId, userId: sessionId };
}

export async function destroySession(): Promise<void> {
  const cookieStore = await cookies();
  const sessionId = cookieStore.get(SESSION_COOKIE_NAME)?.value;

  // Clear Sonar tokens if session exists
  if (sessionId) {
    getTokenStore().clearTokens(sessionId);
  }

  // Delete the session cookie
  cookieStore.delete(SESSION_COOKIE_NAME);
}
