import { useCallback, useEffect, useMemo, useState } from "react";
import { useConnection, useAnchorWallet } from "@solana/wallet-adapter-react";
import { Ed25519Program, PublicKey, SYSVAR_INSTRUCTIONS_PUBKEY, SystemProgram, Transaction } from "@solana/web3.js";
import { AnchorProvider, BN, BorshCoder, Program } from "@coral-xyz/anchor";
import { TOKEN_PROGRAM_ID, getAssociatedTokenAddressSync } from "@solana/spl-token";
import type { GeneratePurchasePermitResponse } from "@echoxyz/sonar-core";
import { PROGRAM_ID, PAYMENT_TOKEN_MINT, saleUUID } from "@/lib/config";
import { IDL } from "@/app/idl/settlement_sale";
import { parse as uuidParse } from "uuid";

interface SolanaPermitJSON {
  SaleSpecificEntityID: string;
  SaleUUID: string;
  Wallet: string;
  ExpiresAt: number;
  MinAmount: number;
  MaxAmount: number;
  MinPrice: number;
  MaxPrice: number;
  OpensAt: number;
  ClosesAt: number;
  Payload: string;
}

interface EntityStateAccount {
  currentAmount: BN;
}

interface SettlementSaleAccount {
  permitSigner: PublicKey;
  vault: PublicKey;
}

function parseIdBytes(id: string): Uint8Array {
  const s = id.replace(/^0x/i, "");
  return s.includes("-") ? uuidParse(s) : Buffer.from(s, "hex");
}

