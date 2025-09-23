import type { StorageLike } from "./storage";

function safeDecodeExp(token: string): number | undefined {
    if (typeof token !== "string") {
        return undefined;
    }
    const parts = token.split(".");
    if (parts.length !== 3) {
        return undefined;
    }
    try {
        // Decode base64url (RFC 7515) to base64
        let base64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
        const payload = JSON.parse(atob(base64));
        const exp = payload?.exp;
        if (typeof exp === "number" && isFinite(exp)) {
            return exp * 1000;
        }
        return undefined;
    } catch {
        return undefined;
    }
}

export function decodeJwtExp(token: string): Date | undefined {
    const ms = safeDecodeExp(token);
    return ms ? new Date(ms) : undefined;
}

export function isExpired(token: string, skewMs: number = 5000): boolean {
    const expMs = safeDecodeExp(token);
    if (!expMs) {
        return true;
    }
    return expMs - skewMs <= Date.now();
}

type Listener = (token?: string) => void;

export class AuthSession {
    private storage: StorageLike;
    private readonly tokenKey: string;
    private onExpire?: () => void;
    private listeners: Set<Listener> = new Set();
    private expiryTimer?: number;

    constructor(opts: { storage: StorageLike; tokenKey?: string; onExpire?: () => void }) {
        this.storage = opts.storage;
        this.tokenKey = opts.tokenKey ?? "sonar:auth-token";
        this.onExpire = opts.onExpire;

        const token = this.getToken();
        if (token) {
            this.scheduleExpiry(token);
        }
    }

    setToken(token: string): void {
        this.storage.setItem(this.tokenKey, token);
        this.clearTimer();
        this.scheduleExpiry(token);
        this.emit(token);
    }

    getToken(): string | undefined {
        const v = this.storage.getItem(this.tokenKey);
        return v ?? undefined;
    }

    clear(): void {
        this.storage.removeItem(this.tokenKey);
        this.clearTimer();
        this.emit(undefined);
        if (this.onExpire) {
            this.onExpire();
        }
    }

    onTokenChange(cb: Listener): () => void {
        this.listeners.add(cb);
        return () => this.listeners.delete(cb);
    }

    private emit(token?: string) {
        for (const cb of this.listeners) {
            try {
                cb(token);
            } catch {
                // ignore listener errors
            }
        }
    }

    private clearTimer() {
        if (this.expiryTimer !== undefined) {
            clearTimeout(this.expiryTimer);
            this.expiryTimer = undefined;
        }
    }

    private scheduleExpiry(token: string) {
        const exp = decodeJwtExp(token);
        if (!exp) {
            this.clear();
            return;
        }
        const delay = Math.max(0, exp.getTime() - Date.now() - 5000);
        if (typeof window !== "undefined") {
            this.expiryTimer = window.setTimeout(() => this.clear(), delay);
        }
    }
}
