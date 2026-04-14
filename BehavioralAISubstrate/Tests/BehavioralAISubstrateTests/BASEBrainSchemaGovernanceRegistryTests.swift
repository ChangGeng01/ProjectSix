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

        #expect(governedObjects.count == 25)
        #expect(Set(governedObjects).count == governedObjects.count)
        #expect(governedObjects.contains("DeviceState"))
        #expect(governedObjects.contains("BudgetFrame"))
        #expect(governedObjects.contains("HostProfile"))
        #expect(governedObjects.contains("RiskCard"))
        #expect(governedObjects.contains("ActionPermit"))
        #expect(governedObjects.contains("UpdateTicket"))
        #expect(governedObjects.contains("EvolutionLineageSummary"))
        #expect(governedObjects.contains("RuntimeTrace"))
        #expect(governedObjects.contains("EvalSample"))
        #expect(governedObjects.contains("ModelArtifact"))
        #expect(governedObjects.contains("FeedbackEvent"))
    }

    @Test("representative governed schemas stay aligned with concrete versioned types")
    func representativeSchemasStayAlignedWithConcreteTypes() {
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryBundle")?.currentVersion == BASMemoryBundle.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostProfile")?.currentVersion == BASHostProfile.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ThoughtFold")?.currentVersion == BASThoughtFold.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RiskCard")?.currentVersion == BASRiskCard.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ActionPermit")?.currentVersion == BASActionPermit.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "UpdateTicket")?.currentVersion == BASUpdateTicket.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RuntimeTrace")?.currentVersion == BASRuntimeTrace.currentSchemaVersion)
    }

    @Test("all governed schemas stay aligned with concrete versioned types")
    func allGovernedSchemasStayAlignedWithConcreteTypes() {
        let actualVersions = Dictionary(uniqueKeysWithValues: BASEBrainSchemaGovernanceRegistry.governedSchemas.map { ($0.objectID, $0.currentVersion) })
        let expectedVersions: [String: String] = [
            "DeviceState": BASDeviceState.currentSchemaVersion,
            "BudgetFrame": BASBudgetFrame.currentSchemaVersion,
            "HostProfile": BASHostProfile.currentSchemaVersion,
            "HostVersion": BASHostVersion.currentSchemaVersion,
            "MemoryAtom": BASMemoryAtom.currentSchemaVersion,
            "MemoryBundle": BASMemoryBundle.currentSchemaVersion,
            "RuleCandidate": BASRuleCandidate.currentSchemaVersion,
            "ContextFrame": BASContextFrame.currentSchemaVersion,
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
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RiskCard")?.migrationTestIDs == ["schema.risk.current", "schema.risk.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ActionPermit")?.migrationTestIDs == ["schema.permit.current", "schema.permit.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ThoughtFold")?.migrationTestIDs == ["schema.fold.current", "schema.fold.backward"])
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "UpdateTicket")?.migrationTestIDs == ["schema.ticket.current", "schema.ticket.backward"])
    }
}
