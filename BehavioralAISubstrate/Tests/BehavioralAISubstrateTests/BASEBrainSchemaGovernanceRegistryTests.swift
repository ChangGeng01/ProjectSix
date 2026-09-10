import Testing
@testable import BASAdmin
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASSovereign
import BASWorldPrior
import BASEvaluation

@Suite("BASEBrain schema governance registry")
struct BASEBrainSchemaGovernanceRegistryTests {
    @Test("unknown schema objects stay ungoverned until registered explicitly")
    func unknownSchemaObjectsReturnNil() {
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "UnknownObject") == nil)
    }

    @Test("every governed schema carries compatibility, migration, and rollback metadata")
    func governedEntriesCarryRequiredMetadata() {
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
        for entry in BASEBrainSchemaGovernanceRegistry.governedSchemas {
            #expect(!entry.currentVersion.isEmpty)
            #expect(entry.compatibilityWindow == "2 minor versions")
            #expect(entry.deprecationPolicy == "Mark deprecated for one milestone before removal.")
            #expect(entry.rollbackPolicy == "Rehydrate the previous schema snapshot and preserve replay fidelity.")
            if let exactTests = canonicalArtifactPayloadTests[entry.objectID] {
                #expect(entry.migrationTestIDs == exactTests)
            } else {
                #expect(entry.migrationTestIDs.count == 2)
            }
            #expect(Set(entry.migrationTestIDs).count == entry.migrationTestIDs.count)
            #expect(entry.migrationTestIDs.allSatisfy { $0.hasPrefix("schema.") })
        }
    }

    @Test("governed schema registry stays uniquely keyed and fully populated")
    func governedRegistryStaysUniquelyKeyedAndComplete() {
        let governedObjects = BASEBrainSchemaGovernanceRegistry.governedSchemas.map(\.objectID)

        #expect(governedObjects.count == 284)  // + Task 4 collaboration/control-loop artifacts
        #expect(Set(governedObjects).count == governedObjects.count)
        #expect(governedObjects.contains("BASTurnOperationPayload"))
        #expect(governedObjects.contains("BASBudgetLeasePayload"))
        #expect(governedObjects.contains("BASJoinArtifact"))
        #expect(governedObjects.contains("BASRemandArtifact"))
        #expect(governedObjects.contains("BASRefusalArtifact"))
        #expect(governedObjects.contains("BASControlLoopEnvelopePayload"))
        #expect(governedObjects.contains("BASControlLoopProgressWitnessPayload"))
        #expect(governedObjects.contains("BASControlLoopTerminalReceiptPayload"))
        #expect(governedObjects.contains("DeviceState"))
        #expect(governedObjects.contains("BudgetFrame"))
        #expect(governedObjects.contains("HostConstitution"))
        #expect(governedObjects.contains("IdentityLattice"))
        #expect(governedObjects.contains("ValueAxisSet"))
        #expect(governedObjects.contains("GoalSpine"))
        #expect(governedObjects.contains("BoundaryVeil"))
        #expect(governedObjects.contains("RelationGravityMap"))
        #expect(governedObjects.contains("RhythmCanopy"))
        #expect(governedObjects.contains("StyleGenome"))
        #expect(governedObjects.contains("RoutineSkeleton"))
        #expect(governedObjects.contains("ConsentLattice"))
        #expect(governedObjects.contains("NarrativeLoom"))
        #expect(governedObjects.contains("ProtectionRing"))
        #expect(governedObjects.contains("HostChangeCandidate"))
        #expect(governedObjects.contains("HostVersionTree"))
        #expect(governedObjects.contains("ForgetRequest"))
        #expect(governedObjects.contains("HostDeletionManifest"))
        #expect(governedObjects.contains("HostSyncRevocationLedger"))
        #expect(governedObjects.contains("HostDeviceConsistencyReport"))
        #expect(governedObjects.contains("HostDeviceMigrationContract"))
        #expect(governedObjects.contains("HostConstitutionVault"))
        #expect(governedObjects.contains("HostProfile"))
        #expect(governedObjects.contains("TemporalMemoryField"))
        #expect(governedObjects.contains("TemporalMemoryRecord"))
        #expect(governedObjects.contains("MemoryTemperatureProfile"))
        #expect(governedObjects.contains("MemoryProvenanceSeal"))
        #expect(governedObjects.contains("MemoryEpisodeArc"))
        #expect(governedObjects.contains("MemoryConflictCluster"))
        #expect(governedObjects.contains("MemoryContinuityAnchor"))
        #expect(governedObjects.contains("MemoryReplayFrame"))
        #expect(governedObjects.contains("MemoryQuarantineRecord"))
        #expect(governedObjects.contains("MemorySanctumEntry"))
        #expect(governedObjects.contains("MemoryForgetCascade"))
        #expect(governedObjects.contains("NeuralOrganMap"))
        #expect(governedObjects.contains("CandidateFrontier"))
        #expect(governedObjects.contains("CounterfactualBundle"))
        #expect(governedObjects.contains("CritiqueBundle"))
        #expect(governedObjects.contains("UncertaintyLedger"))
        #expect(governedObjects.contains("EvidenceDebt"))
        #expect(governedObjects.contains("ConvergenceCertificate"))
        #expect(governedObjects.contains("LoopLeaseReceipt"))
        #expect(governedObjects.contains("SovereignBreakpointHint"))
        #expect(governedObjects.contains("RiskPermitBinding"))
        #expect(governedObjects.contains("ToolIntentEnvelope"))
        #expect(governedObjects.contains("NeuralLeaseReceipt"))
        #expect(governedObjects.contains("MorphGraph"))
        #expect(governedObjects.contains("HotColdMap"))
        #expect(governedObjects.contains("PrecisionProfile"))
        #expect(governedObjects.contains("ThermalExchanger"))
        #expect(governedObjects.contains("IntegrityWeave"))
        #expect(governedObjects.contains("ResumeFrame"))
        #expect(governedObjects.contains("RollbackAnchor"))
        #expect(governedObjects.contains("LungState"))
        #expect(governedObjects.contains("BreathScheduler"))
        #expect(governedObjects.contains("RiskCard"))
        #expect(governedObjects.contains("ActionPermit"))
        #expect(governedObjects.contains("RiskField"))
        #expect(governedObjects.contains("HazardVector"))
        #expect(governedObjects.contains("HarmRadiusMap"))
        #expect(governedObjects.contains("ReversibilityProfile"))
        #expect(governedObjects.contains("EvidenceSufficiency"))
        #expect(governedObjects.contains("GSITrace"))
        #expect(governedObjects.contains("VulnerabilityCoupling"))
        #expect(governedObjects.contains("ActionModeDecision"))
        #expect(governedObjects.contains("DelayReservation"))
        #expect(governedObjects.contains("ProtectiveSubstitute"))
        #expect(governedObjects.contains("SovereignEscalationHint"))
        #expect(governedObjects.contains("RiskDecisionPackage"))
        #expect(governedObjects.contains("ExperienceCandidate"))
        #expect(governedObjects.contains("ShadowTrialRecord"))
        #expect(governedObjects.contains("VersionDelta"))
        #expect(governedObjects.contains("WorkflowCandidate"))
        #expect(governedObjects.contains("GuardTemplateCandidate"))
        #expect(governedObjects.contains("BiasRecord"))
        #expect(governedObjects.contains("RiskPatternCandidate"))
        #expect(governedObjects.contains("RetractionOrder"))
        #expect(governedObjects.contains("LearningExportBundle"))
        #expect(governedObjects.contains("EvolutionSeal"))
        #expect(governedObjects.contains("UpdateTicket"))
        #expect(governedObjects.contains("EvolutionLineageSummary"))
        #expect(governedObjects.contains("RuntimeTrace"))
        #expect(governedObjects.contains("EvalSample"))
        #expect(governedObjects.contains("ModelArtifact"))
        #expect(governedObjects.contains("FeedbackEvent"))
        #expect(governedObjects.contains("SovereignVerdict"))
        #expect(governedObjects.contains("SovereignCommitToken"))
        #expect(governedObjects.contains("SovereignWarrant"))
        #expect(governedObjects.contains("SovereignLock"))
        #expect(governedObjects.contains("QuarantineRecord"))
        #expect(governedObjects.contains("SovereignAuditEntry"))
    }

    @Test("representative governed schemas stay aligned with concrete versioned types")
    func representativeSchemasStayAlignedWithConcreteTypes() {
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryBundle")?.currentVersion == BASMemoryBundle.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostConstitution")?.currentVersion == BASHostConstitution.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostConstitutionVault")?.currentVersion == BASHostConstitutionVault.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostProfile")?.currentVersion == BASHostProfile.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "TemporalMemoryField")?.currentVersion == BASTemporalMemoryField.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "TemporalMemoryRecord")?.currentVersion == BASTemporalMemoryRecord.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryTemperatureProfile")?.currentVersion == BASMemoryTemperatureProfile.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryProvenanceSeal")?.currentVersion == BASMemoryProvenanceSeal.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryEpisodeArc")?.currentVersion == BASMemoryEpisodeArc.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryConflictCluster")?.currentVersion == BASMemoryConflictCluster.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryContinuityAnchor")?.currentVersion == BASMemoryContinuityAnchor.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryReplayFrame")?.currentVersion == BASMemoryReplayFrame.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryQuarantineRecord")?.currentVersion == BASMemoryQuarantineRecord.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemorySanctumEntry")?.currentVersion == BASMemorySanctumEntry.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryForgetCascade")?.currentVersion == BASMemoryForgetCascade.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "NeuralOrganMap")?.currentVersion == BASNeuralOrganMap.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "UncertaintyLedger")?.currentVersion == BASUncertaintyLedger.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "EvidenceDebt")?.currentVersion == BASEvidenceDebt.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ConvergenceCertificate")?.currentVersion == BASConvergenceCertificate.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "LoopLeaseReceipt")?.currentVersion == BASLoopLeaseReceipt.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignBreakpointHint")?.currentVersion == BASSovereignBreakpointHint.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HotColdMap")?.currentVersion == BASHotColdMap.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "LungState")?.currentVersion == BASLungState.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "BreathScheduler")?.currentVersion == BASBreathSchedulerFrame.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ThermalExchanger")?.currentVersion == BASThermalExchangeFrame.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ThoughtFold")?.currentVersion == BASThoughtFold.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ToolIntentEnvelope")?.currentVersion == BASToolIntentEnvelope.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RiskCard")?.currentVersion == BASRiskCard.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ActionPermit")?.currentVersion == BASActionPermit.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "UpdateTicket")?.currentVersion == BASUpdateTicket.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignVerdict")?.currentVersion == BASSovereignVerdict.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignCommitToken")?.currentVersion == BASSovereignCommitToken.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignWarrant")?.currentVersion == BASSovereignWarrant.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignLock")?.currentVersion == BASSovereignLock.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "QuarantineRecord")?.currentVersion == BASQuarantineRecord.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignAuditEntry")?.currentVersion == BASSovereignAuditEntry.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RuntimeTrace")?.currentVersion == BASRuntimeTrace.currentSchemaVersion)
    }

    @Test("all governed schemas stay aligned with concrete versioned types")
    func allGovernedSchemasStayAlignedWithConcreteTypes() {
        let actualVersions = Dictionary(uniqueKeysWithValues: BASEBrainSchemaGovernanceRegistry.governedSchemas.map { ($0.objectID, $0.currentVersion) })
        let expectedVersions: [String: String] = [
            // old-audit schema-parity backfill (2026-07-11): the 12 newly-registered objects
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
            "DeviceState": BASDeviceState.currentSchemaVersion,
            "BudgetFrame": BASBudgetFrame.currentSchemaVersion,
            "WakeIntent": BASWakeIntent.currentSchemaVersion,
            "VitalState": BASVitalState.currentSchemaVersion,
            "RunLease": BASRunLease.currentSchemaVersion,
            "EmergencyBrake": BASEmergencyBrake.currentSchemaVersion,
            "PowerLedger": BASPowerLedger.currentSchemaVersion,  // M106
            "CortexPacket": BASCortexPacket.currentSchemaVersion,  // M107
            "HorizonPrior": BASHorizonPrior.currentSchemaVersion,  // M109
            "WorldFrame": BASWorldFrame.currentSchemaVersion,  // M109
            "AbstractionMap": BASAbstractionMap.currentSchemaVersion,  // M109
            "UncertaintyMap": BASUncertaintyMap.currentSchemaVersion,  // M109
            "BoundaryPrior": BASBoundaryPrior.currentSchemaVersion,  // M109
            "TemporalKnowledgeTier": BASTemporalKnowledgeTier.currentSchemaVersion,  // M109
            "EvidenceGradient": BASEvidenceGradient.currentSchemaVersion,  // M109
            "SituationField": BASSituationField.currentSchemaVersion,  // M111
            "IntentVector": BASIntentVector.currentSchemaVersion,  // M112
            "AffectLayer": BASAffectLayer.currentSchemaVersion,  // M112
            "UnknownSet": BASUnknownSet.currentSchemaVersion,  // M112
            "CognitiveDissectionFrame":
                BASCognitiveDissectionFrame.currentSchemaVersion,  // M112
            "MemoryPromotionPetition":
                BASMemoryPromotionPetition.currentSchemaVersion,  // M113
            // M115 L10:
            "ArbitrationFrame": BASArbitrationFrame.currentSchemaVersion,
            "IdImpulseProfile": BASIdImpulseProfile.currentSchemaVersion,
            "EgoRealityAssessment":
                BASEgoRealityAssessment.currentSchemaVersion,
            "SuperegoJudgment": BASSuperegoJudgment.currentSchemaVersion,
            "TradeoffLedger": BASTradeoffLedger.currentSchemaVersion,
            "VetoMark": BASVetoMark.currentSchemaVersion,
            "AgencyReservation":
                BASAgencyReservation.currentSchemaVersion,
            "RemandOrder": BASRemandOrder.currentSchemaVersion,
            "CourtDecisionDraft":
                BASCourtDecisionDraft.currentSchemaVersion,
            "ThoughtLoopState": BASThoughtLoopState.currentSchemaVersion,  // M114
            "CounterfactualBranch": BASCounterfactualBranch.currentSchemaVersion,  // M114
            "OutcomeProjection": BASOutcomeProjection.currentSchemaVersion,  // M114
            "AdversarialBrief": BASAdversarialBrief.currentSchemaVersion,  // M114
            "HostAlignmentMap": BASHostAlignmentMap.currentSchemaVersion,  // M114
            // M117 L12:
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
            // M118 L13 §4:
            "VersionArboretum":
                BASVersionArboretum.currentSchemaVersion,
            "ArboretumDelta":
                BASArboretumDelta.currentSchemaVersion,
            "RetractionFurnace":
                BASRetractionFurnace.currentSchemaVersion,
            "RetractionFurnaceEntry":
                BASRetractionFurnaceEntry.currentSchemaVersion,
            // M119 L14 §5 Black Ring:
            "SovereignFrame":
                BASSovereignFrame.currentSchemaVersion,
            "JurisdictionMap":
                BASJurisdictionMap.currentSchemaVersion,
            "IntegrityWitness":
                BASIntegrityWitness.currentSchemaVersion,
            "ContinuitySeal":
                BASContinuitySeal.currentSchemaVersion,
            "MutationPetition":
                BASMutationPetition.currentSchemaVersion,
            "ContaminationLineage":
                BASContaminationLineage.currentSchemaVersion,
            "QuarantineMandate":
                BASQuarantineMandate.currentSchemaVersion,
            "RollbackWrit":
                BASRollbackWrit.currentSchemaVersion,
            "DeadStopLatch":
                BASDeadStopLatch.currentSchemaVersion,
            // M120 parity-lint backfill:
            "ForgetCascadeOutcome":
                BASForgetCascadeOutcome.currentSchemaVersion,
            "OrganDeltaPlan":
                BASOrganDeltaPlan.currentSchemaVersion,
            "OrganPackage":
                BASOrganPackage.currentSchemaVersion,
            "SovereignLedgerRotationPlan":
                BASSovereignLedgerRotationPlan.currentSchemaVersion,
            "SovereignLedgerSegment":
                BASSovereignLedgerSegment.currentSchemaVersion,
            "SovereignLineageCutOutcome":
                BASSovereignLineageCutOutcome.currentSchemaVersion,
            "SovereignLineageCutRequest":
                BASSovereignLineageCutRequest.currentSchemaVersion,
            "SurfaceDecision":
                BASSurfaceDecision.currentSchemaVersion,
            "SovereignActuationCommand": BASSovereignActuationCommand.currentSchemaVersion,
            "SovereignExecutionReceipt": BASSovereignExecutionReceipt.currentSchemaVersion,
            "SovereignVerdict": BASSovereignVerdict.currentSchemaVersion,
            "SovereignCommitToken": BASSovereignCommitToken.currentSchemaVersion,
            "SovereignWarrant": BASSovereignWarrant.currentSchemaVersion,
            "SovereignLock": BASSovereignLock.currentSchemaVersion,
            "QuarantineRecord": BASQuarantineRecord.currentSchemaVersion,
            "SovereignAuditEntry": BASSovereignAuditEntry.currentSchemaVersion,
            "RuntimePolicyLineage": BASRuntimePolicyLineage.currentSchemaVersion,
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
            // M287 — Cthulhu-inspiration white paper schema parity:
            "AbyssalPressure":
                BASAbyssalPressure.currentSchemaVersion,
            "HumanAnchorSignal":
                BASHumanAnchorSignal.currentSchemaVersion,
            "AnomalyTrace":
                BASAnomalyTrace.currentSchemaVersion,
            "NarrativeDistortion":
                BASNarrativeDistortion.currentSchemaVersion,
            "AbyssalBranch":
                BASAbyssalBranch.currentSchemaVersion,
            "UnknownReserve":
                BASUnknownReserve.currentSchemaVersion,
            "SealEnvelope":
                BASSealEnvelope.currentSchemaVersion,
            "ForbiddenKnowledgeCandidate":
                BASForbiddenKnowledgeCandidate.currentSchemaVersion,
            // M439 (chapter 一百十四) — 7 missing L4/L7/L9/L10
            // schemas closing 2026-05-04 audit Section B blanks:
            "CosmicScaleView":
                BASCosmicScaleView.currentSchemaVersion,
            "TemporalDepthMap":
                BASTemporalDepthMap.currentSchemaVersion,
            "OntologyFog":
                BASOntologyFog.currentSchemaVersion,
            "OntologyShiftMark":
                BASOntologyShiftMark.currentSchemaVersion,
            "NonEuclideanCandidate":
                BASNonEuclideanCandidate.currentSchemaVersion,
            "UnknownRetentionLoop":
                BASUnknownRetentionLoop.currentSchemaVersion,
            "CosmicColdCounterweight":
                BASCosmicColdCounterweight.currentSchemaVersion,
            // M439 (chapter 一百十四 anti-drift sweep) — 11
            // Kunlun schemas backfilled into governance:
            "KunlunAxis":
                BASKunlunAxis.currentSchemaVersion,
            "AxisAlignment":
                BASAxisAlignment.currentSchemaVersion,
            "JadeCanonSeal":
                BASJadeCanonSeal.currentSchemaVersion,
            "HeavenGatePermit":
                BASHeavenGatePermit.currentSchemaVersion,
            "RiverOriginTrace":
                BASRiverOriginTrace.currentSchemaVersion,
            "YaochiSanctumEntry":
                BASYaochiSanctumEntry.currentSchemaVersion,
            "KunlunAxisView":
                BASKunlunAxisView.currentSchemaVersion,
            "KunlunAscentView":
                BASKunlunAscentView.currentSchemaVersion,
            "KunlunFarWestReserve":
                BASKunlunFarWestReserve.currentSchemaVersion,
            "KunlunTianmenWarrant":
                BASKunlunTianmenWarrant.currentSchemaVersion,
            "KunlunGateDenialWrit":
                BASKunlunGateDenialWrit.currentSchemaVersion,
            // M440 (chapter 一百十五) — 2 layer-naming schemas:
            "AbyssBudget":
                BASAbyssBudget.currentSchemaVersion,
            "ForbiddenCandidateZone":
                BASForbiddenCandidateZone.currentSchemaVersion,
            // M441-M443 (chapter 一百十六) — top-level wrappers:
            "SovereignPlane":
                BASSovereignPlane.currentSchemaVersion,
            "StatePlane":
                BASStatePlane.currentSchemaVersion,
            "ComputePlane":
                BASComputePlane.currentSchemaVersion,
            "LeaseLifeKernel":
                BASLeaseLifeKernel.currentSchemaVersion,
            "NeuralOrganRuntime":
                BASNeuralOrganRuntime.currentSchemaVersion,
            "StateEvolutionGraphKernel":
                BASStateEvolutionGraphKernel.currentSchemaVersion,
            "SovereignMicrokernel":
                BASSovereignMicrokernel.currentSchemaVersion,
            "SnapshotArk":
                BASSnapshotArk.currentSchemaVersion,
            // M460-M462 (chapter 一百二十一) — strict 14-layer
            // Cthulhu whitepaper coverage closures:
            "HumanAnchorProfile":
                BASHumanAnchorProfile.currentSchemaVersion,
            "NarrativeDistortionMap":
                BASNarrativeDistortionMap.currentSchemaVersion,
            "SealedMemory":
                BASSealedMemory.currentSchemaVersion,
            // M465-M470 (chapter 一百二十二) — Kunlun control-flow
            // schemas (Stream A α):
            "AscentLease":
                BASAscentLease.currentSchemaVersion,
            "AxisDeviation":
                BASAxisDeviation.currentSchemaVersion,
            "GatePressure":
                BASGatePressure.currentSchemaVersion,
            "AscentBranch":
                BASAscentBranch.currentSchemaVersion,
            "RestStep":
                BASRestStep.currentSchemaVersion,
            "ReturnPath":
                BASReturnPath.currentSchemaVersion,
            // M471-M475 (chapter 一百二十三) — Kunlun memory +
            // equilibrium + permit-grade + refinement schemas
            // (Stream A β):
            "JadeCasketSnapshot":
                BASJadeCasketSnapshot.currentSchemaVersion,
            "YaochiMemoryLayer":
                BASYaochiMemoryLayer.currentSchemaVersion,
            "TianhengProfile":
                BASTianhengProfile.currentSchemaVersion,
            "JadePermitGrade":
                BASJadePermitGrade.currentSchemaVersion,
            "JadeRefinementTicket":
                BASJadeRefinementTicket.currentSchemaVersion,
            // M476-M479 (chapter 一百二十四) — Kunlun host +
            // integrity schemas (Stream A γ):
            "JadeFidelityMap":
                BASJadeFidelityMap.currentSchemaVersion,
            "HostJadeRegister":
                BASHostJadeRegister.currentSchemaVersion,
            "JadeMirrorDraft":
                BASJadeMirrorDraft.currentSchemaVersion,
            "KunlunUnnamableSet":
                BASKunlunUnnamableSet.currentSchemaVersion,
            "CounterHostCheck":
                BASCounterHostCheck.currentSchemaVersion,
            "AxisStabilityScore":
                BASAxisStabilityScore.currentSchemaVersion,
            "GateFidelityScore":
                BASGateFidelityScore.currentSchemaVersion,
            "OriginTraceCompleteness":
                BASOriginTraceCompleteness.currentSchemaVersion,
            "SanctumLeakRate":
                BASSanctumLeakRate.currentSchemaVersion,
            "DoctrineHarmonyScore":
                BASDoctrineHarmonyScore.currentSchemaVersion,
            "HumanAnchorRetention":
                BASHumanAnchorRetention.currentSchemaVersion,
            // M786 (chapter 二百九十九) — Phase Beta foundation.
            "LayerActorInput":
                BASLayerActorInput.currentSchemaVersion,
            "LayerActorOutput":
                BASLayerActorOutput.currentSchemaVersion,
            // M787 (chapter 三百) — Phase Beta cut 2.
            "LayerSlice":
                BASLayerSlice.currentSchemaVersion,
            "LayerInferenceInput":
                BASLayerInferenceInput.currentSchemaVersion,
            "LayerInferenceOutput":
                BASLayerInferenceOutput.currentSchemaVersion,
            // M788 (chapter 三百〇一) — Phase Beta cut 3 (final
            // foundation): per-layer kill switch + error boundary.
            "LayerKillSwitchState":
                BASLayerKillSwitchState.currentSchemaVersion,
            "LayerErrorBoundaryReport":
                BASLayerErrorBoundaryReport.currentSchemaVersion,
            // M790 (chapter 三百〇三) — Phase Gamma 1st code cut:
            // typed storage options + wire report.
            "HostStorageOptions":
                BASHostStorageOptions.currentSchemaVersion,
            "HostStorageWireReport":
                BASHostStorageWireReport.currentSchemaVersion,
            // M797 (chapter 三百一〇) — Phase Delta 1st code cut:
            // typed ML head slot record.
            "LayerMLHeadSlot":
                BASLayerMLHeadSlot.currentSchemaVersion,
            // M799 (chapter 三百一二) — Phase Delta 3rd code cut:
            // typed cascading inference result.
            "LayerCascadeResult":
                BASLayerCascadeResult.currentSchemaVersion,
            // M800 (chapter 三百一三) — Phase Delta 4th code cut:
            // typed 14-layer × ML head canonical mesh map slot.
            "LayerMeshSlot":
                BAS14LayerMeshSlot.currentSchemaVersion,
            // M805 (chapter 三百一八) — Phase Epsilon 5th code cut:
            // typed cross-instance mesh sync frame + merge report.
            "MeshSyncFrame":
                BASMeshSyncFrame.currentSchemaVersion,
            "MeshSyncFrameMergeReport":
                BASMeshSyncFrameMergeReport.currentSchemaVersion,
            // M807 (chapter 三百二〇) — Phase F (附录 X) 1st code cut:
            // typed CoreML prediction frame.
            "CoreMLPredictionFrame":
                BASCoreMLPredictionFrame.currentSchemaVersion,
            // M808 (chapter 三百二一) — Phase F (附录 X) 2nd code cut:
            // typed mesh registration report.
            "ChengluMeshRegistrationReport":
                BASChengluMeshRegistrationReport.currentSchemaVersion,
            "BASTurnOperationPayload":
                BASTurnOperationPayload.currentSchemaVersion,
            "BASBudgetLeasePayload":
                BASBudgetLeasePayload.currentSchemaVersion,
            "BASJoinArtifact":
                BASJoinArtifact.currentSchemaVersion,
            "BASRemandArtifact":
                BASRemandArtifact.currentSchemaVersion,
            "BASRefusalArtifact":
                BASRefusalArtifact.currentSchemaVersion,
            "BASControlLoopEnvelopePayload":
                BASControlLoopEnvelopePayload.currentSchemaVersion,
            "BASControlLoopProgressWitnessPayload":
                BASControlLoopProgressWitnessPayload.currentSchemaVersion,
            "BASControlLoopTerminalReceiptPayload":
                BASControlLoopTerminalReceiptPayload.currentSchemaVersion,
        ]

        #expect(actualVersions == expectedVersions)
    }

    @Test("governed schemas expose stable migration test IDs for rollback-sensitive objects")
    func rollbackSensitiveObjectsExposeMigrationTests() {
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ContextFrame")?.migrationTestIDs == ["schema.context.current", "schema.context.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostConstitution")?.migrationTestIDs == ["schema.host_constitution.current", "schema.host_constitution.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostVersionTree")?.migrationTestIDs == ["schema.host_version_tree.current", "schema.host_version_tree.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ForgetRequest")?.migrationTestIDs == ["schema.forget_request.current", "schema.forget_request.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostConstitutionVault")?.migrationTestIDs == ["schema.host_constitution_vault.current", "schema.host_constitution_vault.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "TemporalMemoryField")?.migrationTestIDs == ["schema.temporal_memory_field.current", "schema.temporal_memory_field.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "TemporalMemoryRecord")?.migrationTestIDs == ["schema.temporal_memory_record.current", "schema.temporal_memory_record.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryTemperatureProfile")?.migrationTestIDs == ["schema.memory_temperature_profile.current", "schema.memory_temperature_profile.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryProvenanceSeal")?.migrationTestIDs == ["schema.memory_provenance_seal.current", "schema.memory_provenance_seal.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryEpisodeArc")?.migrationTestIDs == ["schema.memory_episode_arc.current", "schema.memory_episode_arc.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryConflictCluster")?.migrationTestIDs == ["schema.memory_conflict_cluster.current", "schema.memory_conflict_cluster.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryContinuityAnchor")?.migrationTestIDs == ["schema.memory_continuity_anchor.current", "schema.memory_continuity_anchor.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryReplayFrame")?.migrationTestIDs == ["schema.memory_replay_frame.current", "schema.memory_replay_frame.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryQuarantineRecord")?.migrationTestIDs == ["schema.memory_quarantine_record.current", "schema.memory_quarantine_record.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemorySanctumEntry")?.migrationTestIDs == ["schema.memory_sanctum_entry.current", "schema.memory_sanctum_entry.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryForgetCascade")?.migrationTestIDs == ["schema.memory_forget_cascade.current", "schema.memory_forget_cascade.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "NeuralOrganMap")?.migrationTestIDs == ["schema.neural_organ_map.current", "schema.neural_organ_map.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "UncertaintyLedger")?.migrationTestIDs == ["schema.uncertainty_ledger.current", "schema.uncertainty_ledger.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "EvidenceDebt")?.migrationTestIDs == ["schema.evidence_debt.current", "schema.evidence_debt.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ConvergenceCertificate")?.migrationTestIDs == ["schema.convergence_certificate.current", "schema.convergence_certificate.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "LoopLeaseReceipt")?.migrationTestIDs == ["schema.loop_lease_receipt.current", "schema.loop_lease_receipt.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignBreakpointHint")?.migrationTestIDs == ["schema.sovereign_breakpoint_hint.current", "schema.sovereign_breakpoint_hint.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignWarrant")?.migrationTestIDs == ["schema.sovereign_warrant.current", "schema.sovereign_warrant.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "LungState")?.migrationTestIDs == ["schema.lung_state.current", "schema.lung_state.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RiskCard")?.migrationTestIDs == ["schema.risk.current", "schema.risk.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ActionPermit")?.migrationTestIDs == ["schema.permit.current", "schema.permit.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RiskField")?.migrationTestIDs == ["schema.risk_field.current", "schema.risk_field.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RiskDecisionPackage")?.migrationTestIDs == ["schema.risk_decision_package.current", "schema.risk_decision_package.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ExperienceCandidate")?.migrationTestIDs == ["schema.experience_candidate.current", "schema.experience_candidate.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ShadowTrialRecord")?.migrationTestIDs == ["schema.shadow_trial_record.current", "schema.shadow_trial_record.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "VersionDelta")?.migrationTestIDs == ["schema.version_delta.current", "schema.version_delta.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "WorkflowCandidate")?.migrationTestIDs == ["schema.workflow_candidate.current", "schema.workflow_candidate.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "GuardTemplateCandidate")?.migrationTestIDs == ["schema.guard_template_candidate.current", "schema.guard_template_candidate.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "BiasRecord")?.migrationTestIDs == ["schema.bias_record.current", "schema.bias_record.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RiskPatternCandidate")?.migrationTestIDs == ["schema.risk_pattern_candidate.current", "schema.risk_pattern_candidate.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RetractionOrder")?.migrationTestIDs == ["schema.retraction_order.current", "schema.retraction_order.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "LearningExportBundle")?.migrationTestIDs == ["schema.learning_export_bundle.current", "schema.learning_export_bundle.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "EvolutionSeal")?.migrationTestIDs == ["schema.evolution_seal.current", "schema.evolution_seal.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ThoughtFold")?.migrationTestIDs == ["schema.fold.current", "schema.fold.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "UpdateTicket")?.migrationTestIDs == ["schema.ticket.current", "schema.ticket.backward"])
    }

    @Test("context governance stays anchored on the current context frame contract")
    func contextGovernanceStaysAnchoredOnCurrentContextFrameContract() {
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ContextFrame")?.currentVersion == BASContextFrame.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ContextFrame")?.migrationTestIDs == ["schema.context.current", "schema.context.backward"])
    }
}
