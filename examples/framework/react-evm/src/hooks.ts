import { BasicPermitV3, GeneratePurchasePermitResponse, Hex } from "@echoxyz/sonar-core";
import { useCallback, useState } from "react";
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { saleContract } from "./config";
import { settlementSaleAbi } from "./abi/SettlementSale";
import { ERC20Abi } from "./abi/ERC20";
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
      amount,
    }: {
      purchasePermitResp: GeneratePurchasePermitResponse;
      token: `0x${string}`;
      amount: bigint;
    }) => {
      if (!("OpensAt" in purchasePermitResp.PermitJSON)) {
        throw new Error("Invalid purchase permit response");
      }
      const permit = purchasePermitResp.PermitJSON as BasicPermitV3;

      const { request: approveRequest } = await simulateContract(config, {
        address: token,
        abi: ERC20Abi,
        functionName: "approve",
        args: [saleContract, amount],
      });

      const approveHash = await writeContractAsync(approveRequest);
      const approveReceipt = await waitForTransactionReceipt(config, { hash: approveHash });

      const bidArgs = [
        token,
        { lockup: false, price: 0n, amount: amount },
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
        blockNumber: approveReceipt.blockNumber,
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

  return {
    entityState: entityStates?.[0],
    entityStateError,
    commitWithPermit,
    awaitingTxReceipt,
    txReceipt,
    awaitingTxReceiptError,
  };
};
