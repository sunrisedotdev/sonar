# @echoxyz/sonar-core

## 0.14.1

### Patch Changes

- 7101949: All onUnauthorized to be passed into createClient

## 0.14.0

### Minor Changes

- Add wrapper function and hook for ReadCommitmentData endpoint

## 0.13.0

### Minor Changes

- c551d7c: Add BasicPermitV3 type with OpensAt and ClosesAt fields for time-gated commitment windows:
    - Add `BasicPermitV3` type with new `OpensAt` and `ClosesAt` fields
    - Add `BASIC_V3` to `PurchasePermitType` enum
    - Update `PurchasePermit` conditional type to handle V3
    - Update `GeneratePurchasePermitResponse` to include `BasicPermitV3`
    - Mark `BasicPermitV2` as deprecated

- b2cd697: Rename Allocation API to Limits API to match backend changes:
    - `fetchAllocation` → `fetchLimits`
    - `AllocationResponse` → `LimitsResponse`
    - Response fields renamed: `HasReservedAllocation` → `HasCustomCommitmentAmountLimit`, `ReservedAmountUSD` removed, `MaxAmountUSD` → `MaxCommitmentAmount`, added `MinCommitmentAmount`
    - `PrePurchaseFailureReason.NO_RESERVED_ALLOCATION` → `PrePurchaseFailureReason.NO_CUSTOM_COMMITMENT_AMOUNT_LIMIT`

### Patch Changes

- e276112: Add `pnpm fmt` script for running prettier and format check to CI
- 171a0db: Added support for ReadEntityInvestmentHistory API

## 0.12.0

### Minor Changes

- cc7380c: Sync EntitySetupState and SaleEligibility with the API

## 0.11.0

### Minor Changes

- cf2914d: Updated entityID name on permit

## 0.10.0

### Minor Changes

- d42882b: Changed entityID parameter names

### Patch Changes

- d3dce74: Change EntityID type to a string and add SaleSpecificEntityID

## 0.9.0

### Minor Changes

- cbf7964: Support new V2 permit

## 0.8.0

### Minor Changes

- f1c6ddd: Added refresh token endpoint. Aligned to new response type shapes.

## 0.7.0

### Minor Changes

- 5b96860: Add listAvailableEntities / useSonarEntities

### Patch Changes

- ef7e0f9: Switch to new ExchangeAuthorizationCodeV2 endpoint

## 0.6.0

### Minor Changes

- f47a532: Replace EntityUUID + ObfuscatedEntityID in the API interface with a single EntityID

## 0.5.0

### Minor Changes

- bece3e6: Update types to match new GeneratePurchasePermit API.

## 0.4.1

### Patch Changes

- d52cd7b: Add MinAmount to AllocationPermit

## 0.4.0

### Minor Changes

- 1ccce38: Remove redundant saleUUID from constructor/Provider

## 0.3.0

### Minor Changes

- c032c29: Strip EntityType param from API requests

## 0.2.1

### Patch Changes

- affa026: Add missing values to PrePurchaseFailureReason enum

## 0.2.0

### Minor Changes

- a043774: Replace listEntities with readEntity function

## 0.1.5

### Patch Changes

- 77db07a: Added tests

## 0.1.4

### Patch Changes

- d04d616: Use bound global fetch

## 0.1.3

### Patch Changes

- f04cb72: Add globalThis fetch, export type

## 0.1.2

### Patch Changes

- 4907b74: Remove unused dependency

## 0.1.1

### Patch Changes

- 95d0235: Include dist in build output for publishing

## 0.1.0

### Minor Changes

- 41247e9: Initial implementation of core/react wrapper.

## 0.0.3

### Patch Changes

- 52ddd3f: Initial commit (empty)
