import { act, cleanup, render, waitFor } from "@testing-library/react";
import React, { useEffect } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { Mock } from "vitest";

import { SonarProvider } from "../src/provider";
import { useSonarAuth, useSonarEntity, useSonarPurchase } from "../src/hooks";
import {
    APIError,
    EntityDetails,
    EntityType,
    EntitySetupState,
    SaleEligibility,
    InvestingRegion,
    PrePurchaseCheckResponse,
    GeneratePurchasePermitResponse,
} from "@echoxyz/sonar-core";

type TestHelpers = {
    emitToken: (token?: string) => void;
    reset: () => void;
    mockClient: {
        clear: Mock;
        readEntity: Mock;
        prePurchaseCheck: Mock;
        generatePurchasePermit: Mock;
    };
};

declare module "@echoxyz/sonar-core" {
    // augment mocked module with test helpers for TypeScript
    export const __test: TestHelpers;
}

vi.mock("@echoxyz/sonar-core", async () => {
    const tokenListeners: Array<(token?: string) => void> = [];
    let currentToken: string | undefined;

    const emitToken = (token?: string) => {
        currentToken = token;
        for (const listener of tokenListeners) {
            listener(token);
        }
    };

    const mockClient = {
        getToken: vi.fn(() => currentToken),
        setToken: vi.fn((token: string) => emitToken(token)),
        clear: vi.fn(() => emitToken(undefined)),
        exchangeAuthorizationCode: vi.fn(async () => ({ token: "mock-token" })),
        readEntity: vi.fn(),
        prePurchaseCheck: vi.fn(),
        generatePurchasePermit: vi.fn(),
    };

    const mockCreateClient = vi.fn((options: { onTokenChange?: (token?: string) => void }) => {
        if (options?.onTokenChange) {
            tokenListeners.push(options.onTokenChange);
        }
        return mockClient;
    });

    return {
        buildAuthorizationUrl: vi.fn(() => new URL("https://example.com")),
        generatePKCEParams: vi.fn(async () => ({
            codeVerifier: "verifier",
            codeChallenge: "challenge",
            state: "state",
        })),
        createClient: mockCreateClient,
        APIError: class APIError extends Error {
            public readonly status: number;
            public readonly code?: string;
            public readonly details?: unknown;

            constructor(status: number, message: string, code?: string, details?: unknown) {
                super(message);
                Object.setPrototypeOf(this, new.target.prototype);
                this.name = "APIError";
                this.status = status;
                this.code = code;
                this.details = details;
            }
        },
        EntityType: {
            USER: "user",
            ORGANIZATION: "organization",
        },
        EntitySetupState: {
            NOT_STARTED: "not-started",
            IN_PROGRESS: "in-progress",
            IN_REVIEW: "in-review",
            FAILURE: "failure",
            FAILURE_FINAL: "failure-final",
            COMPLETE: "complete",
        },
        SaleEligibility: {
            ELIGIBLE: "eligible",
            NOT_ELIGIBLE: "not-eligible",
            UNKNOWN_INCOMPLETE_SETUP: "unknown-incomplete-setup",
        },
        InvestingRegion: {
            UNKNOWN: "unknown",
            OTHER: "other",
            US: "us",
        },
        __test: {
            emitToken,
            reset: () => {
                tokenListeners.length = 0;
                currentToken = undefined;
                mockCreateClient.mockClear();
                mockClient.getToken.mockClear();
                mockClient.setToken.mockClear();
                mockClient.clear.mockClear();
                mockClient.exchangeAuthorizationCode.mockClear();
                mockClient.readEntity.mockClear();
                mockClient.prePurchaseCheck.mockClear();
                mockClient.generatePurchasePermit.mockClear();
            },
            mockClient,
        } satisfies TestHelpers,
    };
});

const { __test } = await import("@echoxyz/sonar-core");

const latestAuth: { current: ReturnType<typeof useSonarAuth> | null } = { current: null };

