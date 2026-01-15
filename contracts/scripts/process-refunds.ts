import { Command } from "commander";
import {
    createBatches,
    createContractReader,
    createContractWriter,
    formatAmount,
    listCommitmentDataWithAcceptedAmounts,
    parseAddress,
    parseBoolean,
    tryGetPrivateKey,
    waitForTransactionReceipt,
} from "./utils.ts";
import { settlementSaleAbi } from "./abis/SettlementSale.ts";
import { CommitmentDataWithAcceptedAmounts } from "./types.ts";

interface Config {
    saleAddress: `0x${string}`;
    rpcUrl: string;
    paymentTokenDecimals: number;
    dryRun: boolean;
    batchSize: number;
    maxPriorityFeePerGas: bigint | undefined;
}

function parseCliArgs(): Config {
    const program = new Command()
        .name("process-refunds")
        .description(
            "Process all refunds for committers on the sale contract. Must be run after all allocations have been set.",
        )
        .requiredOption("--sale-address <address>", "Ethereum address of the sale contract", parseAddress)
        .requiredOption("--rpc-url <url>", "RPC URL to connect to")
        .option("--payment-token-decimals <decimals>", "Payment token decimals", (val) => parseInt(val, 10), 6)
        .option("--dry-run <boolean>", "Validate without submitting transactions (default: true)", parseBoolean, true)
        .option("--batch-size <size>", "Number of committers per batch (default: 200)", (val) => parseInt(val, 10), 200)
        .option(
            "--max-priority-fee-per-gas <wei>",
            "Max priority fee per gas in wei (optional, for faster inclusion)",
            (val) => BigInt(val),
        )
        .parse();

    const opts = program.opts<{
        saleAddress: `0x${string}`;
        rpcUrl: string;
        dryRun: boolean;
        paymentTokenDecimals: number;
        batchSize: number;
        maxPriorityFeePerGas: bigint | undefined;
    }>();

    return {
        saleAddress: opts.saleAddress,
        rpcUrl: opts.rpcUrl,
        paymentTokenDecimals: opts.paymentTokenDecimals,
        dryRun: opts.dryRun,
        batchSize: opts.batchSize,
        maxPriorityFeePerGas: opts.maxPriorityFeePerGas,
    };
}

