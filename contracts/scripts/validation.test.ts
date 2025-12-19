import { describe, it, expect } from "vitest";
import {
    validateNoZeroAllocations,
    validateNoDuplicateAllocations,
    validateNoDuplicateCommitments,
    validateEntitiesExistAndNotRefunded,
    validateAllocationsWithinCommitments,
    validateAllAllocations,
} from "./validation.ts";
import { findUnsetAllocations, calculateTotalByToken } from "./utils.ts";
import type { Allocation, CommitmentDataWithAcceptedAmounts } from "./types.ts";

// Test fixtures
const ENTITY_1 = "0x0000000000000000000000000000000000000001" as const;
const ENTITY_2 = "0x0000000000000000000000000000000000000002" as const;
const ENTITY_3 = "0x0000000000000000000000000000000000000003" as const;
const WALLET_A = "0x000000000000000000000000000000000000000a" as const;
const WALLET_B = "0x000000000000000000000000000000000000000b" as const;
const TOKEN_USDC = "0x00000000000000000000000000000000000000cc" as const;
const TOKEN_USDT = "0x00000000000000000000000000000000000000dd" as const;

function makeAllocation(overrides: Partial<Allocation> = {}): Allocation {
    return {
        saleSpecificEntityID: ENTITY_1,
        wallet: WALLET_A,
        token: TOKEN_USDC,
        acceptedAmount: 1000n,
        ...overrides,
    };
}

function makeCommitmentData(
    overrides: Partial<CommitmentDataWithAcceptedAmounts> & { saleSpecificEntityID: `0x${string}` },
): CommitmentDataWithAcceptedAmounts {
    return {
        commitmentID: "0x0000000000000000000000000000000000000000000000000000000000000000",
        timestamp: 0n,
        price: 0n,
        lockup: false,
        refunded: false,
        extraData: "0x",
        committedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
        acceptedAmounts: [],
        ...overrides,
    };
}

describe("validateNoZeroAllocations", () => {
    it("returns valid when all allocations have non-zero amounts", () => {
        const allocations = [
            makeAllocation({ acceptedAmount: 100n }),
            makeAllocation({ saleSpecificEntityID: ENTITY_2, acceptedAmount: 200n }),
        ];

        const result = validateNoZeroAllocations(allocations);

        expect(result.valid).toBe(true);
        expect(result.errors).toHaveLength(0);
    });

    it("returns error for zero allocation", () => {
        const allocations = [makeAllocation({ acceptedAmount: 0n })];

        const result = validateNoZeroAllocations(allocations);

        expect(result.valid).toBe(false);
        expect(result.errors).toHaveLength(1);
        expect(result.errors[0].type).toBe("zero_allocation");
    });

    it("returns multiple errors for multiple zero allocations", () => {
        const allocations = [
            makeAllocation({ saleSpecificEntityID: ENTITY_1, acceptedAmount: 0n }),
            makeAllocation({ saleSpecificEntityID: ENTITY_2, acceptedAmount: 100n }),
            makeAllocation({ saleSpecificEntityID: ENTITY_3, acceptedAmount: 0n }),
        ];

        const result = validateNoZeroAllocations(allocations);

        expect(result.valid).toBe(false);
        expect(result.errors).toHaveLength(2);
    });

    it("returns valid for empty allocations array", () => {
        const result = validateNoZeroAllocations([]);

        expect(result.valid).toBe(true);
        expect(result.errors).toHaveLength(0);
    });
});

describe("validateNoDuplicateAllocations", () => {
    it("returns valid when all allocations are unique", () => {
        const allocations = [
            makeAllocation({ saleSpecificEntityID: ENTITY_1, wallet: WALLET_A, token: TOKEN_USDC }),
            makeAllocation({ saleSpecificEntityID: ENTITY_1, wallet: WALLET_A, token: TOKEN_USDT }),
            makeAllocation({ saleSpecificEntityID: ENTITY_1, wallet: WALLET_B, token: TOKEN_USDC }),
            makeAllocation({ saleSpecificEntityID: ENTITY_2, wallet: WALLET_A, token: TOKEN_USDC }),
        ];

        const result = validateNoDuplicateAllocations(allocations);

        expect(result.valid).toBe(true);
        expect(result.errors).toHaveLength(0);
    });

    it("returns error for duplicate (entity, wallet, token) tuple", () => {
        const allocations = [
            makeAllocation({ saleSpecificEntityID: ENTITY_1, wallet: WALLET_A, token: TOKEN_USDC }),
            makeAllocation({ saleSpecificEntityID: ENTITY_1, wallet: WALLET_A, token: TOKEN_USDC }),
        ];

        const result = validateNoDuplicateAllocations(allocations);

        expect(result.valid).toBe(false);
        expect(result.errors).toHaveLength(1);
        expect(result.errors[0].type).toBe("duplicate_allocation");
    });

    it("allows same entity with different wallet or token", () => {
        const allocations = [
            makeAllocation({ saleSpecificEntityID: ENTITY_1, wallet: WALLET_A, token: TOKEN_USDC }),
            makeAllocation({ saleSpecificEntityID: ENTITY_1, wallet: WALLET_B, token: TOKEN_USDC }),
            makeAllocation({ saleSpecificEntityID: ENTITY_1, wallet: WALLET_A, token: TOKEN_USDT }),
        ];

        const result = validateNoDuplicateAllocations(allocations);

        expect(result.valid).toBe(true);
    });
});

