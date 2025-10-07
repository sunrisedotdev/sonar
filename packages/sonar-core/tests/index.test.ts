import { describe, expect, it, vi } from "vitest";
import { createClient } from "../src/index";
import { AuthSession } from "../src/auth";

function makeJwt(payload: Record<string, unknown>) {
    const header = { alg: "none", typ: "JWT" };
    const toB64Url = (obj: unknown) =>
        Buffer.from(JSON.stringify(obj)).toString("base64").replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
    return `${toB64Url(header)}.${toB64Url(payload)}.`;
}

describe("createClient", () => {
    it("creates client with default api url and token change wiring", async () => {
        const onTokenChange = vi.fn();
        const originalFetch = globalThis.fetch;
        (globalThis as { fetch: unknown }).fetch = vi.fn(async () => new Response(JSON.stringify({ Entities: [] }), { status: 200 }));
        try {
            const client = createClient({ saleUUID: "sale", onTokenChange });
            await client.readEntity({ saleUUID: "sale", walletAddress: "w" });
            expect(globalThis.fetch).toHaveBeenCalledTimes(1);
            // ensure token change propagation works
            client.setToken(makeJwt({ exp: Math.floor((Date.now() + 60000) / 1000) }));
            expect(onTokenChange).toHaveBeenCalledTimes(1);
        } finally {
            (globalThis as { fetch: unknown }).fetch = originalFetch;
        }
    });

    it("respects custom apiURL and accepts provided AuthSession", async () => {
        const apiURL = "https://custom.example";
        const onExpire = vi.fn();
        const auth = new AuthSession({
            storage: { getItem: () => null, setItem: () => {}, removeItem: () => {} },
            onExpire,
        });
        const fetchSpy = vi.fn(async (input: RequestInfo | URL) => {
            const u = input as URL;
            expect(u.toString()).toBe(`${apiURL}/externalapi.ReadEntity`);
            return new Response(JSON.stringify({ Entities: [] }), { status: 200 });
        });
        const client = createClient({ saleUUID: "sale", apiURL, auth, fetch: fetchSpy });
        await client.readEntity({ saleUUID: "sale", walletAddress: "w" });
        expect(fetchSpy).toHaveBeenCalledTimes(1);
        // onExpire should be called when clear happens due to unauthorized
        const unauthorizedFetch = vi.fn(async () => new Response(JSON.stringify({ message: "nope" }), { status: 401 }));
        const client2 = createClient({ saleUUID: "sale", apiURL, auth, fetch: unauthorizedFetch });
        await expect(client2.readEntity({ saleUUID: "sale", walletAddress: "w" })).rejects.toBeInstanceOf(Error);
        // clear triggers onExpire
        expect(onExpire).toHaveBeenCalledTimes(1);
    });
});
