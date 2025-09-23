import { beforeEach, describe, expect, it, vi } from "vitest";
import { AuthSession, decodeJwtExp, isExpired } from "../src/auth";
import { createMemoryStorage } from "../src/storage";

function makeJwt(payload: Record<string, unknown>) {
    const header = { alg: "none", typ: "JWT" };
    const toB64Url = (obj: unknown) =>
        Buffer.from(JSON.stringify(obj)).toString("base64").replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
    return `${toB64Url(header)}.${toB64Url(payload)}.`;
}

describe("decodeJwtExp", () => {
    it("returns undefined for invalid tokens", () => {
        expect(decodeJwtExp("")).toBeUndefined();
        expect(decodeJwtExp("a.b")).toBeUndefined();
        expect(decodeJwtExp("a.b.c")).toBeUndefined();
    });

    it("parses exp (seconds) into Date (ms)", () => {
        const expSec = Math.floor((Date.now() + 60_000) / 1000);
        const token = makeJwt({ exp: expSec });
        const d = decodeJwtExp(token);
        expect(d).toBeInstanceOf(Date);
        expect(Math.abs(d!.getTime() - expSec * 1000)).toBeLessThan(5);
    });
});

describe("isExpired", () => {
    it("treats invalid tokens as expired", () => {
        expect(isExpired("")).toBe(true);
    });

    it("respects skew and future exp", () => {
        const expMs = Date.now() + 10_000;
        const token = makeJwt({ exp: Math.floor(expMs / 1000) });
        expect(isExpired(token, 0)).toBe(false);
    });

    it("considers near-expiry within skew as expired", () => {
        const expMs = Date.now() + 3_000; // < default 5s skew
        const token = makeJwt({ exp: Math.floor(expMs / 1000) });
        expect(isExpired(token)).toBe(true);
    });
});

describe("AuthSession", () => {
    beforeEach(() => {
        vi.useFakeTimers();
        vi.setSystemTime(new Date("2020-01-01T00:00:00Z"));
    });

    it("stores, reads, and clears token with events", () => {
        const storage = createMemoryStorage();
        const onExpire = vi.fn();
        const s = new AuthSession({ storage, onExpire });

        const changes: Array<string | undefined> = [];
        s.onTokenChange((t) => changes.push(t));

        expect(s.getToken()).toBeUndefined();
        const token = makeJwt({ exp: Math.floor((Date.now() + 60_000) / 1000) });
        s.setToken(token);
        expect(storage.getItem("sonar:auth-token")).toBe(token);
        expect(s.getToken()).toBe(token);

        s.clear();
        expect(s.getToken()).toBeUndefined();
        expect(onExpire).toHaveBeenCalledTimes(1);
        expect(changes).toEqual([token, undefined]);
    });

    it("auto-clears on invalid token", () => {
        const storage = createMemoryStorage();
        const onExpire = vi.fn();
        const s = new AuthSession({ storage, onExpire });
        s.setToken("not-a-jwt");
        // scheduleExpiry sees invalid -> clear immediately
        expect(s.getToken()).toBeUndefined();
        expect(onExpire).toHaveBeenCalledTimes(1);
    });

    it("schedules expiry 5s early in browser only", () => {
        const storage = createMemoryStorage();
        const s = new AuthSession({ storage });
        const expMs = Date.now() + 20_000;
        s.setToken(makeJwt({ exp: Math.floor(expMs / 1000) }));
        // advance to just before early expiry
        vi.advanceTimersByTime(14_900); // 20s - 5s - 100ms
        expect(s.getToken()).toBeDefined();
        vi.advanceTimersByTime(200); // cross threshold
        expect(s.getToken()).toBeUndefined();
    });
});
