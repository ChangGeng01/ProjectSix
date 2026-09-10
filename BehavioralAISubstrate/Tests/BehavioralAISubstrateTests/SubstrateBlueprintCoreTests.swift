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

    @Test("blueprint evidence uses cleaned runtime summary instead of embedded layer stack copy")
    func blueprintUsesDisplayRuntimeSummaryForEvidence() {
        let snapshot = BASConsoleSnapshot(
            overallSummary: "substrate ready",
            runtimeSummary: "Route Foundation Models • gear balanced • requests 12 • attempts 14 • L1 power clock • mode GUARDED • route guarded • loops 2 • candidates 2 • decode 160 | L2 neural core • route guarded • battery 66% • thermal warm • cpu 31% • npu on | L3 compression runtime • fold checksum-1 • slots 2 • restore restore-1 | L4 foundation • task conflict • goals 1 • pressure 1 • ambiguity 63% | L5 host profile • host host.primary • goals 1 • no-go 1 • gate 37% | L6 context • task conflict • pressure 3/1400ms | L7-L9 cognition • contradictions 1 • candidates 2 | L10-L12 adjudication • tri-self veto host_write | L13 evolution • review parser rollback",
            reports: BASLayerKind.allCases.map { kind in
                BASLayerReport(
                    kind: kind,
                    health: .healthy,
                    score: 0.9,
                    summary: "\(kind.title) healthy"
                )
            }
        )

        let blueprint = snapshot.architectureBlueprint
        let executionEvidence = blueprint.stackLayers.first(where: { $0.kind == .execution })?.evidence ?? []
        let systemEvidence = blueprint.stackLayers.first(where: { $0.kind == .system })?.evidence ?? []

        #expect(executionEvidence.contains("Route Foundation Models • gear balanced • requests 12 • attempts 14"))
        #expect(systemEvidence.contains("Route Foundation Models • gear balanced • requests 12 • attempts 14"))
        #expect(!executionEvidence.contains(where: { $0.contains("L1 power clock") }))
        #expect(!executionEvidence.contains(where: { $0.contains("L6 context") }))
        #expect(!systemEvidence.contains(where: { $0.contains("L13 evolution") }))
    }
}
