import { AuthSession } from "./auth";
import type { FetchLike } from "./fetcher";
import { createJsonFetcher } from "./fetcher";
import { createWebStorage } from "./storage";
import type { AllocationPermit, BasicPermit, EntityDetails, EntityType, PurchasePermitType } from "./types";

export type PrePurchaseCheckResponse = {
    ReadyToPurchase: boolean;
    FailureReason: string;
    LivenessCheckURL: string;
};

export type GeneratePurchasePermitResponse = {
    // TODO: Add 'type' field to the permit
    Permit: BasicPermit | AllocationPermit;
    Signature: string;
};

export type AllocationResponse = {
    HasReservedAllocation: boolean;
    ReservedAmountUSD: string;
    MaxAmountUSD: string;
};

export type ClientOptions = {
    auth?: AuthSession;
    fetch?: FetchLike;
};

export class SonarClient {
    private readonly apiURL: string;
    private readonly saleUUID: string;
    private readonly fetcher: FetchLike;
    private readonly auth: AuthSession;

    constructor(args: { apiURL: string; saleUUID: string; opts?: ClientOptions }) {
        this.apiURL = args.apiURL;
        this.saleUUID = args.saleUUID;
        this.auth = args.opts?.auth ?? new AuthSession({ storage: createWebStorage() });
        this.fetcher = args.opts?.fetch ?? createJsonFetcher();
    }

    private headers(): Record<string, string> {
        const headers: Record<string, string> = {
            "Content-Type": "application/json",
        };
        const token = this.auth.getToken();
        if (token) {
            headers["authorization"] = `api:Bearer ${token}`;
        }
        return headers;
    }

    async exchangeAuthorizationCode(args: {
        code: string;
        codeVerifier: string;
        redirectURI: string;
    }): Promise<{ token: string }> {
        const resp = await this.fetcher(new URL("/oauth.ExchangeAuthorizationCode", this.apiURL), {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                Code: args.code,
                CodeVerifier: args.codeVerifier,
                RedirectURI: args.redirectURI,
            }),
        });
        return (await resp.json()) as { token: string };
    }

    async prePurchaseCheck(args: {
        entityUUID: string;
        entityType: EntityType;
        walletAddress: string;
    }): Promise<PrePurchaseCheckResponse> {
        const resp = await this.fetcher(new URL("/externalapi.PrePurchaseCheck", this.apiURL), {
            method: "POST",
            headers: this.headers(),
            body: JSON.stringify({
                SaleUUID: this.saleUUID,
                EntityUUID: args.entityUUID,
                EntityType: args.entityType,
                PurchasingWalletAddress: args.walletAddress,
            }),
        });
        return (await resp.json()) as PrePurchaseCheckResponse;
    }

    async generatePurchasePermit<T extends PurchasePermitType>(args: {
        entityUUID: string;
        entityType: EntityType;
        walletAddress: string;
    }): Promise<GeneratePurchasePermitResponse> {
        const resp = await this.fetcher(new URL("/externalapi.GenerateSalePurchasePermit", this.apiURL), {
            method: "POST",
            headers: this.headers(),
            body: JSON.stringify({
                SaleUUID: this.saleUUID,
                EntityUUID: args.entityUUID,
                EntityType: args.entityType,
                PurchasingWalletAddress: args.walletAddress,
            }),
        });
        return (await resp.json()) as GeneratePurchasePermitResponse;
    }

    async fetchAllocation(args: { walletAddress: string }): Promise<AllocationResponse> {
        const resp = await this.fetcher(new URL("/externalapi.Allocation", this.apiURL), {
            method: "POST",
            headers: this.headers(),
            body: JSON.stringify({
                SaleUUID: this.saleUUID,
                WalletAddress: args.walletAddress,
            }),
        });
        return (await resp.json()) as AllocationResponse;
    }

    async listAvailableEntities(): Promise<EntityDetails[]> {
        const resp = await this.fetcher(new URL("/externalapi.ListAvailableEntities", this.apiURL), {
            method: "POST",
            headers: this.headers(),
            body: JSON.stringify({ SaleUUID: this.saleUUID }),
        });
        const data = (await resp.json()) as { Entities: EntityDetails[] };
        return data.Entities;
    }
}
