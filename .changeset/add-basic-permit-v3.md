---
"@echoxyz/sonar-core": minor
---

Add BasicPermitV3 type with OpensAt and ClosesAt fields for time-gated commitment windows:

- Add `BasicPermitV3` type with new `OpensAt` and `ClosesAt` fields
- Add `BASIC_V3` to `PurchasePermitType` enum
- Update `PurchasePermit` conditional type to handle V3
- Update `GeneratePurchasePermitResponse` to include `BasicPermitV3`
- Mark `BasicPermitV2` as deprecated
