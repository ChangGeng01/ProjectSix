import Foundation
import Testing
@testable import BASAppleAdapters

@Suite("BASApple Entry Intent Outcome Builder")
struct BASAppleEntryIntentOutcomeBuilderTests {
    @Test("predictive intervention resolution synthesizes a suggestion and refresh trigger")
    func predictiveInterventionResolutionBuildsSuggestion() {
        let expiresAt = Date(timeIntervalSince1970: 200)
        let resolution = BASAppleEntryIntentOutcomeBuilder.resolve(
            kindID: "predictiveIntervention",
            surfaceID: "watch",
            preferredModeID: "mirror",
            scenarioID: nil,
            promptSeed: nil,
            riskLevelID: "high",
            triggerReason: "night_pattern",
            expiresAt: expiresAt
        )

        #expect(resolution.actionPlan.actionKind == .predictiveIntervention)
        #expect(resolution.refreshTriggerID == BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue)
        #expect(resolution.predictiveIntervention?.riskLevelID == "high")
        #expect(resolution.predictiveIntervention?.title == "Pause before you decide.")
        #expect(resolution.predictiveIntervention?.evidenceSignalCount == 2)
        #expect(resolution.predictiveIntervention?.reason == "night_pattern")
        #expect(resolution.predictiveIntervention?.expiresAt == expiresAt)
    }

    @Test("non-predictive resolutions keep action plan without synthesizing a suggestion")
    func nonPredictiveResolutionDoesNotCreateSuggestion() {
        let resolution = BASAppleEntryIntentOutcomeBuilder.resolve(
            kindID: "quickCapture",
            surfaceID: "watch",
            preferredModeID: "quick",
            scenarioID: "buy",
            promptSeed: "Hold this.",
            riskLevelID: "medium",
            triggerReason: nil,
            expiresAt: .distantFuture
        )

        #expect(resolution.actionPlan.actionKind == .quickCapture)
        #expect(resolution.refreshTriggerID == BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue)
        #expect(resolution.predictiveIntervention == nil)
    }

    @Test("entry intent executor runs the matching action then refreshes current brain")
    func entryIntentExecutorRunsMatchingActionThenRefreshesCurrentBrain() {
        var calls: [String] = []
        let resolution = BASAppleEntryIntentOutcomeBuilder.resolve(
            kindID: "reopenTomorrowItem",
            surfaceID: "app",
            preferredModeID: "balance",
            scenarioID: nil,
            promptSeed: "reopen this",
            riskLevelID: "medium",
            triggerReason: nil,
            expiresAt: .distantFuture
        )

        BASAppleEntryIntentOutcomeExecutor.execute(
            resolution: resolution,
            performQuickCapture: { _ in calls.append("quick") },
            performOpenMode: { plan in
                calls.append("open:\(plan.preferredModeID ?? "nil"):\(plan.shouldSelectBoxTab)")
            },
            performPredictiveIntervention: { suggestion in
                calls.append("predict:\(suggestion?.title ?? "nil")")
            },
            performRestoreWorkspace: {
                calls.append("restore")
            },
            refreshCurrentBrain: { triggerID in
                calls.append("refresh:\(triggerID)")
            }
        )

        #expect(calls == [
            "open:balance:true",
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
                preferredModeID: "mirror",
                scenarioID: nil,
                promptSeed: "Pause.",
                riskLevelID: "high",
                triggerReason: "night_pattern",
                expiresAt: Date(timeIntervalSince1970: 200)
            ),
            performQuickCapture: { _ in
                calls.append("quick")
            },
            performOpenMode: { _ in
                calls.append("open")
            },
            performPredictiveIntervention: { suggestion in
                calls.append("predict:\(suggestion?.preferredModeID ?? "nil")")
            },
            performRestoreWorkspace: {
                calls.append("restore")
            },
            refreshCurrentBrain: { triggerID in
                calls.append("refresh:\(triggerID)")
            }
        )

        #expect(calls == [
            "predict:mirror",
            "refresh:watchHandoff"
        ])
    }
}
