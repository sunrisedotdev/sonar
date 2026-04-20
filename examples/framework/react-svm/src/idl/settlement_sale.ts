import type { Idl } from "@coral-xyz/anchor";
import { convertIdlToCamelCase } from "@coral-xyz/anchor/dist/cjs/idl.js";
import settlementSaleIdlJson from "./settlement_sale.json";

/**
 * Raw Anchor IDL from the settlement-sale program build (snake_case names).
 * Pass this to {@link import("@coral-xyz/anchor").Program}; it camelCases internally.
 */
export const IDL = settlementSaleIdlJson as Idl;

/**
 * CamelCase IDL for {@link import("@coral-xyz/anchor").BorshCoder}, which does not
 * apply the same conversion as `Program`.
 */
export const IDL_CAMEL = convertIdlToCamelCase(IDL);

/** Program id embedded in the IDL (must match the deployed program). */
export const SETTLEMENT_SALE_PROGRAM_ID = settlementSaleIdlJson.address as string;
