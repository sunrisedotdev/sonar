import { EntityDetails } from "@echoxyz/sonar-core";

interface EligibilityResultsProps {
  entities: EntityDetails[];
  eligibleEntities: EntityDetails[];
  saleUUID: string;
  sonarFrontendURL: string | undefined;
}

export function EligibilityResults({
  entities,
  eligibleEntities,
  saleUUID,
  sonarFrontendURL,
}: EligibilityResultsProps) {
  const hasEligibleEntity = eligibleEntities.length > 0;

  if (entities.length === 0) {
    return null;
  }

  return (
    <div className="p-4 bg-linear-to-r from-indigo-50 to-blue-50 rounded-lg border border-indigo-200">
      {hasEligibleEntity ? (
        <div>
          <p className="text-green-600 font-medium text-lg">
            ✓ You have {eligibleEntities.length} eligible {eligibleEntities.length === 1 ? "entity" : "entities"}!
          </p>
          <p className="text-gray-700">You&apos;re ready to participate when the sale goes live.</p>
        </div>
      ) : (
        <div>
          <p className="text-yellow-700 font-medium text-lg">No eligible entities found</p>
          <p className="text-gray-700">
            Your entities are not eligible for this sale, or you need to complete your setup.
          </p>
          <a
            href={`${sonarFrontendURL}/sonar/${saleUUID}`}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-block bg-yellow-600 hover:bg-yellow-700 text-white font-medium py-2 px-6 rounded-lg transition-colors"
          >
            Continue Setup on Sonar
          </a>
        </div>
      )}
    </div>
  );
}
