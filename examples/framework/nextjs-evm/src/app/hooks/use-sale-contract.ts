import { BasicPermitV3, GeneratePurchasePermitResponse, Hex } from "@echoxyz/sonar-core";
import { useCallback, useState } from "react";
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { saleContract } from "@/lib/config";
import { settlementSaleAbi } from "../abi/SettlementSale";
import { ERC20Abi } from "../abi/ERC20";
import { useConfig } from "wagmi";
import { waitForTransactionReceipt, simulateContract } from "wagmi/actions";

export const useSaleContract = (saleSpecificEntityID: Hex) => {
  const { writeContractAsync } = useWriteContract();
  const config = useConfig();

  const [txHash, setTxHash] = useState<`0x${string}` | undefined>(undefined);

  const {
    data: txReceipt,
    isFetching: awaitingTxReceipt,
    error: awaitingTxReceiptError,
  } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const commitWithPermit = useCallback(
    async ({
      purchasePermitResp,
      token,
      commitmentAmount,
      commitmentAmountIncrement,
    }: {
      purchasePermitResp: GeneratePurchasePermitResponse;
      token: `0x${string}`;
      commitmentAmount: bigint;
      commitmentAmountIncrement: bigint;
    }) => {
      if (!("OpensAt" in purchasePermitResp.PermitJSON)) {
        throw new Error("Invalid purchase permit response");
      }
      const permit = purchasePermitResp.PermitJSON as BasicPermitV3;

      const { request: approveRequest } = await simulateContract(config, {
        address: token,
        abi: ERC20Abi,
        functionName: "approve",
        args: [saleContract, commitmentAmountIncrement],
      });

      const approveHash = await writeContractAsync(approveRequest);
      await waitForTransactionReceipt(config, { hash: approveHash });

      const bidArgs = [
        token,
        { lockup: false, price: BigInt(0), amount: commitmentAmount },
        {
          saleSpecificEntityID: permit.SaleSpecificEntityID,
          saleUUID: permit.SaleUUID,
          wallet: permit.Wallet,
          expiresAt: BigInt(permit.ExpiresAt),
          minAmount: BigInt(permit.MinAmount),
          maxAmount: BigInt(permit.MaxAmount),
          minPrice: BigInt(permit.MinPrice),
          maxPrice: BigInt(permit.MaxPrice),
          opensAt: BigInt(permit.OpensAt),
          closesAt: BigInt(permit.ClosesAt),
          payload: permit.Payload,
        },
        purchasePermitResp.Signature,
      ] as const;

      // TODO could also show an example of using the replaceBidWithPermit function instead of the replaceBidWithApproval function
      const { request: bidRequest } = await simulateContract(config, {
        address: saleContract,
        abi: settlementSaleAbi,
        functionName: "replaceBidWithApproval",
        args: bidArgs,
      });

      const bidHash = await writeContractAsync(bidRequest);

      setTxHash(bidHash);
    },
    [writeContractAsync, config],
  );

  const { data: entityStates, error: entityStateError } = useReadContract({
    address: saleContract,
    abi: settlementSaleAbi,
    functionName: "entityStatesByIDs",
    args: [[saleSpecificEntityID]],
    query: {
      refetchInterval: 3000,
    },
  });

  const currentCommitmentRaw: bigint = entityStates?.[0]?.currentBid?.amount ?? BigInt(0);
  const currentCommitmentFormatted = (Number(currentCommitmentRaw) / 1e6).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

  return {
    entityStateError,
    currentCommitmentRaw,
    currentCommitmentFormatted,
    commitWithPermit,
    awaitingTxReceipt,
    txReceipt,
    awaitingTxReceiptError,
  };
};