describe("validateNoDuplicateCommitments", () => {
    it("returns valid when all commitments are unique", () => {
        const commitmentData: CommitmentDataWithAcceptedAmounts[] = [
            makeCommitmentData({
                saleSpecificEntityID: ENTITY_1,
                committedAmounts: [
                    { wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n },
                    { wallet: WALLET_B, token: TOKEN_USDC, amount: 500n },
                ],
            }),
            makeCommitmentData({
                saleSpecificEntityID: ENTITY_2,
                committedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 2000n }],
            }),
        ];

        const result = validateNoDuplicateCommitments(commitmentData);

        expect(result.valid).toBe(true);
    });

    it("returns error for duplicate commitment within same entity", () => {
        const commitmentData: CommitmentDataWithAcceptedAmounts[] = [
            makeCommitmentData({
                saleSpecificEntityID: ENTITY_1,
                committedAmounts: [
                    { wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n },
                    { wallet: WALLET_A, token: TOKEN_USDC, amount: 500n }, // duplicate
                ],
            }),
        ];

        const result = validateNoDuplicateCommitments(commitmentData);

        expect(result.valid).toBe(false);
        expect(result.errors[0].type).toBe("duplicate_commitment");
    });
});

describe("validateEntitiesExistAndNotRefunded", () => {
    it("returns valid when all entities exist and are not refunded", () => {
        const allocations = [
            makeAllocation({ saleSpecificEntityID: ENTITY_1 }),
            makeAllocation({ saleSpecificEntityID: ENTITY_2 }),
        ];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [ENTITY_1, makeCommitmentData({ saleSpecificEntityID: ENTITY_1, refunded: false })],
            [ENTITY_2, makeCommitmentData({ saleSpecificEntityID: ENTITY_2, refunded: false })],
        ]);

        const result = validateEntitiesExistAndNotRefunded(allocations, commitmentDataMap);

        expect(result.valid).toBe(true);
    });

    it("returns error when entity does not exist", () => {
        const allocations = [makeAllocation({ saleSpecificEntityID: ENTITY_1 })];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>();

        const result = validateEntitiesExistAndNotRefunded(allocations, commitmentDataMap);

        expect(result.valid).toBe(false);
        expect(result.errors[0].type).toBe("entity_not_found");
    });

    it("returns error when entity is refunded", () => {
        const allocations = [makeAllocation({ saleSpecificEntityID: ENTITY_1 })];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [ENTITY_1, makeCommitmentData({ saleSpecificEntityID: ENTITY_1, refunded: true })],
        ]);

        const result = validateEntitiesExistAndNotRefunded(allocations, commitmentDataMap);

        expect(result.valid).toBe(false);
        expect(result.errors[0].type).toBe("entity_refunded");
    });

    it("returns both errors when entity not found and another is refunded", () => {
        const allocations = [
            makeAllocation({ saleSpecificEntityID: ENTITY_1 }),
            makeAllocation({ saleSpecificEntityID: ENTITY_2 }),
        ];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [ENTITY_2, makeCommitmentData({ saleSpecificEntityID: ENTITY_2, refunded: true })],
        ]);

        const result = validateEntitiesExistAndNotRefunded(allocations, commitmentDataMap);

        expect(result.valid).toBe(false);
        expect(result.errors).toHaveLength(2);
        expect(result.errors.map((e) => e.type)).toContain("entity_not_found");
        expect(result.errors.map((e) => e.type)).toContain("entity_refunded");
    });
});

