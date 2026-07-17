import XCTest
@testable import BASAdmin
import BASEvaluation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASSovereign
import BASWorldPrior

/// QINAO substrate gate #97 — L14 schema-governance parity.
///
/// Invariant (tolerance 0): every public `BASSchemaVersioned`-conforming
/// struct that the substrate ships MUST be governed/registered in
/// `BASEBrainSchemaGovernanceRegistry.governedSchemas` consistently —
/// no ungoverned schema, no stale registry entry, and every registry
/// entry's declared `currentVersion` MUST match the concrete conformer's
/// `static currentSchemaVersion` (no version drift).
///
/// Mechanism mirrored: `BASEBrainSchemaGovernanceRegistryTests`
/// (Tests/.../BASEBrainSchemaGovernanceRegistryTests.swift) — its
/// `allGovernedSchemasStayAlignedWithConcreteTypes` builds an explicit
/// conformer→version map and asserts `actual == expected`. This gate
/// raises that bar: it asserts the same parity *bidirectionally* over
/// an explicit governed-conformer set, verifies per-entry concrete-type
/// version parity across EVERY registered entry (not a representative
/// subset), pins unique keying (no stale dupes), full governance
/// metadata, and a mutation/immutability probe.
///
/// HOST-ONLY (partial) note: Swift has no runtime reflection that can
/// enumerate "all `BASSchemaVersioned` conformers in the binary", so the
/// canonical conformer set is an explicit allowlist — the exact same
/// technique the in-repo governance suite uses. The strongest fully
/// host-runnable check is therefore: (a) registry-internal parity across
/// all entries (each entry vs its bound concrete type), proven 100%
/// here; plus (b) bidirectional parity vs the explicit L14 conformer
/// set. A reflection-complete "189 conformers" count cannot be machine-
/// enumerated host-side without a code-gen/AST step (the absent script);
/// this gate asserts everything achievable in pure Swift at tolerance 0.
final class QINAOSchemaGovernanceParityGateTests: XCTestCase {

    /// Box for safe accumulation if needed inside closures (none capture
    /// mutable state here, but kept for the @unchecked Sendable contract).
    private final class QINAOParityBox: @unchecked Sendable {
        var mismatches: [String] = []
    }

