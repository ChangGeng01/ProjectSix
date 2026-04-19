import Testing
@testable import BASAdmin
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

@Suite("BASEBrain schema governance registry")
struct BASEBrainSchemaGovernanceRegistryTests {
    @Test("unknown schema objects stay ungoverned until registered explicitly")
    func unknownSchemaObjectsReturnNil() {
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "UnknownObject") == nil)
    }

    @Test("every governed schema carries compatibility, migration, and rollback metadata")
    func governedEntriesCarryRequiredMetadata() {
        for entry in BASEBrainSchemaGovernanceRegistry.governedSchemas {
            #expect(!entry.currentVersion.isEmpty)
            #expect(entry.compatibilityWindow == "2 minor versions")
            #expect(entry.deprecationPolicy == "Mark deprecated for one milestone before removal.")
            #expect(entry.rollbackPolicy == "Rehydrate the previous schema snapshot and preserve replay fidelity.")
            #expect(entry.migrationTestIDs.count == 2)
            #expect(entry.migrationTestIDs.allSatisfy { $0.hasPrefix("schema.") })
        }
    }

    @Test("governed schema registry stays uniquely keyed and fully populated")
    func governedRegistryStaysUniquelyKeyedAndComplete() {
        let governedObjects = BASEBrainSchemaGovernanceRegistry.governedSchemas.map(\.objectID)

        #expect(governedObjects.count == 84)
        #expect(Set(governedObjects).count == governedObjects.count)
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
        #expect(governedObjects.contains("NeuralOrganMap"))
        #expect(governedObjects.contains("CandidateFrontier"))
        #expect(governedObjects.contains("CounterfactualBundle"))
        #expect(governedObjects.contains("CritiqueBundle"))
        #expect(governedObjects.contains("RiskPermitBinding"))
        #expect(governedObjects.contains("ToolIntentEnvelope"))
        #expect(governedObjects.contains("NeuralLeaseReceipt"))
        #expect(governedObjects.contains("MorphGraph"))
        #expect(governedObjects.contains("HotColdMap"))
        #expect(governedObjects.contains("PrecisionProfile"))
        #expect(governedObjects.contains("ResumeFrame"))
        #expect(governedObjects.contains("RollbackAnchor"))
        #expect(governedObjects.contains("LungState"))
        #expect(governedObjects.contains("BreathScheduler"))
        #expect(governedObjects.contains("RiskCard"))
        #expect(governedObjects.contains("ActionPermit"))
        #expect(governedObjects.contains("UpdateTicket"))
        #expect(governedObjects.contains("EvolutionLineageSummary"))
        #expect(governedObjects.contains("RuntimeTrace"))
        #expect(governedObjects.contains("EvalSample"))
        #expect(governedObjects.contains("ModelArtifact"))
        #expect(governedObjects.contains("FeedbackEvent"))
        #expect(governedObjects.contains("SovereignVerdict"))
        #expect(governedObjects.contains("SovereignCommitToken"))
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
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "NeuralOrganMap")?.currentVersion == BASNeuralOrganMap.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HotColdMap")?.currentVersion == BASHotColdMap.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "LungState")?.currentVersion == BASLungState.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "BreathScheduler")?.currentVersion == BASBreathSchedulerFrame.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ThoughtFold")?.currentVersion == BASThoughtFold.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ToolIntentEnvelope")?.currentVersion == BASToolIntentEnvelope.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RiskCard")?.currentVersion == BASRiskCard.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ActionPermit")?.currentVersion == BASActionPermit.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "UpdateTicket")?.currentVersion == BASUpdateTicket.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignVerdict")?.currentVersion == BASSovereignVerdict.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignCommitToken")?.currentVersion == BASSovereignCommitToken.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignLock")?.currentVersion == BASSovereignLock.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "QuarantineRecord")?.currentVersion == BASQuarantineRecord.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "SovereignAuditEntry")?.currentVersion == BASSovereignAuditEntry.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RuntimeTrace")?.currentVersion == BASRuntimeTrace.currentSchemaVersion)
    }

    @Test("all governed schemas stay aligned with concrete versioned types")
    func allGovernedSchemasStayAlignedWithConcreteTypes() {
        let actualVersions = Dictionary(uniqueKeysWithValues: BASEBrainSchemaGovernanceRegistry.governedSchemas.map { ($0.objectID, $0.currentVersion) })
        let expectedVersions: [String: String] = [
            "DeviceState": BASDeviceState.currentSchemaVersion,
            "BudgetFrame": BASBudgetFrame.currentSchemaVersion,
            "WakeIntent": BASWakeIntent.currentSchemaVersion,
            "VitalState": BASVitalState.currentSchemaVersion,
            "RunLease": BASRunLease.currentSchemaVersion,
            "EmergencyBrake": BASEmergencyBrake.currentSchemaVersion,
            "SovereignActuationCommand": BASSovereignActuationCommand.currentSchemaVersion,
            "SovereignExecutionReceipt": BASSovereignExecutionReceipt.currentSchemaVersion,
            "SovereignVerdict": BASSovereignVerdict.currentSchemaVersion,
            "SovereignCommitToken": BASSovereignCommitToken.currentSchemaVersion,
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
            "MemoryAtom": BASMemoryAtom.currentSchemaVersion,
            "MemoryBundle": BASMemoryBundle.currentSchemaVersion,
            "NeuralOrganMap": BASNeuralOrganMap.currentSchemaVersion,
            "CandidateFrontier": BASCandidateFrontier.currentSchemaVersion,
            "CounterfactualBundle": BASCounterfactualBundle.currentSchemaVersion,
            "CritiqueBundle": BASCritiqueBundle.currentSchemaVersion,
            "RiskPermitBinding": BASRiskPermitBinding.currentSchemaVersion,
            "ToolIntentEnvelope": BASToolIntentEnvelope.currentSchemaVersion,
            "NeuralLeaseReceipt": BASNeuralLeaseReceipt.currentSchemaVersion,
            "MorphGraph": BASMorphGraph.currentSchemaVersion,
            "HotColdMap": BASHotColdMap.currentSchemaVersion,
            "PrecisionProfile": BASPrecisionProfile.currentSchemaVersion,
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
            "UpdateTicket": BASUpdateTicket.currentSchemaVersion,
            "EvolutionLineageSummary": BASEvolutionLineageSummary.currentSchemaVersion,
            "EvolutionFoldedLungSummary": BASEvolutionFoldedLungSummary.currentSchemaVersion,
            "RuntimeTrace": BASRuntimeTrace.currentSchemaVersion,
            "EvalSample": BASEvalSample.currentSchemaVersion,
            "ModelArtifact": BASModelArtifact.currentSchemaVersion,
            "FeedbackEvent": BASFeedbackEvent.currentSchemaVersion
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
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "NeuralOrganMap")?.migrationTestIDs == ["schema.neural_organ_map.current", "schema.neural_organ_map.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "LungState")?.migrationTestIDs == ["schema.lung_state.current", "schema.lung_state.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RiskCard")?.migrationTestIDs == ["schema.risk.current", "schema.risk.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ActionPermit")?.migrationTestIDs == ["schema.permit.current", "schema.permit.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ThoughtFold")?.migrationTestIDs == ["schema.fold.current", "schema.fold.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "UpdateTicket")?.migrationTestIDs == ["schema.ticket.current", "schema.ticket.backward"])
    }

    @Test("context governance stays anchored on the current context frame contract")
    func contextGovernanceStaysAnchoredOnCurrentContextFrameContract() {
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ContextFrame")?.currentVersion == BASContextFrame.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ContextFrame")?.migrationTestIDs == ["schema.context.current", "schema.context.backward"])
    }
}
