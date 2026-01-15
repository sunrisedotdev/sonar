/**
 * Shared domain types for allocation processing.
 */

export type Allocation = {
    saleSpecificEntityID: `0x${string}`;
    wallet: `0x${string}`;
    token: `0x${string}`;
    acceptedAmount: bigint;
};

export type CommittedAmount = {
    wallet: `0x${string}`;
    token: `0x${string}`;
    amount: bigint;
};

export type AcceptedAmount = {
    wallet: `0x${string}`;
    token: `0x${string}`;
    amount: bigint;
};

export type CommitmentDataWithAcceptedAmounts = {
    commitmentID: `0x${string}`;
    saleSpecificEntityID: `0x${string}`;
    timestamp: bigint;
    price: bigint;
    lockup: boolean;
    refunded: boolean;
    extraData: `0x${string}`;
    committedAmounts: readonly CommittedAmount[];
    acceptedAmounts: readonly AcceptedAmount[];
};