    func test_qinao_schema_governance_parity() {
        let registry = BASEBrainSchemaGovernanceRegistry.governedSchemas

        // 1) Registry is non-empty and uniquely keyed — a stale/dup
        //    registry entry (ungoverned drift) fails here (tolerance 0).
        XCTAssertFalse(registry.isEmpty, "QINAO: governed-schema registry is empty")
        let objectIDs = registry.map(\.objectID)
        XCTAssertEqual(
            Set(objectIDs).count,
            objectIDs.count,
            "QINAO: duplicate/stale registry entries — registry must be uniquely keyed"
        )

        // 2) Full governance metadata present on EVERY entry (tolerance 0).
        let canonicalArtifactPayloadTests: [String: [String]] = [
            "BASTurnOperationPayload": [
                "schema.BASTurnOperationPayload.current",
                "schema.BASTurnOperationPayload.backward_v1",
                "schema.BASTurnOperationPayload.future_rejection",
            ],
            "BASBudgetLeasePayload": [
                "schema.BASBudgetLeasePayload.current",
                "schema.BASBudgetLeasePayload.backward_v1",
                "schema.BASBudgetLeasePayload.future_rejection",
            ],
            "BASJoinArtifact": [
                "schema.BASJoinArtifact.current",
                "schema.BASJoinArtifact.backward_v1",
                "schema.BASJoinArtifact.future_rejection",
            ],
            "BASRemandArtifact": [
                "schema.BASRemandArtifact.current",
                "schema.BASRemandArtifact.backward_v1",
                "schema.BASRemandArtifact.future_rejection",
            ],
            "BASRefusalArtifact": [
                "schema.BASRefusalArtifact.current",
                "schema.BASRefusalArtifact.backward_v1",
                "schema.BASRefusalArtifact.future_rejection",
            ],
            "BASControlLoopEnvelopePayload": [
                "schema.BASControlLoopEnvelopePayload.current",
                "schema.BASControlLoopEnvelopePayload.backward_v1",
                "schema.BASControlLoopEnvelopePayload.future_rejection",
            ],
            "BASControlLoopProgressWitnessPayload": [
                "schema.BASControlLoopProgressWitnessPayload.current",
                "schema.BASControlLoopProgressWitnessPayload.backward_v1",
                "schema.BASControlLoopProgressWitnessPayload.future_rejection",
            ],
            "BASControlLoopTerminalReceiptPayload": [
                "schema.BASControlLoopTerminalReceiptPayload.current",
                "schema.BASControlLoopTerminalReceiptPayload.backward_v1",
                "schema.BASControlLoopTerminalReceiptPayload.future_rejection",
            ],
        ]
        for entry in registry {
            XCTAssertFalse(
                entry.currentVersion.isEmpty,
                "QINAO: \(entry.objectID) has empty currentVersion"
            )
            XCTAssertEqual(
                entry.compatibilityWindow,
                "2 minor versions",
                "QINAO: \(entry.objectID) compatibilityWindow drift"
            )
            XCTAssertEqual(
                entry.deprecationPolicy,
                "Mark deprecated for one milestone before removal.",
                "QINAO: \(entry.objectID) deprecationPolicy drift"
            )
            XCTAssertEqual(
                entry.rollbackPolicy,
                "Rehydrate the previous schema snapshot and preserve replay fidelity.",
                "QINAO: \(entry.objectID) rollbackPolicy drift"
            )
            if let exactTests = canonicalArtifactPayloadTests[entry.objectID] {
                XCTAssertEqual(
                    entry.migrationTestIDs,
                    exactTests,
                    "QINAO: \(entry.objectID) canonical fixture IDs drift"
                )
            } else {
                XCTAssertEqual(
                    entry.migrationTestIDs.count,
                    2,
                    "QINAO: \(entry.objectID) must carry current+backward migration tests"
                )
            }
            XCTAssertEqual(
                Set(entry.migrationTestIDs).count,
                entry.migrationTestIDs.count,
                "QINAO: \(entry.objectID) migration test IDs must be unique"
            )
            XCTAssertTrue(
                entry.migrationTestIDs.allSatisfy { $0.hasPrefix("schema.") },
                "QINAO: \(entry.objectID) migration test IDs must be schema.* keyed"
            )
        }

        // 3) Canonical governed-conformer set — explicit allowlist binding
        //    each registry objectID to its concrete `BASSchemaVersioned`
        //    type's static `currentSchemaVersion`. This is the parity
        //    source of truth (same technique as the in-repo governance
        //    suite). Bidirectional comparison below catches BOTH an
        //    ungoverned conformer (present in set, missing from registry)
        //    AND a stale registry entry (present in registry, missing
        //    from set).
        let expectedVersions: [String: String] = QINAOSchemaGovernanceParityGateTests
            .canonicalGovernedConformerVersions()

        let actualVersions = Dictionary(
            uniqueKeysWithValues: registry.map { ($0.objectID, $0.currentVersion) }
        )

        // Direction A — no stale registry entry: every registered key is
        //   in the canonical conformer set, with matching version.
        for (objectID, version) in actualVersions {
            guard let expected = expectedVersions[objectID] else {
                XCTFail("QINAO: stale/ungoverned registry entry not in canonical conformer set: \(objectID)")
                continue
            }
            XCTAssertEqual(
                version, expected,
                "QINAO: version drift for \(objectID) — registry \(version) vs concrete type \(expected)"
            )
        }

        // Direction B — no ungoverned conformer: every canonical conformer
        //   is registered, with matching version.
        for (objectID, expected) in expectedVersions {
            guard let version = actualVersions[objectID] else {
                XCTFail("QINAO: ungoverned schema — canonical conformer missing from registry: \(objectID)")
                continue
            }
            XCTAssertEqual(
                version, expected,
                "QINAO: version drift for \(objectID) — registry \(version) vs concrete type \(expected)"
            )
        }

        // Strongest exact-set assertion: the two maps must be identical
        //   (tolerance 0). Mirrors `actualVersions == expectedVersions`
        //   from the in-repo suite, raised to the full explicit set.
        XCTAssertEqual(
            actualVersions, expectedVersions,
            "QINAO: registry↔conformer parity broken (set or version mismatch)"
        )

        // 4) Per-entry concrete-type parity across ALL registered entries
        //    via `entry(for:)` lookup — proves each governed key resolves
        //    and its version equals the bound conformer's static version
        //    (no representative subset; full alphabet of registered keys).
        for entry in registry {
            let looked = BASEBrainSchemaGovernanceRegistry.entry(for: entry.objectID)
            XCTAssertNotNil(
                looked,
                "QINAO: entry(for:) failed to resolve registered objectID \(entry.objectID)"
            )
            XCTAssertEqual(
                looked?.currentVersion,
                expectedVersions[entry.objectID],
                "QINAO: entry(for: \(entry.objectID)) version not aligned with concrete conformer"
            )
        }

        // 5) Mutation / immutability probe — tampering with a COPY of an
        //    entry must not corrupt the registry's source of truth; the
        //    re-fetched entry must still equal the concrete conformer.
        if var tampered = BASEBrainSchemaGovernanceRegistry.entry(for: "DeviceState") {
            tampered.currentVersion = "999.999.999"
            XCTAssertNotEqual(
                tampered.currentVersion,
                BASEBrainSchemaGovernanceRegistry.entry(for: "DeviceState")?.currentVersion,
                "QINAO: registry entry is not value-immutable (copy mutation leaked)"
            )
            XCTAssertEqual(
                BASEBrainSchemaGovernanceRegistry.entry(for: "DeviceState")?.currentVersion,
                BASDeviceState.currentSchemaVersion,
                "QINAO: post-mutation registry parity broken for DeviceState"
            )
        } else {
            XCTFail("QINAO: anchor schema DeviceState is not governed")
        }

        // 6) Negative governance probe — an unknown object stays ungoverned
        //    (registry does not silently invent entries).
        XCTAssertNil(
            BASEBrainSchemaGovernanceRegistry.entry(for: "QINAONonexistentSchema"),
            "QINAO: registry must not return an entry for an unregistered object"
        )

        print("QINAO-GATE schema_governance_parity: PASS \(registry.count) governed schemas, "
            + "registry↔conformer parity exact (tolerance 0), unique keys, full metadata, "
            + "per-entry concrete-type version parity verified, mutation-immutability held.")
    }

