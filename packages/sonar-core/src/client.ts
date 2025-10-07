import { AuthSession } from "./auth";
import { createWebStorage } from "./storage";
import type { AllocationPermit, BasicPermit, EntityDetails } from "./types";

export type FetchLike = (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;

export type PrePurchaseCheckResponse = {
    ReadyToPurchase: boolean;
    FailureReason: string;
    LivenessCheckURL: string;
};

export type GeneratePurchasePermitResponse = {
    // TODO: Add 'type' field to the permit
    PermitJSON: BasicPermit | AllocationPermit;
    Signature: string;
};

export type AllocationResponse = {
    HasReservedAllocation: boolean;
    ReservedAmountUSD: string;
    MaxAmountUSD: string;
};

export type ReadEntityResponse = {
    Entity: EntityDetails;
};

export type ClientOptions = {
    auth?: AuthSession;
    fetch?: FetchLike;
    onUnauthorized?: () => void;
};

export class SonarClient {
    private readonly apiURL: string;
    private readonly auth: AuthSession;
    private readonly fetchFn: FetchLike;
    private readonly onUnauthorized?: () => void;

    constructor(args: { apiURL: string; opts?: ClientOptions }) {
        this.apiURL = args.apiURL;
        this.auth = args.opts?.auth ?? new AuthSession({ storage: createWebStorage() });
        // Choose the fetch implementation in order of preference:
        // 1. Use the fetch function provided in options, if present.
        // 2. Otherwise, use the global fetch if it exists.
        // 3. If neither is available, throw an error.
        const fetchImpl: FetchLike = (() => {
            if (args.opts?.fetch) {
                return args.opts.fetch;
            }
            if (typeof globalThis.fetch === "function") {
                return globalThis.fetch.bind(globalThis);
            }
            throw new Error("No fetch implementation available");
        })();
        this.fetchFn = fetchImpl;
        this.onUnauthorized = args.opts?.onUnauthorized;
    }

    // Expose token management methods from the underlying AuthSession for convenience
    setToken(token: string): void {
        this.auth.setToken(token);
    }

    getToken(): string | undefined {
        return this.auth.getToken();
    }

    clear(): void {
        this.auth.clear();
    }

    private headers({ includeAuth = true }: { includeAuth?: boolean } = {}): Record<string, string> {
        const headers: Record<string, string> = {
            "Content-Type": "application/json",
        };
        if (includeAuth) {
            const token = this.auth.getToken();
            if (token) {
                headers["authorization"] = `api:Bearer ${token}`;
            }
        }
        return headers;
    }

    private async postJSON<T>(
        path: string,
        body: unknown,
        { includeAuth = true }: { includeAuth?: boolean } = {},
    ): Promise<T> {
        const resp = await this.fetchFn(new URL(path, this.apiURL), {
            method: "POST",
            headers: this.headers({ includeAuth }),
            body: JSON.stringify(body),
        });
        return this.parseJsonResponse<T>(resp);
    }

    private async parseJsonResponse<T>(resp: Response): Promise<T> {
        const bodyText = await resp.text();

        if (resp.status === 401 && this.onUnauthorized) {
            try {
                this.onUnauthorized();
            } catch {
                // Ignore errors from onUnauthorized callback
            }
        }

        if (!resp.ok) {
            let message = `Request failed with status ${resp.status}`;
            let code: string | undefined;
            let details: unknown = bodyText || undefined;

            if (bodyText) {
                try {
                    const parsed = JSON.parse(bodyText);
                    details = parsed;
                    if (typeof parsed === "object" && parsed !== null) {
                        const parsedRecord = parsed as Record<string, unknown>;
                        const parsedMessage =
                            parsedRecord.message ?? parsedRecord.Message ?? parsedRecord.error ?? parsedRecord.Error;
                        if (typeof parsedMessage === "string" && parsedMessage.trim()) {
                            message = parsedMessage;
                        }
                        const parsedCode = parsedRecord.code ?? parsedRecord.Code;
                        if (typeof parsedCode === "string" && parsedCode.trim()) {
                            code = parsedCode;
                        }
                    }
                } catch {
                    // keep text version in details
                }
            }

            throw new APIError(resp.status, message, code, details);
        }

        try {
            return JSON.parse(bodyText) as T;
        } catch {
            throw new APIError(
                resp.status,
                `Failed to parse JSON response (status ${resp.status})`,
                undefined,
                bodyText || undefined,
            );
        }
    }

    async exchangeAuthorizationCode(args: {
        code: string;
        codeVerifier: string;
        redirectURI: string;
    }): Promise<{ token: string }> {
        return this.postJSON<{ token: string }>(
            "/oauth.ExchangeAuthorizationCode",
            {
                Code: args.code,
                CodeVerifier: args.codeVerifier,
                RedirectURI: args.redirectURI,
            },
            { includeAuth: false },
        );
    }

    async prePurchaseCheck(args: {
        saleUUID: string;
        entityUUID: string;
        walletAddress: string;
    }): Promise<PrePurchaseCheckResponse> {
        return this.postJSON<PrePurchaseCheckResponse>("/externalapi.PrePurchaseCheck", {
            SaleUUID: args.saleUUID,
            EntityUUID: args.entityUUID,
            PurchasingWalletAddress: args.walletAddress,
        });
    }

    async generatePurchasePermit(args: {
        saleUUID: string;
        entityUUID: string;
        walletAddress: string;
    }): Promise<GeneratePurchasePermitResponse> {
        return this.postJSON<GeneratePurchasePermitResponse>("/externalapi.GenerateSalePurchasePermit", {
            SaleUUID: args.saleUUID,
            EntityUUID: args.entityUUID,
            PurchasingWalletAddress: args.walletAddress,
        });
    }

    async fetchAllocation(args: { saleUUID: string; walletAddress: string }): Promise<AllocationResponse> {
        return this.postJSON<AllocationResponse>("/externalapi.Allocation", {
            SaleUUID: args.saleUUID,
            WalletAddress: args.walletAddress,
        });
    }

    async readEntity(args: { saleUUID: string; walletAddress: string }): Promise<ReadEntityResponse> {
        return this.postJSON<ReadEntityResponse>("/externalapi.ReadEntity", {
            SaleUUID: args.saleUUID,
            WalletAddress: args.walletAddress,
        });
    }
}

export class APIError extends Error {
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
}
