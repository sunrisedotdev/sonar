"use client";

import { useState, useEffect } from "react";
import { saleUUID, sonarHomeURL, sonarConfig } from "@/lib/config";
import { useAccount } from "wagmi";
import { SaleEligibility } from "@echoxyz/sonar-core";
import { EntityCard } from "./components/entity/EntityCard";
import { AuthenticationSection } from "./components/auth/AuthenticationSection";
import { useSonarEntities } from "./hooks/use-sonar-entities";
import { useSession } from "./hooks/use-session";
import CommitCard from "./components/sale/CommitCard";
import { EntitiesList } from "./components/registration/EntitiesList";
import { EligibilityResults } from "./components/registration/EligibilityResults";
import { ConnectKitButton } from "connectkit";
import { CommitmentDataCard } from "./components/sale/CommitmentDataCard";

export default function Home() {
  const [saleIsLive, setSaleIsLive] = useState(false);
  const [selectedEntityId, setSelectedEntityId] = useState<string | undefined>(undefined);
  const { sonarConnected } = useSession();
  const { address } = useAccount();

  // Load sale state from localStorage
  useEffect(() => {
    const stored = localStorage.getItem("sale_is_live");
    if (stored === "true") {
      setSaleIsLive(true);
    }
  }, []);

  // Save sale state to localStorage
  const toggleSaleLive = () => {
    const newState = !saleIsLive;
    setSaleIsLive(newState);
    localStorage.setItem("sale_is_live", String(newState));
  };

  // Entities data
  const { loading: entitiesLoading, entities, error: entitiesError } = useSonarEntities();

  const eligibleEntities = entities?.filter((entity) => entity.SaleEligibility === SaleEligibility.ELIGIBLE) || [];

  // Resolve the selected entity for the sale phase (default to first entity)
  const selectedEntity = entities?.find((e) => e.EntityID === selectedEntityId) ?? entities?.[0];

  const isEligible = selectedEntity && selectedEntity.SaleEligibility === SaleEligibility.ELIGIBLE;

  const EntitySection = () => {
    if (!address) {
      return (
        <div className="flex flex-col gap-2 bg-yellow-50 border border-yellow-200 rounded-lg p-6 w-full">
          <p className="text-yellow-800 font-medium">Connection Required</p>
          <p className="text-yellow-700">Connect your wallet to continue with your purchase.</p>
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
            <p className="text-yellow-700">
              No entity found for this account.
            </p>
          </div>
          <div>
            <a
              href={sonarHomeURL.href}
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
          <button
            onClick={toggleSaleLive}
            className={`px-4 py-1.5 rounded-md font-medium text-sm transition-colors ${
              saleIsLive
                ? "bg-green-500/20 text-green-400 hover:bg-green-500/30 border border-green-500/50"
                : "bg-amber-500/20 text-amber-400 hover:bg-amber-500/30 border border-amber-500/50"
            }`}
          >
            {saleIsLive ? "🟢 Sale Live" : "⏳ Pre-Sale"}
          </button>
        </div>
      </div>

      <div className="min-h-screen pt-16 py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          <div className="bg-white rounded-lg shadow-xl p-8 w-[620px]">
            {/* Header */}
            <div className="mb-8">
              <div className="flex items-center justify-between mb-4 flex-wrap gap-4">
                <h1 className="text-3xl font-bold text-gray-900">Easy Company Token Sale</h1>
              </div>

              {/* Countdown Banner */}
              {!saleIsLive && (
                <div className="bg-linear-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-lg p-6">
                  <div className="text-center">
                    <p className="text-blue-900 font-semibold text-lg">Sale Starting Soon</p>
                    <p className="text-blue-700">Register now to ensure you&apos;re ready when the sale goes live</p>
                  </div>
                </div>
              )}

              {saleIsLive && (
                <div className="bg-linear-to-r bg-green-50 border border-green-200 rounded-lg p-6">
                  <div className="text-center">
                    <p className="text-green-700 font-semibold text-lg">The sale is now live!</p>
                  </div>
                </div>
              )}
            </div>

            <div className="flex flex-col gap-8">
              <AuthenticationSection />

              {/* Registration Phase */}
              {sonarConnected && !saleIsLive && (
                <div className="flex flex-col gap-4">
                  <h2 className="text-xl font-semibold text-gray-900">Check Your Eligibility</h2>

                  <EntitiesList
                    loading={entitiesLoading}
                    error={entitiesError}
                    entities={entities}
                    saleUUID={saleUUID}
                    sonarFrontendURL={sonarHomeURL.origin}
                  />

                  {!entitiesLoading && !entitiesError && entities && (
                    <EligibilityResults
                      entities={entities}
                      eligibleEntities={eligibleEntities}
                      saleUUID={saleUUID}
                      sonarFrontendURL={sonarHomeURL.origin}
                    />
                  )}
                </div>
              )}

              {/* Sale Phase */}
              {saleIsLive && (
                <div className="flex flex-col gap-4">
                  {sonarConnected && (
                    <div className="flex flex-col gap-4">
                      <ConnectKitButton />

                      <div className="flex flex-col gap-4">
                        <h2 className="text-xl font-semibold text-gray-900">Your Entity Information</h2>
                        <EntitySection />
                      </div>

                      {isEligible && address && selectedEntity && (
                        <div className="flex flex-col gap-4">
                          <h2 className="text-xl font-semibold text-gray-900">Commit funds</h2>
                          <CommitCard
                            entityID={selectedEntity.EntityID}
                            saleSpecificEntityID={selectedEntity.SaleSpecificEntityID}
                            walletAddress={address}
                          />
                        </div>
                      )}
                    </div>
                  )}

                  <div className="flex flex-col gap-4">
                    <h2 className="text-xl font-semibold text-gray-900">Sale Commitment Data</h2>
                    <CommitmentDataCard saleUUID={saleUUID} />
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
