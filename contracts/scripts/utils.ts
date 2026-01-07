import { Abi, createPublicClient, getContract, http } from "viem";
import { mainnet } from "viem/chains";
import { commitmentDataReaderAbi } from "./abis/ICommitmentDataReader";
import { entityAllocationDataReaderAbi } from "./abis/IEntityAllocationDataReader";

export interface Config {
    saleAddress: `0x${string}`;
    rpcUrl: string;
}

function createContractReader<T extends Abi>(config: Config, abi: T) {
    const publicClient = createPublicClient({
        chain: mainnet,
        transport: http(config.rpcUrl, {
            timeout: 10000000,
        }),
    });

    return getContract({
        address: config.saleAddress,
        abi,
        client: publicClient,
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

export async function listCommitmentData(config: Config) {
    const reader = createContractReader(config, commitmentDataReaderAbi);

    return listInBatches(
        () => reader.read.numCommitments(),
        (from, to) => reader.read.readCommitmentDataIn([from, to]),
    );
}

export async function listEntityAllocationData(config: Config) {
    const reader = createContractReader(config, entityAllocationDataReaderAbi);

    return listInBatches(
        () => reader.read.numEntityAllocations(),
        (from, to) => reader.read.readEntityAllocationDataIn([from, to]),
    );
}
