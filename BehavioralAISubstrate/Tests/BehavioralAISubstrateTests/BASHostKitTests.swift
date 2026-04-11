import XCTest
@testable import BASHostKit

final class BASHostKitTests: XCTestCase {
    func testStartSessionBuildsCurrentBrainAndConsoleSnapshot() {
        let runtime = BASHostRuntime()

        let result = runtime.startSession(
            BASHostSessionRequest(
                kind: .mirror,
                mode: .mirror,
                surface: .app,
                prompt: "I need to slow down before I send this message.",
                title: "Mirror this decision",
                riskLevel: .medium
            )
        )

        XCTAssertEqual(result.requestKind, .mirror)
        XCTAssertEqual(result.currentBrain.mode, BASDecisionMode.mirror.rawValue)
        XCTAssertFalse(result.currentBrain.dominantGoals.isEmpty)
        XCTAssertFalse(result.consoleSnapshot.reports.isEmpty)
        XCTAssertEqual(result.consoleSnapshot.reports.count, BASLayerKind.allCases.count)
        XCTAssertNotNil(result.interventionSuggestion)
    }

    func testBootstrapUsesLifecyclePlannerNotices() {
        let runtime = BASHostRuntime()

        let result = runtime.bootstrap(
            BASHostLifecycleRequest(
                phase: .initialAppearance,
                preferredMode: .quick,
                promptSeed: "Load the substrate before the UI asks for help."
            )
        )

        XCTAssertEqual(result.activeSessionTitle, "Lifecycle Bootstrap")
        XCTAssertTrue(result.notices.contains("Refresh memory projection"))
        XCTAssertTrue(result.followUpActions.contains("Load the current brain before rendering"))
    }

    func testReopenHighRiskProducesFollowUpSuggestion() {
        let runtime = BASHostRuntime()

        let result = runtime.reopen(
            BASHostReopenRequest(
                mode: .balance,
                title: "Reopen this choice",
                detail: "There is enough risk here that we want more structure.",
                promptSeed: "Look at the cost of acting tonight.",
                riskLevel: .high,
                templateHint: "Use the cooling template.",
                interventionHistorySummary: "Night-time messages go worse without delay."
            )
        )

        XCTAssertEqual(result.requestKind, .reopen)
        XCTAssertEqual(result.currentBrain.mode, BASDecisionMode.balance.rawValue)
        XCTAssertNotNil(result.interventionSuggestion)
        XCTAssertTrue(result.followUpActions.contains("Require stronger confirmation"))
    }

    func testExecuteLifecyclePhaseDelegatesEntryConsumptionAndRefreshOrder() {
        let runtime = BASHostRuntime()
        var actions: [String] = []

        runtime.executeLifecyclePhase(
            .initialAppearance,
            refreshMemoryProjection: { actions.append("projection") },
            refreshCurrentBrain: { actions.append("brain:\($0)") },
            presentPendingReflection: { actions.append("reflection") },
            consumeHandoff: { "handoff" },
            handleHandoff: { envelope in actions.append("handoff:\(envelope)") },
            consumePendingRequest: { nil as String? },
            handlePendingRequest: { request in actions.append("pending:\(request)") },
            restoreActiveWorkspace: { actions.append("restore") },
            refreshPredictedIntervention: { actions.append("prediction") },
            syncWidgetSnapshot: { actions.append("widget") }
        )

        XCTAssertEqual(
            actions,
            [
                "projection",
                "brain:launch",
                "reflection",
                "handoff:handoff",
                "restore",
                "prediction",
                "widget"
            ]
        )
    }
}
