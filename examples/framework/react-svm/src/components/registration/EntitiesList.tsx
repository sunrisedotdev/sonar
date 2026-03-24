import { EntityDetails } from "@echoxyz/sonar-core";
import { EntityCard } from "../entity/EntityCard";
import { sonarConfig } from "../../config";

interface EntitiesListProps {
  loading: boolean;
  error?: Error;
  entities?: EntityDetails[];
  saleUUID: string;
  sonarFrontendURL: string | undefined;
}

export function EntitiesList({ loading, error, entities, saleUUID, sonarFrontendURL }: EntitiesListProps) {
  if (loading) {
    return <p className="text-gray-600">Loading your entities...</p>;
  }

  if (error) {
    return (
      <div className="p-4 bg-red-50 border border-red-200 rounded-lg">
        <p className="text-red-800">Error loading entities: {error.message}</p>
      </div>
    );
  }

  if (!entities || entities.length === 0) {
    return (
      <div className="flex flex-col gap-2 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
        <p className="text-yellow-800 font-medium">No entities found</p>
        <p className="text-yellow-700">
          You need to set up an entity on Sonar before you can participate in this sale.
        </p>
        <a
          href={`${sonarFrontendURL}/sonar/${saleUUID}`}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-block bg-yellow-600 hover:bg-yellow-700 text-white font-medium py-2 px-6 rounded-lg transition-colors w-fit"
        >
          Continue Setup on Sonar
        </a>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <p className="text-gray-700 text-sm">
        You can manage and add entities on{" "}
        <a
          href={`${sonarConfig.frontendURL}/sonar/${saleUUID}`}
          target="_blank"
          rel="noopener noreferrer"
          className="text-blue-600 hover:text-blue-800 underline"
        >
          Sonar
        </a>
        .
      </p>
      <div className="flex flex-col gap-4">
        {entities.map((entity) => (
          <EntityCard key={entity.EntityID} entity={entity} />
        ))}
      </div>
    </div>
  );
}
