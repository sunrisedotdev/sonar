---
"@echoxyz/sonar-core": minor
---

Rename Allocation API to Limits API to match backend changes:

- `fetchAllocation` → `fetchLimits`
- `AllocationResponse` → `LimitsResponse`
- Response fields renamed: `HasReservedAllocation` → `HasCustomCommitmentAmountLimit`, `ReservedAmountUSD` removed, `MaxAmountUSD` → `MaxCommitmentAmount`, added `MinCommitmentAmount`
- `PrePurchaseFailureReason.NO_RESERVED_ALLOCATION` → `PrePurchaseFailureReason.NO_CUSTOM_COMMITMENT_AMOUNT_LIMIT`
