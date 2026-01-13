import type { Allocation, CommitmentDataWithAcceptedAmounts } from "./types.ts";

export type ValidationError = {
    type:
        | "zero_allocation"
        | "duplicate_allocation"
        | "duplicate_commitment"
        | "entity_not_found"
        | "entity_refunded"
        | "exceeds_commitment"
        | "no_matching_commitment";
    message: string;
    details?: Record<string, unknown>;
};

export type ValidationResult = {
    valid: boolean;
    errors: ValidationError[];
};

export function validateNoZeroAllocations(allocations: Allocation[]): ValidationResult {
    const errors: ValidationError[] = [];

    for (const allocation of allocations) {
        if (allocation.acceptedAmount === 0n) {
            errors.push({
                type: "zero_allocation",
                message: `Allocation has 0 accepted amount`,
                details: {
                    saleSpecificEntityID: allocation.saleSpecificEntityID,
                    wallet: allocation.wallet,
                    token: allocation.token,
                },
            });
        }
    }

    return { valid: errors.length === 0, errors };
}

export function validateNoDuplicateAllocations(allocations: Allocation[]): ValidationResult {
    const errors: ValidationError[] = [];
    const seen = new Set<string>();

    for (const allocation of allocations) {
        const key = `${allocation.saleSpecificEntityID}:${allocation.wallet}:${allocation.token}`;
        if (seen.has(key)) {
            errors.push({
                type: "duplicate_allocation",
                message: `Duplicate allocation in CSV`,
                details: {
                    saleSpecificEntityID: allocation.saleSpecificEntityID,
                    wallet: allocation.wallet,
                    token: allocation.token,
                },
            });
        }
        seen.add(key);
    }

    return { valid: errors.length === 0, errors };
}

export function validateNoDuplicateCommitments(commitmentData: CommitmentDataWithAcceptedAmounts[]): ValidationResult {
    const errors: ValidationError[] = [];
    const seen = new Set<string>();

    for (const commitment of commitmentData) {
        for (const committed of commitment.committedAmounts) {
            const key = `${commitment.saleSpecificEntityID}:${committed.wallet}:${committed.token}`;
            if (seen.has(key)) {
                errors.push({
                    type: "duplicate_commitment",
                    message: `Duplicate commitment`,
                    details: {
                        saleSpecificEntityID: commitment.saleSpecificEntityID,
                        wallet: committed.wallet,
                        token: committed.token,
                    },
                });
            }
            seen.add(key);
        }
    }

    return { valid: errors.length === 0, errors };
}

export function validateEntitiesExistAndNotRefunded(
    allocations: Allocation[],
    commitmentDataMap: Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>,
): ValidationResult {
    const errors: ValidationError[] = [];

    for (const allocation of allocations) {
        const commitment = commitmentDataMap.get(allocation.saleSpecificEntityID);

        if (!commitment) {
            errors.push({
                type: "entity_not_found",
                message: `Entity not found in commitment data`,
                details: {
                    saleSpecificEntityID: allocation.saleSpecificEntityID,
                },
            });
            continue;
        }

        if (commitment.refunded) {
            errors.push({
                type: "entity_refunded",
                message: `Entity has already been refunded`,
                details: {
                    saleSpecificEntityID: allocation.saleSpecificEntityID,
                },
            });
        }
    }

    return { valid: errors.length === 0, errors };
}

export function validateAllocationsWithinCommitments(
    allocations: Allocation[],
    commitmentDataMap: Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>,
): ValidationResult {
    const errors: ValidationError[] = [];

    for (const allocation of allocations) {
        const commitment = commitmentDataMap.get(allocation.saleSpecificEntityID);

        if (!commitment) {
            // This is handled by validateEntitiesExistAndNotRefunded
            continue;
        }

        const matchingCommitted = commitment.committedAmounts.find(
            (c) => c.wallet === allocation.wallet && c.token === allocation.token,
        );

        if (!matchingCommitted) {
            errors.push({
                type: "no_matching_commitment",
                message: `No matching commitment found`,
                details: {
                    saleSpecificEntityID: allocation.saleSpecificEntityID,
                    wallet: allocation.wallet,
                    token: allocation.token,
                },
            });
            continue;
        }

        if (allocation.acceptedAmount > matchingCommitted.amount) {
            errors.push({
                type: "exceeds_commitment",
                message: `Allocation exceeds committed amount`,
                details: {
                    saleSpecificEntityID: allocation.saleSpecificEntityID,
                    wallet: allocation.wallet,
                    token: allocation.token,
                    acceptedAmount: allocation.acceptedAmount.toString(),
                    committedAmount: matchingCommitted.amount.toString(),
                },
            });
        }
    }

    return { valid: errors.length === 0, errors };
}

export function validateAllocations(
    allocations: Allocation[],
    commitmentDataMap: Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>,
): ValidationResult {
    const allErrors: ValidationError[] = [];

    // Validate allocations
    const noZero = validateNoZeroAllocations(allocations);
    allErrors.push(...noZero.errors);

    const noDuplicateAlloc = validateNoDuplicateAllocations(allocations);
    allErrors.push(...noDuplicateAlloc.errors);

    // Validate commitment data
    const commitmentData = Array.from(commitmentDataMap.values());
    const noDuplicateCommit = validateNoDuplicateCommitments(commitmentData);
    allErrors.push(...noDuplicateCommit.errors);

    // Cross-validate allocations against commitments
    const entitiesValid = validateEntitiesExistAndNotRefunded(allocations, commitmentDataMap);
    allErrors.push(...entitiesValid.errors);

    const withinCommitments = validateAllocationsWithinCommitments(allocations, commitmentDataMap);
    allErrors.push(...withinCommitments.errors);

    return { valid: allErrors.length === 0, errors: allErrors };
}
