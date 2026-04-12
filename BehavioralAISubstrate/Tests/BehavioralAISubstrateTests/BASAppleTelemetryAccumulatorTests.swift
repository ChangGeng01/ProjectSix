import Testing
@testable import BASAppleAdapters
@testable import BASObservability
@testable import BASOrchestration

@Suite("BASApple Telemetry Accumulator")
struct BASAppleTelemetryAccumulatorTests {
    @Test("accumulator records compiled telemetry and produces summary snapshots")
    func accumulatorBuildsSnapshotAndSummary() async {
        let accumulator = BASAppleTelemetryAccumulator(
            config: BASAppleTelemetryAccumulatorConfig(
                selectionKindRawValue: "selection",
                selectionKnowledgeNeedRawValue: "knowledge",
                selectionControlNeedRawValue: "control",
                selectionRetrievalBypassReasonRawValues: ["insufficientChoiceSpread", "retrievalNotNeeded"],
                avoidableSkipReasonRawValues: ["templateAlreadySufficient", "insufficientSourceMaterial"]
            )
        )

        await accumulator.record(
            from: BASAppleTelemetryRecordInput(
                kind: "primary",
                outcome: .providerSuccess,
                activeProviderID: "gemmaE4B",
                attemptedProviderIDs: ["gemmaE4B"],
                usedFallback: false,
                durationMs: 180,
                lifecycleMetrics: BASRequestLifecycleMetrics(
                    promptAssemblyMs: 25,
                    admissionEvaluationMs: 10,
                    providerSelectionMs: 15,
                    firstPresentableMs: 90,
                    executionMs: 40
                ),
                promptBudget: BASPromptBudget(
                    targetCharacters: 260,
                    prefixCharacters: 90,
                    suffixCharacters: 70
                ),
                runtimeTimeBudgetMs: 600,
                admissionPressureID: "low",
                activeBackendID: "coreML"
            )
        )
        await accumulator.record(
            from: BASAppleTelemetryRecordInput(
                kind: "selection",
                outcome: .admissionSkipped,
                activeProviderID: nil,
                attemptedProviderIDs: [],
                usedFallback: false,
                durationMs: 40,
                runtimeTimeBudgetMs: 600,
                admissionPressureID: "low",
                admissionSkipReasonID: "retrievalNotNeeded",
                selectionNeedID: "control"
            )
        )

        let snapshot = await accumulator.snapshot()

        #expect(snapshot.requestCountByKind["primary"] == 1)
        #expect(snapshot.requestCountByKind["selection"] == 1)
        #expect(snapshot.outcomeCount[.providerSuccess] == 1)
        #expect(snapshot.outcomeCount[.admissionSkipped] == 1)
        #expect(snapshot.activeProviderCount["gemmaE4B"] == 1)
        #expect(snapshot.backendCount["coreML"] == 1)
        #expect(snapshot.promptPressureCount["low"] == 2)
        #expect(snapshot.selectionNeedCount["control"] == 1)
        #expect(snapshot.admissionSkipCountByReason["retrievalNotNeeded"] == 1)
        #expect(snapshot.summary.totalRequests == 2)
        #expect(snapshot.summary.lowPressureModelCallRate == 0.5)
        #expect(snapshot.summary.selectionControlOnlyRate == 1.0)
        #expect(snapshot.summary.averageFirstPresentableMs == 45)
    }

    @Test("accumulator clear drops all raw counters and summary totals")
    func accumulatorClearResetsState() async {
        let accumulator = BASAppleTelemetryAccumulator(
            config: BASAppleTelemetryAccumulatorConfig(
                selectionKindRawValue: "selection",
                selectionKnowledgeNeedRawValue: "knowledge",
                selectionControlNeedRawValue: "control",
                selectionRetrievalBypassReasonRawValues: ["insufficientChoiceSpread", "retrievalNotNeeded"],
                avoidableSkipReasonRawValues: ["templateAlreadySufficient", "insufficientSourceMaterial"]
            )
        )

        await accumulator.record(
            from: BASAppleTelemetryRecordInput(
                kind: "reflective",
                outcome: .deterministicFallback,
                activeProviderID: nil,
                attemptedProviderIDs: ["foundationModels"],
                usedFallback: false,
                durationMs: 1_700,
                runtimeTimeBudgetMs: 800
            )
        )

        await accumulator.clear()
        let snapshot = await accumulator.snapshot()

        #expect(snapshot.requestCountByKind.isEmpty)
        #expect(snapshot.outcomeCount.isEmpty)
        #expect(snapshot.summary.totalRequests == 0)
        #expect(snapshot.summary.slowRequestRate == 0)
    }
}
