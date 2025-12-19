import { Command } from "commander";
import {
    formatAmount,
    listBidData,
    parseAddress,
    parseBoolean,
    createBatches,
    createOffchainSettlement,
    waitForTransactionReceipt,
} from "./utils.ts";
import { readFileSync } from "fs";

const BATCH_SIZE = 500; // Adjust based on gas limits

interface Config {
    allocationsCsv: string;
    saleAddress: `0x${string}`;
    rpcUrl: string;
    paymentTokenDecimals: number;
    allowedOverwrites: boolean;
}

function parseCliArgs(): Config {
    const program = new Command()
        .name("bid-data-csv")
        .description("Export auction bid data to CSV format")
        .requiredOption("--allocations-csv <path>", "Path to the allocations CSV file")
        .requiredOption("allowed-overwrites <boolean>", "Whether to allow overwrites", parseBoolean, false)
        .requiredOption("--sale-address <address>", "Ethereum address of the sale contract", parseAddress)
        .requiredOption("--rpc-url <url>", "RPC URL to connect to")
        .requiredOption("--payment-token-decimals <decimals>", "Payment token decimals", parseInt, 6)
        .parse();

    const opts = program.opts<{
        allocationsCsv: string;
        saleAddress: `0x${string}`;
        rpcUrl: string;
        paymentTokenDecimals: number;
        allowedOverwrites: boolean;
    }>();

    return {
        saleAddress: opts.saleAddress,
        rpcUrl: opts.rpcUrl,
        allocationsCsv: opts.allocationsCsv,
        paymentTokenDecimals: opts.paymentTokenDecimals,
        allowedOverwrites: opts.allowedOverwrites,
    };
}

function getPrivateKey(): `0x${string}` {
    const envKey = process.env.PRIVATE_KEY;
    if (!envKey) {
        throw new Error("PRIVATE_KEY environment variable is required");
    }
    if (!envKey.startsWith("0x")) {
        return `0x${envKey}` as `0x${string}`;
    }
    return envKey as `0x${string}`;
}

async function run() {
    const config = parseCliArgs();
    const privateKey = getPrivateKey();
    const offchainSettlement = createOffchainSettlement(config, privateKey);

    // Read allocations from allocations.csv
    const allocations = readAllocations(config.allocationsCsv);
    console.log(`\nRead ${allocations.length} allocations from CSV`);

    const totalAllocated = allocations.reduce((sum, allocation) => sum + allocation.acceptedAmount, 0n);
    console.log(`Total allocation in CSV: ${formatAmount(totalAllocated, config.paymentTokenDecimals)}\n`);

    // we don't allow 0 allocations
    for (const allocation of allocations) {
        if (allocation.acceptedAmount === 0n) {
            throw new Error(`Allocation ${allocation.committer} has 0 accepted amount`);
        }
    }

    // Log the sum of all allocations
    const totalAllocatedFromCSV = allocations.reduce((sum, allocation) => sum + allocation.acceptedAmount, 0n);
    console.log(
        `Total of all allocations from CSV: ${formatAmount(totalAllocatedFromCSV, config.paymentTokenDecimals)}`,
    );

    console.log("Loading entity states...");
    const states = await listBidData(config);
    console.log("Fetched ", states.length, " states");

    // Create a map of entity states for quick lookup
    const stateMap = new Map(states.map((state) => [state.saleSpecificEntityID, state]));

    // Check if any of the entities in the allocation have already been refunded
    const refundedEntities = allocations.filter((allocation) => {
        const state = stateMap.get(allocation.committer);
        if (!state) {
            throw new Error(`Entity ${allocation.committer} not found in entity states`);
        }

        return state.refunded === true;
    });

    if (refundedEntities.length > 0) {
        throw new Error(
            `Found ${refundedEntities.length} already refunded entities: ${refundedEntities
                .map((a) => a.committer)
                .join(", ")}`,
        );
    }

    // Check if we're trying to allocation that exceed the committed amount
    const allocationsExceedingCommitment = allocations.filter((allocation) => {
        const state = stateMap.get(allocation.committer);
        if (!state) {
            throw new Error(`Entity ${allocation.committer} not found in entity states`);
        }

        return allocation.acceptedAmount > state.amount;
    });

    if (allocationsExceedingCommitment.length > 0) {
        throw new Error(
            `Found ${
                allocationsExceedingCommitment.length
            } allocations that exceed the committed amount:\n${allocationsExceedingCommitment
                .map(
                    (a) =>
                        `${a.committer} (${formatAmount(a.acceptedAmount, config.paymentTokenDecimals)} > ${formatAmount(
                            stateMap.get(a.committer)!.amount,
                            config.paymentTokenDecimals,
                        )})`,
                )
                .join("\n")}`,
        );
    }

    // Create batches of allocations
    const batches = createBatches(allocations, BATCH_SIZE);
    console.log(`Created ${batches.length} batches of allocations`);

    // Post the batches to the contract with `setAllocations`
    for (let i = 0; i < batches.length; i++) {
        console.log(`Processing batch ${i + 1}/${batches.length} with ${batches[i].length} allocations...`);

        const contractAllocations = batches[i].map((allocation) => ({
            committer: allocation.committer,
            acceptedAmount: allocation.acceptedAmount,
        }));

        const gasEstimate = await offchainSettlement.estimateGas.setAllocations(
            [contractAllocations, config.allowedOverwrites],
            {},
        );
        console.log(`Batch ${i + 1} gas estimate: ${gasEstimate}`);

        const hash = await offchainSettlement.write.setAllocations([contractAllocations, config.allowedOverwrites]);
        console.log(`Batch ${i + 1} transaction hash: ${hash}`);

        // Wait for transaction to be included in a block
        // This ensures the transaction is mined before sending the next one,
        // which allows viem to automatically manage nonces correctly
        const receipt = await waitForTransactionReceipt(config, hash);
        console.log(`Batch ${i + 1} confirmed in block ${receipt.blockNumber}`);
    }

    console.log("All batches have been submitted\n");
}

type Allocation = {
    committer: `0x${string}`;
    acceptedAmount: bigint;
};

// expects a CSV file with the following format:
// COMMITTER,ACCEPTED_AMOUNT
// 0x...,...
function readAllocations(csvPath: string): Allocation[] {
    const csvContent = readFileSync(csvPath, "utf-8");

    const lines = csvContent.trim().split("\n");

    // Check if first line is a header (doesn't start with 0x)
    const startIndex = lines.length > 0 && !lines[0].trim().startsWith("0x") ? 1 : 0;

    return lines
        .slice(startIndex)
        .filter((line) => line.trim().length > 0)
        .map((line) => {
            const [committer, acceptedAmount] = line.split(",").map((s) => s.trim());
            return {
                committer: `0x${committer.replace(/^0x/, "")}` as `0x${string}`,
                acceptedAmount: BigInt(acceptedAmount),
            };
        });
}

run().catch(console.error);
