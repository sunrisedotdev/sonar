import { createPublicClient, createWalletClient, getContract, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { mainnet } from "viem/chains";
import { auctionBidDataReaderAbi } from "./abis/IAuctionBidDataReader";
import { offchainSettlementAbi } from "./abis/IOffchainSettlement";

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

export function createAuctionBidDataReader(config: Config) {
    return getContract({
        address: config.saleAddress,
        abi: auctionBidDataReaderAbi,
        client: publicClient(config),
    });
}

export function createOffchainSettlement(config: Config, privateKey: `0x${string}`) {
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

export async function listBidData(config: Config) {
    const auctionBidDataReader = createAuctionBidDataReader(config);

    // fetch the total number of bids
    const numBids = await auctionBidDataReader.read.numBids();

    // build batches [from, to)
    type Batch = { from: bigint; to: bigint };
    const batches: Batch[] = [];
    for (let i = 0n; i < numBids; i += MAX_BATCH_SIZE) {
        const from = i;
        const to = i + MAX_BATCH_SIZE < numBids ? i + MAX_BATCH_SIZE : numBids;
        batches.push({ from, to });
    }

    // fetch bids for batches
    const bidData = await Promise.all(
        batches.map(async (b) => {
            return auctionBidDataReader.read.readBidDataIn([b.from, b.to]);
        }),
    );

    return bidData.flat();
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
