import { beforeEach, describe, expect, it, vi } from "vitest";
import { APIError, SonarClient } from "../src/client";
import { AuthSession } from "../src/auth";
import { createMemoryStorage } from "../src/storage";

type MockResponseInit = {
    status: number;
    json?: unknown;
    text?: string;
    headers?: Record<string, string>;
};

function mockResponse(init: MockResponseInit): Response {
    const body = init.json !== undefined ? JSON.stringify(init.json) : (init.text ?? "");
    return new Response(body, { status: init.status, headers: init.headers });
}

function makeJwt(payload: Record<string, unknown>) {
    const header = { alg: "none", typ: "JWT" };
    const toB64Url = (obj: unknown) =>
        Buffer.from(JSON.stringify(obj)).toString("base64").replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
    return `${toB64Url(header)}.${toB64Url(payload)}.`;
}

describe("SonarClient", () => {
    const apiURL = "https://api.example.test";
    let auth: AuthSession;

    beforeEach(() => {
        auth = new AuthSession({ storage: createMemoryStorage() });
        vi.restoreAllMocks();
    });

    it("uses provided fetch before global", async () => {
        const localFetch = vi.fn(async () => mockResponse({ status: 200, json: { ok: true } }));
        const client = new SonarClient({ apiURL, opts: { fetch: localFetch, auth } });
        await client.readEntity({ saleUUID: "s", walletAddress: "w" });
        expect(localFetch).toHaveBeenCalledTimes(1);
    });

    it("throws if no fetch available", () => {
        const original = globalThis.fetch;
        (globalThis as any).fetch = undefined;
        try {
            expect(() =>
                new SonarClient({ apiURL, opts: { auth } }).readEntity({ saleUUID: "s", walletAddress: "w" }),
            ).toThrowError(/No fetch implementation/);
        } finally {
            (globalThis as any).fetch = original;
        }
    });

    it("adds authorization header when token present", async () => {
        const expMs = Date.now() + 60_000;
        auth.setToken(makeJwt({ exp: Math.floor(expMs / 1000) }));
        const fetchSpy = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
            const req = input as URL;
            expect(req.toString()).toBe(`${apiURL}/externalapi.ReadEntity`);
            expect(init?.headers).toMatchObject({
                "Content-Type": "application/json",
                authorization: expect.stringContaining("api:Bearer"),
            });
            return mockResponse({ status: 200, json: { Entities: [] } });
        });
        const client = new SonarClient({ apiURL, opts: { fetch: fetchSpy, auth } });
        await client.readEntity({ saleUUID: "s", walletAddress: "w" });
        expect(fetchSpy).toHaveBeenCalledTimes(1);
    });

    it("omits authorization header when no token", async () => {
        const fetchSpy = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
            expect((init?.headers as Record<string, string>).authorization).toBeUndefined();
            return mockResponse({ status: 200, json: { Entities: [] } });
        });
        const client = new SonarClient({ apiURL, opts: { fetch: fetchSpy, auth } });
        await client.readEntity({ saleUUID: "s", walletAddress: "w" });
    });

    it("parses successful JSON responses", async () => {
        const fetchSpy = vi.fn(async () => mockResponse({ status: 200, json: { Entity: { id: 1 } } }));
        const client = new SonarClient({ apiURL, opts: { fetch: fetchSpy, auth } });
        const res = await client.readEntity({ saleUUID: "s", walletAddress: "w" });
        expect(res.Entity).not.toBeUndefined();
    });

    it("throws APIError with parsed message/code/details on failure", async () => {
        const fetchSpy = vi.fn(async () =>
            mockResponse({ status: 400, json: { message: "bad", code: "BadRequest", extra: 1 } }),
        );
        const client = new SonarClient({ apiURL, opts: { fetch: fetchSpy, auth } });
        await expect(client.readEntity({ saleUUID: "s", walletAddress: "w" })).rejects.toMatchObject({
            status: 400,
            message: "bad",
            code: "BadRequest",
        });
        await expect(client.readEntity({ saleUUID: "s", walletAddress: "w" })).rejects.toHaveProperty("details");
    });

    it("falls back to text details when invalid JSON on error", async () => {
        const fetchSpy = vi.fn(async () => mockResponse({ status: 500, text: "oops" }));
        const client = new SonarClient({ apiURL, opts: { fetch: fetchSpy, auth } });
        await expect(client.readEntity({ saleUUID: "s", walletAddress: "w" })).rejects.toMatchObject({
            status: 500,
            message: expect.stringContaining("Request failed"),
            details: "oops",
        });
    });

    it("calls onUnauthorized on 401 before throwing", async () => {
        const onUnauthorized = vi.fn();
        const fetchSpy = vi.fn(async () => mockResponse({ status: 401, json: { message: "nope" } }));
        const client = new SonarClient({ apiURL, opts: { fetch: fetchSpy, auth, onUnauthorized } });
        await expect(client.readEntity({ saleUUID: "s", walletAddress: "w" })).rejects.toBeInstanceOf(APIError);
        expect(onUnauthorized).toHaveBeenCalledTimes(1);
    });

    it("sends correct payload shapes for helpers", async () => {
        const fetchSpy = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
            const body = JSON.parse(init!.body as string);
            // minimal check of keys
            if (body.Code !== undefined) {
                return mockResponse({ status: 200, json: { token: "t" } });
            }
            if (body.PurchasingWalletAddress) {
                return mockResponse({ status: 200, json: { Permit: {}, Signature: "sig" } });
            }
            if (body.WalletAddress) {
                return mockResponse({
                    status: 200,
                    json: { HasReservedAllocation: false, ReservedAmountUSD: "0", MaxAmountUSD: "0" },
                });
            }
            if (body.SaleUUID && Object.keys(body).length === 1) {
                return mockResponse({ status: 200, json: { Entities: [] } });
            }
            return mockResponse({ status: 200, json: {} });
        });

        const client = new SonarClient({ apiURL, opts: { fetch: fetchSpy, auth } });
        await client.exchangeAuthorizationCode({ code: "c", codeVerifier: "v", redirectURI: "u" });
        await client.generatePurchasePermit({
            saleUUID: "s",
            entityUUID: "e",
            walletAddress: "w",
        });
        await client.fetchAllocation({ saleUUID: "s", walletAddress: "w" });
        await client.readEntity({ saleUUID: "s", walletAddress: "w" });
        expect(fetchSpy).toHaveBeenCalledTimes(4);
    });
});
