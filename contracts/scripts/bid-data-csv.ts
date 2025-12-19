import { Command, InvalidArgumentError } from "commander";
import { type Config, listBidData } from "./utils.ts";

function parseAddress(value: string): `0x${string}` {
    if (!/^0x[a-fA-F0-9]{40}$/.test(value)) {
        throw new InvalidArgumentError(
            `Invalid address "${value}". Expected format: 0x followed by 40 hexadecimal characters.`,
        );
    }
    return value as `0x${string}`;
}

function parseCliArgs(): Config {
    const program = new Command()
        .name("bid-data-csv")
        .description("Export auction bid data to CSV format")
        .requiredOption("--sale-address <address>", "Ethereum address of the sale contract", parseAddress)
        .requiredOption("--rpc-url <url>", "RPC URL to connect to")
        .parse();

    const opts = program.opts<{ saleAddress: `0x${string}`; rpcUrl: string }>();

    return {
        saleAddress: opts.saleAddress,
        rpcUrl: opts.rpcUrl,
    };
}

async function run() {
    const config = parseCliArgs();
    const bids = await listBidData(config);

    // CSV header
    const header = [
        "SALE_SPECIFIC_ENTITY_ID",
        "BID_ID",
        "COMMITTER",
        "TIMESTAMP",
        "PRICE",
        "AMOUNT",
        "REFUNDED",
        "EXTRA_DATA",
    ].join(",");

    // CSV rows
    const rows = bids.map((bid) =>
        [
            bid.saleSpecificEntityID,
            bid.bidID,
            bid.committer,
            bid.timestamp.toString(),
            bid.price.toString(),
            bid.amount.toString(),
            bid.refunded.toString(),
            bid.extraData,
        ].join(","),
    );

    console.log(header);
    rows.forEach((row) => console.log(row));
}

run().catch(console.error);
