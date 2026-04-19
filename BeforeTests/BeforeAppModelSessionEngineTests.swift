import XCTest
import SwiftData
import BASHostKit
@testable import Before

final class BeforeAppModelSessionEngineTests: XCTestCase {
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        try await resetPersistentState()
    }

    @MainActor
    override func tearDown() async throws {
        try await resetPersistentState()
        try await super.tearDown()
    }

    @MainActor
    private func resetPersistentState() async throws {
        await BeforeAppModel.drainDeferredSessionEngineTasksForTesting()
        await DecisionTestingInterface.resetTransientIntelligenceState()
        ActiveDecisionWorkspaceStore.clear()
        DecisionTaskGraphStore.clear()
        PendingReflectionStore.clear()
        PendingLaunchRequestStore.clear()
        DecisionIntentEnvelopeStore.clear()
        DecisionReactionBanditStore.clear()
        WidgetSnapshotStore.clear()
        BeforeRuntimePolicyStore.clearOverride()
        DecisionEvolutionKillSwitchStore.clear()
        ProtectedLocalStateStore.clearQuarantine(key: "before.active.decision.workspace")
        StateStorageIssueRecorder.clear()
        PersistenceIssueRecorder.clear()
        UserDefaults.standard.removeObject(forKey: "before.active.decision.workspace")
        UserDefaults.standard.removeObject(forKey: "before.preferences")
        try await DecisionSessionEngine.shared?.resetForTesting()
    }

    @MainActor
    func testQuickEvaluationWritesSessionEngineEventsAndCheckpoint() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this tonight?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let engineSession = try await engine.getSession(sessionID)
        let events = try await engine.listEvents(
            sessionId: sessionID,
            branchId: engineSession.headBranchId
        )
        let latestCheckpoint = try await engine.getLatestCheckpoint(
            sessionId: sessionID,
            branchId: engineSession.headBranchId
        )
        let snapshot = try await engine.snapshot()
        let inspected = try XCTUnwrap(snapshot.recentSessions.first(where: { $0.sessionID == sessionID }))

        XCTAssertTrue(events.contains(where: { $0.type == .userMessage }))
        XCTAssertTrue(events.contains(where: { $0.type == .assistantMessage }))
        XCTAssertNotNil(latestCheckpoint)
        XCTAssertEqual(inspected.status, .active)
        XCTAssertEqual(inspected.openStepCount, 0)
        XCTAssertNotNil(inspected.latestCheckpointID)
        XCTAssertTrue(inspected.latestCheckpointBudgetLine?.hasPrefix("eBrain budget:") == true)
        XCTAssertTrue(inspected.latestCheckpointRouteLine?.hasPrefix("eBrain route:") == true)
        XCTAssertTrue(inspected.latestCheckpointPressureLine?.hasPrefix("eBrain pressure: latency ") == true)
        XCTAssertTrue(inspected.latestCheckpointDecisionLine?.contains("eBrain risk:") == true)
        XCTAssertTrue(inspected.latestCheckpointDecisionLine?.contains("eBrain permit:") == true)
        XCTAssertTrue(latestCheckpoint?.summary.acceptedConstraints.contains(where: { $0.hasPrefix("eBrain budget:") }) == true)
        XCTAssertTrue(latestCheckpoint?.summary.confirmedFacts.contains(where: { $0.hasPrefix("eBrain pressure: latency ") }) == true)
        XCTAssertTrue(latestCheckpoint?.summary.confirmedFacts.contains(where: { $0.hasPrefix("eBrain risk:") }) == true)
        XCTAssertTrue(latestCheckpoint?.summary.confirmedFacts.contains(where: { $0.hasPrefix("eBrain permit:") }) == true)
        XCTAssertTrue(latestCheckpoint?.summary.confirmedFacts.contains(where: { $0.hasPrefix("eBrain fold:") }) == true)
        XCTAssertTrue(latestCheckpoint?.summary.currentScope.contains("ebrain") == true)
        XCTAssertEqual(
            latestCheckpoint?.runtimeState.eBrainAnchor?.sessionID,
            inspected.latestCheckpointEBrainAnchor?.sessionID
        )
        XCTAssertEqual(
            latestCheckpoint?.runtimeState.eBrainAnchor?.thoughtFoldChecksum,
            inspected.latestCheckpointEBrainAnchor?.thoughtFoldChecksum
        )
        XCTAssertEqual(
            latestCheckpoint?.runtimeState.eBrainAnchor?.riskLevel,
            inspected.latestCheckpointEBrainAnchor?.riskLevel
        )
        XCTAssertEqual(
            latestCheckpoint?.runtimeState.eBrainAnchor?.permitMode,
            inspected.latestCheckpointEBrainAnchor?.permitMode
        )
        XCTAssertNotNil(latestCheckpoint?.runtimeState.eBrainAnchor?.riskLevel)
        XCTAssertNotNil(latestCheckpoint?.runtimeState.eBrainAnchor?.permitMode)
        XCTAssertNotNil(latestCheckpoint?.runtimeState.eBrainAnchor?.hostGatePercent)
    }

    @MainActor
    func testSubstrateInspectionConvenienceAccessorsMirrorInspectionSnapshot() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this tonight?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let inspection = await app.substrateInspectionSnapshot()
        let kernelFrame = await app.substrateEBrainKernelFrame()
        let presentationFrame = await app.substrateEBrainPresentationFrame()
        let factsBundle = await app.substrateEBrainFactsBundle()
        let layerStackLines = await app.substrateLayerStackLines()
        let persistenceIssue = await app.substrateLatestPersistenceIssue()
        let persistenceRemediation = await app.substrateLatestPersistenceRemediationSnapshot()
        let runtimePolicyLineage = await app.substrateRuntimePolicyLineage()
        let runtimePolicyIssues = await app.substrateRuntimePolicyIssues()

        XCTAssertEqual(kernelFrame, inspection.liveEBrainKernelFrame)
        XCTAssertEqual(presentationFrame, inspection.liveEBrainPresentationFrame)
        XCTAssertEqual(factsBundle, inspection.effectiveEBrainFactsBundle)
        XCTAssertEqual(layerStackLines, inspection.effectiveLayerStackLines)
        XCTAssertEqual(persistenceIssue, inspection.latestPersistenceIssue)
        XCTAssertEqual(persistenceRemediation, inspection.latestPersistenceRemediationSnapshot)
        XCTAssertEqual(runtimePolicyLineage, inspection.runtimePolicyLineage)
        XCTAssertEqual(runtimePolicyIssues, inspection.runtimePolicyIssues)
        XCTAssertNotNil(kernelFrame?.runModeID)
        XCTAssertNotNil(kernelFrame?.wakeIntentLevelID)
        XCTAssertNotNil(kernelFrame?.lungState)
        XCTAssertNotNil(kernelFrame?.resumeFrame)
        XCTAssertNotNil(kernelFrame?.rollbackAnchor)
        XCTAssertNotNil(presentationFrame?.runModeTitle)
        XCTAssertNotNil(presentationFrame?.sourceDescriptor)
        XCTAssertNotNil(presentationFrame?.lungLine)
        XCTAssertNotNil(presentationFrame?.resumeLine)
        XCTAssertNotNil(presentationFrame?.rollbackLine)
        XCTAssertFalse(layerStackLines.isEmpty)
        XCTAssertEqual(layerStackLines.count, 10)
        XCTAssertTrue(layerStackLines.first?.hasPrefix("L1 power clock") == true)
        XCTAssertTrue(layerStackLines.last?.hasPrefix("L14 sovereign") == true)
    }

    @MainActor
    func testSuppressHostedTestPresentationsClearsTransientModalState() throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Transient quick flow")
        app.startBalanceBoard(entrySource: .app, prompt: "Transient balance flow")
        app.startMirrorWorkspace(entrySource: .app, prompt: "Transient mirror flow")
        app.reflectionContext = ReflectionContext(
            id: UUID(),
            eventID: UUID(),
            scenario: .other,
            finalAction: .wait90s
        )
        app.letGoContext = LetGoContext(
            mode: .quick,
            eyebrow: "Test",
            title: "Let it go",
            subtitle: "Transient state",
            itemTitle: "Trigger",
            itemDetail: "Noise",
            instructionTitle: "Instruction",
            instructionDetail: "Release it",
            completionTitle: "Done",
            completionSubtitle: "Settled",
            settledTitle: "Settled",
            settledDetail: "Quiet",
            primaryActionTitle: "Home",
            primaryTarget: .home
        )
        app.isEvolutionControlCenterPresented = true
        app.isSessionEngineControlCenterPresented = true
        app.presentSessionEngineBundleIssue("Import issue")

        app.suppressHostedTestPresentations()

        XCTAssertNil(app.activeQuickSession)
        XCTAssertNil(app.activeBalanceSession)
        XCTAssertNil(app.activeMirrorSession)
        XCTAssertNil(app.reflectionContext)
        XCTAssertNil(app.letGoContext)
        XCTAssertFalse(app.isEvolutionControlCenterPresented)
        XCTAssertFalse(app.isSessionEngineControlCenterPresented)
        XCTAssertNil(app.sessionEngineBundleIssue)
        XCTAssertTrue(app.hasSeenOnboarding)
    }

    @MainActor
    func testBalanceEvaluationCreatesSessionEngineBindingAndMeaningfulCheckpointGoal() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startBalanceBoard(entrySource: .app, prompt: "Should I leave this contract?")

        let session = try XCTUnwrap(app.activeBalanceSession)
        session.desire = "Protect my energy"
        session.concern = "I might damage the relationship"
        session.constraint = "I need clarity this week"
        session.longTerm = "I do not want to repeat this pattern"

        await app.evaluateBalanceSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let engineSession = try await engine.getSession(sessionID)
        let latestCheckpoint = try await engine.getLatestCheckpoint(
            sessionId: sessionID,
            branchId: engineSession.headBranchId
        )
        let events = try await engine.listEvents(
            sessionId: sessionID,
            branchId: engineSession.headBranchId
        )

        XCTAssertEqual(latestCheckpoint?.summary.goal, "Should I leave this contract?")
        XCTAssertTrue(latestCheckpoint?.summary.confirmedFacts.contains(where: { $0.contains("desire: Protect my energy") }) == true)
        XCTAssertTrue(events.contains(where: { $0.type == .assistantMessage }))
    }

    @MainActor
    func testSystemFlightDeckCarriesActiveSessionEngineSummaryAfterMirrorEvaluation() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startMirrorWorkspace(entrySource: .app, prompt: "Why do I keep freezing before I send the message?")

        let session = try XCTUnwrap(app.activeMirrorSession)
        session.emotion = "I draft the text, then stare at it and do nothing."
        session.relationship = "If I send it, I lose the safety of postponing."
        session.reality = "I want reassurance before I risk conflict."
        session.longTerm = "I keep replaying the same loop."
        session.selfLens = "Part of me still treats delay as protection."

        await app.evaluateMirrorSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let flightDeck = await app.systemFlightDeck()
        let summary = try XCTUnwrap(flightDeck.sessionEngineSummary)
        let activeSession = try XCTUnwrap(summary.activeSession)
        let presentation = flightDeck.sessionEnginePresentation
        let presentedActiveSession = try XCTUnwrap(presentation.activeSession)

        XCTAssertEqual(activeSession.sessionID, sessionID)
        XCTAssertGreaterThanOrEqual(summary.sessions, 1)
        XCTAssertGreaterThanOrEqual(summary.checkpoints, 1)
        XCTAssertTrue(summary.headline.contains("Session Engine"))
        XCTAssertEqual(presentedActiveSession.sessionID, sessionID)
        XCTAssertTrue(presentation.countsLine.contains("Sessions"))
        XCTAssertTrue(presentedActiveSession.checkpointBudgetLine?.contains("eBrain budget:") == true)
        XCTAssertTrue(presentedActiveSession.checkpointPressureLine?.contains("eBrain pressure: latency ") == true)
        XCTAssertTrue(presentedActiveSession.checkpointRiskFactorsLine?.hasPrefix("Factors: ") == true)
        XCTAssertTrue(presentedActiveSession.checkpointReasonCodesLine?.hasPrefix("Reason codes: ") == true)
        XCTAssertTrue(presentedActiveSession.replayRecoverySummary.budgetLine?.contains("eBrain budget:") == true)
        XCTAssertTrue(presentedActiveSession.replayRecoverySummary.pressureLine?.contains("eBrain pressure: latency ") == true)
        XCTAssertTrue(presentedActiveSession.replayRecoverySummary.riskFactorsLine?.hasPrefix("Factors: ") == true)
        XCTAssertTrue(presentedActiveSession.replayRecoverySummary.reasonCodesLine?.hasPrefix("Reason codes: ") == true)
        XCTAssertTrue(
            presentedActiveSession.replayRecoverySummary.digestLines.contains {
                $0.contains("Factors: ") && $0.contains("Reason codes: ")
            }
        )
    }

    @MainActor
    func testQuickCompletionRecordsToolLifecycleAndActionCheckpointFact() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)
        await app.completeCheck(using: session, action: .decideTomorrow)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let engineSession = try await engine.getSession(sessionID)

        let events = try await waitForSessionToolLifecycle(
            engine: engine,
            sessionID: sessionID,
            branchID: engineSession.headBranchId,
            tool: "complete_quick_check"
        )

        let latestCheckpoint = try await engine.getLatestCheckpoint(
            sessionId: sessionID,
            branchId: engineSession.headBranchId
        )
        let checkpoints = try await engine.listCheckpoints(sessionId: sessionID)

        XCTAssertTrue(events.contains(where: { $0.type == .toolCallStarted }))
        XCTAssertTrue(events.contains(where: { $0.type == .toolCallFinished }))
        XCTAssertTrue(
            checkpoints.contains {
                $0.branchId == engineSession.headBranchId &&
                $0.summary.confirmedFacts.contains(
                    "action: completed quick check with action Move it to tomorrow"
                )
            }
        )
        XCTAssertTrue(
            latestCheckpoint?.summary.acceptedConstraints.contains(where: { $0.hasPrefix("eBrain budget:") }) == true
        )
        XCTAssertTrue(
            latestCheckpoint?.summary.confirmedFacts.contains(where: { $0.hasPrefix("eBrain risk:") }) == true
        )
        XCTAssertTrue(
            latestCheckpoint?.summary.confirmedFacts.contains(where: { $0.hasPrefix("eBrain permit:") }) == true
        )
        XCTAssertTrue(
            latestCheckpoint?.summary.confirmedFacts.contains(where: { $0.hasPrefix("eBrain fold:") }) == true
        )
        XCTAssertTrue(latestCheckpoint?.summary.currentScope.contains("ebrain") == true)
    }

    @MainActor
    func testQuickCompletionKeepsEvaluationPolicyWhenRuntimeOverrideChangesBeforeAction() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)
        let evaluationTurn = try XCTUnwrap(session.lastEvaluationEBrainTurn)
        let baselineDecodeTokens = evaluationTurn.budgetFrame.maxDecodeTokens
        let baselineRuntimeTuningPolicyID = evaluationTurn.policyLineage?.runtimeTuningPolicyID
        XCTAssertEqual(baselineRuntimeTuningPolicyID, "before.host.runtime-synthesis.v1")

        XCTAssertTrue(
            BeforeRuntimePolicyStore.saveOverride(
                makeRuntimePolicyBundle(
                    bundleVersion: "override.v2",
                    runtimeTuningPolicyID: "override.runtime-tuning.v2"
                )
            )
        )
        XCTAssertEqual(
            BeforeProductCompatibility.resolvedRuntimePolicy.lineage.runtimeTuningPolicyID,
            "override.runtime-tuning.v2"
        )

        await app.completeCheck(using: session, action: .decideTomorrow)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let engineSession = try await engine.getSession(sessionID)
        _ = try await waitForSessionToolLifecycle(
            engine: engine,
            sessionID: sessionID,
            branchID: engineSession.headBranchId,
            tool: "clear_active_workspace_state"
        )
        let latestCheckpoint = try await engine.getLatestCheckpoint(
            sessionId: sessionID,
            branchId: engineSession.headBranchId
        )

        XCTAssertTrue(
            latestCheckpoint?.summary.acceptedConstraints.contains(where: {
                $0.hasPrefix("eBrain budget:") && $0.contains("decode \(baselineDecodeTokens)")
            }) == true
        )
        XCTAssertEqual(
            app.currentBrainState?.evolutionState.latestCheckpoint?.lineageSummary?.policyLineage?.runtimeTuningPolicyID,
            baselineRuntimeTuningPolicyID
        )
    }

    @MainActor
    func testQuickCompletionClearsWorkspaceStateWithTrackedLifecycle() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I leave this draft alone?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)
        await app.completeCheck(using: session, action: .decideTomorrow)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let engineSession = try await engine.getSession(sessionID)
        let clearEvents = try await waitForSessionToolLifecycle(
            engine: engine,
            sessionID: sessionID,
            branchID: engineSession.headBranchId,
            tool: "clear_active_workspace_state"
        )
        let checkpoints = try await engine.listCheckpoints(sessionId: sessionID)
        let steps = try await engine.listAllSteps(sessionId: sessionID)
        let clearStartedCount = try await sourceToolEventCount(
            clearEvents,
            type: .toolCallStarted,
            tool: "clear_active_workspace_state",
            engine: engine
        )
        let clearFinishedCount = try await sourceToolEventCount(
            clearEvents,
            type: .toolCallFinished,
            tool: "clear_active_workspace_state",
            engine: engine
        )

        XCTAssertNil(app.activeQuickSession)
        XCTAssertNil(ActiveDecisionWorkspaceStore.load())
        XCTAssertGreaterThanOrEqual(clearStartedCount, 1)
        XCTAssertGreaterThanOrEqual(clearFinishedCount, 1)
        XCTAssertNotNil(steps.last(where: { $0.status == .completed })?.heartbeatAt)
        XCTAssertTrue(
            checkpoints.contains {
                $0.branchId == engineSession.headBranchId &&
                $0.summary.confirmedFacts.contains("action: cleared active quick workspace state")
            }
        )

        let flightDeck = await app.systemFlightDeck()
        let presentedSession = try XCTUnwrap(
            ([flightDeck.sessionEnginePresentation.activeSession].compactMap { $0 }
                + flightDeck.sessionEnginePresentation.recentSessions)
                .first(where: { $0.sessionID == sessionID })
        )
        XCTAssertEqual(
            presentedSession.checkpointActionLine,
            "action: cleared active quick workspace state"
        )
        XCTAssertTrue(
            flightDeck.sessionEngineSummary?.signals.contains(where: {
                $0.contains("action: cleared active quick workspace state")
            }) == true
        )
    }

    @MainActor
    func testReplayLookupHelpersResolveSharedHistoryAndReviewProfileEntries() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)
        await app.completeCheck(using: session, action: .decideTomorrow)

        let quickEvent = try XCTUnwrap(
            DecisionMemorySystem.fetchCheckEvents(in: app.modelContainer.mainContext, limit: 1).first
        )
        let historyReplay = await app.replayEntry(
            matchingRecordID: HistoryDetailSelection.quick(quickEvent).id
        )
        let historyPresentation = await app.replayDiagnosticsPresentation(
            matchingRecordID: HistoryDetailSelection.quick(quickEvent).id
        )
        let reviewEntry = try XCTUnwrap(
            DecisionReviewEngine.recentEntries(
                for: .quick,
                quick: [quickEvent],
                balance: [],
                mirror: [],
                limit: 1
            ).first
        )
        let reviewReplayEntries = await app.replayEntriesByRecordID(matching: [reviewEntry.id])
        let reviewPresentations = await app.replayDiagnosticsPresentationsByRecordID(
            matching: [reviewEntry.id]
        )
        let recentPresentations = await app.recentReplayDiagnosticsPresentations(limit: 3)
        let recentPresentation = try XCTUnwrap(
            recentPresentations.first {
                $0.summaryLine == historyPresentation?.summaryLine &&
                $0.sourceTitle == historyPresentation?.sourceTitle
            }
        )

        XCTAssertEqual(historyReplay?.id, "quick-\(quickEvent.id.uuidString)")
        XCTAssertEqual(reviewReplayEntries[reviewEntry.id]?.id, historyReplay?.id)
        XCTAssertEqual(
            reviewReplayEntries[reviewEntry.id]?.diagnosticsPresentation.summaryLine,
            historyReplay?.diagnosticsPresentation.summaryLine
        )
        XCTAssertEqual(historyPresentation?.summaryLine, historyReplay?.diagnosticsPresentation.summaryLine)
        XCTAssertEqual(reviewPresentations[reviewEntry.id]?.summaryLine, historyPresentation?.summaryLine)
        XCTAssertEqual(reviewPresentations[reviewEntry.id]?.sourceTitle, historyPresentation?.sourceTitle)
        XCTAssertEqual(reviewPresentations[reviewEntry.id]?.budgetLine, historyPresentation?.budgetLine)
        XCTAssertEqual(reviewPresentations[reviewEntry.id]?.taskLine, historyPresentation?.taskLine)
        XCTAssertEqual(
            reviewPresentations[reviewEntry.id]?.layerStackLines,
            historyPresentation?.layerStackLines
        )
        XCTAssertEqual(
            reviewPresentations[reviewEntry.id]?.overviewPresentation,
            historyPresentation?.overviewPresentation
        )
        XCTAssertEqual(recentPresentation.summaryLine, historyPresentation?.summaryLine)
        XCTAssertEqual(recentPresentation.sourceTitle, historyPresentation?.sourceTitle)
        XCTAssertEqual(recentPresentation.budgetLine, historyPresentation?.budgetLine)
        XCTAssertEqual(recentPresentation.taskLine, historyPresentation?.taskLine)
        XCTAssertEqual(recentPresentation.layerStackLines, historyPresentation?.layerStackLines)
        XCTAssertEqual(recentPresentation.overviewPresentation, historyPresentation?.overviewPresentation)
    }

    @MainActor
    func testRecentReplayDiagnosticsPresentationsExposeSharedSummarySurface() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)
        await app.completeCheck(using: session, action: .decideTomorrow)

        let presentations = await app.recentReplayDiagnosticsPresentations(limit: 3)
        let quickPresentation = try XCTUnwrap(
            presentations.first(where: { $0.modeTitle == DecisionMode.quick.shortTitle })
        )

        XCTAssertGreaterThanOrEqual(presentations.count, 1)
        XCTAssertFalse(quickPresentation.summaryLine.isEmpty)
        XCTAssertNotNil(quickPresentation.sourceTitle)
        XCTAssertFalse(quickPresentation.overviewPresentation.labelLine.isEmpty)
        XCTAssertFalse(quickPresentation.overviewPresentation.titleLine.isEmpty)
    }

    @MainActor
    func testToolLifecycleCreatesDedicatedWaitingToolStepAndHeartbeats() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let stepsBeforeAction = try await engine.listAllSteps(sessionId: sessionID)
        let previousStepCount = stepsBeforeAction.count

        await app.completeCheck(using: session, action: .decideTomorrow)

        let engineSession = try await engine.getSession(sessionID)
        let events = try await waitForSessionToolLifecycle(
            engine: engine,
            sessionID: sessionID,
            branchID: engineSession.headBranchId,
            tool: "complete_quick_check"
        )
        let stepsAfterAction = try await engine.listAllSteps(sessionId: sessionID)
        let latestCompletedStep = try XCTUnwrap(
            stepsAfterAction
                .filter { $0.status == .completed }
                .max(by: { $0.startedAt < $1.startedAt })
        )

        XCTAssertGreaterThanOrEqual(stepsAfterAction.count, previousStepCount + 1)
        XCTAssertEqual(latestCompletedStep.branchId, engineSession.headBranchId)
        XCTAssertNotNil(latestCompletedStep.heartbeatAt)
        XCTAssertGreaterThanOrEqual(events.filter { $0.type == .stepStarted }.count, 2)
        XCTAssertGreaterThanOrEqual(events.filter { $0.type == .stepHeartbeat }.count, 5)
    }

    @MainActor
    func testSavingBalanceBoardRecordsToolLifecycle() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startBalanceBoard(entrySource: .app, prompt: "Should I leave this contract?")

        let session = try XCTUnwrap(app.activeBalanceSession)
        session.desire = "Protect my energy"
        session.concern = "I might damage the relationship"
        session.constraint = "I need clarity this week"
        session.longTerm = "I do not want to repeat this pattern"

        await app.evaluateBalanceSessionWithIntelligence(session)
        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        app.saveBalanceBoard(session)

        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let engineSession = try await engine.getSession(sessionID)
        let events = try await waitForSessionToolLifecycle(
            engine: engine,
            sessionID: sessionID,
            branchID: engineSession.headBranchId,
            tool: "save_balance_board"
        )
        let steps = try await engine.listAllSteps(sessionId: sessionID)
        let latestCheckpoint = try await engine.getLatestCheckpoint(
            sessionId: sessionID,
            branchId: engineSession.headBranchId
        )

        XCTAssertTrue(events.contains(where: { $0.type == .toolCallStarted }))
        XCTAssertTrue(events.contains(where: { $0.type == .toolCallFinished }))
        XCTAssertGreaterThanOrEqual(steps.count, 2)
        XCTAssertGreaterThanOrEqual(steps.filter { $0.status == .completed }.count, 2)
        XCTAssertNotNil(steps.last(where: { $0.status == .completed })?.heartbeatAt)
        XCTAssertTrue(
            latestCheckpoint?.summary.acceptedConstraints.contains(where: { $0.hasPrefix("eBrain budget:") }) == true
        )
        XCTAssertTrue(
            latestCheckpoint?.summary.confirmedFacts.contains(where: { $0.hasPrefix("eBrain risk:") }) == true
        )
        XCTAssertTrue(
            latestCheckpoint?.summary.confirmedFacts.contains(where: { $0.hasPrefix("eBrain permit:") }) == true
        )
        XCTAssertTrue(
            latestCheckpoint?.summary.confirmedFacts.contains(where: { $0.hasPrefix("eBrain fold:") }) == true
        )
        XCTAssertTrue(latestCheckpoint?.summary.currentScope.contains("ebrain") == true)
    }

    @MainActor
    func testSavingBalanceBoardKeepsEvaluationPolicyWhenRuntimeOverrideChangesBeforeSave() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startBalanceBoard(entrySource: .app, prompt: "Should I leave this contract?")

        let session = try XCTUnwrap(app.activeBalanceSession)
        session.desire = "Protect my energy"
        session.concern = "I might damage the relationship"
        session.constraint = "I need clarity this week"
        session.longTerm = "I do not want to repeat this pattern"

        await app.evaluateBalanceSessionWithIntelligence(session)
        let evaluationTurn = try XCTUnwrap(session.lastEvaluationEBrainTurn)
        let baselineDecodeTokens = evaluationTurn.budgetFrame.maxDecodeTokens
        let baselineRuntimeTuningPolicyID = evaluationTurn.policyLineage?.runtimeTuningPolicyID
        XCTAssertEqual(baselineRuntimeTuningPolicyID, "before.host.runtime-synthesis.v1")

        XCTAssertTrue(
            BeforeRuntimePolicyStore.saveOverride(
                makeRuntimePolicyBundle(
                    bundleVersion: "override.v2",
                    runtimeTuningPolicyID: "override.runtime-tuning.v2"
                )
            )
        )
        XCTAssertEqual(
            BeforeProductCompatibility.resolvedRuntimePolicy.lineage.runtimeTuningPolicyID,
            "override.runtime-tuning.v2"
        )

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        app.saveBalanceBoard(session)

        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let engineSession = try await engine.getSession(sessionID)
        _ = try await waitForSessionToolLifecycle(
            engine: engine,
            sessionID: sessionID,
            branchID: engineSession.headBranchId,
            tool: "clear_active_workspace_state"
        )
        let latestCheckpoint = try await engine.getLatestCheckpoint(
            sessionId: sessionID,
            branchId: engineSession.headBranchId
        )

        XCTAssertTrue(
            latestCheckpoint?.summary.acceptedConstraints.contains(where: {
                $0.hasPrefix("eBrain budget:") && $0.contains("decode \(baselineDecodeTokens)")
            }) == true
        )
        XCTAssertEqual(
            app.currentBrainState?.evolutionState.latestCheckpoint?.lineageSummary?.policyLineage?.runtimeTuningPolicyID,
            baselineRuntimeTuningPolicyID
        )
    }

    @MainActor
    func testSavingMirrorWorkspaceKeepsEvaluationPolicyWhenRuntimeOverrideChangesBeforeSave() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startMirrorWorkspace(entrySource: .app, prompt: "Why do I keep freezing before I send the message?")

        let session = try XCTUnwrap(app.activeMirrorSession)
        session.emotion = "I draft the text, then stare at it and do nothing."
        session.relationship = "If I send it, I lose the safety of postponing."
        session.reality = "I want reassurance before I risk conflict."
        session.longTerm = "I keep replaying the same loop."
        session.selfLens = "Part of me still treats delay as protection."

        await app.evaluateMirrorSessionWithIntelligence(session)
        let evaluationTurn = try XCTUnwrap(session.lastEvaluationEBrainTurn)
        let baselineDecodeTokens = evaluationTurn.budgetFrame.maxDecodeTokens
        let baselineRuntimeTuningPolicyID = evaluationTurn.policyLineage?.runtimeTuningPolicyID
        XCTAssertEqual(baselineRuntimeTuningPolicyID, "before.host.runtime-synthesis.v1")

        XCTAssertTrue(
            BeforeRuntimePolicyStore.saveOverride(
                makeRuntimePolicyBundle(
                    bundleVersion: "override.v2",
                    runtimeTuningPolicyID: "override.runtime-tuning.v2"
                )
            )
        )
        XCTAssertEqual(
            BeforeProductCompatibility.resolvedRuntimePolicy.lineage.runtimeTuningPolicyID,
            "override.runtime-tuning.v2"
        )

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        app.saveMirrorWorkspace(session)

        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let engineSession = try await engine.getSession(sessionID)
        _ = try await waitForSessionToolLifecycle(
            engine: engine,
            sessionID: sessionID,
            branchID: engineSession.headBranchId,
            tool: "clear_active_workspace_state"
        )
        let latestCheckpoint = try await engine.getLatestCheckpoint(
            sessionId: sessionID,
            branchId: engineSession.headBranchId
        )

        XCTAssertTrue(
            latestCheckpoint?.summary.acceptedConstraints.contains(where: {
                $0.hasPrefix("eBrain budget:") && $0.contains("decode \(baselineDecodeTokens)")
            }) == true
        )
        XCTAssertEqual(
            app.currentBrainState?.evolutionState.latestCheckpoint?.lineageSummary?.policyLineage?.runtimeTuningPolicyID,
            baselineRuntimeTuningPolicyID
        )
    }

    @MainActor
    func testWorkspacePersistenceAndRestoreRecordTrackedSessionEngineLifecycle() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I keep this draft open?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let engineSession = try await engine.getSession(sessionID)
        let branchID = engineSession.headBranchId
        let stepsBeforePersistence = try await engine.listAllSteps(sessionId: sessionID)
        let eventsBeforePersistence = try await engine.listEvents(
            sessionId: sessionID,
            branchId: branchID
        )
        let persistedStartedBaseline = try await sourceToolEventCount(
            eventsBeforePersistence,
            type: .toolCallStarted,
            tool: "persist_active_workspace_state",
            engine: engine
        )
        let persistedFinishedBaseline = try await sourceToolEventCount(
            eventsBeforePersistence,
            type: .toolCallFinished,
            tool: "persist_active_workspace_state",
            engine: engine
        )

        app.handleScenePhase(.background)

        let persistedEvents = try await waitForSessionToolLifecycle(
            engine: engine,
            sessionID: sessionID,
            branchID: branchID,
            tool: "persist_active_workspace_state",
            minimumStartedCount: persistedStartedBaseline + 1,
            minimumFinishedCount: persistedFinishedBaseline + 1
        )
        let stepsAfterPersistence = try await engine.listAllSteps(sessionId: sessionID)
        let persistenceCheckpoints = try await engine.listCheckpoints(sessionId: sessionID)
        let persistedStartedCount = try await sourceToolEventCount(
            persistedEvents,
            type: .toolCallStarted,
            tool: "persist_active_workspace_state",
            engine: engine
        )
        let persistedFinishedCount = try await sourceToolEventCount(
            persistedEvents,
            type: .toolCallFinished,
            tool: "persist_active_workspace_state",
            engine: engine
        )

        XCTAssertGreaterThanOrEqual(persistedStartedCount, 1)
        XCTAssertGreaterThanOrEqual(persistedFinishedCount, 1)
        XCTAssertGreaterThanOrEqual(stepsAfterPersistence.count, stepsBeforePersistence.count + 1)
        XCTAssertGreaterThan(
            stepsAfterPersistence.filter { $0.status == .completed }.count,
            stepsBeforePersistence.filter { $0.status == .completed }.count
        )
        XCTAssertNotNil(stepsAfterPersistence.last(where: { $0.status == .completed })?.heartbeatAt)
        XCTAssertTrue(
            persistenceCheckpoints.contains {
                $0.branchId == branchID &&
                $0.summary.confirmedFacts.contains("action: persisted active quick workspace state")
            }
        )

        let restoredApp = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        restoredApp.handleInitialAppearance()
        restoredApp.handleScenePhase(.active)

        let restoredSession = try XCTUnwrap(restoredApp.activeQuickSession)
        XCTAssertEqual(restoredSession.note, session.note)
        XCTAssertEqual(restoredSession.sessionEngineSessionID, sessionID)

        let restoredEvents = try await waitForSessionToolLifecycle(
            engine: engine,
            sessionID: sessionID,
            branchID: branchID,
            tool: "restore_active_workspace_state"
        )
        let stepsAfterRestore = try await engine.listAllSteps(sessionId: sessionID)
        let restoreCheckpoints = try await engine.listCheckpoints(sessionId: sessionID)
        let restoredStartedCount = try await sourceToolEventCount(
            restoredEvents,
            type: .toolCallStarted,
            tool: "restore_active_workspace_state",
            engine: engine
        )
        let restoredFinishedCount = try await sourceToolEventCount(
            restoredEvents,
            type: .toolCallFinished,
            tool: "restore_active_workspace_state",
            engine: engine
        )

        XCTAssertGreaterThanOrEqual(restoredStartedCount, 1)
        XCTAssertGreaterThanOrEqual(restoredFinishedCount, 1)
        XCTAssertGreaterThanOrEqual(stepsAfterRestore.count, stepsAfterPersistence.count + 1)
        XCTAssertGreaterThan(
            stepsAfterRestore.filter { $0.status == .completed }.count,
            stepsAfterPersistence.filter { $0.status == .completed }.count
        )
        XCTAssertNotNil(stepsAfterRestore.last(where: { $0.status == .completed })?.heartbeatAt)
        XCTAssertTrue(
            restoreCheckpoints.contains {
                $0.branchId == branchID &&
                $0.summary.confirmedFacts.contains("action: restored active quick workspace state")
            }
        )

        let restoredFlightDeck = await restoredApp.systemFlightDeck()
        let presentedRestoredSession = try XCTUnwrap(
            restoredFlightDeck.sessionEnginePresentation.activeSession
        )
        XCTAssertEqual(presentedRestoredSession.sessionID, sessionID)
        XCTAssertEqual(
            presentedRestoredSession.checkpointActionLine,
            "action: restored active quick workspace state"
        )
        XCTAssertTrue(
            restoredFlightDeck.sessionEngineSummary?.signals.contains(where: {
                $0.contains("action: restored active quick workspace state")
            }) == true
        )
    }

    @MainActor
    func testWorkspaceRestoreKeepsPersistedEvaluationPolicyWhenRuntimeOverrideChangesBeforeRestore() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I keep this draft open?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)
        let evaluationTurn = try XCTUnwrap(session.lastEvaluationEBrainTurn)
        let baselineDecodeTokens = evaluationTurn.budgetFrame.maxDecodeTokens
        let baselineRuntimeTuningPolicyID = evaluationTurn.policyLineage?.runtimeTuningPolicyID
        XCTAssertEqual(baselineRuntimeTuningPolicyID, "before.host.runtime-synthesis.v1")

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let engineSession = try await engine.getSession(sessionID)

        app.handleScenePhase(.background)
        _ = try await waitForSessionToolLifecycle(
            engine: engine,
            sessionID: sessionID,
            branchID: engineSession.headBranchId,
            tool: "persist_active_workspace_state"
        )

        XCTAssertTrue(
            BeforeRuntimePolicyStore.saveOverride(
                makeRuntimePolicyBundle(
                    bundleVersion: "override.v2",
                    runtimeTuningPolicyID: "override.runtime-tuning.v2"
                )
            )
        )
        XCTAssertEqual(
            BeforeProductCompatibility.resolvedRuntimePolicy.lineage.runtimeTuningPolicyID,
            "override.runtime-tuning.v2"
        )

        let restoredApp = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        restoredApp.handleInitialAppearance()
        restoredApp.handleScenePhase(.active)

        let restoredSession = try XCTUnwrap(restoredApp.activeQuickSession)
        XCTAssertEqual(restoredSession.sessionEngineSessionID, sessionID)
        XCTAssertEqual(
            restoredSession.lastEvaluationEBrainTurn?.budgetFrame.maxDecodeTokens,
            baselineDecodeTokens
        )
        XCTAssertEqual(
            restoredSession.lastEvaluationEBrainTurn?.policyLineage?.runtimeTuningPolicyID,
            baselineRuntimeTuningPolicyID
        )

        await restoredApp.completeCheck(using: restoredSession, action: .decideTomorrow)

        let updatedSession = try await engine.getSession(sessionID)
        _ = try await waitForSessionToolLifecycle(
            engine: engine,
            sessionID: sessionID,
            branchID: updatedSession.headBranchId,
            tool: "clear_active_workspace_state"
        )
        let latestCheckpoint = try await engine.getLatestCheckpoint(
            sessionId: sessionID,
            branchId: updatedSession.headBranchId
        )

        XCTAssertTrue(
            latestCheckpoint?.summary.acceptedConstraints.contains(where: {
                $0.hasPrefix("eBrain budget:") && $0.contains("decode \(baselineDecodeTokens)")
            }) == true
        )
        XCTAssertEqual(
            restoredApp.currentBrainState?.evolutionState.latestCheckpoint?.lineageSummary?.policyLineage?.runtimeTuningPolicyID,
            baselineRuntimeTuningPolicyID
        )
    }

    @MainActor
    func testSessionEngineBindingPersistsWorkspaceStateWithTrackedLifecycle() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I keep this draft open?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        let sessionID = try await waitForSessionEngineSessionID(on: session)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let engineSession = try await engine.getSession(sessionID)
        let branchID = engineSession.headBranchId

        let persistedEvents = try await waitForSessionToolLifecycle(
            engine: engine,
            sessionID: sessionID,
            branchID: branchID,
            tool: "persist_active_workspace_state"
        )
        let checkpoints = try await engine.listCheckpoints(sessionId: sessionID)
        let steps = try await engine.listAllSteps(sessionId: sessionID)
        let persistedStartedCount = try await sourceToolEventCount(
            persistedEvents,
            type: .toolCallStarted,
            tool: "persist_active_workspace_state",
            engine: engine
        )
        let persistedFinishedCount = try await sourceToolEventCount(
            persistedEvents,
            type: .toolCallFinished,
            tool: "persist_active_workspace_state",
            engine: engine
        )

        XCTAssertGreaterThanOrEqual(persistedStartedCount, 1)
        XCTAssertGreaterThanOrEqual(persistedFinishedCount, 1)
        XCTAssertEqual(steps.last?.status, .completed)
        XCTAssertNotNil(steps.last?.heartbeatAt)
        XCTAssertTrue(
            checkpoints.contains {
                $0.branchId == branchID &&
                $0.summary.confirmedFacts.contains("action: persisted active quick workspace state")
            }
        )
    }

    @MainActor
    func testApplyingSessionEngineCorrectionCreatesNewBranchWithoutOverwritingOriginalHistory() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let originalSession = try await engine.getSession(sessionID)
        let originalBranchID = originalSession.headBranchId
        let originalEvents = try await engine.listEvents(
            sessionId: sessionID,
            branchId: originalBranchID
        )

        await app.appendSessionEngineCorrection(
            sessionID,
            newText: "Correction: only revise the parser path, not the whole module."
        )

        let updatedSession = try await engine.getSession(sessionID)
        XCTAssertNotEqual(updatedSession.headBranchId, originalBranchID)

        let correctionEvents = try await engine.listEvents(
            sessionId: sessionID,
            branchId: updatedSession.headBranchId
        )
        let originalBranchEvents = try await engine.listEvents(
            sessionId: sessionID,
            branchId: originalBranchID
        )

        XCTAssertTrue(
            originalEvents.allSatisfy { originalEvent in
                originalBranchEvents.contains(where: { $0.id == originalEvent.id })
            }
        )
        XCTAssertGreaterThanOrEqual(originalBranchEvents.count, originalEvents.count)
        XCTAssertFalse(originalBranchEvents.contains(where: { $0.type == .correctionAdded }))
        XCTAssertTrue(correctionEvents.contains(where: { $0.type == .branchCreated }))
        XCTAssertTrue(correctionEvents.contains(where: { $0.type == .correctionAdded }))
    }

    @MainActor
    func testApplyingSessionEngineCorrectionCanTargetSpecificHistoryEvent() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let originalSession = try await engine.getSession(sessionID)
        let originalEvents = try await engine.listEvents(
            sessionId: sessionID,
            branchId: originalSession.headBranchId
        )
        let targetEvent = try XCTUnwrap(originalEvents.first(where: { $0.type == .userMessage }))

        await app.appendSessionEngineCorrection(
            sessionID,
            targetEventID: targetEvent.id,
            newText: "Correction: keep the parser work isolated from the rest of the module."
        )

        let updatedSession = try await engine.getSession(sessionID)
        let correctionEvents = try await engine.listEvents(
            sessionId: sessionID,
            branchId: updatedSession.headBranchId
        )
        let correctionEvent = try XCTUnwrap(correctionEvents.first(where: { $0.type == .correctionAdded }))
        let payloadDataValue = try await engine.loadPayloadData(for: correctionEvent)
        let payloadData = try XCTUnwrap(payloadDataValue)
        let payload = try JSONDecoder().decode(DecisionSessionPayloadCorrection.self, from: payloadData)

        XCTAssertEqual(payload.targetEventId, targetEvent.id)
        XCTAssertTrue(app.startupNotice?.contains("event \(targetEvent.seq)") == true)
    }

    @MainActor
    func testSwitchingAndAbandoningSessionEngineBranchKeepsHeadExplicit() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let originalSession = try await engine.getSession(sessionID)
        let originalBranchID = originalSession.headBranchId

        await app.appendSessionEngineCorrection(
            sessionID,
            newText: "Correction: branch this into a parser-only version."
        )

        let correctedSession = try await engine.getSession(sessionID)
        let correctionBranchID = correctedSession.headBranchId
        XCTAssertNotEqual(correctionBranchID, originalBranchID)

        await app.switchSessionEngineBranch(
            sessionID: sessionID,
            branchID: originalBranchID
        )

        let switchedSession = try await engine.getSession(sessionID)
        XCTAssertEqual(switchedSession.headBranchId, originalBranchID)

        await app.abandonSessionEngineBranch(
            sessionID: sessionID,
            branchID: correctionBranchID
        )

        let branches = try await engine.listBranches(sessionId: sessionID)
        let abandonedBranch = try XCTUnwrap(branches.first(where: { $0.id == correctionBranchID }))
        let activeBranch = try XCTUnwrap(branches.first(where: { $0.id == originalBranchID }))

        XCTAssertEqual(abandonedBranch.status, .abandoned)
        XCTAssertEqual(activeBranch.status, .active)
    }

    @MainActor
    func testSessionEngineControlSnapshotCanInspectNonHeadBranchTimeline() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)

        await app.appendSessionEngineCorrection(
            sessionID,
            newText: "Correction: inspect the branched parser-only line."
        )

        let updatedSession = try await engine.getSession(sessionID)
        let correctionBranchID = updatedSession.headBranchId
        let controlSnapshot = await app.sessionEngineControlSnapshot(
            selectedSessionID: sessionID,
            selectedBranchID: correctionBranchID
        )

        XCTAssertEqual(controlSnapshot.selectedSessionID, sessionID)
        XCTAssertEqual(controlSnapshot.selectedBranchID, correctionBranchID)
        XCTAssertTrue(controlSnapshot.selectedBranches.contains(where: {
            $0.id == correctionBranchID && $0.isInspecting
        }))
        XCTAssertTrue(controlSnapshot.timelineItems.allSatisfy { $0.branchID == correctionBranchID })
    }

    @MainActor
    func testMergingCorrectionBranchMarksBranchMergedAndKeepsHeadStable() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let originalSession = try await engine.getSession(sessionID)
        let originalBranchID = originalSession.headBranchId

        await app.appendSessionEngineCorrection(
            sessionID,
            newText: "Correction: make this a safer parser-only version."
        )

        let correctedSession = try await engine.getSession(sessionID)
        let correctionBranchID = correctedSession.headBranchId
        XCTAssertNotEqual(correctionBranchID, originalBranchID)

        await app.switchSessionEngineBranch(
            sessionID: sessionID,
            branchID: originalBranchID
        )
        await app.mergeSessionEngineBranch(
            sessionID: sessionID,
            sourceBranchID: correctionBranchID
        )

        let branches = try await engine.listBranches(sessionId: sessionID)
        let mergedBranch = try XCTUnwrap(branches.first(where: { $0.id == correctionBranchID }))
        let currentSession = try await engine.getSession(sessionID)
        let headTimeline = try await engine.rebuildTimeline(
            sessionId: sessionID,
            branchId: currentSession.headBranchId
        )

        XCTAssertEqual(currentSession.headBranchId, originalBranchID)
        XCTAssertEqual(mergedBranch.status, .merged)
        XCTAssertTrue(headTimeline.items.contains(where: { item in
            if case .event(let event) = item.kind {
                return event.type == .branchMerged
            }
            return false
        }))
    }

    @MainActor
    func testRestoringCheckpointCreatesRecoveryBranchAndMovesHead() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let originalSession = try await engine.getSession(sessionID)
        let originalBranchID = originalSession.headBranchId
        let latestCheckpointValue = try await engine.getLatestCheckpoint(
            sessionId: sessionID,
            branchId: originalBranchID
        )
        let latestCheckpoint = try XCTUnwrap(latestCheckpointValue)

        await app.restoreSessionEngineCheckpoint(latestCheckpoint.id)

        let restoredSession = try await engine.getSession(sessionID)
        XCTAssertNotEqual(restoredSession.headBranchId, originalBranchID)

        let branches = try await engine.listBranches(sessionId: sessionID)
        let recoveredBranch = try XCTUnwrap(branches.first(where: { $0.id == restoredSession.headBranchId }))
        XCTAssertEqual(recoveredBranch.parentBranchId, originalBranchID)
        XCTAssertEqual(recoveredBranch.baseCheckpointId, latestCheckpoint.id)

        let recoveredTimeline = try await engine.rebuildTimeline(
            sessionId: sessionID,
            branchId: recoveredBranch.id
        )
        XCTAssertTrue(recoveredTimeline.items.contains(where: { item in
            if case .event(let event) = item.kind {
                return event.type == .sessionRecovered
            }
            return false
        }))
    }

    @MainActor
    func testRecoveringSessionEngineSessionPublishesRecoveryNoticeAndMovesHead() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let originalSession = try await engine.getSession(sessionID)
        let originalBranchID = originalSession.headBranchId

        await app.recoverSessionEngineSession(sessionID)

        let recoveredSession = try await engine.getSession(sessionID)
        XCTAssertNotEqual(recoveredSession.headBranchId, originalBranchID)
        XCTAssertTrue(app.startupNotice?.contains("Recovered session") == true)

        let recoveredTimeline = try await engine.rebuildTimeline(
            sessionId: sessionID,
            branchId: recoveredSession.headBranchId
        )
        XCTAssertTrue(recoveredTimeline.items.contains(where: { item in
            if case .event(let event) = item.kind {
                return event.type == .sessionRecovered
            }
            return false
        }))
    }

    @MainActor
    func testSessionEngineWatchdogPublishesNoopNoticeWhenNothingIsStalled() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)

        await app.sweepSessionEngineWatchdog()

        XCTAssertEqual(app.startupNotice, "Session Engine watchdog found no stalled steps.")
    }

    @MainActor
    func testSessionEngineWatchdogPublishesRecoveredCountAndMovesHead() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let originalSession = try await engine.getSession(sessionID)
        let originalBranchID = originalSession.headBranchId

        _ = try await engine.appendToolCallStarted(
            sessionId: sessionID,
            tool: "file_write",
            argsPreview: ["path": "src/parser.ts"],
            branchId: originalBranchID
        )
        _ = try await engine.startStep(
            sessionId: sessionID,
            branchId: originalBranchID,
            status: .waitingTool,
            ttlMs: 50
        )

        try await Task.sleep(nanoseconds: 80_000_000)
        await app.sweepSessionEngineWatchdog()

        XCTAssertEqual(app.startupNotice, "Session Engine watchdog recovered 1 stalled step(s).")

        let recoveredSession = try await engine.getSession(sessionID)
        XCTAssertNotEqual(recoveredSession.headBranchId, originalBranchID)
    }

    @MainActor
    func testExportingAndImportingSessionEngineBundleRoundTripsThroughAppModel() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let sourceSessionBeforeTransfer = try await engine.getSession(sessionID)
        let sourceBranchID = sourceSessionBeforeTransfer.headBranchId
        let stepsBeforeTransfer = try await engine.listAllSteps(sessionId: sessionID)
        let exportedURLValue = await app.exportSessionEngineSession(sessionID)
        let exportURL = try XCTUnwrap(exportedURLValue)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
        XCTAssertTrue(app.startupNotice?.contains("Exported Session Engine bundle") == true)

        let importedSessionValue = await app.importSessionEngineBundle(from: exportURL)
        let importedSession = try XCTUnwrap(importedSessionValue)
        XCTAssertNotEqual(importedSession.id, sessionID)
        XCTAssertEqual(importedSession.status, .paused)
        XCTAssertTrue(importedSession.title.hasSuffix("(Imported)"))
        XCTAssertTrue(app.startupNotice?.contains("Imported Session Engine bundle") == true)

        let sourceEvents = try await engine.listEvents(
            sessionId: sessionID,
            branchId: sourceBranchID
        )
        let sourceStepsAfterTransfer = try await engine.listAllSteps(sessionId: sessionID)
        let importedBranches = try await engine.listBranches(sessionId: importedSession.id)
        XCTAssertFalse(importedBranches.isEmpty)
        XCTAssertGreaterThanOrEqual(
            sourceEvents.filter { $0.type == .toolCallStarted }.count,
            2
        )
        XCTAssertGreaterThanOrEqual(
            sourceEvents.filter { $0.type == .toolCallFinished }.count,
            2
        )
        XCTAssertGreaterThanOrEqual(sourceStepsAfterTransfer.count, stepsBeforeTransfer.count + 2)
        XCTAssertEqual(sourceStepsAfterTransfer.last?.status, .completed)
        XCTAssertNotNil(sourceStepsAfterTransfer.last?.heartbeatAt)
    }

    @MainActor
    func testInspectingSessionEngineBundleReturnsImportPreviewBeforeMutation() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let exportedURLValue = await app.exportSessionEngineSession(sessionID)
        let exportURL = try XCTUnwrap(exportedURLValue)

        let previewValue = await app.inspectSessionEngineBundle(from: exportURL)
        let preview = try XCTUnwrap(previewValue)

        XCTAssertEqual(preview.sourceSessionId, sessionID)
        XCTAssertTrue(preview.importedTitle.hasSuffix("(Imported)"))
        XCTAssertTrue(preview.countsLine.contains("Events"))
    }

    @MainActor
    func testStagingSessionEngineBundleImportKeepsPreviewUntilCommit() async throws {
        let app = BeforeAppModel(modelContainer: try makeContainer(), startupNotice: nil)
        app.startQuickCheck(entrySource: .app, prompt: "Should I send this now?")

        let session = try XCTUnwrap(app.activeQuickSession)
        session.scenario = .other
        session.motivation = .stressed
        session.expectedOutcome = .temporaryRelief
        session.controlLevel = .maybe

        await app.evaluateQuickSessionWithIntelligence(session)

        let sessionID = try XCTUnwrap(session.sessionEngineSessionID)
        let engine = try XCTUnwrap(DecisionSessionEngine.shared)
        let sourceSessionBeforeTransfer = try await engine.getSession(sessionID)
        let sourceBranchID = sourceSessionBeforeTransfer.headBranchId
        let stepsBeforeTransfer = try await engine.listAllSteps(sessionId: sessionID)
        let exportedURLValue = await app.exportSessionEngineSession(sessionID)
        let exportURL = try XCTUnwrap(exportedURLValue)

        let draftValue = await app.stageSessionEngineBundleImport(from: exportURL)
        let draft = try XCTUnwrap(draftValue)
        XCTAssertEqual(draft.preview.sourceSessionId, sessionID)
        XCTAssertEqual(app.pendingSessionEngineImportDraft?.id, draft.id)

        let flightDeckWhilePending = await app.systemFlightDeck()
        let pendingImportPreview = try XCTUnwrap(flightDeckWhilePending.sessionEngineSummary?.pendingImportPreview)
        XCTAssertEqual(pendingImportPreview.bundleLine, "Bundle \(exportURL.lastPathComponent)")
        XCTAssertEqual(pendingImportPreview.importedLine, "Will import as \(draft.preview.importedTitle)")

        let controlSnapshotWhilePending = await app.sessionEngineControlSnapshot()
        XCTAssertEqual(controlSnapshotWhilePending.reviewItems.first?.title, "Pending import draft")
        XCTAssertTrue(
            controlSnapshotWhilePending.reviewItems.first?.detail.contains("Bundle \(exportURL.lastPathComponent)") == true
        )

        let importedSessionValue = await app.importStagedSessionEngineBundle()
        let importedSession = try XCTUnwrap(importedSessionValue)
        XCTAssertNotEqual(importedSession.id, sessionID)
        XCTAssertNil(app.pendingSessionEngineImportDraft)
        XCTAssertTrue(app.startupNotice?.contains("Imported Session Engine bundle") == true)

        let sourceEvents = try await engine.listEvents(
            sessionId: sessionID,
            branchId: sourceBranchID
        )
        let sourceStepsAfterTransfer = try await engine.listAllSteps(sessionId: sessionID)
        XCTAssertGreaterThanOrEqual(
            sourceEvents.filter { $0.type == .toolCallStarted }.count,
            2
        )
        XCTAssertGreaterThanOrEqual(
            sourceEvents.filter { $0.type == .toolCallFinished }.count,
            2
        )
        XCTAssertGreaterThanOrEqual(sourceStepsAfterTransfer.count, stepsBeforeTransfer.count + 2)
        XCTAssertEqual(sourceStepsAfterTransfer.last?.status, .completed)
        XCTAssertNotNil(sourceStepsAfterTransfer.last?.heartbeatAt)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: CheckEvent.self,
            DecisionMemoryRecord.self,
            DecisionMemoryCandidateRecord.self,
            BalanceDecisionRecord.self,
            MirrorDecisionRecord.self,
            BrainStateUpdate.self,
            DecisionEvolutionCheckpoint.self,
            InterventionTemplateRecord.self,
            FailurePatternRecord.self,
            InterventionTrigger.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    private func waitForSessionEngineSessionID(
        on session: QuickCheckSession,
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        pollIntervalNanoseconds: UInt64 = 50_000_000
    ) async throws -> String {
        let start = Date()
        while Date().timeIntervalSince(start) < Double(timeoutNanoseconds) / 1_000_000_000 {
            if let sessionID = session.sessionEngineSessionID, !sessionID.isEmpty {
                return sessionID
            }
            try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        XCTFail("Timed out waiting for Session Engine session ID")
        throw NSError(domain: "BeforeAppModelSessionEngineTests", code: 1)
    }

    @MainActor
    private func waitForSessionEvents(
        engine: DecisionSessionEngine,
        sessionID: String,
        branchID: String,
        requiredEventTypes: [DecisionSessionEventType],
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        pollIntervalNanoseconds: UInt64 = 50_000_000
    ) async throws -> [DecisionSessionEvent] {
        let start = Date()
        while Date().timeIntervalSince(start) < Double(timeoutNanoseconds) / 1_000_000_000 {
            let events = try await engine.listEvents(
                sessionId: sessionID,
                branchId: branchID
            )
            if requiredEventTypes.allSatisfy({ requiredType in
                events.contains(where: { $0.type == requiredType })
            }) {
                return events
            }
            try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        return try await engine.listEvents(
            sessionId: sessionID,
            branchId: branchID
        )
    }

    @MainActor
    private func waitForSessionToolLifecycle(
        engine: DecisionSessionEngine,
        sessionID: String,
        branchID: String,
        tool: String,
        minimumStartedCount: Int = 1,
        minimumFinishedCount: Int = 1,
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        pollIntervalNanoseconds: UInt64 = 50_000_000
    ) async throws -> [DecisionSessionEvent] {
        let start = Date()
        while Date().timeIntervalSince(start) < Double(timeoutNanoseconds) / 1_000_000_000 {
            let events = try await engine.listEvents(
                sessionId: sessionID,
                branchId: branchID
            )
            let startedCount = try await sourceToolEventCount(
                events,
                type: .toolCallStarted,
                tool: tool,
                engine: engine
            )
            let finishedCount = try await sourceToolEventCount(
                events,
                type: .toolCallFinished,
                tool: tool,
                engine: engine
            )
            if startedCount >= minimumStartedCount,
               finishedCount >= minimumFinishedCount {
                return events
            }
            try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        return try await engine.listEvents(
            sessionId: sessionID,
            branchId: branchID
        )
    }

    @MainActor
    private func sourceToolEventCount(
        _ events: [DecisionSessionEvent],
        type: DecisionSessionEventType,
        tool: String,
        engine: DecisionSessionEngine
    ) async throws -> Int {
        var count = 0
        for event in events where event.type == type {
            if try await toolName(for: event, engine: engine) == tool {
                count += 1
            }
        }
        return count
    }

    @MainActor
    private func toolName(
        for event: DecisionSessionEvent,
        engine: DecisionSessionEngine
    ) async throws -> String? {
        guard let payloadData = try await engine.loadPayloadData(for: event) else {
            return nil
        }

        let decoder = JSONDecoder()
        switch event.type {
        case .toolCallStarted:
            return try decoder.decode(DecisionSessionPayloadToolCallStarted.self, from: payloadData).tool
        case .toolCallFinished:
            return try decoder.decode(DecisionSessionPayloadToolCallFinished.self, from: payloadData).tool
        case .toolCallFailed:
            return try decoder.decode(DecisionSessionPayloadToolCallFailed.self, from: payloadData).tool
        default:
            return nil
        }
    }

    private func makeRuntimePolicyBundle(
        bundleVersion: String,
        runtimeTuningPolicyID: String
    ) -> BeforeRuntimePolicyBundle {
        let baselineRuntimePolicy = BeforeProductCompatibility.resolvedRuntimePolicyBundle
            .runtimeTuningRegistry
            .policiesByID["before.host.runtime-synthesis.v1"]!
        var overrideBudget = baselineRuntimePolicy.budget
        overrideBudget.standardDecodeTokens = 180
        overrideBudget.unstableDecodeTokens = 210
        overrideBudget.guardedDecodeTokens = 240
        overrideBudget.maintenanceBatteryFloor = 0.4
        let providerRegistry = BASProviderRoutingPolicyRegistry(
            schemaVersion: "before.provider-routing-registry.session-engine-tests.v1",
            defaultPolicyID: "before.provider-routing.v1",
            policiesByID: [
                "before.provider-routing.v1": BASProviderRoutingPolicy(
                    schemaVersion: "before.provider-routing.v1",
                    deterministicProviderID: BASReferenceProviderRuntime.templateProviderID,
                    testingOverrideProviderID: BASReferenceProviderRuntime.testingStubProviderID,
                    preferenceOrderings: [
                        BASProviderPreferenceOrdering(
                            preferredProviderID: BASReferenceProviderRuntime.gemmaE4BProviderID,
                            orderedProviderIDs: [
                                BASReferenceProviderRuntime.gemmaE4BProviderID,
                                BASReferenceProviderRuntime.foundationModelsProviderID
                            ]
                        )
                    ]
                )
            ]
        )
        let runtimeRegistry = BASEBrainRuntimeSynthesisPolicyRegistry(
            schemaVersion: "before.runtime-tuning-registry.session-engine-tests.v1",
            defaultPolicyID: "before.host.runtime-synthesis.v1",
            policiesByID: [
                "before.host.runtime-synthesis.v1": baselineRuntimePolicy,
                "override.runtime-tuning.v2": BASEBrainRuntimeSynthesisPolicy(
                    schemaVersion: "override.runtime-tuning.v2",
                    guardrailPressure: .init(
                        protectiveBoundaryIncrement: 0.21,
                        calibrationWatchIncrement: 0.11,
                        calibrationDriftingIncrement: 0.19,
                        boundaryConstraintUnit: 0.04,
                        boundaryConstraintCap: 0.20,
                        calibrationAlertUnit: 0.04,
                        calibrationAlertCap: 0.16,
                        failureGuardUnit: 0.03,
                        failureGuardCap: 0.13,
                        riskFlagUnit: 0.04,
                        riskFlagCap: 0.15,
                        maximumPressure: 0.68
                    ),
                    budget: overrideBudget,
                    wakeIntent: baselineRuntimePolicy.wakeIntent,
                    stateTransitions: baselineRuntimePolicy.stateTransitions,
                    lease: baselineRuntimePolicy.lease,
                    maintenance: baselineRuntimePolicy.maintenance,
                    sovereignExecution: baselineRuntimePolicy.sovereignExecution,
                    hostThresholds: .init(
                        caution: 0.48,
                        protective: 0.75,
                        block: 0.95
                    ),
                    context: baselineRuntimePolicy.context,
                    triSelf: baselineRuntimePolicy.triSelf,
                    risk: baselineRuntimePolicy.risk
                )
            ]
        )

        return BeforeRuntimePolicyBundle(
            schemaVersion: "before.runtime-policy-bundle.v1",
            bundleVersion: bundleVersion,
            providerRoutingRegistry: providerRegistry,
            providerRoutingPolicyID: "before.provider-routing.v1",
            runtimeTuningRegistry: runtimeRegistry,
            runtimeTuningPolicyID: runtimeTuningPolicyID,
            updatedAt: Date(timeIntervalSince1970: 1_713_715_200)
        )
    }
}
