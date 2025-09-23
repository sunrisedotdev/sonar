import { act, cleanup, render, waitFor } from "@testing-library/react";
import React, { useEffect } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { Mock } from "vitest";

import { SonarProvider, useSonarAuth } from "../src/react";

type TestHelpers = {
    emitToken: (token?: string) => void;
    reset: () => void;
    mockClient: {
        clear: Mock;
    };
};

declare module "@echoxyz/sonar-core" {
    // augment mocked module with test helpers for TypeScript
    // eslint-disable-next-line @typescript-eslint/naming-convention
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
    saleUUID: "sale-uuid",
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
