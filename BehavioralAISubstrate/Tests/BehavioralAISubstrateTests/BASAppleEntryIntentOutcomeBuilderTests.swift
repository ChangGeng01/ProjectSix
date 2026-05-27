import Foundation
import Testing
@testable import BASAppleAdapters

#if !os(iOS)  // ch 1022 source-gate: SwiftTesting iOS bundle discovery quirk
@Suite("BASApple Entry Intent Outcome Builder")
struct BASAppleEntryIntentOutcomeBuilderTests {
    @Test("predictive intervention resolution synthesizes a suggestion and refresh trigger")
    func predictiveInterventionResolutionBuildsSuggestion() {
        let expiresAt = Date(timeIntervalSince1970: 200)
        let resolution = BASAppleEntryIntentOutcomeBuilder.resolve(
            kindID: "predictiveIntervention",
            surfaceID: "watch",
            preferredModeID: "reflective",
            scenarioID: nil,
            promptSeed: nil,
            riskLevelID: "high",
            triggerReason: "night_pattern",
            expiresAt: expiresAt
        )

        #expect(resolution.actionPlan.actionKind == .predictiveIntervention)
        #expect(resolution.refreshTriggerID == BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue)
        #expect(resolution.predictiveIntervention?.riskLevelID == "high")
        #expect(resolution.predictiveIntervention?.title == "A lower-pressure next step may help here.")
        #expect(resolution.predictiveIntervention?.evidenceSignalCount == 2)
        #expect(resolution.predictiveIntervention?.reason == "night_pattern")
        #expect(resolution.predictiveIntervention?.expiresAt == expiresAt)
    }

    @Test("non-predictive resolutions keep action plan without synthesizing a suggestion")
    func nonPredictiveResolutionDoesNotCreateSuggestion() {
        let resolution = BASAppleEntryIntentOutcomeBuilder.resolve(
            kindID: "capture",
            surfaceID: "watch",
            preferredModeID: "primary",
            scenarioID: "buy",
            promptSeed: "Hold this.",
            riskLevelID: "medium",
            triggerReason: nil,
            expiresAt: .distantFuture
        )

        #expect(resolution.actionPlan.actionKind == .capture)
        #expect(resolution.refreshTriggerID == BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue)
        #expect(resolution.predictiveIntervention == nil)
    }

    @Test("entry intent executor runs the matching action then refreshes current brain")
    func entryIntentExecutorRunsMatchingActionThenRefreshesCurrentBrain() {
        var calls: [String] = []
        let resolution = BASAppleEntryIntentOutcomeBuilder.resolve(
            kindID: "reopen",
            surfaceID: "app",
            preferredModeID: "comparative",
            scenarioID: nil,
            promptSeed: "reopen this",
            riskLevelID: "medium",
            triggerReason: nil,
            expiresAt: .distantFuture
        )

        BASAppleEntryIntentOutcomeExecutor.execute(
            resolution: resolution,
            performCapture: { _ in calls.append("primary") },
            performPresent: { plan in
                calls.append("open:\(plan.preferredModeID ?? "nil"):\(plan.shouldSelectBoxTab)")
            },
            performRoutedInput: { plan in
                calls.append("route:\(plan.promptSeed)")
            },
            performPredictiveIntervention: { suggestion in
                calls.append("predict:\(suggestion?.title ?? "nil")")
            },
            performRestore: {
                calls.append("restore")
            },
            refreshCurrentBrain: { triggerID in
                calls.append("refresh:\(triggerID)")
            }
        )

        #expect(calls == [
            "open:comparative:true",
            "refresh:explicitRefresh"
        ])
    }

    @Test("entry intent runtime executor resolves and executes in one package-owned step")
    func entryIntentRuntimeExecutorResolvesAndExecutes() {
        var calls: [String] = []

        BASAppleEntryIntentRuntimeExecutor.execute(
            input: BASAppleEntryIntentRuntimeInput(
                kindID: "predictiveIntervention",
                surfaceID: "watch",
                preferredModeID: "reflective",
                scenarioID: nil,
                promptSeed: "Pause.",
                riskLevelID: "high",
                triggerReason: "night_pattern",
                expiresAt: Date(timeIntervalSince1970: 200)
            ),
            performCapture: { _ in
                calls.append("primary")
            },
            performPresent: { _ in
                calls.append("open")
            },
            performRoutedInput: { _ in
                calls.append("route")
            },
            performPredictiveIntervention: { suggestion in
                calls.append("predict:\(suggestion?.preferredModeID ?? "nil")")
            },
            performRestore: {
                calls.append("restore")
            },
            refreshCurrentBrain: { triggerID in
                calls.append("refresh:\(triggerID)")
            }
        )

        #expect(calls == [
            "predict:reflective",
            "refresh:watchHandoff"
        ])
    }

    @Test("entry intent runtime executor routes shared routed-input intents then refreshes current brain")
    func entryIntentRuntimeExecutorRoutesSharedRoutedInput() {
        var calls: [String] = []

        BASAppleEntryIntentRuntimeExecutor.execute(
            input: BASAppleEntryIntentRuntimeInput(
                kindID: "routedInput",
                surfaceID: "app",
                preferredModeID: nil,
                scenarioID: nil,
                promptSeed: "Route this shared prompt.",
                riskLevelID: nil,
                triggerReason: nil,
                expiresAt: .distantFuture
            ),
            performCapture: { _ in
                calls.append("capture")
            },
            performPresent: { _ in
                calls.append("present")
            },
            performRoutedInput: { plan in
                calls.append("route:\(plan.promptSeed)")
            },
            performPredictiveIntervention: { _ in
                calls.append("predict")
            },
            performRestore: {
                calls.append("restore")
            },
            refreshCurrentBrain: { triggerID in
                calls.append("refresh:\(triggerID)")
            }
        )

        #expect(calls == [
            "route:Route this shared prompt.",
            "refresh:explicitRefresh"
        ])
    }
}
#endif
