import { beforeEach, describe, expect, it, vi } from "vitest";
import {
    AllocationResponse,
    APIError,
    GeneratePurchasePermitResponse,
    ListAvailableEntitiesResponse,
    ReadEntityResponse,
    SonarClient,
} from "../src/client";
import { AuthSession } from "../src/auth";
import { createMemoryStorage } from "../src/storage";
import { EntityType, EntitySetupState, SaleEligibility, InvestingRegion, EntityDetails } from "../src/types";

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
        (globalThis as { fetch: unknown }).fetch = undefined;
        try {
            expect(() =>
                new SonarClient({ apiURL, opts: { auth } }).readEntity({ saleUUID: "s", walletAddress: "w" }),
            ).toThrowError(/No fetch implementation/);
        } finally {
            (globalThis as { fetch: unknown }).fetch = original;
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

    it("sends correct payload for exchangeAuthorizationCode", async () => {
        const fetchSpy = vi.fn(async (input: RequestInfo | URL) => {
            const url = input as URL;
            expect(url.pathname).toBe("/oauth.ExchangeAuthorizationCodeV2");
            return mockResponse({ status: 200, json: { token: "t" } });
        });

        const client = new SonarClient({ apiURL, opts: { fetch: fetchSpy, auth } });
        const token = await client.exchangeAuthorizationCode({ code: "c", codeVerifier: "v", redirectURI: "u" });

        expect(token).toEqual({ token: "t" } satisfies { token: string });
    });

    it("sends correct payload for generatePurchasePermit with basic permit", async () => {
        const fetchSpy = vi.fn(async (input: RequestInfo | URL) => {
            const url = input as URL;
            expect(url.pathname).toBe("/externalapi.GenerateSalePurchasePermit");
            return mockResponse({
                status: 200,
                json: {
                    PermitJSON: {
                        EntityID: "0xe",
                        SaleUUID: "0xs",
                        Wallet: "0xw",
                        ExpiresAt: 0,
                        MinAmount: "100",
                        MaxAmount: "5000",
                        MinPrice: 100,
                        MaxPrice: 5000,
                        Payload: "0xp",
                    },
                    Signature: "0xsig",
                },
            });
        });

        const client = new SonarClient({ apiURL, opts: { fetch: fetchSpy, auth } });
        const permit = await client.generatePurchasePermit({
            saleUUID: "s",
            entityID: "0xe",
            walletAddress: "w",
        });

        expect(permit).toEqual({
            PermitJSON: {
                EntityID: "0xe",
                SaleUUID: "0xs",
                Wallet: "0xw",
                ExpiresAt: 0,
                MinAmount: "100",
                MaxAmount: "5000",
                MinPrice: 100,
                MaxPrice: 5000,
                Payload: "0xp",
            },
            Signature: "0xsig",
        } satisfies GeneratePurchasePermitResponse);
    });

    it("sends correct payload for generatePurchasePermit with allocation permit", async () => {
        const fetchSpy = vi.fn(async (input: RequestInfo | URL) => {
            const url = input as URL;
            expect(url.pathname).toBe("/externalapi.GenerateSalePurchasePermit");
            return mockResponse({
                status: 200,
                json: {
                    PermitJSON: {
                        EntityID: "0xe",
                        SaleUUID: "0xs",
                        Wallet: "0xw",
                        ExpiresAt: 0,
                        MinAmount: "100",
                        MaxAmount: "5000",
                        MinPrice: 100,
                        MaxPrice: 5000,
                        Payload: "0xp",
                    },
                    Signature: "0xsig",
                },
            });
        });

        const client = new SonarClient({ apiURL, opts: { fetch: fetchSpy, auth } });
        const permit = await client.generatePurchasePermit({
            saleUUID: "s",
            entityID: "0xe",
            walletAddress: "w",
        });

        expect(permit).toEqual({
            PermitJSON: {
                EntityID: "0xe",
                SaleUUID: "0xs",
                Wallet: "0xw",
                ExpiresAt: 0,
                MinAmount: "100",
                MaxAmount: "5000",
                MinPrice: 100,
                MaxPrice: 5000,
                Payload: "0xp",
            },
            Signature: "0xsig",
        } satisfies GeneratePurchasePermitResponse);
    });

    it("sends correct payload for fetchAllocation", async () => {
        const fetchSpy = vi.fn(async (input: RequestInfo | URL) => {
            const url = input as URL;
            expect(url.pathname).toBe("/externalapi.Allocation");
            return mockResponse({
                status: 200,
                json: { HasReservedAllocation: false, ReservedAmountUSD: "0", MaxAmountUSD: "0" },
            });
        });

        const client = new SonarClient({ apiURL, opts: { fetch: fetchSpy, auth } });
        const allocation = await client.fetchAllocation({ saleUUID: "s", walletAddress: "w" });

        expect(allocation).toEqual({
            HasReservedAllocation: false,
            ReservedAmountUSD: "0",
            MaxAmountUSD: "0",
        } satisfies AllocationResponse);
    });

    it("sends correct payload for readEntity", async () => {
        const fetchSpy = vi.fn(async (input: RequestInfo | URL) => {
            const url = input as URL;
            expect(url.pathname).toBe("/externalapi.ReadEntity");
            return mockResponse({
                status: 200,
                json: {
                    Entity: {
                        Label: "Test Entity",
                        EntityID: "abcde",
                        SaleSpecificEntityID: "0x1234",
                        EntityType: EntityType.USER,
                        EntitySetupState: EntitySetupState.COMPLETE,
                        SaleEligibility: SaleEligibility.ELIGIBLE,
                        InvestingRegion: InvestingRegion.US,
                    },
                },
            });
        });

        const client = new SonarClient({ apiURL, opts: { fetch: fetchSpy, auth } });
        const entity = await client.readEntity({ saleUUID: "s", walletAddress: "w" });

        expect(entity).toEqual({
            Entity: {
                Label: "Test Entity",
                EntityID: "abcde",
                SaleSpecificEntityID: "0x1234",
                EntityType: EntityType.USER,
                EntitySetupState: EntitySetupState.COMPLETE,
                SaleEligibility: SaleEligibility.ELIGIBLE,
                InvestingRegion: InvestingRegion.US,
            },
        } satisfies ReadEntityResponse);
    });

    it("sends correct payload for listAvailableEntities", async () => {
        const fetchSpy = vi.fn(async (input: RequestInfo | URL) => {
            const url = input as URL;
            expect(url.pathname).toBe("/externalapi.ListAvailableEntities");
            return mockResponse({
                status: 200,
                json: {
                    Entities: [
                        {
                            Label: "Test Entity",
                            EntityID: "abcde",
                            EntityType: EntityType.USER,
                            SaleSpecificEntityID: "0x1234",
                            EntitySetupState: EntitySetupState.COMPLETE,
                            SaleEligibility: SaleEligibility.ELIGIBLE,
                            InvestingRegion: InvestingRegion.US,
                        },
                    ],
                },
            });
        });

        const client = new SonarClient({ apiURL, opts: { fetch: fetchSpy, auth } });
        const entities = await client.listAvailableEntities({ saleUUID: "s" });

        expect(entities).toEqual({
            Entities: [
                {
                    Label: "Test Entity",
                    EntityID: "abcde",
                    SaleSpecificEntityID: "0x1234",
                    EntityType: EntityType.USER,
                    EntitySetupState: EntitySetupState.COMPLETE,
                    SaleEligibility: SaleEligibility.ELIGIBLE,
                    InvestingRegion: InvestingRegion.US,
                },
            ],
        } satisfies ListAvailableEntitiesResponse);
    });


    it("client method arguments are compatible with EntityDetails types", async () => {
        const fetchSpy = vi.fn(async (input: RequestInfo | URL) => {
            const url = input as URL;
            return mockResponse({
                status: 200,
                json: {},
            });
        });

        const client = new SonarClient({ apiURL, opts: { fetch: fetchSpy, auth } });
        const details: EntityDetails = {
            Label: "Test Entity",
            EntityID: "abcde",
            SaleSpecificEntityID: "0x1234",
            EntityType: EntityType.USER,
            EntitySetupState: EntitySetupState.COMPLETE,
            SaleEligibility: SaleEligibility.ELIGIBLE,
            InvestingRegion: InvestingRegion.US,
        };

        const prePurchaseCheck = await client.prePurchaseCheck({ saleUUID: "s", entityID: details.EntityID, walletAddress: "w" });
        const generatePurchasePermit = await client.generatePurchasePermit({ saleUUID: "s", entityID: details.EntityID, walletAddress: "w" });
    })
});
