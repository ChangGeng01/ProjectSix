import Foundation
import Testing
@testable import BASAdmin
@testable import BASAppleAdapters

@Suite("BASApple Console Snapshot Builder")
struct BASAppleConsoleSnapshotBuilderTests {
    @Test("console snapshot builder compiles runtime and brain summaries from apple flight deck input")
    func consoleSnapshotBuilderCompilesHostFacingSummary() {
        let compilation = BASAppleFlightDeckCompilation(
            generatedAt: Date(timeIntervalSince1970: 1_744_000_000),
            overallScore: 91,
            overallHealthID: "strong",
            layerReports: [
                BASAppleFlightDeckLayerReport(
                    layerID: "runtime",
                    score: 92,
                    healthID: "strong",
                    headline: "Runtime layer is stable.",
                    signals: ["ttft tracked"],
                    blockers: []
                ),
                BASAppleFlightDeckLayerReport(
                    layerID: "memory",
                    score: 84,
                    healthID: "watch",
                    headline: "Memory layer is governed.",
                    signals: ["hot warm cold tiers"],
                    blockers: ["Cold archive is not fully compacted."]
                )
            ],
            isPureLocalClosedLoop: true,
            dominantBlockers: ["Cold archive is not fully compacted."]
        )

        let snapshot = BASAppleConsoleSnapshotBuilder.build(
            from: BASAppleConsoleSnapshotSourceInput(
                generatedAt: compilation.generatedAt,
                flightDeckCompilation: compilation,
                activeProviderTitle: "Foundation Models",
                runtimeGearID: "balanced",
                totalRequests: 12,
                totalProviderAttempts: 14,
                roleName: "Stability Guide",
                boundaryModeID: "localOnlyAdvisory",
                calibrationStatusID: "stable",
                verificationSnapshot: "brain_fp"
            )
        )

        #expect(snapshot.isPureLocal)
        #expect(snapshot.runtimeSummary == "Route Foundation Models • gear balanced • requests 12 • attempts 14")
        #expect(snapshot.brainSummary == "Stability Guide • localOnlyAdvisory • stable • fingerprint brain_fp")
        #expect(snapshot.reports.first(where: { $0.kind == .runtime })?.summary == "Runtime layer is stable.")
        #expect(snapshot.reports.first(where: { $0.kind == .memory })?.blockers == ["Cold archive is not fully compacted."])
        #expect(snapshot.programExecutionBlueprint != nil)
        #expect(snapshot.currentProgramExecutionBlueprint.layers.count == 13)
        #expect(snapshot.currentProgramExecutionBlueprint.workPackages.count == 19)
    }
}
