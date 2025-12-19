import { Abi, createPublicClient, createWalletClient, getContract, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { mainnet } from "viem/chains";
import { offchainSettlementAbi } from "./abis/IOffchainSettlement";
import { commitmentDataReaderAbi } from "./abis/ICommitmentDataReader";
import { entityAllocationDataReaderAbi } from "./abis/IEntityAllocationDataReader";
import type { Allocation, CommitmentDataWithAcceptedAmounts } from "./types.ts";

export interface Config {
    saleAddress: `0x${string}`;
    rpcUrl: string;
}

const publicClient = (config: Config) => {
    return createPublicClient({
        chain: mainnet,
        transport: http(config.rpcUrl, {
            timeout: 10000000,
        }),
    });
};

export function createContractReader<T extends Abi>(config: Config, abi: T) {
    return getContract({
        address: config.saleAddress,
        abi,
        client: publicClient(config),
    });
}

export function createContractWriter<T extends Abi>(config: Config, privateKey: `0x${string}`, abi: T) {
    const account = privateKeyToAccount(privateKey);
    const walletClient = createWalletClient({
        account,
        chain: mainnet,
        transport: http(config.rpcUrl, {
            timeout: 10000000,
        }),
    });
    return getContract({
        address: config.saleAddress,
        abi: offchainSettlementAbi,
        client: { public: publicClient(config), wallet: walletClient },
    });
}

const MAX_BATCH_SIZE = 2000n;

async function listInBatches<T>(
    getTotal: () => Promise<bigint>,
    readBatch: (from: bigint, to: bigint) => Promise<readonly T[]>,
): Promise<T[]> {
    const total = await getTotal();

    type Batch = { from: bigint; to: bigint };
    const batches: Batch[] = [];
    for (let i = 0n; i < total; i += MAX_BATCH_SIZE) {
        const from = i;
        const to = i + MAX_BATCH_SIZE < total ? i + MAX_BATCH_SIZE : total;
        batches.push({ from, to });
    }

    const results = await Promise.all(batches.map((b) => readBatch(b.from, b.to)));

    return results.flat();
}

async function listCommitmentData(config: Config) {
    const reader = createContractReader(config, commitmentDataReaderAbi);

    return listInBatches(
        () => reader.read.numCommitments(),
        (from, to) => reader.read.readCommitmentDataIn([from, to]),
    );
}

async function listEntityAllocationData(config: Config) {
    const reader = createContractReader(config, entityAllocationDataReaderAbi);

    return listInBatches(
        () => reader.read.numEntityAllocations(),
        (from, to) => reader.read.readEntityAllocationDataIn([from, to]),
    );
}

/**
 * Fetches commitment data and entity allocation data, then merges them
 * into the expected CommitmentData format.
 */
export async function listCommitmentDataWithAcceptedAmounts(
    config: Config,
): Promise<CommitmentDataWithAcceptedAmounts[]> {
    const [rawCommitments, rawAllocations] = await Promise.all([
        listCommitmentData(config),
        listEntityAllocationData(config),
    ]);

    // Build a map of entity ID -> accepted amounts
    const allocationMap = new Map(rawAllocations.map((a) => [a.saleSpecificEntityID, a.acceptedAmounts]));

    // Transform and merge the data
    return rawCommitments.map((c) => ({
        commitmentID: c.commitmentID,
        saleSpecificEntityID: c.saleSpecificEntityID,
        timestamp: c.timestamp,
        price: c.price,
        lockup: c.lockup,
        refunded: c.refunded,
        extraData: c.extraData,
        committedAmounts: c.amounts.map((a) => ({
            wallet: a.wallet,
            token: a.token,
            amount: a.amount,
        })),
        acceptedAmounts: (allocationMap.get(c.saleSpecificEntityID) ?? []).map((a) => ({
            wallet: a.wallet,
            token: a.token,
            amount: a.amount,
        })),
    }));
}

export function waitForTransactionReceipt(config: Config, hash: `0x${string}`) {
    return publicClient(config).waitForTransactionReceipt({ hash });
}

export function createBatches<T>(items: T[], batchSize: number): T[][] {
    const batches: T[][] = [];
    for (let i = 0; i < items.length; i += batchSize) {
        batches.push(items.slice(i, i + batchSize));
    }
    return batches;
}

export function parseBoolean(value: string): boolean {
    if (value === "true") return true;
    if (value === "false") return false;
    throw new Error(`Invalid boolean "${value}". Expected "true" or "false".`);
}

export function parseAddress(value: string): `0x${string}` {
    if (!/^0x[a-fA-F0-9]{40}$/.test(value)) {
        throw new Error(`Invalid address "${value}". Expected format: 0x followed by 40 hexadecimal characters.`);
    }
    return value as `0x${string}`;
}

export const formatAmount = (amount: bigint, decimals: number) => {
    const intAmount = amount / 10n ** BigInt(decimals);
    const decimalAmount = amount % 10n ** BigInt(decimals);
    return `${intAmount.toLocaleString()}.${decimalAmount.toString().padStart(decimals, "0")}`;
};

export function findUnsetAllocations(
    allocations: Allocation[],
    commitmentDataMap: Map<`0x${string}`, CommitmentDataWithAcceptedAmounts>,
): Allocation[] {
    return allocations.filter((allocation) => {
        const commitment = commitmentDataMap.get(allocation.saleSpecificEntityID);
        if (!commitment) {
            return false; // Should already have been caught by validation
        }

        const accepted = commitment.acceptedAmounts.find(
            (a) => a.wallet === allocation.wallet && a.token === allocation.token,
        );
        return accepted === undefined || accepted.amount === 0n;
    });
}

export function calculateTotalByToken(allocations: Allocation[]): Map<`0x${string}`, bigint> {
    return allocations.reduce((acc, allocation) => {
        const current = acc.get(allocation.token) ?? 0n;
        acc.set(allocation.token, current + allocation.acceptedAmount);
        return acc;
    }, new Map<`0x${string}`, bigint>());
}
