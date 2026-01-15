import { Command } from "commander";
import {
    formatAmount,
    parseAddress,
    parseBoolean,
    createBatches,
    waitForTransactionReceipt,
    listCommitmentDataWithAcceptedAmounts,
    findAllocationsNeedingUpdate,
    calculateTotalByToken,
    createContractWriter,
    createContractReader,
    tryGetPrivateKey,
} from "./utils.ts";
import { validateAllocations } from "./validation.ts";
import type { Allocation } from "./types.ts";
import { readFileSync } from "fs";
import { settlementSaleAbi } from "./abis/SettlementSale.ts";
import { getAddress } from "viem";

interface Config {
    allocationsCsv: string;
    saleAddress: `0x${string}`;
    rpcUrl: string;
    paymentTokenDecimals: number;
    allowOverwrites: boolean;
    dryRun: boolean;
    batchSize: number;
    maxPriorityFeePerGas: bigint | undefined;
}

function parseCliArgs(): Config {
    const program = new Command()
        .name("set-allocations")
        .description("Set allocations on the sale contract from a CSV file")
        .requiredOption("--allocations-csv <path>", "Path to the allocations CSV file")
        .requiredOption("--allow-overwrites <boolean>", "Whether to allow overwrites", parseBoolean, false)
        .requiredOption("--sale-address <address>", "Ethereum address of the sale contract", parseAddress)
        .requiredOption("--rpc-url <url>", "RPC URL to connect to")
        .requiredOption("--payment-token-decimals <decimals>", "Payment token decimals", parseInt, 6)
        .option("--dry-run <boolean>", "Validate without submitting transactions (default: true)", parseBoolean, true)
        .option(
            "--batch-size <size>",
            "Number of allocations per batch (default: 200)",
            (val) => parseInt(val, 10),
            200,
        )
        .option(
            "--max-priority-fee-per-gas <wei>",
            "Max priority fee per gas in wei (optional, for faster inclusion)",
            (val) => BigInt(val),
        )
        .parse();

    const opts = program.opts<{
        allocationsCsv: string;
        saleAddress: `0x${string}`;
        rpcUrl: string;
        paymentTokenDecimals: number;
        allowOverwrites: boolean;
        dryRun: boolean;
        batchSize: number;
        maxPriorityFeePerGas: bigint | undefined;
    }>();

    return {
        saleAddress: opts.saleAddress,
        rpcUrl: opts.rpcUrl,
        allocationsCsv: opts.allocationsCsv,
        paymentTokenDecimals: opts.paymentTokenDecimals,
        allowOverwrites: opts.allowOverwrites,
        dryRun: opts.dryRun,
        batchSize: opts.batchSize,
        maxPriorityFeePerGas: opts.maxPriorityFeePerGas,
    };
}