export function useSaleContract(saleSpecificEntityID: string) {
  const { connection } = useConnection();
  const wallet = useAnchorWallet();

  const [txSignature, setTxSignature] = useState<string | undefined>();
  const [confirmed, setConfirmed] = useState(false);
  const [awaitingTxReceipt, setAwaitingTxReceipt] = useState(false);
  const [committedAmount, setCommittedAmount] = useState<bigint | undefined>();
  const [entityStateError, setEntityStateError] = useState<Error | undefined>();

  const programPublicKey = useMemo(() => new PublicKey(PROGRAM_ID), []);

  const { salePDA, entityStatePDA } = useMemo(() => {
    const saleUuidBytes = parseIdBytes(saleUUID);
    const [salePDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("settlement_sale"), Buffer.from(saleUuidBytes)],
      programPublicKey
    );
    const saleEntityIdBytes = parseIdBytes(saleSpecificEntityID);
    const [entityStatePDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("entity_state"), salePDA.toBuffer(), Buffer.from(saleEntityIdBytes)],
      programPublicKey
    );
    return { salePDA, entityStatePDA };
  }, [saleSpecificEntityID, programPublicKey]);

  useEffect(() => {
    let cancelled = false;

    const fetchEntityState = async () => {
      try {
        const provider = new AnchorProvider(
          connection,
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          wallet ?? ({ publicKey: PublicKey.default } as any),
          { commitment: "confirmed" }
        );
        const program = new Program(IDL, provider);
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const state = (await (program.account as any).entityState.fetchNullable(entityStatePDA)) as EntityStateAccount | null;
        if (!cancelled) {
          setCommittedAmount(state ? BigInt(state.currentAmount.toString()) : 0n);
          setEntityStateError(undefined);
        }
      } catch (err) {
        if (!cancelled) setEntityStateError(err as Error);
      }
    };

    fetchEntityState();
    const interval = setInterval(fetchEntityState, 3000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, [connection, wallet, entityStatePDA]);

  const commitWithPermit = useCallback(
    async ({
      purchasePermitResp,
      commitmentAmount,
    }: {
      purchasePermitResp: GeneratePurchasePermitResponse;
      commitmentAmount: bigint;
      commitmentAmountIncrement: bigint;
    }) => {
      if (!wallet) throw new Error("Wallet not connected");

      const provider = new AnchorProvider(connection, wallet, { commitment: "confirmed" });
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const program = new Program(IDL as any, provider);

      const permit = purchasePermitResp.PermitJSON as unknown as SolanaPermitJSON;
      const saleEntityIdArr = parseIdBytes(permit.SaleSpecificEntityID);
      const saleUuidArr = parseIdBytes(permit.SaleUUID);

      // Re-derive entityStatePDA from the permit's SaleSpecificEntityID, not the prop,
      // since the program validates the account against the permit's entity ID.
      const [permitEntityStatePDA] = PublicKey.findProgramAddressSync(
        [Buffer.from("entity_state"), salePDA.toBuffer(), Buffer.from(saleEntityIdArr)],
        programPublicKey
      );
      const walletBytes = Array.from(new PublicKey(permit.Wallet).toBytes());
      const payloadHex = permit.Payload.replace(/^0x/, "");
      const payloadBytes = payloadHex.length > 0 ? Buffer.from(payloadHex, "hex") : Buffer.from([]);

      const permitData = {
        saleSpecificEntityId: saleEntityIdArr,
        saleUuid: saleUuidArr,
        wallet: walletBytes,
        expiresAt: new BN(permit.ExpiresAt),
        minAmount: new BN(permit.MinAmount),
        maxAmount: new BN(permit.MaxAmount),
        minPrice: new BN(permit.MinPrice),
        maxPrice: new BN(permit.MaxPrice),
        opensAt: new BN(permit.OpensAt),
        closesAt: new BN(permit.ClosesAt),
        payload: payloadBytes,
      };

      // Borsh-encode the permit to build the Ed25519 verify instruction
      const coder = new BorshCoder(IDL);
      const messageBytes = coder.types.encode("purchasePermitV3", permitData);

      // Fetch sale account for the permit signer and vault public keys
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const saleAccount = (await (program.account as any).settlementSale.fetch(salePDA)) as SettlementSaleAccount;

      const sigHex = purchasePermitResp.Signature.replace(/^0x/, "");
      const signatureBytes = Buffer.from(sigHex, "hex");

      // Ed25519 verify instruction — required for the on-chain permit sig check via sysvar
      const ed25519Ix = Ed25519Program.createInstructionWithPublicKey({
        publicKey: saleAccount.permitSigner.toBytes(),
        message: messageBytes,
        signature: signatureBytes,
      });

      const [walletBindingPDA] = PublicKey.findProgramAddressSync(
        [Buffer.from("wallet_binding"), salePDA.toBuffer(), wallet.publicKey.toBuffer()],
        programPublicKey
      );

      const bidderTokenAccount = getAssociatedTokenAddressSync(new PublicKey(PAYMENT_TOKEN_MINT), wallet.publicKey);

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const placeBidIx = await (program.methods as any)
        .placeBid(permitData, new BN(commitmentAmount.toString()), new BN(0), false)
        .accounts({
          bidder: wallet.publicKey,
          sale: salePDA,
          entityState: permitEntityStatePDA,
          walletBinding: walletBindingPDA,
          bidderTokenAccount,
          vault: saleAccount.vault,
          paymentTokenMint: new PublicKey(PAYMENT_TOKEN_MINT),
          tokenProgram: TOKEN_PROGRAM_ID,
          systemProgram: SystemProgram.programId,
          instructions: SYSVAR_INSTRUCTIONS_PUBKEY,
        })
        .instruction();

      const tx = new Transaction();
      tx.add(ed25519Ix, placeBidIx);
      tx.feePayer = wallet.publicKey;
      const { blockhash } = await connection.getLatestBlockhash();
      tx.recentBlockhash = blockhash;

      const signed = await wallet.signTransaction(tx);
      const sig = await connection.sendRawTransaction(signed.serialize());
      setTxSignature(sig);

      setAwaitingTxReceipt(true);
      await connection.confirmTransaction(sig, "confirmed");
      setConfirmed(true);
      setAwaitingTxReceipt(false);
    },
    [wallet, connection, salePDA, entityStatePDA, programPublicKey]
  );

  const currentTotalRaw: bigint = committedAmount ?? 0n;
  const currentTotalHumanReadableStr = (Number(currentTotalRaw) / 1e6).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

  return {
    commitWithPermit,
    txSignature,
    confirmed,
    awaitingTxReceipt,
    currentTotalRaw,
    currentTotalHumanReadableStr,
    entityStateError,
  };
}
