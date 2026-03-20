"use client";

import { createContext, useContext, useState, useEffect, useCallback, ReactNode } from "react";
import { login as loginAction, logout as logoutAction, getSessionStatus } from "@/app/actions/auth";

interface SessionState {
  authenticated: boolean;
  sonarConnected: boolean;
  loading: boolean;
}

interface SessionContextValue extends SessionState {
  login: () => Promise<void>;
  logout: () => Promise<void>;
  refreshSession: () => Promise<void>;
}

const SessionContext = createContext<SessionContextValue | null>(null);

export function SessionProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<SessionState>({
    authenticated: false,
    sonarConnected: false,
    loading: true,
  });

  const refreshSession = useCallback(async () => {
    try {
      const data = await getSessionStatus();
      setState({
        authenticated: data.authenticated,
        sonarConnected: data.sonarConnected,
        loading: false,
      });
    } catch {
      setState({
        authenticated: false,
        sonarConnected: false,
        loading: false,
      });
    }
  }, []);

  useEffect(() => {
    refreshSession();
  }, [refreshSession]);

  const login = useCallback(async () => {
    try {
      await loginAction();
      await refreshSession();
    } catch (error) {
      console.error("Login failed:", error);
    }
  }, [refreshSession]);

  const logout = useCallback(async () => {
    try {
      await logoutAction();
      await refreshSession();
    } catch (error) {
      console.error("Logout failed:", error);
    }
  }, [refreshSession]);

  return (
    <SessionContext.Provider value={{ ...state, login, logout, refreshSession }}>{children}</SessionContext.Provider>
  );
}

export function useSession() {
  const context = useContext(SessionContext);
  if (!context) {
    throw new Error("useSession must be used within a SessionProvider");
  }
  return context;
}
