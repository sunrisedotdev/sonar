import { BasicPermitV3, GeneratePurchasePermitResponse, Hex } from "@echoxyz/sonar-core";
import { useCallback, useState } from "react";
import { useAccount, useReadContract, useSwitchChain, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { baseSepolia } from "wagmi/chains";
import { saleContract, paymentTokenAddress } from "./config";
import { settlementSaleAbi } from "./abi/SettlementSale";
import { ERC20Abi } from "./abi/ERC20";
import { useConfig } from "wagmi";
import { waitForTransactionReceipt, simulateContract } from "wagmi/actions";

export const useSaleContract = (saleSpecificEntityID: Hex) => {
  const { writeContractAsync } = useWriteContract();
  const config = useConfig();
  const { chainId, address } = useAccount();
  const { switchChainAsync } = useSwitchChain();

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
      newTotalRaw,
      incrementRaw,
    }: {
      purchasePermitResp: GeneratePurchasePermitResponse;
      token: `0x${string}`;
      newTotalRaw: bigint;
      incrementRaw: bigint;
    }) => {
      if (chainId !== baseSepolia.id) {
        await switchChainAsync({ chainId: baseSepolia.id });
      }

      if (!("OpensAt" in purchasePermitResp.PermitJSON)) {
        throw new Error("Invalid purchase permit response");
      }
      const permit = purchasePermitResp.PermitJSON as BasicPermitV3;

      const { request: approveRequest } = await simulateContract(config, {
        address: token,
        abi: ERC20Abi,
        functionName: "approve",
        args: [saleContract, incrementRaw],
      });

      const approveHash = await writeContractAsync(approveRequest);
      await waitForTransactionReceipt(config, { hash: approveHash });

      const bidArgs = [
        token,
        { lockup: false, price: 0n, amount: newTotalRaw },
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
    [writeContractAsync, config, chainId, switchChainAsync],
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

  const { data: usdcBalance } = useReadContract({
    address: paymentTokenAddress,
    abi: ERC20Abi,
    functionName: "balanceOf",
    args: [address ?? "0x"],
    query: {
      enabled: !!address && !!paymentTokenAddress,
      refetchInterval: 3000,
    },
  });

  const isEntityStateLoaded = entityStates !== undefined;
  const currentTotalRaw: bigint = entityStates?.[0]?.currentBid?.amount ?? 0n;
  const currentTotalReadableStr = (Number(currentTotalRaw) / 1e6).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

  return {
    entityStateError,
    isEntityStateLoaded,
    currentTotalRaw,
    currentTotalReadableStr,
    commitWithPermit,
    awaitingTxReceipt,
    txReceipt,
    awaitingTxReceiptError,
    isWrongChain: chainId !== undefined && chainId !== baseSepolia.id,
    usdcBalance: usdcBalance as bigint | undefined,
  };
};