    /// Canonical objectID → concrete `BASSchemaVersioned.currentSchemaVersion`
    /// allowlist. One entry per governed schema. Drawn verbatim from the
    /// registry's own type bindings (`BASEBrainSchemaGovernanceRegistry`
    /// `entry(_:versionedType:tests:)` calls). Adding/removing a governed
    /// schema in the registry without updating this set fails the gate —
    /// which is the parity invariant.
    private static func canonicalGovernedConformerVersions() -> [String: String] {
        [
            "DeviceState": BASDeviceState.currentSchemaVersion,
            "BudgetFrame": BASBudgetFrame.currentSchemaVersion,
            "WakeIntent": BASWakeIntent.currentSchemaVersion,
            "VitalState": BASVitalState.currentSchemaVersion,
            "RunLease": BASRunLease.currentSchemaVersion,
            "EmergencyBrake": BASEmergencyBrake.currentSchemaVersion,
            "PowerLedger": BASPowerLedger.currentSchemaVersion,
            "SovereignActuationCommand": BASSovereignActuationCommand.currentSchemaVersion,
            "SovereignExecutionReceipt": BASSovereignExecutionReceipt.currentSchemaVersion,
            "RuntimePolicyLineage": BASRuntimePolicyLineage.currentSchemaVersion,
            "SovereignVerdict": BASSovereignVerdict.currentSchemaVersion,
            "SovereignCommitToken": BASSovereignCommitToken.currentSchemaVersion,
            "SovereignWarrant": BASSovereignWarrant.currentSchemaVersion,
            "SovereignLock": BASSovereignLock.currentSchemaVersion,
            "QuarantineRecord": BASQuarantineRecord.currentSchemaVersion,
            "SovereignAuditEntry": BASSovereignAuditEntry.currentSchemaVersion,
            "HostRhythmProfile": BASHostRhythmProfile.currentSchemaVersion,
            "HostConstitution": BASHostConstitution.currentSchemaVersion,
            "IdentityLattice": BASIdentityLattice.currentSchemaVersion,
            "ValueAxisSet": BASValueAxisSet.currentSchemaVersion,
            "GoalSpine": BASGoalSpine.currentSchemaVersion,
            "BoundaryVeil": BASBoundaryVeil.currentSchemaVersion,
            "RelationGravityMap": BASRelationGravityMap.currentSchemaVersion,
            "RhythmCanopy": BASRhythmCanopy.currentSchemaVersion,
            "StyleGenome": BASStyleGenome.currentSchemaVersion,
            "RoutineSkeleton": BASRoutineSkeleton.currentSchemaVersion,
            "ConsentLattice": BASConsentLattice.currentSchemaVersion,
            "NarrativeLoom": BASNarrativeLoom.currentSchemaVersion,
            "ProtectionRing": BASProtectionRing.currentSchemaVersion,
            "HostChangeCandidate": BASHostChangeCandidate.currentSchemaVersion,
            "HostVersionTree": BASHostVersionTree.currentSchemaVersion,
            "ForgetRequest": BASForgetRequest.currentSchemaVersion,
            "HostDeletionManifest": BASHostDeletionManifest.currentSchemaVersion,
            "HostSyncRevocationLedger": BASHostSyncRevocationLedger.currentSchemaVersion,
            "HostDeviceConsistencyReport": BASHostDeviceConsistencyReport.currentSchemaVersion,
            "HostDeviceMigrationContract": BASHostDeviceMigrationContract.currentSchemaVersion,
            "HostConstitutionVault": BASHostConstitutionVault.currentSchemaVersion,
            "RecoveryDisposition": BASRecoveryDisposition.currentSchemaVersion,
            "HostProfile": BASHostProfile.currentSchemaVersion,
            "HostVersion": BASHostVersion.currentSchemaVersion,
            "TemporalMemoryField": BASTemporalMemoryField.currentSchemaVersion,
            "TemporalMemoryRecord": BASTemporalMemoryRecord.currentSchemaVersion,
            "MemoryTemperatureProfile": BASMemoryTemperatureProfile.currentSchemaVersion,
            "MemoryProvenanceSeal": BASMemoryProvenanceSeal.currentSchemaVersion,
            "MemoryEpisodeArc": BASMemoryEpisodeArc.currentSchemaVersion,
            "MemoryConflictCluster": BASMemoryConflictCluster.currentSchemaVersion,
            "MemoryContinuityAnchor": BASMemoryContinuityAnchor.currentSchemaVersion,
            "MemoryReplayFrame": BASMemoryReplayFrame.currentSchemaVersion,
            "MemoryQuarantineRecord": BASMemoryQuarantineRecord.currentSchemaVersion,
            "MemorySanctumEntry": BASMemorySanctumEntry.currentSchemaVersion,
            "MemoryForgetCascade": BASMemoryForgetCascade.currentSchemaVersion,
            "MemoryAtom": BASMemoryAtom.currentSchemaVersion,
            "MemoryBundle": BASMemoryBundle.currentSchemaVersion,
            "NeuralOrganMap": BASNeuralOrganMap.currentSchemaVersion,
            "CortexPacket": BASCortexPacket.currentSchemaVersion,
            "HorizonPrior": BASHorizonPrior.currentSchemaVersion,
            "WorldFrame": BASWorldFrame.currentSchemaVersion,
            "AbstractionMap": BASAbstractionMap.currentSchemaVersion,
            "UncertaintyMap": BASUncertaintyMap.currentSchemaVersion,
            "BoundaryPrior": BASBoundaryPrior.currentSchemaVersion,
            "TemporalKnowledgeTier": BASTemporalKnowledgeTier.currentSchemaVersion,
            "EvidenceGradient": BASEvidenceGradient.currentSchemaVersion,
            "SituationField": BASSituationField.currentSchemaVersion,
            "IntentVector": BASIntentVector.currentSchemaVersion,
            "AffectLayer": BASAffectLayer.currentSchemaVersion,
            "UnknownSet": BASUnknownSet.currentSchemaVersion,
            "CognitiveDissectionFrame": BASCognitiveDissectionFrame.currentSchemaVersion,
            "MemoryPromotionPetition": BASMemoryPromotionPetition.currentSchemaVersion,
            "ArbitrationFrame": BASArbitrationFrame.currentSchemaVersion,
            "IdImpulseProfile": BASIdImpulseProfile.currentSchemaVersion,
            "EgoRealityAssessment": BASEgoRealityAssessment.currentSchemaVersion,
            "SuperegoJudgment": BASSuperegoJudgment.currentSchemaVersion,
            "TradeoffLedger": BASTradeoffLedger.currentSchemaVersion,
            "VetoMark": BASVetoMark.currentSchemaVersion,
            "AgencyReservation": BASAgencyReservation.currentSchemaVersion,
            "RemandOrder": BASRemandOrder.currentSchemaVersion,
            "CourtDecisionDraft": BASCourtDecisionDraft.currentSchemaVersion,
            "ThoughtLoopState": BASThoughtLoopState.currentSchemaVersion,
            "CounterfactualBranch": BASCounterfactualBranch.currentSchemaVersion,
            "OutcomeProjection": BASOutcomeProjection.currentSchemaVersion,
            "AdversarialBrief": BASAdversarialBrief.currentSchemaVersion,
            "HostAlignmentMap": BASHostAlignmentMap.currentSchemaVersion,
            "RenderFrame": BASRenderFrame.currentSchemaVersion,
            "OutputSurface": BASOutputSurface.currentSchemaVersion,
            "ToneWeaveProfile": BASToneWeaveProfile.currentSchemaVersion,
            "ForceCurve": BASForceCurve.currentSchemaVersion,
            "MirrorResponse": BASMirrorResponse.currentSchemaVersion,
            "BoundaryScript": BASBoundaryScript.currentSchemaVersion,
            "ComparePanel": BASComparePanel.currentSchemaVersion,
            "StepBundle": BASStepBundle.currentSchemaVersion,
            "DelayPacket": BASDelayPacket.currentSchemaVersion,
            "AgencyHandle": BASAgencyHandle.currentSchemaVersion,
            "DisclosureProfile": BASDisclosureProfile.currentSchemaVersion,
            "SilentStub": BASSilentStub.currentSchemaVersion,
            "VersionArboretum": BASVersionArboretum.currentSchemaVersion,
            "ArboretumDelta": BASArboretumDelta.currentSchemaVersion,
            "RetractionFurnace": BASRetractionFurnace.currentSchemaVersion,
            "RetractionFurnaceEntry": BASRetractionFurnaceEntry.currentSchemaVersion,
            "SovereignFrame": BASSovereignFrame.currentSchemaVersion,
            "JurisdictionMap": BASJurisdictionMap.currentSchemaVersion,
            "IntegrityWitness": BASIntegrityWitness.currentSchemaVersion,
            "ContinuitySeal": BASContinuitySeal.currentSchemaVersion,
            "MutationPetition": BASMutationPetition.currentSchemaVersion,
            "ContaminationLineage": BASContaminationLineage.currentSchemaVersion,
            "QuarantineMandate": BASQuarantineMandate.currentSchemaVersion,
            "RollbackWrit": BASRollbackWrit.currentSchemaVersion,
            "DeadStopLatch": BASDeadStopLatch.currentSchemaVersion,
            "ForgetCascadeOutcome": BASForgetCascadeOutcome.currentSchemaVersion,
            "OrganDeltaPlan": BASOrganDeltaPlan.currentSchemaVersion,
            "OrganPackage": BASOrganPackage.currentSchemaVersion,
            "SovereignLedgerRotationPlan": BASSovereignLedgerRotationPlan.currentSchemaVersion,
            "SovereignLedgerSegment": BASSovereignLedgerSegment.currentSchemaVersion,
            "SovereignLineageCutOutcome": BASSovereignLineageCutOutcome.currentSchemaVersion,
            "SovereignLineageCutRequest": BASSovereignLineageCutRequest.currentSchemaVersion,
            "SurfaceDecision": BASSurfaceDecision.currentSchemaVersion,
            "CandidateFrontier": BASCandidateFrontier.currentSchemaVersion,
            "CounterfactualBundle": BASCounterfactualBundle.currentSchemaVersion,
            "CritiqueBundle": BASCritiqueBundle.currentSchemaVersion,
            "UncertaintyLedger": BASUncertaintyLedger.currentSchemaVersion,
            "EvidenceDebt": BASEvidenceDebt.currentSchemaVersion,
            "ConvergenceCertificate": BASConvergenceCertificate.currentSchemaVersion,
            "LoopLeaseReceipt": BASLoopLeaseReceipt.currentSchemaVersion,
            "SovereignBreakpointHint": BASSovereignBreakpointHint.currentSchemaVersion,
            "RiskPermitBinding": BASRiskPermitBinding.currentSchemaVersion,
            "ToolIntentEnvelope": BASToolIntentEnvelope.currentSchemaVersion,
            "NeuralLeaseReceipt": BASNeuralLeaseReceipt.currentSchemaVersion,
            "MorphGraph": BASMorphGraph.currentSchemaVersion,
            "HotColdMap": BASHotColdMap.currentSchemaVersion,
            "PrecisionProfile": BASPrecisionProfile.currentSchemaVersion,
            "ThermalExchanger": BASThermalExchangeFrame.currentSchemaVersion,
            "IntegrityWeave": BASIntegrityWeaveFrame.currentSchemaVersion,
            "ResumeFrame": BASResumeFrame.currentSchemaVersion,
            "RollbackAnchor": BASRollbackAnchor.currentSchemaVersion,
            "LungState": BASLungState.currentSchemaVersion,
            "BreathScheduler": BASBreathSchedulerFrame.currentSchemaVersion,
            "RuleCandidate": BASRuleCandidate.currentSchemaVersion,
            "ContextFrame": BASContextFrame.currentSchemaVersion,
            "ContextSceneType": BASContextSceneType.currentSchemaVersion,
            "RoleGeometry": BASRoleGeometry.currentSchemaVersion,
            "PowerGradient": BASPowerGradient.currentSchemaVersion,
            "EmotionalWeather": BASEmotionalWeather.currentSchemaVersion,
            "UrgencyTruth": BASUrgencyTruth.currentSchemaVersion,
            "ConsequenceHorizon": BASConsequenceHorizon.currentSchemaVersion,
            "ManipulationTrace": BASManipulationTrace.currentSchemaVersion,
            "HostResonance": BASHostResonance.currentSchemaVersion,
            "ContinuityAnchor": BASContinuityAnchor.currentSchemaVersion,
            "ContextRouteHint": BASContextRouteHint.currentSchemaVersion,
            "DecomposeFrame": BASDecomposeFrame.currentSchemaVersion,
            "CandidatePath": BASCandidatePath.currentSchemaVersion,
            "ForecastItem": BASForecastItem.currentSchemaVersion,
            "CritiqueItem": BASCritiqueItem.currentSchemaVersion,
            "ThoughtFrame": BASThoughtFrame.currentSchemaVersion,
            "ThoughtFold": BASThoughtFold.currentSchemaVersion,
            "TriSelfScore": BASTriSelfScore.currentSchemaVersion,
            "MergedChoice": BASMergedChoice.currentSchemaVersion,
            "RenderedOutput": BASRenderedOutput.currentSchemaVersion,
            "RiskCard": BASRiskCard.currentSchemaVersion,
            "ActionPermit": BASActionPermit.currentSchemaVersion,
            "RiskField": BASRiskField.currentSchemaVersion,
            "HazardVector": BASHazardVector.currentSchemaVersion,
            "HarmRadiusMap": BASHarmRadiusMap.currentSchemaVersion,
            "ReversibilityProfile": BASReversibilityProfile.currentSchemaVersion,
            "EvidenceSufficiency": BASEvidenceSufficiency.currentSchemaVersion,
            "GSITrace": BASGSITrace.currentSchemaVersion,
            "VulnerabilityCoupling": BASVulnerabilityCoupling.currentSchemaVersion,
            "ActionModeDecision": BASActionModeDecision.currentSchemaVersion,
            "DelayReservation": BASDelayReservation.currentSchemaVersion,
            "ProtectiveSubstitute": BASProtectiveSubstitute.currentSchemaVersion,
            "SovereignEscalationHint": BASSovereignEscalationHint.currentSchemaVersion,
            "RiskDecisionPackage": BASRiskDecisionPackage.currentSchemaVersion,
            "ExperienceCandidate": BASExperienceCandidate.currentSchemaVersion,
            "ShadowTrialRecord": BASShadowTrialRecord.currentSchemaVersion,
            "VersionDelta": BASVersionDelta.currentSchemaVersion,
            "WorkflowCandidate": BASWorkflowCandidate.currentSchemaVersion,
            "GuardTemplateCandidate": BASGuardTemplateCandidate.currentSchemaVersion,
            "BiasRecord": BASBiasRecord.currentSchemaVersion,
            "RiskPatternCandidate": BASRiskPatternCandidate.currentSchemaVersion,
            "RetractionOrder": BASRetractionOrder.currentSchemaVersion,
            "LearningExportBundle": BASLearningExportBundle.currentSchemaVersion,
            "EvolutionSeal": BASEvolutionSeal.currentSchemaVersion,
            "UpdateTicket": BASUpdateTicket.currentSchemaVersion,
            "EvolutionLineageSummary": BASEvolutionLineageSummary.currentSchemaVersion,
            "EvolutionFoldedLungSummary": BASEvolutionFoldedLungSummary.currentSchemaVersion,
            "RuntimeTrace": BASRuntimeTrace.currentSchemaVersion,
            "EvalSample": BASEvalSample.currentSchemaVersion,
            "ModelArtifact": BASModelArtifact.currentSchemaVersion,
            "FeedbackEvent": BASFeedbackEvent.currentSchemaVersion,
            "AbyssalPressure": BASAbyssalPressure.currentSchemaVersion,
            "HumanAnchorSignal": BASHumanAnchorSignal.currentSchemaVersion,
            "AnomalyTrace": BASAnomalyTrace.currentSchemaVersion,
            "NarrativeDistortion": BASNarrativeDistortion.currentSchemaVersion,
            "AbyssalBranch": BASAbyssalBranch.currentSchemaVersion,
            "UnknownReserve": BASUnknownReserve.currentSchemaVersion,
            "SealEnvelope": BASSealEnvelope.currentSchemaVersion,
            "ForbiddenKnowledgeCandidate": BASForbiddenKnowledgeCandidate.currentSchemaVersion,
            "CosmicScaleView": BASCosmicScaleView.currentSchemaVersion,
            "TemporalDepthMap": BASTemporalDepthMap.currentSchemaVersion,
            "OntologyFog": BASOntologyFog.currentSchemaVersion,
            "OntologyShiftMark": BASOntologyShiftMark.currentSchemaVersion,
            "NonEuclideanCandidate": BASNonEuclideanCandidate.currentSchemaVersion,
            "UnknownRetentionLoop": BASUnknownRetentionLoop.currentSchemaVersion,
            "CosmicColdCounterweight": BASCosmicColdCounterweight.currentSchemaVersion,
            "KunlunAxis": BASKunlunAxis.currentSchemaVersion,
            "AxisAlignment": BASAxisAlignment.currentSchemaVersion,
            "JadeCanonSeal": BASJadeCanonSeal.currentSchemaVersion,
            "HeavenGatePermit": BASHeavenGatePermit.currentSchemaVersion,
            "RiverOriginTrace": BASRiverOriginTrace.currentSchemaVersion,
            "YaochiSanctumEntry": BASYaochiSanctumEntry.currentSchemaVersion,
            "KunlunAxisView": BASKunlunAxisView.currentSchemaVersion,
            "KunlunAscentView": BASKunlunAscentView.currentSchemaVersion,
            "KunlunFarWestReserve": BASKunlunFarWestReserve.currentSchemaVersion,
            "KunlunTianmenWarrant": BASKunlunTianmenWarrant.currentSchemaVersion,
            "KunlunGateDenialWrit": BASKunlunGateDenialWrit.currentSchemaVersion,
            "AbyssBudget": BASAbyssBudget.currentSchemaVersion,
            "ForbiddenCandidateZone": BASForbiddenCandidateZone.currentSchemaVersion,
            "SovereignPlane": BASSovereignPlane.currentSchemaVersion,
            "StatePlane": BASStatePlane.currentSchemaVersion,
            "ComputePlane": BASComputePlane.currentSchemaVersion,
            "LeaseLifeKernel": BASLeaseLifeKernel.currentSchemaVersion,
            "NeuralOrganRuntime": BASNeuralOrganRuntime.currentSchemaVersion,
            "StateEvolutionGraphKernel": BASStateEvolutionGraphKernel.currentSchemaVersion,
            "SovereignMicrokernel": BASSovereignMicrokernel.currentSchemaVersion,
            "SnapshotArk": BASSnapshotArk.currentSchemaVersion,
            "HumanAnchorProfile": BASHumanAnchorProfile.currentSchemaVersion,
            "NarrativeDistortionMap": BASNarrativeDistortionMap.currentSchemaVersion,
            "SealedMemory": BASSealedMemory.currentSchemaVersion,
            "AscentLease": BASAscentLease.currentSchemaVersion,
            "AxisDeviation": BASAxisDeviation.currentSchemaVersion,
            "GatePressure": BASGatePressure.currentSchemaVersion,
            "AscentBranch": BASAscentBranch.currentSchemaVersion,
            "RestStep": BASRestStep.currentSchemaVersion,
            "ReturnPath": BASReturnPath.currentSchemaVersion,
            "JadeCasketSnapshot": BASJadeCasketSnapshot.currentSchemaVersion,
            "YaochiMemoryLayer": BASYaochiMemoryLayer.currentSchemaVersion,
            "TianhengProfile": BASTianhengProfile.currentSchemaVersion,
            "JadePermitGrade": BASJadePermitGrade.currentSchemaVersion,
            "JadeRefinementTicket": BASJadeRefinementTicket.currentSchemaVersion,
            "JadeFidelityMap": BASJadeFidelityMap.currentSchemaVersion,
            "HostJadeRegister": BASHostJadeRegister.currentSchemaVersion,
            "JadeMirrorDraft": BASJadeMirrorDraft.currentSchemaVersion,
            "KunlunUnnamableSet": BASKunlunUnnamableSet.currentSchemaVersion,
            "CounterHostCheck": BASCounterHostCheck.currentSchemaVersion,
            "AxisStabilityScore": BASAxisStabilityScore.currentSchemaVersion,
            "GateFidelityScore": BASGateFidelityScore.currentSchemaVersion,
            "OriginTraceCompleteness": BASOriginTraceCompleteness.currentSchemaVersion,
            "SanctumLeakRate": BASSanctumLeakRate.currentSchemaVersion,
            "DoctrineHarmonyScore": BASDoctrineHarmonyScore.currentSchemaVersion,
            "HumanAnchorRetention": BASHumanAnchorRetention.currentSchemaVersion,
            "LayerActorInput": BASLayerActorInput.currentSchemaVersion,
            "LayerActorOutput": BASLayerActorOutput.currentSchemaVersion,
            "LayerSlice": BASLayerSlice.currentSchemaVersion,
            "LayerInferenceInput": BASLayerInferenceInput.currentSchemaVersion,
            "LayerInferenceOutput": BASLayerInferenceOutput.currentSchemaVersion,
            "LayerKillSwitchState": BASLayerKillSwitchState.currentSchemaVersion,
            "LayerErrorBoundaryReport": BASLayerErrorBoundaryReport.currentSchemaVersion,
            "HostStorageOptions": BASHostStorageOptions.currentSchemaVersion,
            "HostStorageWireReport": BASHostStorageWireReport.currentSchemaVersion,
            "LayerMLHeadSlot": BASLayerMLHeadSlot.currentSchemaVersion,
            "LayerCascadeResult": BASLayerCascadeResult.currentSchemaVersion,
            "LayerMeshSlot": BAS14LayerMeshSlot.currentSchemaVersion,
            "MeshSyncFrame": BASMeshSyncFrame.currentSchemaVersion,
            "MeshSyncFrameMergeReport": BASMeshSyncFrameMergeReport.currentSchemaVersion,
            "CoreMLPredictionFrame": BASCoreMLPredictionFrame.currentSchemaVersion,
            "ChengluMeshRegistrationReport": BASChengluMeshRegistrationReport.currentSchemaVersion,
            "BASTurnOperationPayload": BASTurnOperationPayload.currentSchemaVersion,
            "BASBudgetLeasePayload": BASBudgetLeasePayload.currentSchemaVersion,
            "BASJoinArtifact": BASJoinArtifact.currentSchemaVersion,
            "BASRemandArtifact": BASRemandArtifact.currentSchemaVersion,
            "BASRefusalArtifact": BASRefusalArtifact.currentSchemaVersion,
            "BASControlLoopEnvelopePayload": BASControlLoopEnvelopePayload.currentSchemaVersion,
            "BASControlLoopProgressWitnessPayload": BASControlLoopProgressWitnessPayload.currentSchemaVersion,
            "BASControlLoopTerminalReceiptPayload": BASControlLoopTerminalReceiptPayload.currentSchemaVersion,
            // old-audit schema-parity backfill (2026-07-11): the 12 newly-registered conformers
            "DistillationBank": BASDistillationBank.currentSchemaVersion,
            "EvidenceAtom": BASEvidenceAtom.currentSchemaVersion,
            "GuardBranch": BASGuardBranch.currentSchemaVersion,
            "MemoryUsageRecord": BASMemoryUsageRecord.currentSchemaVersion,
            "RegretProfile": BASRegretProfile.currentSchemaVersion,
            "RiskCalibrationBundle": BASRiskCalibrationBundle.currentSchemaVersion,
            "RiskCalibrationStratumDelta": BASRiskCalibrationStratumDelta.currentSchemaVersion,
            "RiskCalibrationStratumSubModelRef": BASRiskCalibrationStratumSubModelRef.currentSchemaVersion,
            "SacrificeMap": BASSacrificeMap.currentSchemaVersion,
            "ShadowEvaluationResult": BASShadowEvaluationResult.currentSchemaVersion,
            "ShadowEvaluatorMeridianResult": BASShadowEvaluatorMeridianResult.currentSchemaVersion,
            "ShadowTrialTypedEffect": BASShadowTrialTypedEffect.currentSchemaVersion,
        ]
    }
}
