import Foundation
import Testing
@testable import BASAdmin

@Suite("BASSubstrateArchitectureBlueprint")
struct SubstrateBlueprintCoreTests {
    @Test("blueprint derives five stack layers, two cross-cutting systems, and core loops")
    func blueprintDerivesArchitectureFromConsoleSnapshot() {
        let snapshot = BASConsoleSnapshotBuilder.build(
            from: BASFlightDeckMetrics(
                generatedAt: Date(timeIntervalSince1970: 1_700_000_123),
                layerInputs: [
                    BASLayerAssessmentInput(layer: .runtime, score: 91, summary: "Runtime stable"),
                    BASLayerAssessmentInput(layer: .data, score: 83, summary: "Typed event ledger live"),
                    BASLayerAssessmentInput(layer: .memory, score: 88, summary: "Governed memory tiers live"),
                    BASLayerAssessmentInput(layer: .security, score: 79, summary: "Protected recall fences active"),
                    BASLayerAssessmentInput(layer: .orchestration, score: 84, summary: "Workflow graphs and checkpoints live"),
                    BASLayerAssessmentInput(layer: .observability, score: 82, summary: "Trace and replay live"),
                    BASLayerAssessmentInput(layer: .evaluation, score: 77, summary: "Regression gates live"),
                    BASLayerAssessmentInput(layer: .delivery, score: 72, summary: "Host shell still carries some seams", blockers: ["Host still owns some substrate glue"])
                ],
                runtimeSummary: "Local route with bounded budgets",
                brainSummary: "Thin host, thick substrate",
                isPureLocal: true,
                capabilityCoverage: BASCapabilityCoverageBuilder.build(
                    sections: [
                        BASCapabilitySection(
                            domain: .context,
                            items: [
                                BASCapabilityItem(
                                    id: "context.compactor",
                                    title: "Context compactor",
                                    summary: "Keep stable kernel and active state before retrieval overflow.",
                                    status: .ready
                                ),
                                BASCapabilityItem(
                                    id: "context.harness",
                                    title: "Consistency harness",
                                    summary: "Verify truth-state and action drift before release.",
                                    status: .partial
                                )
                            ]
                        ),
                        BASCapabilitySection(
                            domain: .runtime,
                            items: [
                                BASCapabilityItem(
                                    id: "runtime.local_first",
                                    title: "Local-first runtime",
                                    summary: "Prefer local execution and expose hybrid seams.",
                                    status: .ready
                                )
                            ]
                        )
                    ]
                )
            )
        )

        let blueprint = snapshot.architectureBlueprint

        #expect(blueprint.headline == "Behavioral AI Substrate")
        #expect(blueprint.stackLayers.count == 5)
        #expect(blueprint.crossCuttingSystems.count == 2)
        #expect(blueprint.controlLoops.count == 3)
        #expect(blueprint.truthPlanes.count == 4)
        #expect(blueprint.executionLanes.count == 2)
        #expect(blueprint.stackLayers.first(where: { $0.kind == .cognitiveCore })?.summary.contains("context discipline") == true)
        #expect(blueprint.priorityGaps.contains(where: { $0.contains("Host still owns some substrate glue") }))
        #expect(blueprint.innovationThesis.contains(where: { $0.contains("compact context") }))
    }
}
