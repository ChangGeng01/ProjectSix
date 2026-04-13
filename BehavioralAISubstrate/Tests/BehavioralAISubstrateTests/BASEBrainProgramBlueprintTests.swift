import Foundation
import Testing
@testable import BASAdmin
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy

@Suite("BASEBrain program blueprint")
struct BASEBrainProgramBlueprintTests {
    @Test("v1.2 program blueprint exposes thirteen layers, nineteen work packages, and governed schemas")
    func v12BlueprintCapturesExecutionPlan() {
        let blueprint = BASProgramExecutionBlueprintBuilder.v12

        #expect(blueprint.layers.count == 13)
        #expect(blueprint.workPackages.count == 19)
        #expect(blueprint.milestones.count == 8)
        #expect(blueprint.governedSchemas.count == 10)
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

        #expect(governedObjects == Set([
            "ContextFrame",
            "RiskCard",
            "ActionPermit",
            "HostProfile",
            "MemoryAtom",
            "MemoryBundle",
            "ThoughtFrame",
            "ThoughtFold",
            "UpdateTicket",
            "RuntimeTrace"
        ]))
        #expect(blueprint.governedSchemas.allSatisfy { !$0.currentVersion.isEmpty })
        #expect(blueprint.hardRedLines.contains("Host preferences must never bypass the risk gate."))
        #expect(blueprint.hardRedLines.contains("Production must not silently rewrite long-term host identity or rules."))
    }

    @Test("schema governance registry tracks live schema versions instead of hard-coded values")
    func schemaRegistryTracksLiveVersions() {
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ContextFrame")?.currentVersion == BASContextFrame.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RiskCard")?.currentVersion == BASRiskCard.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ActionPermit")?.currentVersion == BASActionPermit.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "HostProfile")?.currentVersion == BASHostProfile.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryAtom")?.currentVersion == BASMemoryAtom.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "MemoryBundle")?.currentVersion == BASMemoryBundle.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ThoughtFrame")?.currentVersion == BASThoughtFrame.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "ThoughtFold")?.currentVersion == BASThoughtFold.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "UpdateTicket")?.currentVersion == BASUpdateTicket.currentSchemaVersion)
        #expect(BASEBrainSchemaGovernanceRegistry.entry(for: "RuntimeTrace")?.currentVersion == BASRuntimeTrace.currentSchemaVersion)
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
