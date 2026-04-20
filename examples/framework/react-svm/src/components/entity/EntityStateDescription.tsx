import { EntityDetails, EntitySetupState, SaleEligibility } from "@echoxyz/sonar-core";

interface EntityStateDescriptionProps {
  entity?: EntityDetails;
}

export function EntityStateDescription({ entity }: EntityStateDescriptionProps) {
  if (!entity) {
    return (
      <div className="bg-amber-50 p-2 rounded-md w-full">
        <p className="text-amber-500 w-full">
          No entity found. You must have an entity in Sonar with a linked wallet matching the currently connected
          wallet.
        </p>
      </div>
    );
  }

  let stateDescription;
  let stateFgColor;
  let stateBgColor;

  switch (entity.EntitySetupState as EntitySetupState) {
    case EntitySetupState.NOT_STARTED:
    case EntitySetupState.IN_PROGRESS:
      stateFgColor = "text-amber-600";
      stateBgColor = "bg-amber-50";
      stateDescription = "You need to complete entity setup on Sonar";
      break;
    case EntitySetupState.IN_REVIEW:
      stateFgColor = "text-gray-900";
      stateBgColor = "bg-gray-200";
      stateDescription = "Your entity is currently under review by Sonar";
      break;
    case EntitySetupState.FAILURE:
      stateFgColor = "text-amber-500";
      stateBgColor = "bg-amber-50";
      stateDescription = "There is an issue with your entity setup that needs to be resolved on Sonar";
      break;
    case EntitySetupState.FAILURE_FINAL:
      stateFgColor = "text-red-500";
      stateBgColor = "bg-red-50";
      stateDescription = "You are not eligible to invest in this sale";
      break;
    case EntitySetupState.COMPLETE:
      switch (entity.SaleEligibility as SaleEligibility) {
        case SaleEligibility.ELIGIBLE:
          stateFgColor = "text-green-800";
          stateBgColor = "bg-green-200";
          stateDescription = "You are eligible to invest in this sale";
          break;
        case SaleEligibility.NOT_ELIGIBLE:
          stateFgColor = "text-red-500";
          stateBgColor = "bg-red-50";
          stateDescription = "You are not currently eligible to invest in this sale";
          break;
        default:
          stateFgColor = "text-gray-900";
          stateBgColor = "bg-gray-200";
          stateDescription = "Entity setup complete";
      }
      break;
    default:
      stateFgColor = "text-gray-900";
      stateBgColor = "bg-gray-200";
      stateDescription = "Unknown status";
  }

  return (
    <div className={`${stateBgColor} p-2 rounded-md w-full`}>
      <p className={`${stateFgColor} w-full`}>{stateDescription}</p>
    </div>
  );
}
