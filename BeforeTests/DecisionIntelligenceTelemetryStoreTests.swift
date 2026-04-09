import XCTest
@testable import Before

final class DecisionIntelligenceTelemetryStoreTests: XCTestCase {
    func testSnapshotTracksFallbacksAndGemmaBackends() async {
        let store = DecisionIntelligenceTelemetryStore()
        let quickStrategy = DecisionAdaptiveTaskStrategy(
            kind: .quick,
            entropy: .low,
            runtimeGear: .balanced,
            preferredProvider: .gemmaE4B,
            contextBudget: 220,
            timeBudgetMs: 200,
            retrievalMode: .off,
            thinkingMode: .off,
            outputMode: .guidedShort,
            tone: .briefWarm,
            actionSpace: ["encourage", "next_step"],
            allowsModelInvocation: true
        )
        let mirrorStrategy = DecisionAdaptiveTaskStrategy(
            kind: .mirror,
            entropy: .high,
            runtimeGear: .balanced,
            preferredProvider: .gemmaE4B,
            contextBudget: 320,
            timeBudgetMs: 900,
            retrievalMode: .filtered,
            thinkingMode: .gated,
            outputMode: .reflectiveStructured,
            tone: .reflectiveClear,
            actionSpace: ["clarify", "surface_pattern"],
            allowsModelInvocation: true
        )

        await store.record(
            kind: .quick,
            outcome: .providerSuccess,
            activeProvider: .gemmaE4B,
            attemptedProviders: [.gemmaE4B],
            usedFallback: false,
            durationMs: 120,
            runtimeStrategy: quickStrategy,
            admissionDecision: DecisionIntelligenceAdmissionDecision(
                isAllowed: true,
                pressure: .low,
                reason: "Allowed for testing.",
                skipReason: nil
            ),
            gemmaBackendResolution: InferenceBackendResolver.resolve(
                policy: .coreMLPreferred,
                device: DeviceCapabilitySnapshot(
                    isSimulator: false,
                    supportsMetal: true,
                    supportsCoreMLAcceleration: true
                )
            )
        )
        await store.record(
            kind: .mirror,
            outcome: .deterministicFallback,
            activeProvider: nil,
            attemptedProviders: [.foundationModels, .gemmaE4B],
            usedFallback: false,
            durationMs: 2_400,
            runtimeStrategy: mirrorStrategy
        )

        let snapshot = await store.snapshot()

        XCTAssertEqual(snapshot.totalRequests, 2)
        XCTAssertEqual(snapshot.outcomeCount[.providerSuccess], 1)
        XCTAssertEqual(snapshot.outcomeCount[.deterministicFallback], 1)
        XCTAssertEqual(snapshot.activeProviderCount[.gemmaE4B], 1)
        XCTAssertEqual(snapshot.attemptedProviderCount[.foundationModels], 1)
        XCTAssertEqual(snapshot.gemmaBackendCount[.coreML], 1)
        XCTAssertEqual(snapshot.deterministicFallbackRate, 0.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.providerBypassRate, 0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.lowPressureModelCallRate, 0.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.lowPressureModelCallRateByKind[.quick] ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(snapshot.averageRequestDurationMs, 1_260, accuracy: 0.0001)
        XCTAssertEqual(snapshot.averageRequestDurationMsByKind[.quick] ?? 0, 120, accuracy: 0.0001)
        XCTAssertEqual(snapshot.averageRequestDurationMsByGemmaBackend[.coreML] ?? 0, 120, accuracy: 0.0001)
        XCTAssertEqual(snapshot.slowRequestRate, 0.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.slowRequestRateByKind[.mirror] ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(snapshot.overTimeBudgetRate, 0.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.overTimeBudgetRateByKind[.mirror] ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(snapshot.avoidableModelCallRate, 0, accuracy: 0.0001)
    }

    func testSnapshotTracksAvoidableModelCallSkips() async {
        let store = DecisionIntelligenceTelemetryStore()

        await store.record(
            kind: .quick,
            outcome: .admissionSkipped,
            activeProvider: nil,
            attemptedProviders: [],
            usedFallback: false,
            durationMs: 12,
            admissionDecision: DecisionIntelligenceAdmissionDecision(
                isAllowed: false,
                pressure: .low,
                reason: "Template already covers this turn.",
                skipReason: .templateAlreadySufficient
            )
        )
        await store.record(
            kind: .balance,
            outcome: .providerSuccess,
            activeProvider: .gemmaE4B,
            attemptedProviders: [.gemmaE4B],
            usedFallback: false,
            durationMs: 220,
            admissionDecision: DecisionIntelligenceAdmissionDecision(
                isAllowed: true,
                pressure: .elevated,
                reason: "Allowed for testing.",
                skipReason: nil
            )
        )

        let snapshot = await store.snapshot()

        XCTAssertEqual(snapshot.avoidableModelCallRate, 0.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.avoidableModelCallRateByKind[.quick] ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(snapshot.avoidableModelCallRateByKind[.balance] ?? 0, 0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.admissionSkipCountByReasonAndKind[.templateAlreadySufficient]?[.quick], 1)
    }

    func testSnapshotTracksReminderKnowledgeAndControlNeed() async {
        let store = DecisionIntelligenceTelemetryStore()

        await store.record(
            kind: .reminder,
            outcome: .admissionSkipped,
            activeProvider: nil,
            attemptedProviders: [],
            usedFallback: false,
            durationMs: 18,
            admissionDecision: DecisionIntelligenceAdmissionDecision(
                isAllowed: false,
                pressure: .low,
                reason: "Deterministic leader is already clear.",
                skipReason: .retrievalNotNeeded,
                reminderSelectionNeed: .control
            )
        )
        await store.record(
            kind: .reminder,
            outcome: .providerSuccess,
            activeProvider: .gemmaE4B,
            attemptedProviders: [.gemmaE4B],
            usedFallback: false,
            durationMs: 130,
            admissionDecision: DecisionIntelligenceAdmissionDecision(
                isAllowed: true,
                pressure: .elevated,
                reason: "Prompt creates real candidate conflict.",
                skipReason: nil,
                reminderSelectionNeed: .knowledge
            )
        )

        let snapshot = await store.snapshot()

        XCTAssertEqual(snapshot.reminderSelectionNeedCount[.control], 1)
        XCTAssertEqual(snapshot.reminderSelectionNeedCount[.knowledge], 1)
        XCTAssertEqual(snapshot.reminderKnowledgeNeedRate, 0.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.reminderControlOnlyRate, 0.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.reminderRetrievalBypassRate, 0.5, accuracy: 0.0001)
    }
}