function AuthStateProbe() {
    const value = useSonarAuth();

    useEffect(() => {
        latestAuth.current = value;
    }, [value]);

    return (
        <div
            data-testid="auth-state"
            data-ready={value.ready ? "true" : "false"}
            data-authenticated={value.authenticated ? "true" : "false"}
            data-token={value.token ?? ""}
        />
    );
}

const config = {
    clientUUID: "client-uuid",
    redirectURI: "https://example.com/callback",
};

describe("SonarProvider auth state", () => {
    beforeEach(() => {
        __test.reset();
        latestAuth.current = null;
    });

    afterEach(() => {
        cleanup();
    });

    it("marks ready once the initial token read completes", async () => {
        const { getByTestId } = render(
            <SonarProvider config={config}>
                <AuthStateProbe />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("auth-state").dataset.ready).toBe("true"));
        expect(getByTestId("auth-state").dataset.authenticated).toBe("false");
    });

    it("updates authenticated state when the token changes", async () => {
        const { getByTestId } = render(
            <SonarProvider config={config}>
                <AuthStateProbe />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("auth-state").dataset.ready).toBe("true"));

        act(() => {
            __test.emitToken("token-123");
        });

        await waitFor(() => expect(getByTestId("auth-state").dataset.authenticated).toBe("true"));
        expect(getByTestId("auth-state").dataset.token).toBe("token-123");
    });

    it("clears authenticated state on logout", async () => {
        const { getByTestId } = render(
            <SonarProvider config={config}>
                <AuthStateProbe />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("auth-state").dataset.ready).toBe("true"));

        act(() => {
            __test.emitToken("token-abc");
        });

        await waitFor(() => expect(getByTestId("auth-state").dataset.authenticated).toBe("true"));

        await waitFor(() => {
            expect(latestAuth.current).not.toBeNull();
        });

        act(() => {
            latestAuth.current?.logout();
        });

        await waitFor(() => expect(getByTestId("auth-state").dataset.authenticated).toBe("false"));
        expect(__test.mockClient.clear).toHaveBeenCalledTimes(1);
    });
});

function EntityStateProbe({ saleUUID, walletAddress }: { saleUUID: string; walletAddress?: string }) {
    const value = useSonarEntity({ saleUUID, walletAddress });

    return (
        <div
            data-testid="entity-state"
            data-authenticated={value.authenticated ? "true" : "false"}
            data-loading={value.loading ? "true" : "false"}
            data-entity-uuid={value.entity?.EntityUUID ?? ""}
            data-entity-label={value.entity?.Label ?? ""}
            data-error={value.error?.message ?? ""}
        />
    );
}

function PurchaseStateProbe({
    saleUUID,
    entityUUID,
    walletAddress,
}: {
    saleUUID: string;
    entityUUID: string;
    walletAddress: string;
}) {
    const value = useSonarPurchase({ saleUUID, entityUUID, walletAddress });

    return (
        <div
            data-testid="purchase-state"
            data-loading={value.loading ? "true" : "false"}
            data-ready-to-purchase={value.readyToPurchase ? "true" : "false"}
            data-failure-reason={value.readyToPurchase === false && "failureReason" in value ? value.failureReason : ""}
            data-liveness-check-url={
                value.readyToPurchase === false && "livenessCheckURL" in value ? value.livenessCheckURL : ""
            }
            data-has-generate-permit={
                value.readyToPurchase === true && "generatePurchasePermit" in value ? "true" : "false"
            }
            data-error={value.error?.message ?? ""}
        />
    );
}

