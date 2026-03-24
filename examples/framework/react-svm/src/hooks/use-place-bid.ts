import { useCallback, useEffect, useMemo, useState } from "react";
import { useConnection, useAnchorWallet } from "@solana/wallet-adapter-react";
import { Ed25519Program, PublicKey, SYSVAR_INSTRUCTIONS_PUBKEY, SystemProgram, Transaction } from "@solana/web3.js";
import { AnchorProvider, BN, BorshCoder, Program } from "@coral-xyz/anchor";
import { TOKEN_PROGRAM_ID, getAssociatedTokenAddressSync } from "@solana/spl-token";
import type { GeneratePurchasePermitResponse } from "@echoxyz/sonar-core";
import { PROGRAM_ID, PAYMENT_TOKEN_MINT, saleUUID } from "../config";
import { IDL } from "../idl/settlement_sale";

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

function parseUUID(uuid: string): number[] {
  const hex = uuid.replace(/-/g, "");
  const bytes: number[] = [];
  for (let i = 0; i < hex.length; i += 2) {
    bytes.push(parseInt(hex.slice(i, i + 2), 16));
  }
  return bytes;
}

export function usePlaceBid(saleSpecificEntityID: string) {
  const { connection } = useConnection();
  const wallet = useAnchorWallet();

  const [txSignature, setTxSignature] = useState<string | undefined>();
  const [confirmed, setConfirmed] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const [entityCurrentAmount, setEntityCurrentAmount] = useState<bigint | undefined>();
  const [entityStateError, setEntityStateError] = useState<Error | undefined>();

  const programPublicKey = useMemo(() => new PublicKey(PROGRAM_ID), []);

  const { salePDA, entityStatePDA } = useMemo(() => {
    const saleUuidBytes = parseUUID(saleUUID);
    const [salePDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("settlement_sale"), Buffer.from(saleUuidBytes)],
      programPublicKey
    );
    const saleEntityIdBytes = parseUUID(saleSpecificEntityID);
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
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const program = new Program(IDL as any, provider);
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const state = (await (program.account as any).entityState.fetchNullable(entityStatePDA)) as EntityStateAccount | null;
        if (!cancelled) {
          setEntityCurrentAmount(state ? BigInt(state.currentAmount.toString()) : BigInt(0));
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
      amount,
    }: {
      purchasePermitResp: GeneratePurchasePermitResponse;
      amount: bigint;
    }) => {
      if (!wallet) throw new Error("Wallet not connected");

      const provider = new AnchorProvider(connection, wallet, { commitment: "confirmed" });
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const program = new Program(IDL as any, provider);

      const permit = purchasePermitResp.PermitJSON as unknown as SolanaPermitJSON;
      const saleEntityIdArr = parseUUID(permit.SaleSpecificEntityID);
      const saleUuidArr = parseUUID(permit.SaleUUID);
      const walletBytes = Array.from(new PublicKey(permit.Wallet).toBytes());
      const payloadHex = permit.Payload.replace(/^0x/, "");
      const payloadBytes = payloadHex.length > 0 ? Array.from(Buffer.from(payloadHex, "hex")) : [];

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
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const coder = new BorshCoder(IDL as any);
      const messageBytes = coder.types.encode("PurchasePermitV3", permitData);

      // Fetch sale account for the permit signer and vault public keys
      const saleAccount = (await (program.account as any).settlementSale.fetch(salePDA)) as SettlementSaleAccount; // eslint-disable-line @typescript-eslint/no-explicit-any

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
        .placeBid(permitData, new BN(amount.toString()), new BN(0), false)
        .accounts({
          bidder: wallet.publicKey,
          sale: salePDA,
          entityState: entityStatePDA,
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

      setConfirming(true);
      await connection.confirmTransaction(sig, "confirmed");
      setConfirmed(true);
      setConfirming(false);
    },
    [wallet, connection, salePDA, entityStatePDA, programPublicKey]
  );

  return {
    commitWithPermit,
    txSignature,
    confirmed,
    confirming,
    entityCurrentAmount,
    entityStateError,
  };
}