async function run() {
    const config = parseCliArgs();
    const contractReader = createContractReader(config, settlementSaleAbi);

    console.log("Loading total committed...");
    const totalCommitted = await contractReader.read.totalCommittedAmountByToken();

    console.log("Loading total accepted...");
    const totalAccepted = await contractReader.read.totalAcceptedAmountByToken();

    console.log("Loading total refunded...");
    const totalRefunded = await contractReader.read.totalRefundedAmountByToken();

    // Subtract totalAccepted and totalRefunded from totalCommitted to get the total amount to refund by token
    const totalAmountToRefundByToken = new Map<`0x${string}`, bigint>();
    for (const { token, amount } of totalCommitted) {
        const accepted = totalAccepted.find((t) => t.token === token);
        const refunded = totalRefunded.find((t) => t.token === token);
        totalAmountToRefundByToken.set(token, amount - (accepted?.amount || 0n) - (refunded?.amount || 0n));
    }

    console.log("Loading commitment data...");
    const commitmentData = await listCommitmentDataWithAcceptedAmounts(config);

    const committersToRefund = commitmentData.filter(
        (commitment) => !commitment.refunded && commitmentRefundAmount(commitment) > 0n,
    );

    // Sanity check that the calculated totals match the totalAmountToRefundByToken
    const refundByTokenFromCommitmentData = new Map<`0x${string}`, bigint>();
    for (const commitment of committersToRefund) {
        for (const committedAmount of commitment.committedAmounts) {
            const accepted =
                commitment.acceptedAmounts.find(
                    (a) => a.wallet === committedAmount.wallet && a.token === committedAmount.token,
                )?.amount ?? 0n;
            const refundForToken = committedAmount.amount - accepted;
            refundByTokenFromCommitmentData.set(
                committedAmount.token,
                (refundByTokenFromCommitmentData.get(committedAmount.token) ?? 0n) + refundForToken,
            );
        }
    }
    for (const [token, expectedAmount] of totalAmountToRefundByToken) {
        const fromCommitmentData = refundByTokenFromCommitmentData.get(token) ?? 0n;
        if (fromCommitmentData !== expectedAmount) {
            throw new Error(
                `Total amount to refund for token ${token} from commitmentData (${fromCommitmentData}) does not match expected (${expectedAmount})`,
            );
        }
    }

    // Create batches of commitments to refund
    const batches = createBatches(committersToRefund, config.batchSize);

    console.log("\n=== SUMMARY ===");
    console.log(`Sale contract: ${config.saleAddress}`);
    console.log(`Commitments in contract: ${commitmentData.length}`);
    console.log(`Commitments to refund: ${committersToRefund.length}`);
    console.log(`Total committed by token in contract:`);
    for (const { token, amount } of totalCommitted) {
        console.log(`  ${token}: ${formatAmount(amount, config.paymentTokenDecimals)}`);
    }
    console.log(`Total accepted by token in contract:`);
    for (const { token, amount } of totalAccepted) {
        console.log(`  ${token}: ${formatAmount(amount, config.paymentTokenDecimals)}`);
    }
    console.log(`Total refunded by token in contract (includes cancellations):`);
    for (const { token, amount } of totalRefunded) {
        console.log(`  ${token}: ${formatAmount(amount, config.paymentTokenDecimals)}`);
    }
    console.log();
    console.log(`Total amount to refund by token:`);
    for (const [token, amount] of totalAmountToRefundByToken) {
        console.log(`  ${token}: ${formatAmount(amount, config.paymentTokenDecimals)}`);
    }
    console.log(`Batches to submit: ${batches.length}`);
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
    const contractWriter = createContractWriter(config, privateKey, settlementSaleAbi);
    console.log();

    let totalGasEstimate = 0n;
    // Post the batches to the contract with `processRefunds`
    for (let i = 0; i < batches.length; i++) {
        console.log(`Processing batch ${i + 1}/${batches.length} with ${batches[i].length} entities to refund...`);

        const entityIDs = batches[i].map((state) => state.saleSpecificEntityID);

        const gasEstimate = await contractWriter.estimateGas.processRefunds([entityIDs, true]);
        console.log(`  Gas estimate: ${gasEstimate}`);
        totalGasEstimate += gasEstimate;

        // we don't want to submit transactions in dry run mode
        if (config.dryRun) {
            console.log("  Dry run mode, skipping transaction submission");
            continue;
        }

        const hash = await contractWriter.write.processRefunds([entityIDs, true], {
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

    const totalRefundedAfter = await contractReader.read.totalRefundedAmountByToken();
    console.log(`Total refunded by token in contract after (includes cancellations):`);
    for (const { token, amount } of totalRefundedAfter) {
        console.log(`  ${token}: ${formatAmount(amount, config.paymentTokenDecimals)}`);
    }

    // Print the difference between the total refunded after and the total refunded before
    console.log(`Difference in total refunded by token:`);
    for (const { token, amount } of totalRefundedAfter) {
        const totalRefundedBefore = totalRefunded.find((t) => t.token === token)?.amount ?? 0n;
        console.log(`  ${token}: ${formatAmount(amount - totalRefundedBefore, config.paymentTokenDecimals)}`);
    }
    console.log();
}

function commitmentRefundAmount(commitment: CommitmentDataWithAcceptedAmounts): bigint {
    let totalRefund = 0n;
    for (const committedAmount of commitment.committedAmounts) {
        const accepted =
            commitment.acceptedAmounts.find(
                (a) => a.wallet === committedAmount.wallet && a.token === committedAmount.token,
            )?.amount ?? 0n;
        totalRefund += committedAmount.amount - accepted;
    }
    return totalRefund;
}

run().catch(console.error);
