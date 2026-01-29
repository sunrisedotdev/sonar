import { Command, InvalidArgumentError } from "commander";
import { type Config, listCommitmentDataWithAcceptedAmounts } from "./utils.ts";
import { writeFileSync } from "fs";

interface CliConfig extends Config {
    outputCsv?: string;
}

function parseAddress(value: string): `0x${string}` {
    if (!/^0x[a-fA-F0-9]{40}$/.test(value)) {
        throw new InvalidArgumentError(
            `Invalid address "${value}". Expected format: 0x followed by 40 hexadecimal characters.`,
        );
    }
    return value as `0x${string}`;
}

function parseCliArgs(): CliConfig {
    const program = new Command()
        .name("commitment-data-csv")
        .description("Export commitment data to CSV format")
        .requiredOption("--sale-address <address>", "Ethereum address of the sale contract", parseAddress)
        .requiredOption("--rpc-url <url>", "RPC URL to connect to")
        .option("--output-csv <path>", "Path to write CSV output (defaults to stdout)")
        .parse();

    const opts = program.opts<{ saleAddress: `0x${string}`; rpcUrl: string; outputCsv?: string }>();

    return {
        saleAddress: opts.saleAddress,
        rpcUrl: opts.rpcUrl,
        outputCsv: opts.outputCsv,
    };
}

async function run() {
    const config = parseCliArgs();

    const commitments = await listCommitmentDataWithAcceptedAmounts(config);

    // Build accepted amounts lookup (entityID:wallet:token -> amount)
    const acceptedAmounts = new Map(
        commitments.flatMap((c) =>
            c.acceptedAmounts.map((a) => [`${c.saleSpecificEntityID}:${a.wallet}:${a.token}`, a.amount] as const),
        ),
    );

    // Flatten commitments to rows
    const commitmentRows = commitments.flatMap((commitment) =>
        commitment.committedAmounts.map((c) => ({
            entityId: commitment.saleSpecificEntityID,
            commitmentId: commitment.commitmentID,
            wallet: c.wallet,
            token: c.token,
            timestamp: commitment.timestamp,
            price: commitment.price,
            lockup: commitment.lockup,
            refunded: commitment.refunded,
            extraData: commitment.extraData,
            committed: c.amount,
        })),
    );

    // CSV header
    const header = [
        "SALE_SPECIFIC_ENTITY_ID",
        "WALLET",
        "TOKEN",
        "COMMITMENT_ID",
        "TIMESTAMP",
        "PRICE",
        "LOCKUP",
        "COMMITTED_AMOUNT",
        "ACCEPTED_AMOUNT",
        "REFUNDED",
        "EXTRA_DATA",
    ].join(",");

    // CSV rows
    const rows = commitmentRows.map((row) => {
        const accepted = acceptedAmounts.get(`${row.entityId}:${row.wallet}:${row.token}`) ?? 0n;
        return [
            row.entityId,
            row.wallet,
            row.token,
            row.commitmentId,
            row.timestamp.toString(),
            row.price.toString(),
            row.lockup.toString(),
            row.committed.toString(),
            accepted.toString(),
            row.refunded.toString(),
            row.extraData,
        ].join(",");
    });

    const csvContent = [header, ...rows].join("\n") + "\n";

    if (config.outputCsv) {
        writeFileSync(config.outputCsv, csvContent);
        console.log(`Wrote ${rows.length} rows to ${config.outputCsv}`);
    } else {
        process.stdout.write(csvContent);
    }
}

run().catch(console.error);
