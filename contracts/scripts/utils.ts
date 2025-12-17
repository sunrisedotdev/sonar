import { createPublicClient, getContract, http } from "viem";
import { mainnet } from "viem/chains";
import { auctionBidDataReaderAbi } from "./abis/IAuctionBidDataReader";

export interface Config {
    saleAddress: `0x${string}`;
    rpcUrl: string;
}

function createAuctionBidDataReader(config: Config) {
    const publicClient = createPublicClient({
        chain: mainnet,
        transport: http(config.rpcUrl, {
            timeout: 10000000,
        }),
    });

    return getContract({
        address: config.saleAddress,
        abi: auctionBidDataReaderAbi,
        client: publicClient,
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
