import { EntityDetails, SaleEligibility } from "@echoxyz/sonar-core";
import { EntityDetailRows } from "./EntityDetailRows";
import { EntityStateDescription } from "./EntityStateDescription";

interface EntityCardProps {
  entity: EntityDetails;
}

export function EntityCard({ entity }: EntityCardProps) {
  const isEligible = entity.SaleEligibility === SaleEligibility.ELIGIBLE;

  return (
    <div
      className={`flex flex-col gap-4 p-4 rounded-lg border-2 ${
        isEligible ? "bg-green-50 border-green-300" : "bg-gray-50 border-gray-300"
      }`}
    >
      <div className="flex justify-between items-center">
        <p className="font-semibold text-gray-900">{entity.Label || "No name set"}</p>
      </div>

      <EntityDetailRows entity={entity} />
      <EntityStateDescription entity={entity} />
    </div>
  );
}
