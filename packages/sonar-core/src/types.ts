export type Hex = `0x${string}`;

export enum EntityType {
    USER = "user",
    ORGANIZATION = "organization",
}

export enum EntitySetupState {
    NOT_STARTED = "not-started",
    IN_PROGRESS = "in-progress",
    IN_REVIEW = "in-review",
    FAILURE = "failure",
    FAILURE_FINAL = "failure-final",
    COMPLETE = "complete",
}

export enum SaleEligibility {
    ELIGIBLE = "eligible",
    NOT_ELIGIBLE = "not-eligible",
    UNKNOWN_INCOMPLETE_SETUP = "unknown-incomplete-setup",
}

export type BasicPermit = {
    EntityID: Uint8Array;
    SaleUUID: Uint8Array;
    Wallet: string;
    ExpiresAt: string;
    Payload: Uint8Array;
};

export type AllocationPermit = {
    Permit: BasicPermit;
    ReservedAmount: string;
    MaxAmount: string;
};

export enum PurchasePermitType {
    BASIC = "basic",
    ALLOCATION = "allocation",
}

export type PurchasePermit<T extends PurchasePermitType> = T extends PurchasePermitType.BASIC
    ? BasicPermit
    : T extends PurchasePermitType.ALLOCATION
      ? AllocationPermit
      : never;

export enum PrePurchaseFailureReason {
    UNKNOWN = "unknown",
    WALLET_RISK = "wallet-risk",
    MAX_WALLETS_USED = "max-wallets-used",
    REQUIRES_LIVENESS = "requires-liveness",
    NO_RESERVED_ALLOCATION = "no-reserved-allocation",
}

export type EntityDetails = {
    Label: string;
    EntityUUID: string;
    EntityType: EntityType;
    EntitySetupState: string;
    SaleEligibility: string;
    InvestingRegion: string;
    ObfuscatedEntityID: `0x${string}`;
};