describe("validateAllocationsWithinCommitments", () => {
    it("returns valid when allocation equals committed amount", () => {
        const allocations = [
            makeAllocation({
                saleSpecificEntityID: ENTITY_1,
                wallet: WALLET_A,
                token: TOKEN_USDC,
                acceptedAmount: 1000n,
            }),
        ];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [
                ENTITY_1,
                makeCommitmentData({
                    saleSpecificEntityID: ENTITY_1,
                    committedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
                }),
            ],
        ]);

        const result = validateAllocationsWithinCommitments(allocations, commitmentDataMap);

        expect(result.valid).toBe(true);
    });

    it("returns valid when allocation is less than committed amount", () => {
        const allocations = [makeAllocation({ acceptedAmount: 500n })];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [
                ENTITY_1,
                makeCommitmentData({
                    saleSpecificEntityID: ENTITY_1,
                    committedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
                }),
            ],
        ]);

        const result = validateAllocationsWithinCommitments(allocations, commitmentDataMap);

        expect(result.valid).toBe(true);
    });

    it("returns error when allocation exceeds committed amount", () => {
        const allocations = [makeAllocation({ acceptedAmount: 1500n })];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [
                ENTITY_1,
                makeCommitmentData({
                    saleSpecificEntityID: ENTITY_1,
                    committedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
                }),
            ],
        ]);

        const result = validateAllocationsWithinCommitments(allocations, commitmentDataMap);

        expect(result.valid).toBe(false);
        expect(result.errors[0].type).toBe("exceeds_commitment");
    });

    it("returns error when no matching commitment found for wallet/token combo", () => {
        const allocations = [
            makeAllocation({ wallet: WALLET_B }), // Different wallet
        ];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [
                ENTITY_1,
                makeCommitmentData({
                    saleSpecificEntityID: ENTITY_1,
                    committedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
                }),
            ],
        ]);

        const result = validateAllocationsWithinCommitments(allocations, commitmentDataMap);

        expect(result.valid).toBe(false);
        expect(result.errors[0].type).toBe("no_matching_commitment");
    });

    it("skips entities not in map (handled by other validation)", () => {
        const allocations = [makeAllocation({ saleSpecificEntityID: ENTITY_1 })];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>();

        const result = validateAllocationsWithinCommitments(allocations, commitmentDataMap);

        expect(result.valid).toBe(true); // This validation doesn't check for missing entities
    });
});

describe("createCommitmentDataMap", () => {
    it("creates map from commitment data array", () => {
        const commitmentData: CommitmentDataWithAcceptedAmounts[] = [
            makeCommitmentData({ saleSpecificEntityID: ENTITY_1 }),
            makeCommitmentData({ saleSpecificEntityID: ENTITY_2 }),
        ];

        const map = new Map(commitmentData.map((c) => [c.saleSpecificEntityID, c]));

        expect(map.size).toBe(2);
        expect(map.get(ENTITY_1)?.saleSpecificEntityID).toBe(ENTITY_1);
        expect(map.get(ENTITY_2)?.saleSpecificEntityID).toBe(ENTITY_2);
    });
});

describe("findUnsetAllocations", () => {
    it("returns allocations that have no accepted amount", () => {
        const allocations = [makeAllocation({ saleSpecificEntityID: ENTITY_1 })];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [
                ENTITY_1,
                makeCommitmentData({
                    saleSpecificEntityID: ENTITY_1,
                    acceptedAmounts: [], // No accepted amounts
                }),
            ],
        ]);

        const unset = findUnsetAllocations(allocations, commitmentDataMap);

        expect(unset).toHaveLength(1);
    });

    it("returns allocations where accepted amount is zero", () => {
        const allocations = [makeAllocation({ saleSpecificEntityID: ENTITY_1 })];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [
                ENTITY_1,
                makeCommitmentData({
                    saleSpecificEntityID: ENTITY_1,
                    acceptedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 0n }],
                }),
            ],
        ]);

        const unset = findUnsetAllocations(allocations, commitmentDataMap);

        expect(unset).toHaveLength(1);
    });

    it("excludes allocations that have been set (non-zero accepted amount)", () => {
        const allocations = [makeAllocation({ saleSpecificEntityID: ENTITY_1 })];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [
                ENTITY_1,
                makeCommitmentData({
                    saleSpecificEntityID: ENTITY_1,
                    acceptedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
                }),
            ],
        ]);

        const unset = findUnsetAllocations(allocations, commitmentDataMap);

        expect(unset).toHaveLength(0);
    });

    it("handles mix of set and unset allocations", () => {
        const allocations = [
            makeAllocation({ saleSpecificEntityID: ENTITY_1, wallet: WALLET_A }),
            makeAllocation({ saleSpecificEntityID: ENTITY_1, wallet: WALLET_B }),
        ];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [
                ENTITY_1,
                makeCommitmentData({
                    saleSpecificEntityID: ENTITY_1,
                    committedAmounts: [
                        { wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n },
                        { wallet: WALLET_B, token: TOKEN_USDC, amount: 500n },
                    ],
                    acceptedAmounts: [
                        { wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }, // Set
                        // WALLET_B not set
                    ],
                }),
            ],
        ]);

        const unset = findUnsetAllocations(allocations, commitmentDataMap);

        expect(unset).toHaveLength(1);
        expect(unset[0].wallet).toBe(WALLET_B);
    });
});

