import { describe, it, expect } from "vitest";
import { findAllocationsNeedingUpdate } from "./utils.ts";
import type { Allocation, CommitmentDataWithAcceptedAmounts } from "./types.ts";

const ENTITY_1 = "0x0000000000000000000000000000000000000001" as const;
const ENTITY_2 = "0x0000000000000000000000000000000000000002" as const;
const WALLET_A = "0x000000000000000000000000000000000000000a" as const;
const WALLET_B = "0x000000000000000000000000000000000000000b" as const;
const TOKEN_USDC = "0x00000000000000000000000000000000000000cc" as const;

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
    overrides: Partial<CommitmentDataWithAcceptedAmounts> = {},
): CommitmentDataWithAcceptedAmounts {
    return {
        commitmentID: "0x0000000000000000000000000000000000000000000000000000000000000000",
        saleSpecificEntityID: ENTITY_1,
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

describe("findAllocationsNeedingUpdate", () => {
    it("returns allocations where contract accepted differs from CSV accepted", () => {
        const allocations = [makeAllocation({ acceptedAmount: 500n })];
        const commitmentData = [
            makeCommitmentData({
                acceptedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
            }),
        ];

        const result = findAllocationsNeedingUpdate(allocations, commitmentData);

        expect(result.allocations).toHaveLength(1);
        expect(result.allocations[0].wallet).toBe(WALLET_A);
        expect(result.allocations[0].acceptedAmount).toBe(500n);
        expect(result.numOverwritten).toBe(1);
    });

    it("excludes allocations that already match the contract", () => {
        const allocations = [makeAllocation({ acceptedAmount: 1000n })];
        const commitmentData = [
            makeCommitmentData({
                acceptedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
            }),
        ];

        const result = findAllocationsNeedingUpdate(allocations, commitmentData);

        expect(result.allocations).toHaveLength(0);
        expect(result.numCorrectContract).toBe(1);
        expect(result.numCorrectCSV).toBe(1);
    });

    it("does not include allocations for wallets not in commitmentData", () => {
        // The function iterates over commitmentData, so wallets only in CSV
        // but not in commitmentData are not returned
        const allocations = [makeAllocation({ acceptedAmount: 1000n })];
        const commitmentData: CommitmentDataWithAcceptedAmounts[] = [];

        const result = findAllocationsNeedingUpdate(allocations, commitmentData);

        expect(result.allocations).toHaveLength(0);
    });

    it("returns zero-amount allocations for committed wallets with accepted amounts not in CSV", () => {
        const allocations: Allocation[] = []; // Empty CSV - no allocations
        const commitmentData = [
            makeCommitmentData({
                committedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
                acceptedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
            }),
        ];

        const result = findAllocationsNeedingUpdate(allocations, commitmentData);

        expect(result.allocations).toHaveLength(1);
        expect(result.allocations[0].wallet).toBe(WALLET_A);
        expect(result.allocations[0].acceptedAmount).toBe(0n);
        expect(result.numOverwritten).toBe(1);
    });

    it("ignores commitments with zero accepted amounts not in CSV", () => {
        const allocations: Allocation[] = [];
        const commitmentData = [
            makeCommitmentData({
                committedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
                acceptedAmounts: [], // No accepted amounts
            }),
        ];

        const result = findAllocationsNeedingUpdate(allocations, commitmentData);

        expect(result.allocations).toHaveLength(0);
        expect(result.numCorrectContract).toBe(1);
    });

    it("handles mix of updates, removals, and unchanged allocations", () => {
        const allocations = [
            makeAllocation({ saleSpecificEntityID: ENTITY_1, wallet: WALLET_A, acceptedAmount: 500n }), // needs update (contract has 1000)
            makeAllocation({ saleSpecificEntityID: ENTITY_2, wallet: WALLET_B, acceptedAmount: 200n }), // already correct
        ];
        const WALLET_C = "0x000000000000000000000000000000000000000c" as const;
        const commitmentData = [
            makeCommitmentData({
                saleSpecificEntityID: ENTITY_1,
                committedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
                acceptedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
            }),
            makeCommitmentData({
                saleSpecificEntityID: ENTITY_2,
                committedAmounts: [
                    { wallet: WALLET_B, token: TOKEN_USDC, amount: 200n },
                    { wallet: WALLET_C, token: TOKEN_USDC, amount: 300n },
                ],
                acceptedAmounts: [
                    { wallet: WALLET_B, token: TOKEN_USDC, amount: 200n },
                    { wallet: WALLET_C, token: TOKEN_USDC, amount: 300n }, // not in CSV, should be zeroed
                ],
            }),
        ];

        const result = findAllocationsNeedingUpdate(allocations, commitmentData);

        expect(result.allocations).toHaveLength(2);
        const wallets = result.allocations.map((a) => a.wallet);
        expect(wallets).toContain(WALLET_A);
        expect(wallets).toContain(WALLET_C);

        const walletAUpdate = result.allocations.find((a) => a.wallet === WALLET_A);
        expect(walletAUpdate?.acceptedAmount).toBe(500n);

        const walletCUpdate = result.allocations.find((a) => a.wallet === WALLET_C);
        expect(walletCUpdate?.acceptedAmount).toBe(0n);

        expect(result.numCorrectContract).toBe(1);
        expect(result.numCorrectCSV).toBe(1);
        expect(result.numOverwritten).toBe(2);
    });

    it("tracks numUnset for allocations where contract has zero but CSV has non-zero", () => {
        const allocations = [makeAllocation({ acceptedAmount: 500n })];
        const commitmentData = [
            makeCommitmentData({
                committedAmounts: [{ wallet: WALLET_A, token: TOKEN_USDC, amount: 1000n }],
                acceptedAmounts: [], // No accepted amount in contract
            }),
        ];

        const result = findAllocationsNeedingUpdate(allocations, commitmentData);

        expect(result.allocations).toHaveLength(1);
        expect(result.allocations[0].acceptedAmount).toBe(500n);
        expect(result.numUnset).toBe(1);
        expect(result.numOverwritten).toBe(0);
    });
});
