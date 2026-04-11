import XCTest
@testable import BASHostKit

final class BASHostKitTests: XCTestCase {
    func testStartSessionBuildsCurrentBrainAndConsoleSnapshot() {
        let runtime = BASHostRuntime()

        let result = runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "I need to slow down before I send this message.",
                title: "Reflect on this decision",
                riskLevel: .medium
            )
        )

        XCTAssertEqual(result.requestKind, .interactive)
        XCTAssertEqual(result.workflowProfile, .reflective)
        XCTAssertEqual(result.currentBrain.workflowProfile, .reflective)
        XCTAssertEqual(result.currentBrain.workflowTitle, "Reflective")
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
                preferredProfile: .rapid,
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
                workflowProfile: .deliberate,
                title: "Reopen this choice",
                detail: "There is enough risk here that we want more structure.",
                promptSeed: "Look at the cost of acting tonight.",
                riskLevel: .high,
                templateHint: "Use the cooling template.",
                interventionHistorySummary: "Night-time messages go worse without delay."
            )
        )

        XCTAssertEqual(result.requestKind, .reopen)
        XCTAssertEqual(result.workflowProfile, .deliberate)
        XCTAssertEqual(result.currentBrain.workflowProfile, .deliberate)
        XCTAssertGreaterThan(result.currentBrain.failureGuardCount, 0)
        XCTAssertNotNil(result.interventionSuggestion)
        XCTAssertTrue(result.followUpActions.contains("Require stronger confirmation"))
    }

    func testCustomPresentationLetsHostOwnWorkflowLanguage() {
        let runtime = BASHostRuntime(
            configuration: BASHostConfiguration(
                presentation: BASHostPresentationConfiguration(
                    workflowTitles: BASHostWorkflowTitles(
                        rapid: "Quick Judgment",
                        deliberate: "Balance Board",
                        reflective: "Mirror"
                    ),
                    surfaceTitles: BASHostSurfaceTitles(
                        application: "App",
                        wearable: "Watch",
                        widget: "Widget",
                        shortcut: "Shortcut",
                        voiceAssistant: "Siri",
                        notification: "Notification",
                        system: "System"
                    ),
                    sessionTitles: BASHostSessionTitles(
                        rapid: "Quick Judgment",
                        deliberate: "Balance Board",
                        reflective: "Mirror",
                        initialAppearance: "Before Bootstrap",
                        sceneActive: "Before Refresh"
                    ),
                    followUpActions: BASHostFollowUpActions(
                        rapid: ["Name the urge", "Choose one clean next move"],
                        deliberate: ["Surface the real trade-off", "Name one cost and one benefit"],
                        reflective: ["Slow the story", "Name one grounded truth"],
                        highRiskEscalation: ["Require stronger confirmation"]
                    ),
                    lifecycle: BASHostLifecyclePresentation(
                        refreshMemoryProjectionNotice: "Refresh Before memory projection",
                        refreshCurrentBrainNotice: "Refresh Before brain state",
                        presentPendingReflectionNotice: "Present the pending reflection",
                        consumePendingLaunchRequestNotice: "Consume the pending launch request",
                        restoreActiveWorkspaceNotice: "Restore the structured workspace",
                        refreshPredictedInterventionNotice: "Refresh the guarded intervention state",
                        syncWidgetSnapshotNotice: "Sync the Before widget snapshot",
                        loadCurrentBrainFollowUp: "Load the current brain before rendering Before",
                        resumeStructuredWorkspaceFollowUp: "Resume the last structured Before workspace",
                        recomputeGuardedInterventionFollowUp: "Recompute the guarded intervention state"
                    ),
                    notices: BASHostNoticeTemplates(
                        enteredWorkflow: "{surface} entered {workflow} through Before.",
                        runtimeProfile: "Before runtime profile {runtimeProfile} is active.",
                        reopenFollowUpAction: "Reopen with {workflow} structure",
                        emptyPromptGoalFallback: "Stay clear before acting."
                    ),
                    predictiveIntervention: BASHostPredictiveInterventionPresentation(
                        mediumRiskTitle: "Pause before you decide.",
                        mediumRiskDetail: "Before sees a context that benefits from one slower step.",
                        highRiskTitle: "Add more friction before acting.",
                        highRiskDetail: "Before sees elevated risk and wants stronger confirmation before the next move.",
                        reopenRiskDetail: "This reopen path is carrying risk, so Before is asking for more structure.",
                        fallbackReopenSuggestionDetail: "A prior hold suggests slowing this down.",
                        defaultReason: "Before prefers a slower path here."
                    )
                )
            )
        )

        let session = runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .rapid,
                surface: .application,
                prompt: "I want to move fast.",
                riskLevel: .low
            )
        )
        let bootstrap = runtime.bootstrap(
            BASHostLifecycleRequest(
                phase: .initialAppearance,
                preferredProfile: .rapid,
                promptSeed: "Load the current brain before speaking."
            )
        )

        XCTAssertEqual(session.activeSessionTitle, "Quick Judgment")
        XCTAssertTrue(session.notices.contains("App entered quick judgment through Before."))
        XCTAssertTrue(session.notices.contains("Before runtime profile apple.local-first is active."))
        XCTAssertEqual(session.followUpActions, ["Name the urge", "Choose one clean next move"])
        XCTAssertEqual(bootstrap.activeSessionTitle, "Before Bootstrap")
        XCTAssertTrue(bootstrap.notices.contains("Refresh Before memory projection"))
        XCTAssertTrue(bootstrap.followUpActions.contains("Load the current brain before rendering Before"))
    }

    func testCustomPredictiveInterventionCopyBelongsToHost() {
        let runtime = BASHostRuntime(
            configuration: BASHostConfiguration(
                presentation: BASHostPresentationConfiguration(
                    predictiveIntervention: BASHostPredictiveInterventionPresentation(
                        mediumRiskTitle: "Host says pause.",
                        mediumRiskDetail: "Host wants one slower pass.",
                        highRiskTitle: "Host wants another checkpoint.",
                        highRiskDetail: "Host sees elevated risk and wants stronger confirmation.",
                        reopenRiskDetail: "Host sees risk in this reopen path and wants structure.",
                        fallbackReopenSuggestionDetail: "Host says slow this reopen down.",
                        defaultReason: "Host policy prefers a slower lane."
                    )
                )
            )
        )

        let session = runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .deliberate,
                surface: .application,
                prompt: "I need to compare these options carefully.",
                riskLevel: .medium
            )
        )
        let reopen = runtime.reopen(
            BASHostReopenRequest(
                workflowProfile: .deliberate,
                title: "Reopen this choice",
                promptSeed: "Look at the cost of acting tonight.",
                riskLevel: .high,
                templateHint: "Use the cooling template."
            )
        )

        XCTAssertEqual(session.interventionSuggestion?.title, "Host says pause.")
        XCTAssertEqual(session.interventionSuggestion?.detail, "Host wants one slower pass.")
        XCTAssertEqual(session.interventionSuggestion?.reason, "Host policy prefers a slower lane.")
        XCTAssertEqual(reopen.interventionSuggestion?.detail, "Host says slow this reopen down.")
    }

    func testCustomWorkflowBehaviorBelongsToHost() {
        let runtime = BASHostRuntime(
            configuration: BASHostConfiguration(
                workflowBehavior: BASHostWorkflowBehaviorConfiguration(
                    templateIDsByProfileID: [
                        BASHostWorkflowProfile.rapid.rawValue: ["before.template.quick-judgment"]
                    ],
                    memorySourceIDsByProfileID: [
                        BASHostWorkflowProfile.rapid.rawValue: BASMemorySource.history.rawValue
                    ],
                    interactiveRetrievalModeByProfileID: [
                        BASHostWorkflowProfile.rapid.rawValue: "balanced"
                    ],
                    hostNamespace: "before-sdk"
                )
            )
        )

        let result = runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .rapid,
                surface: .application,
                prompt: "I need one cleaner pass before I act.",
                riskLevel: .low
            )
        )

        XCTAssertEqual(result.projection.activeTemplateIDs, ["before.template.quick-judgment"])
        XCTAssertEqual(result.currentBrain.verificationSummary.split(separator: "/").first, "before-sdk")
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

    func testCommitProjectionRefreshPublishesProjectionAndNotice() {
        let runtime = BASHostRuntime()
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?

        runtime.commitProjectionRefresh(
            outcome: BASAppleProjectionRefreshResult(
                projection: "projection",
                refreshed: true,
                notice: "refresh notice"
            ),
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 }
        )

        XCTAssertEqual(committedProjection, "projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "refresh notice")
    }

    func testResolveProjectionRefreshUsesResolverAndCommitsState() {
        let runtime = BASHostRuntime()
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?

        runtime.resolveProjectionRefresh(
            using: {
                BASAppleProjectionRefreshResult(
                    projection: "resolved-projection",
                    refreshed: true,
                    notice: "resolved notice"
                )
            },
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 }
        )

        XCTAssertEqual(committedProjection, "resolved-projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "resolved notice")
    }

    func testActivateSessionCommitsProjectionBrainAndSession() {
        let runtime = BASHostRuntime()
        var loadedSession: [String] = []
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?
        var committedBrain: String?
        var committedSession: String?

        runtime.activateSession(
            session: "session",
            outcome: BASAppleCurrentBrainProjectionRuntimeResult(
                currentBrain: "brain",
                projection: "projection",
                refreshedProjection: true,
                notice: "activation notice"
            ),
            loadBrainState: { session, currentBrain in
                loadedSession = [session, currentBrain]
            },
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 },
            commitCurrentBrain: { committedBrain = $0 },
            commitSession: { committedSession = $0 }
        )

        XCTAssertEqual(loadedSession, ["session", "brain"])
        XCTAssertEqual(committedProjection, "projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "activation notice")
        XCTAssertEqual(committedBrain, "brain")
        XCTAssertEqual(committedSession, "session")
    }

    func testResolveCurrentBrainProjectionUsesResolverAndCommitsBrain() {
        let runtime = BASHostRuntime()
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?
        var committedBrain: String?

        runtime.resolveCurrentBrainProjection(
            using: {
                BASAppleCurrentBrainProjectionRuntimeResult(
                    currentBrain: "resolved-brain",
                    projection: "resolved-projection",
                    refreshedProjection: true,
                    notice: "resolved current brain"
                )
            },
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 },
            commitCurrentBrain: { committedBrain = $0 }
        )

        XCTAssertEqual(committedProjection, "resolved-projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "resolved current brain")
        XCTAssertEqual(committedBrain, "resolved-brain")
    }

    func testResolveAndActivateSessionUsesResolverAndCommitsSession() {
        let runtime = BASHostRuntime()
        var loadedSession: [String] = []
        var committedProjection: String?
        var dirtyFlag = true
        var publishedNotice: String?
        var committedBrain: String?
        var committedSession: String?

        runtime.resolveAndActivateSession(
            session: "session",
            using: {
                BASAppleCurrentBrainProjectionRuntimeResult(
                    currentBrain: "brain",
                    projection: "projection",
                    refreshedProjection: true,
                    notice: "resolved activation"
                )
            },
            loadBrainState: { session, currentBrain in
                loadedSession = [session, currentBrain]
            },
            commitProjection: { committedProjection = $0 },
            setProjectionDirty: { dirtyFlag = $0 },
            publishNotice: { publishedNotice = $0 },
            commitCurrentBrain: { committedBrain = $0 },
            commitSession: { committedSession = $0 }
        )

        XCTAssertEqual(loadedSession, ["session", "brain"])
        XCTAssertEqual(committedProjection, "projection")
        XCTAssertFalse(dirtyFlag)
        XCTAssertEqual(publishedNotice, "resolved activation")
        XCTAssertEqual(committedBrain, "brain")
        XCTAssertEqual(committedSession, "session")
    }

    func testReopenHeldItemAppliesFollowUpSuggestion() {
        let runtime = BASHostRuntime()
        var actions: [String] = []
        var suggestion: BASAppleReopenInterventionSuggestion?

        runtime.reopenHeldItem(
            modeID: BASDecisionMode.balance.rawValue,
            promptSeed: "Slow this choice down.",
            hasDraft: false,
            title: "Reopen carefully",
            detail: "High-risk reopen",
            riskLevelID: BASRiskLevel.high.rawValue,
            reopenHint: "Use more structure",
            templateHint: "Cooling template",
            interventionHistorySummary: "Past nighttime choices went worse.",
            clearActiveDecisionFlows: { actions.append("clear") },
            activatePrimaryFromDraft: { actions.append("draft-quick") },
            activateComparativeFromDraft: { actions.append("draft-balance") },
            activateReflectiveFromDraft: { actions.append("draft-mirror") },
            startPrimary: { _ in actions.append("start-quick") },
            startComparative: { _ in actions.append("start-balance") },
            startReflective: { _ in actions.append("start-mirror") },
            removeItem: { actions.append("remove") },
            applyInterventionSuggestion: { suggestion = $0; actions.append("suggest") },
            refreshPredictedIntervention: { actions.append("refresh") },
            selectHomeTab: { actions.append("home") },
            persistActiveWorkspaceState: { actions.append("persist") },
            now: .distantPast
        )

        XCTAssertEqual(actions, ["clear", "start-balance", "remove", "suggest", "home", "persist"])
        XCTAssertEqual(suggestion?.title, "Use more structure")
        XCTAssertEqual(suggestion?.suggestedModeID, BASDecisionMode.balance.rawValue)
    }

    func testRestoreActiveWorkspaceIfNeededRestoresMatchingMode() {
        let runtime = BASHostRuntime()
        var actions: [String] = []

        runtime.restoreActiveWorkspaceIfNeeded(
            restoreEnabled: true,
            hasActivePrimaryWorkflow: false,
            hasActiveComparativeWorkflow: false,
            hasActiveReflectiveWorkflow: false,
            hasReflectionContext: false,
            loadState: { "mirror" },
            modeID: { $0 },
            restorePrimary: { _ in actions.append("quick") },
            restoreComparative: { _ in actions.append("balance") },
            restoreReflective: { _ in actions.append("mirror") },
            selectHomeTab: { actions.append("home") },
            afterRestore: { actions.append("after") }
        )

        XCTAssertEqual(actions, ["mirror", "home", "after"])
    }

    func testRefreshActiveTaskGraphChoosesFirstAvailableSnapshot() {
        let runtime = BASHostRuntime()
        var savedSnapshot: String?
        var cleared = false
        let snapshotLoaders: [() -> String?] = [
            { nil },
            { "balance-snapshot" },
            { "mirror-snapshot" }
        ]

        let snapshot = runtime.refreshActiveTaskGraph(
            snapshotsInPriorityOrder: snapshotLoaders,
            saveSnapshot: { savedSnapshot = $0 },
            clearSnapshot: { cleared = true }
        )

        XCTAssertEqual(snapshot, "balance-snapshot")
        XCTAssertEqual(savedSnapshot, "balance-snapshot")
        XCTAssertFalse(cleared)
    }

    func testReconcilePredictiveInterventionKeepsExistingPresentationStable() {
        let runtime = BASHostRuntime()
        let existing = BASApplePredictiveInterventionCandidateSummary(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            riskLevelID: BASRiskLevel.medium.rawValue,
            title: "Pause",
            detail: "Slow down",
            evidenceSignalCount: 2,
            preferredModeID: BASDecisionMode.mirror.rawValue,
            reason: "Recent signals say pause.",
            createdAt: .distantPast,
            expiresAt: .distantFuture
        )
        let next = BASApplePredictiveInterventionCandidateSummary(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            riskLevelID: BASRiskLevel.medium.rawValue,
            title: "Pause",
            detail: "Slow down",
            evidenceSignalCount: 2,
            preferredModeID: BASDecisionMode.mirror.rawValue,
            reason: "Recent signals say pause.",
            createdAt: .now,
            expiresAt: .distantFuture
        )

        let reconciled = runtime.reconcilePredictiveIntervention(
            existing: existing,
            next: next
        )

        XCTAssertEqual(reconciled?.id, existing.id)
    }

    func testExecutePredictiveInterventionDeliverySchedulesAllowedCandidate() {
        let runtime = BASHostRuntime()
        let candidate = BASApplePredictiveInterventionCandidateSummary(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            riskLevelID: BASRiskLevel.high.rawValue,
            title: "Pause",
            detail: "Slow down",
            evidenceSignalCount: 3,
            preferredModeID: BASDecisionMode.mirror.rawValue,
            reason: "High-risk context",
            createdAt: .now,
            expiresAt: .distantFuture
        )
        var upserts: [(UUID, Bool)] = []
        var cancelled: [UUID] = []
        var scheduled: [UUID] = []

        runtime.executePredictiveInterventionDelivery(
            candidate: candidate,
            predictiveInterventionsEnabled: true,
            policyAllowed: true,
            upsertTrigger: { summary, wasDelivered in
                upserts.append((summary.id, wasDelivered))
            },
            cancelNotification: { cancelled.append($0) },
            scheduleNotification: { scheduled.append($0.id) }
        )

        XCTAssertEqual(upserts.count, 1)
        XCTAssertEqual(upserts.first?.0, candidate.id)
        XCTAssertEqual(upserts.first?.1, true)
        XCTAssertTrue(cancelled.isEmpty)
        XCTAssertEqual(scheduled, [candidate.id])
    }
}
