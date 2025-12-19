import { Command } from "commander";
import {
    formatAmount,
    parseAddress,
    parseBoolean,
    createBatches,
    waitForTransactionReceipt,
    listCommitmentDataWithAcceptedAmounts,
    findUnsetAllocations,
    calculateTotalByToken,
    createContractWriter,
    createContractReader,
} from "./utils.ts";
import { validateAllAllocations } from "./validation.ts";
import type { Allocation } from "./types.ts";
import { readFileSync } from "fs";
import * as readline from "readline";
import { offchainSettlementAbi } from "./abis/IOffchainSettlement.ts";
import { totalCommitmentsReaderAbi } from "./abis/ITotalCommitmentsReader.ts";
import { totalAllocationsReaderAbi } from "./abis/ITotalAllocationsReader.ts";

const BATCH_SIZE = 500; // Adjust based on gas limits

interface Config {
    allocationsCsv: string;
    saleAddress: `0x${string}`;
    rpcUrl: string;
    paymentTokenDecimals: number;
    allowedOverwrites: boolean;
    dryRun: boolean;
}

function parseCliArgs(): Config {
    const program = new Command()
        .name("set-allocations")
        .description("Set allocations on the sale contract from a CSV file")
        .requiredOption("--allocations-csv <path>", "Path to the allocations CSV file")
        .requiredOption("--allowed-overwrites <boolean>", "Whether to allow overwrites", parseBoolean, false)
        .requiredOption("--sale-address <address>", "Ethereum address of the sale contract", parseAddress)
        .requiredOption("--rpc-url <url>", "RPC URL to connect to")
        .requiredOption("--payment-token-decimals <decimals>", "Payment token decimals", parseInt, 6)
        .option("--dry-run <boolean>", "Validate without submitting transactions (default: true)", parseBoolean, true)
        .parse();

    const opts = program.opts<{
        allocationsCsv: string;
        saleAddress: `0x${string}`;
        rpcUrl: string;
        paymentTokenDecimals: number;
        allowedOverwrites: boolean;
        dryRun: boolean;
    }>();

    return {
        saleAddress: opts.saleAddress,
        rpcUrl: opts.rpcUrl,
        allocationsCsv: opts.allocationsCsv,
        paymentTokenDecimals: opts.paymentTokenDecimals,
        allowedOverwrites: opts.allowedOverwrites,
        dryRun: opts.dryRun,
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

async function promptConfirmation(message: string): Promise<boolean> {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
    });

    return new Promise((resolve) => {
        rl.question(`${message} [y/N]: `, (answer) => {
            rl.close();
            resolve(answer.toLowerCase() === "y" || answer.toLowerCase() === "yes");
        });
    });
}

async function run() {
    const config = parseCliArgs();
    const privateKey = getPrivateKey();
    const totalCommitmentsReader = createContractReader(config, totalCommitmentsReaderAbi);
    const totalAllocationsReader = createContractReader(config, totalAllocationsReaderAbi);
    const offchainSettlement = createContractWriter(config, privateKey, offchainSettlementAbi);

    // Read allocations from allocations.csv
    const allocations = readAllocations(config.allocationsCsv);
    console.log(`\nRead ${allocations.length} allocations from CSV`);

    const totalToAllocateInCSV = calculateTotalByToken(allocations);

    console.log("Loading total committed...");
    const totalCommitted = await totalCommitmentsReader.read.totalCommittedAmountByToken();

    console.log("Loading total accepted...");
    const totalAccepted = await totalAllocationsReader.read.totalAcceptedAmountByToken();

    console.log("Loading commitment data...");
    const commitmentData = await listCommitmentDataWithAcceptedAmounts(config);

    // Create commitment data map for lookups
    const commitmentDataMap = new Map(commitmentData.map((c) => [c.saleSpecificEntityID, c]));

    // Find unset allocations
    const unsetAllocations = findUnsetAllocations(allocations, commitmentDataMap);
    const totalUnsetAllocationByToken = calculateTotalByToken(unsetAllocations);

    // Run all validations
    const validationResult = validateAllAllocations(allocations, commitmentDataMap);
    if (!validationResult.valid) {
        const errorMessages = validationResult.errors
            .map((e) => `  - [${e.type}] ${e.message}: ${JSON.stringify(e.details)}`)
            .join("\n");
        throw new Error(`Validation failed with ${validationResult.errors.length} error(s):\n${errorMessages}`);
    }

    // Create batches of allocations
    const batches = createBatches(allocations, BATCH_SIZE);

    console.log("\n=== SUMMARY ===");
    console.log(`Sale contract: ${config.saleAddress}`);
    console.log(`Committers in contract: ${commitmentData.length}`);
    console.log(`Total committed by token in contract:`);
    for (const { token, amount } of totalCommitted) {
        console.log(`  ${token}: ${formatAmount(amount, config.paymentTokenDecimals)}`);
    }
    console.log(`Total accepted by token in contract:`);
    for (const { token, amount } of totalAccepted) {
        console.log(`  ${token}: ${formatAmount(amount, config.paymentTokenDecimals)}`);
    }
    console.log();
    console.log(
        `Total unique entity,wallet,token in CSV: ${allocations.length} (not allocated in contract: ${unsetAllocations.length})`,
    );
    console.log(`Total accepted by token in CSV:`);
    for (const [token, total] of totalToAllocateInCSV) {
        console.log(`  ${token}: ${formatAmount(total, config.paymentTokenDecimals)}`);
    }
    console.log(`Total accepted by token in CSV, not allocated in contract:`);
    for (const [token, total] of totalUnsetAllocationByToken) {
        console.log(`  ${token}: ${formatAmount(total, config.paymentTokenDecimals)}`);
    }
    console.log(`Batches to submit: ${batches.length}`);
    console.log(`Allow overwrites: ${config.allowedOverwrites}`);
    console.log();

    // If dry-run mode, print summary and exit
    if (config.dryRun) {
        console.log("\n=== DRY RUN MODE ===");
        console.log("Validation passed. No transactions will be submitted.");
        console.log("To submit transactions, run with --dry-run false\n");
        return;
    }

    const confirmed = await promptConfirmation("Do you want to submit these transactions?");
    if (!confirmed) {
        console.log("Aborted by user.");
        return;
    }

    console.log();

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

    console.log("\nAll batches have been submitted successfully.\n");

    // Check that all transactions are done and fetch the total allocated amount from the contract
    const totalAcceptedAfter = await totalAllocationsReader.read.totalAcceptedAmountByToken();
    console.log(`Total accept by token after:`);
    for (const { token, amount } of totalAcceptedAfter) {
        console.log(`  ${token}: ${formatAmount(amount, config.paymentTokenDecimals)}`);
    }

    if (totalAcceptedAfter.length !== totalToAllocateInCSV.size) {
        console.warn(
            `⚠ Warning: Total accepted amount by token after does not match total to allocate by token in CSV`,
        );
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

// expects a CSV file with the following format:
// SALE_SPECIFIC_ENTITY_ID,WALLET,TOKEN,ACCEPTED_AMOUNT
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
            const [saleSpecificEntityID, wallet, token, acceptedAmount] = line.split(",").map((s) => s.trim());
            return {
                saleSpecificEntityID: `0x${saleSpecificEntityID.replace(/^0x/, "")}` as `0x${string}`,
                wallet: `0x${wallet.replace(/^0x/, "")}` as `0x${string}`,
                token: `0x${token.replace(/^0x/, "")}` as `0x${string}`,
                acceptedAmount: BigInt(acceptedAmount),
            };
        });
}

run().catch(console.error);
