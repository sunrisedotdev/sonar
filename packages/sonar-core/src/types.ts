export type Hex = `0x${string}`;

export enum EntityType {
    USER = "user",
    ORGANIZATION = "organization",
}

export enum EntitySetupState {
    NOT_STARTED = "not-started",
    IN_PROGRESS = "in-progress",
    READY_FOR_REVIEW = "ready-for-review",
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
    EntityID: Hex;
    SaleUUID: Hex;
    Wallet: Hex;
    ExpiresAt: number;
    Payload: Hex;
};

export type AllocationPermit = {
    Permit: BasicPermit;
    ReservedAmount: string;
    MaxAmount: string;
    MinAmount: string;
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
    SALE_NOT_ACTIVE = "sale-not-active",
    WALLET_NOT_LINKED = "wallet-not-linked",
}

export enum InvestingRegion {
    UNKNOWN = "unknown",
    OTHER = "other",
    US = "us",
}

export type EntityDetails = {
    Label: string;
    EntityID: Hex;
    EntityType: EntityType;
    EntitySetupState: EntitySetupState;
    SaleEligibility: SaleEligibility;
    InvestingRegion: InvestingRegion;
};