async function run() {
    const config = parseCliArgs();
    const contractReader = createContractReader(config, settlementSaleAbi);

    // Read allocations from allocations.csv
    const allocations = readAllocations(config.allocationsCsv);
    console.log(`\nRead ${allocations.length} allocations from CSV`);

    const totalToAllocateInCSV = calculateTotalByToken(allocations);
    console.log(` with a total by token of:`);
    for (const [token, amount] of totalToAllocateInCSV) {
        console.log(`  ${token}: ${formatAmount(amount, config.paymentTokenDecimals)}`);
    }

    console.log("Loading total committed...");
    const totalCommitted = await contractReader.read.totalCommittedAmountByToken();

    console.log("Loading total accepted...");
    const totalAccepted = await contractReader.read.totalAcceptedAmountByToken();

    console.log("Loading commitment data...");
    const commitmentData = await listCommitmentDataWithAcceptedAmounts(config);

    // Run all validations
    const validationResult = validateAllocations(allocations, commitmentData);
    if (!validationResult.valid) {
        const errorMessages = validationResult.errors
            .map((e) => `  - [${e.type}] ${e.message}: ${JSON.stringify(e.details)}`)
            .join("\n");
        throw new Error(`Validation failed with ${validationResult.errors.length} error(s):\n${errorMessages}`);
    }

    // Find allocations that need updating (where contract accepted != CSV accepted)
    const allocationsToUpdate = findAllocationsNeedingUpdate(allocations, commitmentData);

    // Create batches of allocations (only those needing updates)
    const batches = createBatches(allocationsToUpdate.allocations, config.batchSize);

    console.log("\n=== SUMMARY ===");
    console.log(`Sale contract: ${config.saleAddress}`);
    console.log(`Total committed by token in contract (including refunds):`);
    for (const { token, amount } of totalCommitted) {
        console.log(`  ${token}: ${formatAmount(amount, config.paymentTokenDecimals)}`);
    }
    console.log(`Total accepted by token in contract:`);
    for (const { token, amount } of totalAccepted) {
        console.log(`  ${token}: ${formatAmount(amount, config.paymentTokenDecimals)}`);
    }
    console.log();
    console.log(`Number of allocations in CSV: ${allocations.length}`);
    console.log(`  of which already have a matching accepted amount in contract: ${allocationsToUpdate.numCorrectCSV}`);
    console.log();
    console.log(
        `Number of non-refunded, possibly zero, commitments by entity,wallet,token in contract: ${allocationsToUpdate.numContract}`,
    );
    console.log(`  of which already have a matching accepted amount: ${allocationsToUpdate.numCorrectContract}`);
    console.log(`  of which have no accepted amount in contract and need to be set: ${allocationsToUpdate.numUnset}`);
    console.log(
        `  of which have an accepted amount in contract but need to be overwritten: ${allocationsToUpdate.numOverwritten}`,
    );
    console.log();
    console.log(`Total number of allocations to update: ${allocationsToUpdate.allocations.length}`);
    console.log(`Batches to submit: ${batches.length}`);
    console.log(`Allow overwrites: ${config.allowOverwrites}`);
    console.log();

    // If dry-run mode, print summary and exit
    if (config.dryRun) {
        console.log("\n=== DRY RUN MODE ===");
        console.log("Validation passed. No transactions will be submitted.");
        console.log("To submit transactions, run with --dry-run false\n");
    }

    const privateKey = tryGetPrivateKey();
    if (!privateKey) {
        // in dry run mode it's fine not to have a private key, and we just skip the transaction simulation
        if (config.dryRun) {
            console.log("No PRIVATE_KEY environment variable found, skipping transaction simulation");
            return;
        }

        throw new Error("PRIVATE_KEY environment variable is required");
    }

    const offchainSettlement = createContractWriter(config, privateKey, settlementSaleAbi);
    console.log();

    let totalGasEstimate = 0n;

    // Post the batches to the contract with `setAllocations`
    for (let i = 0; i < batches.length; i++) {
        console.log(`Processing batch ${i + 1}/${batches.length} with ${batches[i].length} allocations...`);

        const contractAllocations = batches[i].map((allocation) => ({
            saleSpecificEntityID: allocation.saleSpecificEntityID,
            wallet: allocation.wallet,
            token: allocation.token,
            acceptedAmount: allocation.acceptedAmount,
        }));

        const gasEstimate = await offchainSettlement.estimateGas.setAllocations(
            [contractAllocations, config.allowOverwrites],
            {},
        );
        console.log(`  Gas estimate: ${gasEstimate}`);
        totalGasEstimate += gasEstimate;

        // we don't want to submit transactions in dry run mode
        if (config.dryRun) {
            console.log("  Dry run mode, skipping transaction submission");
            continue;
        }

        const hash = await offchainSettlement.write.setAllocations([contractAllocations, config.allowOverwrites], {
            maxPriorityFeePerGas: config.maxPriorityFeePerGas,
        });
        console.log(`  Transaction hash: ${hash}`);

        // Wait for transaction to be included in a block
        // This ensures the transaction is mined before sending the next one,
        // which allows viem to automatically manage nonces correctly
        const receipt = await waitForTransactionReceipt(config, hash);

        if (receipt.status === "reverted") {
            throw new Error(
                `Batch ${i + 1} transaction reverted in block ${receipt.blockNumber}. Transaction hash: ${hash}`,
            );
        }

        console.log(`  Confirmed in block ${receipt.blockNumber}`);
    }

    if (config.dryRun) {
        console.log(`Total gas estimate: ${totalGasEstimate}`);
        return;
    }

    console.log("\nAll batches have been submitted successfully.\n");

    // Check that all transactions are done and fetch the total allocated amount from the contract
    const totalAcceptedAfter = await contractReader.read.totalAcceptedAmountByToken();
    console.log(`Total accept by token after:`);
    for (const { token, amount } of totalAcceptedAfter) {
        console.log(`  ${token}: ${formatAmount(amount, config.paymentTokenDecimals)}`);
    }

    for (const { token, amount } of totalAcceptedAfter) {
        const totalToAllocate = totalToAllocateInCSV.get(token) ?? 0n;
        if (amount !== totalToAllocate) {
            console.warn(
                `⚠ Warning: Total accepted amount (${formatAmount(amount, config.paymentTokenDecimals)}) does not match expected total (${formatAmount(totalToAllocate, config.paymentTokenDecimals)})`,
            );
        }
    }
}

const EXPECTED_HEADER = ["SALE_SPECIFIC_ENTITY_ID", "WALLET", "TOKEN", "ACCEPTED_AMOUNT"];

export function isHeaderRow(fields: string[]): boolean {
    if (fields.length !== EXPECTED_HEADER.length) {
        return false;
    }
    return fields.every((field, i) => field.trim().toUpperCase() === EXPECTED_HEADER[i]);
}

// expects a CSV file with the following format:
// SALE_SPECIFIC_ENTITY_ID,WALLET,TOKEN,ACCEPTED_AMOUNT
// 0x...,...
function readAllocations(csvPath: string): Allocation[] {
    const csvContent = readFileSync(csvPath, "utf-8");

    const lines = csvContent.trim().split("\n");

    // Check if first line is the expected header row
    const firstLineFields = lines.length > 0 ? lines[0].split(",") : [];
    const startIndex = isHeaderRow(firstLineFields) ? 1 : 0;

    return lines
        .slice(startIndex)
        .filter((line) => line.trim().length > 0)
        .map((line) => {
            const [saleSpecificEntityID, wallet, token, acceptedAmount] = line.split(",").map((s) => s.trim());
            return {
                saleSpecificEntityID: saleSpecificEntityID as `0x${string}`,
                wallet: getAddress(wallet),
                token: getAddress(token),
                acceptedAmount: BigInt(acceptedAmount),
            };
        });
}

run().catch(console.error);