describe("calculateTotalByToken", () => {
    it("calculates total per token", () => {
        const allocations = [
            makeAllocation({ token: TOKEN_USDC, acceptedAmount: 100n }),
            makeAllocation({ token: TOKEN_USDC, acceptedAmount: 200n, saleSpecificEntityID: ENTITY_2 }),
            makeAllocation({ token: TOKEN_USDT, acceptedAmount: 500n, saleSpecificEntityID: ENTITY_3 }),
        ];

        const totals = calculateTotalByToken(allocations);

        expect(totals.get(TOKEN_USDC)).toBe(300n);
        expect(totals.get(TOKEN_USDT)).toBe(500n);
    });

    it("returns empty map for empty allocations", () => {
        const totals = calculateTotalByToken([]);

        expect(totals.size).toBe(0);
    });
});

describe("validateAllAllocations", () => {
    it("returns valid for correct allocations", () => {
        const allocations = [makeAllocation({ saleSpecificEntityID: ENTITY_1, acceptedAmount: 500n })];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [
                ENTITY_1,
                makeCommitmentData({
                    saleSpecificEntityID: ENTITY_1,
                    committedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
                }),
            ],
        ]);

        const result = validateAllAllocations(allocations, commitmentDataMap);

        expect(result.valid).toBe(true);
        expect(result.errors).toHaveLength(0);
    });

    it("aggregates errors from multiple validations", () => {
        const allocations = [
            makeAllocation({ saleSpecificEntityID: ENTITY_1, acceptedAmount: 0n }), // zero
            makeAllocation({ saleSpecificEntityID: ENTITY_1, acceptedAmount: 100n }), // duplicate entity
            makeAllocation({ saleSpecificEntityID: ENTITY_1, acceptedAmount: 100n }), // duplicate
        ];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [
                ENTITY_1,
                makeCommitmentData({
                    saleSpecificEntityID: ENTITY_1,
                    committedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
                }),
            ],
        ]);

        const result = validateAllAllocations(allocations, commitmentDataMap);

        expect(result.valid).toBe(false);
        expect(result.errors.length).toBeGreaterThan(1);
    });

    it("catches entity not found", () => {
        const allocations = [makeAllocation({ saleSpecificEntityID: ENTITY_1 })];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>(); // No entities

        const result = validateAllAllocations(allocations, commitmentDataMap);

        expect(result.valid).toBe(false);
        expect(result.errors.some((e) => e.type === "entity_not_found")).toBe(true);
    });

    it("catches refunded entity", () => {
        const allocations = [makeAllocation({ saleSpecificEntityID: ENTITY_1 })];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [
                ENTITY_1,
                makeCommitmentData({
                    saleSpecificEntityID: ENTITY_1,
                    refunded: true,
                    committedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
                }),
            ],
        ]);

        const result = validateAllAllocations(allocations, commitmentDataMap);

        expect(result.valid).toBe(false);
        expect(result.errors.some((e) => e.type === "entity_refunded")).toBe(true);
    });

    it("catches allocation exceeding commitment", () => {
        const allocations = [makeAllocation({ saleSpecificEntityID: ENTITY_1, acceptedAmount: 2000n })];
        const commitmentDataMap = new Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>([
            [
                ENTITY_1,
                makeCommitmentData({
                    saleSpecificEntityID: ENTITY_1,
                    committedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
                }),
            ],
        ]);

        const result = validateAllAllocations(allocations, commitmentDataMap);

        expect(result.valid).toBe(false);
        expect(result.errors.some((e) => e.type === "exceeds_commitment")).toBe(true);
    });
});