describe("useSonarEntity", () => {
    const mockEntity: EntityDetails = {
        Label: "Test Entity",
        EntityUUID: "entity-uuid-123",
        EntityType: EntityType.USER,
        EntitySetupState: EntitySetupState.COMPLETE,
        SaleEligibility: SaleEligibility.ELIGIBLE,
        InvestingRegion: InvestingRegion.US,
        ObfuscatedEntityID: "0x1234567890abcdef",
    };

    const mockWalletAddress = "0x1234567890abcdef1234567890abcdef12345678";

    beforeEach(() => {
        __test.reset();
        latestAuth.current = null;
    });

    afterEach(() => {
        cleanup();
    });

    it("throws error when saleUUID is not provided", () => {
        const consoleSpy = vi.spyOn(console, "error").mockImplementation(() => {});

        expect(() => {
            render(
                <SonarProvider config={config}>
                    <EntityStateProbe saleUUID="" walletAddress={mockWalletAddress} />
                </SonarProvider>,
            );
        }).toThrow("saleUUID is required");

        consoleSpy.mockRestore();
    });

    it("initializes with correct default state", async () => {
        const { getByTestId } = render(
            <SonarProvider config={config}>
                <EntityStateProbe saleUUID="test-sale" walletAddress={mockWalletAddress} />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("entity-state").dataset.authenticated).toBe("false"));
        expect(getByTestId("entity-state").dataset.loading).toBe("false");
        expect(getByTestId("entity-state").dataset.entityUuid).toBe("");
        expect(getByTestId("entity-state").dataset.error).toBe("");
    });

    it("fetches entity when fully connected", async () => {
        const mockReadEntity = vi.fn().mockResolvedValue({ Entity: mockEntity });
        __test.mockClient.readEntity = mockReadEntity;

        const { getByTestId } = render(
            <SonarProvider config={config}>
                <EntityStateProbe saleUUID="test-sale" walletAddress={mockWalletAddress} />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("entity-state").dataset.authenticated).toBe("false"));

        act(() => {
            __test.emitToken("token-123");
        });

        await waitFor(() => expect(getByTestId("entity-state").dataset.authenticated).toBe("true"));
        await waitFor(() => expect(getByTestId("entity-state").dataset.loading).toBe("false"));

        expect(mockReadEntity).toHaveBeenCalledWith({
            saleUUID: "test-sale",
            walletAddress: mockWalletAddress,
        });
        expect(getByTestId("entity-state").dataset.entityUuid).toBe(mockEntity.EntityUUID);
        expect(getByTestId("entity-state").dataset.entityLabel).toBe(mockEntity.Label);
    });

    it("handles 404 error by setting entity to undefined", async () => {
        const mockReadEntity = vi.fn().mockRejectedValue(new APIError(404, "Not found"));
        __test.mockClient.readEntity = mockReadEntity;

        const { getByTestId } = render(
            <SonarProvider config={config}>
                <EntityStateProbe saleUUID="test-sale" walletAddress={mockWalletAddress} />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("entity-state").dataset.authenticated).toBe("false"));

        act(() => {
            __test.emitToken("token-123");
        });

        await waitFor(() => expect(getByTestId("entity-state").dataset.authenticated).toBe("true"));
        await waitFor(() => expect(getByTestId("entity-state").dataset.loading).toBe("false"));

        expect(getByTestId("entity-state").dataset.entityUuid).toBe("");
        expect(getByTestId("entity-state").dataset.error).toBe("");
    });

    it("handles API errors by setting error state", async () => {
        const mockReadEntity = vi.fn().mockRejectedValue(new APIError(500, "Server error"));
        __test.mockClient.readEntity = mockReadEntity;

        const { getByTestId } = render(
            <SonarProvider config={config}>
                <EntityStateProbe saleUUID="test-sale" walletAddress={mockWalletAddress} />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("entity-state").dataset.authenticated).toBe("false"));

        act(() => {
            __test.emitToken("token-123");
        });

        await waitFor(() => expect(getByTestId("entity-state").dataset.authenticated).toBe("true"));
        await waitFor(() => expect(getByTestId("entity-state").dataset.loading).toBe("false"));

        expect(getByTestId("entity-state").dataset.entityUuid).toBe("");
        expect(getByTestId("entity-state").dataset.error).toBe("Server error");
    });

    it("resets state when wallet disconnects", async () => {
        const mockReadEntity = vi.fn().mockResolvedValue({ Entity: mockEntity });
        __test.mockClient.readEntity = mockReadEntity;

        const { getByTestId, rerender } = render(
            <SonarProvider config={config}>
                <EntityStateProbe saleUUID="test-sale" walletAddress={mockWalletAddress} />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("entity-state").dataset.authenticated).toBe("false"));

        act(() => {
            __test.emitToken("token-123");
        });

        await waitFor(() => expect(getByTestId("entity-state").dataset.authenticated).toBe("true"));
        await waitFor(() => expect(getByTestId("entity-state").dataset.entityUuid).toBe(mockEntity.EntityUUID));

        rerender(
            <SonarProvider config={config}>
                <EntityStateProbe saleUUID="test-sale" walletAddress={undefined} />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("entity-state").dataset.entityUuid).toBe(""));
        expect(getByTestId("entity-state").dataset.error).toBe("");
    });

    it("resets state when user logs out", async () => {
        const mockReadEntity = vi.fn().mockResolvedValue({ Entity: mockEntity });
        __test.mockClient.readEntity = mockReadEntity;

        const { getByTestId } = render(
            <SonarProvider config={config}>
                <EntityStateProbe saleUUID="test-sale" walletAddress={mockWalletAddress} />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("entity-state").dataset.authenticated).toBe("false"));

        act(() => {
            __test.emitToken("token-123");
        });

        await waitFor(() => expect(getByTestId("entity-state").dataset.authenticated).toBe("true"));
        await waitFor(() => expect(getByTestId("entity-state").dataset.entityUuid).toBe(mockEntity.EntityUUID));

        act(() => {
            __test.emitToken(undefined);
        });

        await waitFor(() => expect(getByTestId("entity-state").dataset.authenticated).toBe("false"));
        await waitFor(() => expect(getByTestId("entity-state").dataset.entityUuid).toBe(""));
        expect(getByTestId("entity-state").dataset.error).toBe("");
    });

    it("re-runs entity fetch when wallet address changes", async () => {
        const mockReadEntity = vi.fn().mockResolvedValue({ Entity: mockEntity });
        __test.mockClient.readEntity = mockReadEntity;

        const { getByTestId, rerender } = render(
            <SonarProvider config={config}>
                <EntityStateProbe saleUUID="test-sale" walletAddress={mockWalletAddress} />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("entity-state").dataset.authenticated).toBe("false"));

        act(() => {
            __test.emitToken("token-123");
        });

        await waitFor(() => expect(getByTestId("entity-state").dataset.authenticated).toBe("true"));
        await waitFor(() => expect(getByTestId("entity-state").dataset.loading).toBe("false"));
        expect(mockReadEntity).toHaveBeenCalledTimes(1);

        // Change wallet address - the hook should now re-fetch automatically
        const newWalletAddress = "0x9876543210fedcba9876543210fedcba98765432";
        rerender(
            <SonarProvider config={config}>
                <EntityStateProbe saleUUID="test-sale" walletAddress={newWalletAddress} />
            </SonarProvider>,
        );

        // The entity fetch should be called again with the new wallet address
        await waitFor(() => expect(mockReadEntity).toHaveBeenCalledTimes(2));
        expect(mockReadEntity).toHaveBeenLastCalledWith({
            saleUUID: "test-sale",
            walletAddress: newWalletAddress,
        });
    });
});

