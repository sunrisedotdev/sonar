import { useState, useEffect } from "react";
import { ConnectKitButton } from "connectkit";
import { useSonarAuth, useSonarEntities } from "@echoxyz/sonar-react";
import { saleUUID, sonarConfig } from "../config";
import { useAccount } from "wagmi";
import CommitCard from "../components/sale/CommitCard";
import CancelCard from "../components/sale/CancelCard";
import { SaleEligibility } from "@echoxyz/sonar-core";
import { AuthenticationSection } from "../components/auth/AuthenticationSection";
import { EntityCard } from "@shared/components/entity/EntityCard";
import { EntitiesList } from "@shared/components/registration/EntitiesList";
import { EligibilityResults } from "@shared/components/registration/EligibilityResults";
import { CommitmentDataCard } from "@shared/components/sale/CommitmentDataCard";

type SalePhase = "presale" | "live" | "cancellation";

export function Home() {
  const [salePhase, setSalePhase] = useState<SalePhase>("presale");
  const [selectedEntityId, setSelectedEntityId] = useState<string | undefined>(undefined);

  // Load sale phase from localStorage
  useEffect(() => {
    const stored = localStorage.getItem("sale_phase");
    if (stored === "live" || stored === "cancellation" || stored === "presale") {
      setSalePhase(stored);
    }
  }, []);

  const handlePhaseChange = (phase: SalePhase) => {
    setSalePhase(phase);
    localStorage.setItem("sale_phase", phase);
  };

  // Auth and data hooks
  const { address } = useAccount();
  const { login, authenticated, logout, ready } = useSonarAuth();

  // Entities data
  const {
    loading: entitiesLoading,
    entities,
    error: entitiesError,
  } = useSonarEntities({
    saleUUID: saleUUID,
  });

  const eligibleEntities = entities?.filter((entity) => entity.SaleEligibility === SaleEligibility.ELIGIBLE) || [];

  // Resolve the selected entity for the sale phase (default to first entity)
  const selectedEntity = entities?.find((e) => e.EntityID === selectedEntityId) ?? entities?.[0];

  const isEligible = selectedEntity && selectedEntity.SaleEligibility === SaleEligibility.ELIGIBLE;

  const EntitySection = () => {
    if (!address || !authenticated) {
      return (
        <div className="flex flex-col gap-2 bg-yellow-50 border border-yellow-200 rounded-lg p-6 w-full">
          <p className="text-yellow-800 font-medium">Connection Required</p>
          <p className="text-yellow-700">Connect your wallet and Sonar account to continue with your purchase.</p>
        </div>
      );
    }

    if (entitiesLoading) {
      return (
        <div className="flex flex-col gap-2 bg-gray-50 rounded-lg p-6 w-full">
          <p className="text-gray-600">Loading your entity information...</p>
        </div>
      );
    }

    if (entitiesError) {
      return (
        <div className="flex flex-col gap-2 bg-red-50 border border-red-200 rounded-lg p-6 w-full">
          <p className="text-red-800 font-medium">Error</p>
          <p className="text-red-700">{entitiesError.message}</p>
        </div>
      );
    }

    if (!entities || entities.length === 0) {
      return (
        <div className="flex flex-col gap-2 bg-yellow-50 border border-yellow-200 rounded-lg p-6 w-full">
          <div>
            <p className="text-yellow-800 font-medium">No Entity Found</p>
            <p className="text-yellow-700">No entity found for this account.</p>
          </div>
          <div>
            <a
              href={sonarConfig.frontendURL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-block bg-yellow-600 hover:bg-yellow-700 text-white font-medium py-2 px-6 rounded-lg transition-colors"
            >
              Continue Setup on Sonar
            </a>
          </div>
        </div>
      );
    }

    return (
      <div className="flex flex-col gap-2 w-full">
        {entities.length > 1 && (
          <div className="flex flex-col gap-1">
            <label htmlFor="entity-select" className="text-sm font-medium text-gray-700">
              Select Sonar Entity
            </label>
            <select
              id="entity-select"
              value={selectedEntity?.EntityID ?? ""}
              onChange={(e) => setSelectedEntityId(e.target.value)}
              className="border border-gray-300 rounded-lg px-3 py-2 text-gray-900 bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              {entities.map((e) => (
                <option key={e.EntityID} value={e.EntityID}>
                  {e.Label || "Unknown Entity"}
                </option>
              ))}
            </select>
          </div>
        )}
        {selectedEntity && <EntityCard entity={selectedEntity} />}
        {selectedEntity && (
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
        )}
      </div>
    );
  };

  return (
    <>
      {/* Fixed Demo Control Bar */}
      <div className="fixed top-0 left-0 right-0 z-50 bg-gray-900 border-b border-gray-700 shadow-lg">
        <div className="max-w-4xl mx-auto px-4 py-2 flex items-center justify-between">
          <span className="text-gray-400 text-sm font-medium">Demo Controls</span>
          <select
            value={salePhase}
            onChange={(e) => handlePhaseChange(e.target.value as SalePhase)}
            className="px-3 py-1.5 rounded-md font-medium text-sm bg-gray-800 border border-gray-600 text-gray-200 focus:outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer"
          >
            <option value="presale">⏳ Pre-Sale</option>
            <option value="live">🟢 Sale Live</option>
            <option value="cancellation">🟡 Cancellation</option>
          </select>
        </div>
      </div>

      <div className="min-h-screen pt-16 py-12 px-4 sm:px-6 lg:px-8 flex justify-center">
        <div className="bg-white rounded-lg shadow-xl p-8 w-[620px]">
          {/* Header */}
          <div className="mb-8">
            <div className="flex items-center justify-between mb-4 flex-wrap gap-4">
              <h1 className="text-3xl font-bold text-gray-900">Easy Company Token Sale</h1>
            </div>

            {/* Phase Banner */}
            {salePhase === "presale" && (
              <div className="bg-linear-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-lg p-6">
                <div className="text-center">
                  <p className="text-blue-900 font-semibold text-lg">Sale Starting Soon</p>
                  <p className="text-blue-700">Register now to ensure you&apos;re ready when the sale goes live</p>
                </div>
              </div>
            )}

            {salePhase === "live" && (
              <div className="bg-linear-to-r bg-green-50 border border-green-200 rounded-lg p-6">
                <div className="text-center">
                  <p className="text-green-700 font-semibold text-lg">The sale is now live!</p>
                </div>
              </div>
            )}

            {salePhase === "cancellation" && (
              <div className="bg-linear-to-r from-amber-50 to-yellow-50 border border-amber-200 rounded-lg p-6">
                <div className="text-center">
                  <p className="text-amber-800 font-semibold text-lg">Cancellation Period</p>
                  <p className="text-amber-700">Commitments can be cancelled during this period</p>
                </div>
              </div>
            )}
          </div>

          {/* Registration Phase */}
          {salePhase === "presale" && (
            <div className="flex flex-col gap-8">
              <AuthenticationSection ready={ready} authenticated={authenticated} login={login} logout={logout} />

              {authenticated && (
                <div className="flex flex-col gap-4">
                  <h2 className="text-xl font-semibold text-gray-900">Check Your Eligibility</h2>

                  <EntitiesList
                    loading={entitiesLoading}
                    error={entitiesError}
                    entities={entities}
                    saleUUID={saleUUID}
                    sonarFrontendURL={sonarConfig.frontendURL}
                  />

                  {!entitiesLoading && !entitiesError && entities && (
                    <EligibilityResults
                      entities={entities}
                      eligibleEntities={eligibleEntities}
                      saleUUID={saleUUID}
                      sonarFrontendURL={sonarConfig.frontendURL}
                    />
                  )}
                </div>
              )}
            </div>
          )}

          {/* Sale Phase */}
          {salePhase === "live" && (
            <div className="flex flex-col gap-8">
              {/* Connection Buttons */}
              <AuthenticationSection ready={ready} authenticated={authenticated} login={login} logout={logout} />
              <ConnectKitButton />

              {/* Entity Information */}
              <div className="flex flex-col gap-4">
                <h2 className="text-xl font-semibold text-gray-900">Your Entity Information</h2>
                <EntitySection />
              </div>

              {/* Commit Card */}
              {isEligible && address && (
                <div className="flex flex-col gap-4">
                  <h2 className="text-xl font-semibold text-gray-900">Commit funds</h2>
                  <CommitCard
                    entityID={selectedEntity.EntityID}
                    saleSpecificEntityID={selectedEntity.SaleSpecificEntityID}
                    walletAddress={address}
                  />
                </div>
              )}

              {/* Commitment Data Card */}
              <div className="flex flex-col gap-4">
                <h2 className="text-xl font-semibold text-gray-900">Sale Commitment Data</h2>
                <CommitmentDataCard saleUUID={saleUUID} />
              </div>
            </div>
          )}

          {/* Cancellation Phase */}
          {salePhase === "cancellation" && (
            <div className="flex flex-col gap-8">
              {/* Connection Buttons */}
              <AuthenticationSection ready={ready} authenticated={authenticated} login={login} logout={logout} />
              <ConnectKitButton />

              {/* Entity Information */}
              <div className="flex flex-col gap-4">
                <h2 className="text-xl font-semibold text-gray-900">Your Entity Information</h2>
                <EntitySection />
              </div>

              {/* Cancel Card */}
              {address && selectedEntity && (
                <div className="flex flex-col gap-4">
                  <h2 className="text-xl font-semibold text-gray-900">Cancel Your Bid</h2>
                  <CancelCard saleSpecificEntityID={selectedEntity.SaleSpecificEntityID} />
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </>
  );
}
