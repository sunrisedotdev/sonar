import { Command, InvalidArgumentError } from "commander";
import { type Config, listCommitmentData, listEntityAllocationData } from "./utils.ts";

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
        .name("commitment-data-csv")
        .description("Export commitment data to CSV format")
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

    // Fetch commitment data and entity allocation data in parallel
    const [commitments, entityAllocations] = await Promise.all([
        listCommitmentData(config),
        listEntityAllocationData(config),
    ]);

    // Flatten commitments to rows
    const commitmentRows = commitments.flatMap((commitment) =>
        commitment.amounts.map((c) => ({
            entityId: commitment.saleSpecificEntityID,
            commitmentId: commitment.commitmentID,
            wallet: c.wallet,
            token: c.token,
            timestamp: commitment.timestamp,
            price: commitment.price,
            refunded: commitment.refunded,
            extraData: commitment.extraData,
            committed: c.amount,
        })),
    );

    // Build accepted amounts lookup (entityID:wallet:token -> amount)
    const acceptedAmounts = new Map(
        entityAllocations.flatMap((allocation) =>
            allocation.acceptedAmounts.map(
                (a) => [`${allocation.saleSpecificEntityID}:${a.wallet}:${a.token}`, a.amount] as const,
            ),
        ),
    );

    // CSV header
    const header = [
        "SALE_SPECIFIC_ENTITY_ID",
        "COMMITMENT_ID",
        "WALLET",
        "TOKEN",
        "TIMESTAMP",
        "PRICE",
        "COMMITTED_AMOUNT",
        "ACCEPTED_AMOUNT",
        "REFUNDED",
        "EXTRA_DATA",
    ].join(",");

    // Generate CSV rows
    const rows = commitmentRows.map((row) => {
        const accepted = acceptedAmounts.get(`${row.entityId}:${row.wallet}:${row.token}`) ?? 0n;
        return [
            row.entityId,
            row.commitmentId,
            row.wallet,
            row.token,
            row.timestamp.toString(),
            row.price.toString(),
            row.committed.toString(),
            accepted.toString(),
            row.refunded.toString(),
            row.extraData,
        ].join(",");
    });

    console.log(header);
    rows.forEach((row) => console.log(row));
}

run().catch(console.error);