describe("useSonarPurchase", () => {
    const mockPrePurchaseCheckResponse: PrePurchaseCheckResponse = {
        ReadyToPurchase: true,
        FailureReason: "",
        LivenessCheckURL: "https://example.com/liveness",
    };

    const mockGeneratePurchasePermitResponse: GeneratePurchasePermitResponse = {
        PermitJSON: {
            EntityID: new Uint8Array([1, 2, 3, 4]),
            SaleUUID: new Uint8Array([5, 6, 7, 8]),
            Wallet: "0x1234567890abcdef1234567890abcdef12345678",
            ExpiresAt: "2024-12-31T23:59:59Z",
            Payload: new Uint8Array([9, 10, 11, 12]),
        },
        Signature: "mock-signature-123",
    };

    const mockEntityUUID = "entity-uuid-123";
    const mockWalletAddress = "0x1234567890abcdef1234567890abcdef12345678";

    beforeEach(() => {
        __test.reset();
        latestAuth.current = null;
    });

    afterEach(() => {
        cleanup();
    });

    it("performs pre-purchase check when all required parameters are provided", async () => {
        const mockPrePurchaseCheck = vi.fn().mockResolvedValue(mockPrePurchaseCheckResponse);
        __test.mockClient.prePurchaseCheck = mockPrePurchaseCheck;

        const { getByTestId } = render(
            <SonarProvider config={config}>
                <PurchaseStateProbe
                    saleUUID="test-sale"
                    entityUUID={mockEntityUUID}
                    walletAddress={mockWalletAddress}
                />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("purchase-state").dataset.loading).toBe("false"));

        expect(mockPrePurchaseCheck).toHaveBeenCalledWith({
            saleUUID: "test-sale",
            entityUUID: mockEntityUUID,
            walletAddress: mockWalletAddress,
        });
        expect(getByTestId("purchase-state").dataset.readyToPurchase).toBe("true");
        expect(getByTestId("purchase-state").dataset.failureReason).toBe("");
        expect(getByTestId("purchase-state").dataset.livenessCheckUrl).toBe("");
        expect(getByTestId("purchase-state").dataset.hasGeneratePermit).toBe("true");
    });

    it("handles pre-purchase check errors", async () => {
        const mockPrePurchaseCheck = vi.fn().mockRejectedValue(new Error("API Error"));
        __test.mockClient.prePurchaseCheck = mockPrePurchaseCheck;

        const { getByTestId } = render(
            <SonarProvider config={config}>
                <PurchaseStateProbe
                    saleUUID="test-sale"
                    entityUUID={mockEntityUUID}
                    walletAddress={mockWalletAddress}
                />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("purchase-state").dataset.loading).toBe("false"));

        expect(mockPrePurchaseCheck).toHaveBeenCalledWith({
            saleUUID: "test-sale",
            entityUUID: mockEntityUUID,
            walletAddress: mockWalletAddress,
        });
        expect(getByTestId("purchase-state").dataset.readyToPurchase).toBe("false");
        expect(getByTestId("purchase-state").dataset.error).toBe("API Error");
        expect(getByTestId("purchase-state").dataset.hasGeneratePermit).toBe("false");
    });

    it("handles pre-purchase check when not ready to purchase", async () => {
        const notReadyResponse: PrePurchaseCheckResponse = {
            ReadyToPurchase: false,
            FailureReason: "wallet-risk",
            LivenessCheckURL: "https://example.com/liveness",
        };

        const mockPrePurchaseCheck = vi.fn().mockResolvedValue(notReadyResponse);
        __test.mockClient.prePurchaseCheck = mockPrePurchaseCheck;

        const { getByTestId } = render(
            <SonarProvider config={config}>
                <PurchaseStateProbe
                    saleUUID="test-sale"
                    entityUUID={mockEntityUUID}
                    walletAddress={mockWalletAddress}
                />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("purchase-state").dataset.loading).toBe("false"));

        expect(getByTestId("purchase-state").dataset.readyToPurchase).toBe("false");
        expect(getByTestId("purchase-state").dataset.failureReason).toBe("wallet-risk");
        expect(getByTestId("purchase-state").dataset.livenessCheckUrl).toBe("https://example.com/liveness");
        expect(getByTestId("purchase-state").dataset.hasGeneratePermit).toBe("false");
    });

    it("provides generatePurchasePermit function when ready to purchase", async () => {
        const mockPrePurchaseCheck = vi.fn().mockResolvedValue(mockPrePurchaseCheckResponse);
        const mockGeneratePurchasePermit = vi.fn().mockResolvedValue(mockGeneratePurchasePermitResponse);
        __test.mockClient.prePurchaseCheck = mockPrePurchaseCheck;
        __test.mockClient.generatePurchasePermit = mockGeneratePurchasePermit;

        const { getByTestId } = render(
            <SonarProvider config={config}>
                <PurchaseStateProbe
                    saleUUID="test-sale"
                    entityUUID={mockEntityUUID}
                    walletAddress={mockWalletAddress}
                />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("purchase-state").dataset.readyToPurchase).toBe("true"));
        expect(getByTestId("purchase-state").dataset.hasGeneratePermit).toBe("true");
    });

    it("re-runs pre-purchase check when wallet address changes", async () => {
        const mockPrePurchaseCheck = vi.fn().mockResolvedValue(mockPrePurchaseCheckResponse);
        __test.mockClient.prePurchaseCheck = mockPrePurchaseCheck;

        const { getByTestId, rerender } = render(
            <SonarProvider config={config}>
                <PurchaseStateProbe
                    saleUUID="test-sale"
                    entityUUID={mockEntityUUID}
                    walletAddress={mockWalletAddress}
                />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("purchase-state").dataset.loading).toBe("false"));
        const initialCallCount = mockPrePurchaseCheck.mock.calls.length;

        // Change wallet address - the hook should now re-fetch automatically
        const newWalletAddress = "0x9876543210fedcba9876543210fedcba98765432";
        rerender(
            <SonarProvider config={config}>
                <PurchaseStateProbe saleUUID="test-sale" entityUUID={mockEntityUUID} walletAddress={newWalletAddress} />
            </SonarProvider>,
        );

        // The pre-purchase check should be called again with the new wallet address
        await waitFor(() => expect(mockPrePurchaseCheck.mock.calls.length).toBeGreaterThan(initialCallCount));
        expect(mockPrePurchaseCheck).toHaveBeenLastCalledWith({
            saleUUID: "test-sale",
            entityUUID: mockEntityUUID,
            walletAddress: newWalletAddress,
        });
    });

    it("reruns pre-purchase check when entityUUID changes", async () => {
        const mockPrePurchaseCheck = vi.fn().mockResolvedValue(mockPrePurchaseCheckResponse);
        __test.mockClient.prePurchaseCheck = mockPrePurchaseCheck;

        const { getByTestId, rerender } = render(
            <SonarProvider config={config}>
                <PurchaseStateProbe
                    saleUUID="test-sale"
                    entityUUID={mockEntityUUID}
                    walletAddress={mockWalletAddress}
                />
            </SonarProvider>,
        );

        await waitFor(() => expect(getByTestId("purchase-state").dataset.loading).toBe("false"));
        expect(mockPrePurchaseCheck).toHaveBeenCalledTimes(1);
        expect(mockPrePurchaseCheck).toHaveBeenCalledWith({
            saleUUID: "test-sale",
            entityUUID: mockEntityUUID,
            walletAddress: mockWalletAddress,
        });

        // Change entityUUID - the hook should re-fetch automatically
        const newEntityUUID = "new-entity-uuid-456";
        rerender(
            <SonarProvider config={config}>
                <PurchaseStateProbe saleUUID="test-sale" entityUUID={newEntityUUID} walletAddress={mockWalletAddress} />
            </SonarProvider>,
        );

        // The pre-purchase check should be called again with the new entityUUID
        await waitFor(() => expect(mockPrePurchaseCheck.mock.calls.length).toBeGreaterThan(1));
        expect(mockPrePurchaseCheck).toHaveBeenCalledTimes(2);
    });
});
