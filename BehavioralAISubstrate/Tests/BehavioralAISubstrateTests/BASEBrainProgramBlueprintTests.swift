import Foundation
import Testing
@testable import BASAdmin
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

@Suite("BASEBrain program blueprint")
struct BASEBrainProgramBlueprintTests {
    @Test("v1.2 program blueprint exposes thirteen layers, nineteen work packages, and governed schemas")
    func v12BlueprintCapturesExecutionPlan() {
        let blueprint = BASProgramExecutionBlueprintBuilder.v12

        #expect(blueprint.layers.count == 13)
        #expect(blueprint.workPackages.count == 19)
        #expect(blueprint.milestones.count == 8)
        #expect(blueprint.governedSchemas.count == BASEBrainSchemaGovernanceRegistry.governedSchemas.count)
        #expect(blueprint.requiredAppendices.count == 4)
        #expect(blueprint.hardRedLines.count == 10)
        #expect(blueprint.layers.first?.kind == .powerClock)
        #expect(blueprint.layers.last?.kind == .evolution)
    }

    @Test("first-batch work packages match the M1-M3 critical path")
    func firstBatchMatchesCriticalPath() {
        let blueprint = BASProgramExecutionBlueprintBuilder.v12
        let firstBatchIDs = Set(
            blueprint.workPackages
                .filter { $0.deliveryBatch == .first }
                .map(\.id)
        )

        #expect(firstBatchIDs == Set(["WP0", "WP1", "WP2", "WP5", "WP6", "WP7", "WP9", "WP11", "WP12"]))
        #expect(blueprint.workPackages.first(where: { $0.id == "WP11" })?.ownership.dri == "Risk Lead")
        #expect(blueprint.workPackages.first(where: { $0.id == "WP1" })?.schedule.milestoneIDs.contains("M1") == true)
        #expect(blueprint.workPackages.first(where: { $0.id == "WP9" })?.schedule.milestoneIDs.contains("M3") == true)
    }

    @Test("schema governance and red lines protect the main contracts")
    func governanceProtectsMainContracts() {
        let blueprint = BASProgramExecutionBlueprintBuilder.v12
        let governedObjects = Set(blueprint.governedSchemas.map(\.objectID))

        #expect(governedObjects.contains("DeviceState"))
        #expect(governedObjects.contains("BudgetFrame"))
        #expect(governedObjects.contains("HostVersion"))
        #expect(governedObjects.contains("RuleCandidate"))
        #expect(governedObjects.contains("DecomposeFrame"))
        #expect(governedObjects.contains("CandidatePath"))
        #expect(governedObjects.contains("TriSelfScore"))
        #expect(governedObjects.contains("MergedChoice"))
        #expect(governedObjects.contains("RenderedOutput"))
        #expect(governedObjects.contains("EvalSample"))
        #expect(governedObjects.contains("ModelArtifact"))
        #expect(governedObjects.contains("FeedbackEvent"))
        #expect(blueprint.governedSchemas.allSatisfy { !$0.currentVersion.isEmpty })
        #expect(blueprint.hardRedLines.contains("Host preferences must never bypass the risk gate."))
        #expect(blueprint.hardRedLines.contains("Production must not silently rewrite long-term host identity or rules."))
    }

    @Test("schema governance registry expands across control, knowledge, cognition, and eval planes")
    func schemaGovernanceRegistryCoversThirteenLayerPlan() {
        let governedObjects = Set(BASEBrainSchemaGovernanceRegistry.governedSchemas.map(\.objectID))

        #expect(BASEBrainSchemaGovernanceRegistry.governedSchemas.count == 25)
        #expect(governedObjects == Set([
            "DeviceState",
            "BudgetFrame",
            "HostProfile",
            "HostVersion",
            "MemoryAtom",
            "MemoryBundle",
            "RuleCandidate",
            "ContextFrame",
            "DecomposeFrame",
            "CandidatePath",
            "ForecastItem",
            "CritiqueItem",
            "ThoughtFrame",
            "ThoughtFold",
            "TriSelfScore",
            "MergedChoice",
            "RenderedOutput",
            "RiskCard",
            "ActionPermit",
            "UpdateTicket",
            "EvolutionLineageSummary",
            "RuntimeTrace",
            "EvalSample",
            "ModelArtifact",
            "FeedbackEvent"
        ]))
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "DeviceState")?.currentVersion == BASDeviceState.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "BudgetFrame")?.currentVersion == BASBudgetFrame.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostVersion")?.currentVersion == BASHostVersion.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RuleCandidate")?.currentVersion == BASRuleCandidate.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "DecomposeFrame")?.currentVersion == BASDecomposeFrame.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "CandidatePath")?.currentVersion == BASCandidatePath.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ForecastItem")?.currentVersion == BASForecastItem.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "CritiqueItem")?.currentVersion == BASCritiqueItem.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "TriSelfScore")?.currentVersion == BASTriSelfScore.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MergedChoice")?.currentVersion == BASMergedChoice.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RenderedOutput")?.currentVersion == BASRenderedOutput.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "EvolutionLineageSummary")?.currentVersion == BASEvolutionLineageSummary.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "EvalSample")?.currentVersion == BASEvalSample.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ModelArtifact")?.currentVersion == BASModelArtifact.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "FeedbackEvent")?.currentVersion == BASFeedbackEvent.currentSchemaVersion)
    }

    @Test("console snapshots resolve the v1.2 execution blueprint by default")
    func consoleSnapshotsCarryExecutionBlueprint() {
        let snapshot = BASFlightDeckBuilder().build(
            from: BASFlightDeckInput(
                overallSummary: "Execution blueprint is attached to console output.",
                layerMetrics: BASLayerKind.allCases.map {
                    BASFlightDeckLayerMetric(kind: $0, score: 1.0, summary: "\($0.title) ready")
                }
            )
        )

        #expect(snapshot.programExecutionBlueprint != nil)
        #expect(snapshot.currentProgramExecutionBlueprint.title == BASProgramExecutionBlueprintBuilder.v12.title)
        #expect(snapshot.currentProgramExecutionBlueprint.workPackages.count == 19)
        #expect(snapshot.currentProgramExecutionBlueprint.milestones.map(\.id) == ["M0", "M1", "M2", "M3", "M4", "M5", "M6", "M7"])
    }
}
