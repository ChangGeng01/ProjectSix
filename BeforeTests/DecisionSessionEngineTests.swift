import XCTest
import BASHostKit
@testable import Before

final class DecisionSessionEngineTests: XCTestCase {
    func testCheckpointSummaryRecognizesLegacyReviewTaskPrefix() {
        let summary = DecisionSessionCheckpointSummary(
            goal: "hold boundary",
            acceptedConstraints: [],
            confirmedFacts: [],
            openTasks: ["Review: Hold before sending"],
            currentScope: ["ebrain"]
        )

        XCTAssertEqual(summary.eBrainTaskLine, "Review: Hold before sending")
    }

    func testCheckpointRuntimeStatePersistsStructuredEBrainAnchor() async throws {
        let engine = try makeEngine()
        let session = try await engine.createSession(title: "anchor persistence")

        let created = try await engine.createCheckpoint(
            sessionId: session.id,
            draft: DecisionSessionCheckpointDraft(
                summary: DecisionSessionCheckpointSummary(
                    goal: "preserve structured anchor",
                    acceptedConstraints: [],
                    confirmedFacts: [],
                    openTasks: [],
                    currentScope: ["ebrain"]
                ),
                runtimeState: DecisionSessionCheckpointRuntimeState(
                    workspacePath: "/project/a",
                    branchName: "feature/parser",
                    activeFiles: ["src/parser.ts"],
                    currentMode: .review,
                    eBrainAnchor: DecisionSessionCheckpointEBrainAnchor(
                        sessionID: "sess-anchor",
                        thoughtFoldChecksum: "fold9abc12345",
                        riskLevel: "guarded",
                        permitMode: "replace",
                        hostGatePercent: 61,
                        reviewDirectiveLine: "  Review update ticket: preserve parser-only correction  ",
                        executionCapability: DecisionSessionCheckpointExecutionCapability(
                            activeProviderID: DecisionModelProviderKind.foundationModels.rawValue,
                            preferredProviderID: DecisionModelProviderPreference.foundationModels.rawValue,
                            fallbackProviderID: DecisionModelProviderKind.gemmaE4B.rawValue,
                            providerTrackID: DecisionModelProviderTrack.builtInSystem.rawValue,
                            executionTierID: DecisionIntelligenceExecutionTier.systemManaged.rawValue,
                            foundationTierID: DecisionEBrainFoundationTier.systemManaged.rawValue,
                            reasonCodes: [
                                "tier:\(DecisionIntelligenceExecutionTier.systemManaged.rawValue)",
                                "active:\(DecisionModelProviderKind.foundationModels.rawValue)",
                                "preferred:\(DecisionModelProviderPreference.foundationModels.rawValue)",
                                "fallback:\(DecisionModelProviderKind.gemmaE4B.rawValue)",
                                "foundation_available"
                            ]
                        )
                    )
                )
            )
        )

        let latestCheckpoint = try await engine.getLatestCheckpoint(
            sessionId: session.id,
            branchId: created.branchId
        )
        let fetched = try XCTUnwrap(latestCheckpoint)

        XCTAssertEqual(fetched.runtimeState.eBrainAnchor?.sessionID, "sess-anchor")
        XCTAssertEqual(fetched.runtimeState.eBrainAnchor?.thoughtFoldChecksum, "fold9abc12345")
        XCTAssertEqual(fetched.runtimeState.eBrainAnchor?.riskLevel, "guarded")
        XCTAssertEqual(fetched.runtimeState.eBrainAnchor?.permitMode, "replace")
        XCTAssertEqual(fetched.runtimeState.eBrainAnchor?.hostGatePercent, 61)
        XCTAssertEqual(
            fetched.runtimeState.eBrainAnchor?.reviewDirectiveLine,
            "Review update ticket: preserve parser-only correction"
        )
        XCTAssertEqual(
            fetched.runtimeState.eBrainAnchor?.executionCapability?.activeProviderID,
            DecisionModelProviderKind.foundationModels.rawValue
        )
        XCTAssertEqual(
            fetched.runtimeState.eBrainAnchor?.executionCapability?.fallbackProviderID,
            DecisionModelProviderKind.gemmaE4B.rawValue
        )
        XCTAssertEqual(
            fetched.runtimeState.eBrainAnchor?.executionCapability?.foundationTierID,
            DecisionEBrainFoundationTier.systemManaged.rawValue
        )
        XCTAssertEqual(
            fetched.runtimeState.eBrainAnchor?.executionCapabilityFrame?.detailLine,
            "Capability systemManaged • Foundation systemManaged • Posture trustedProduction • Boundary externalTraining • Active Apple Foundation Model • Preferred Apple Foundation Model • Track builtInSystem • Fallback Gemma 4 E4B"
        )
        XCTAssertEqual(
            fetched.runtimeState.eBrainAnchor?.executionCapabilityFrame?.horizonLine,
            "Horizon worldPriorFabric • Stability invariant • Evidence grounded • Host hostIsolated • Session sessionIsolated • Tool toolRefreshRequired"
        )
        XCTAssertEqual(
            fetched.runtimeState.eBrainAnchor?.executionCapabilityFrame?.stabilityTierID,
            DecisionEBrainHorizonStabilityTier.invariant.rawValue
        )
        XCTAssertEqual(
            fetched.runtimeState.eBrainAnchor?.executionCapabilityFrame?.evidenceGradientID,
            DecisionEBrainEvidenceGradient.grounded.rawValue
        )
    }

    func testCheckpointRuntimeStatePersistsExplicitHorizonContracts() async throws {
        let engine = try makeEngine()
        let session = try await engine.createSession(title: "explicit horizon persistence")
        let worldPrior = DecisionEBrainWorldPriorContract(
            priorID: "worldPriorFabric.experimental",
            posture: .heuristicPreview,
            boundaryID: "referenceOnly",
            hostIsolationID: "hostQuarantined",
            sessionIsolationID: "sessionScoped",
            toolTruthModeID: "toolObserved"
        )
        let temporal = DecisionEBrainTemporalKnowledgeContract(
            tier: .volatile,
            refreshRequirement: .perUse,
            decayPolicy: .sessionRecompute,
            timeScope: .runtimeWindow
        )
        let evidence = DecisionEBrainEvidenceContract(
            gradient: .heuristic,
            claimType: .heuristicEstimate,
            requiresCaveat: true,
            requiresExternalRefresh: true
        )

        let created = try await engine.createCheckpoint(
            sessionId: session.id,
            draft: DecisionSessionCheckpointDraft(
                summary: DecisionSessionCheckpointSummary(
                    goal: "preserve explicit horizon contracts",
                    acceptedConstraints: [],
                    confirmedFacts: [],
                    openTasks: [],
                    currentScope: ["ebrain"]
                ),
                runtimeState: DecisionSessionCheckpointRuntimeState(
                    workspacePath: "/project/horizon",
                    branchName: "feature/horizon",
                    activeFiles: ["Sources/Horizon.swift"],
                    currentMode: .review,
                    eBrainAnchor: DecisionSessionCheckpointEBrainAnchor(
                        sessionID: "sess-horizon",
                        thoughtFoldChecksum: "fold-explicit-horizon",
                        riskLevel: "guarded",
                        permitMode: "delay",
                        hostGatePercent: 58,
                        reviewDirectiveLine: "Review horizon contract integrity.",
                        executionCapability: DecisionSessionCheckpointExecutionCapability(
                            activeProviderID: DecisionModelProviderKind.openModel.rawValue,
                            preferredProviderID: DecisionModelProviderPreference.openModel.rawValue,
                            fallbackProviderID: DecisionModelProviderKind.template.rawValue,
                            providerTrackID: DecisionModelProviderTrack.builtInOpenModel.rawValue,
                            executionTierID: DecisionIntelligenceExecutionTier.balancedGemma.rawValue,
                            foundationTierID: DecisionEBrainFoundationTier.openModelHeuristic.rawValue,
                            reasonCodes: ["external_refresh:yes"],
                            worldPriorContract: worldPrior,
                            temporalKnowledgeContract: temporal,
                            evidenceContract: evidence
                        )
                    )
                )
            )
        )

        let latestCheckpoint = try await engine.getLatestCheckpoint(
            sessionId: session.id,
            branchId: created.branchId
        )
        let fetched = try XCTUnwrap(latestCheckpoint)
        let restoredFrame = try XCTUnwrap(
            fetched.runtimeState.eBrainAnchor?.executionCapabilityFrame
        )

        XCTAssertEqual(restoredFrame.worldPriorContract.priorID, "worldPriorFabric.experimental")
        XCTAssertEqual(restoredFrame.worldPriorContract.posture, .heuristicPreview)
        XCTAssertEqual(restoredFrame.worldPriorContract.boundaryID, "referenceOnly")
        XCTAssertEqual(restoredFrame.worldPriorContract.hostIsolationID, "hostQuarantined")
        XCTAssertEqual(restoredFrame.worldPriorContract.sessionIsolationID, "sessionScoped")
        XCTAssertEqual(restoredFrame.worldPriorContract.toolTruthModeID, "toolObserved")
        XCTAssertEqual(restoredFrame.temporalKnowledgeContract.tier, .volatile)
        XCTAssertEqual(restoredFrame.temporalKnowledgeContract.refreshRequirement, .perUse)
        XCTAssertEqual(restoredFrame.temporalKnowledgeContract.decayPolicy, .sessionRecompute)
        XCTAssertEqual(restoredFrame.temporalKnowledgeContract.timeScope, .runtimeWindow)
        XCTAssertEqual(restoredFrame.evidenceContract.gradient, .heuristic)
        XCTAssertEqual(restoredFrame.evidenceContract.claimType, .heuristicEstimate)
        XCTAssertEqual(restoredFrame.evidenceContract.requiresCaveat, true)
        XCTAssertEqual(restoredFrame.evidenceContract.requiresExternalRefresh, true)
        XCTAssertEqual(
            restoredFrame.horizonLine,
            "Horizon worldPriorFabric.experimental • Stability volatile • Evidence heuristic • Host hostQuarantined • Session sessionScoped • Tool toolObserved"
        )
        XCTAssertEqual(
            restoredFrame.temporalLine,
            "Temporal volatile • Refresh perUse • Decay sessionRecompute • Scope runtimeWindow"
        )
        XCTAssertEqual(
            restoredFrame.evidenceLine,
            "Evidence heuristic • Claim heuristicEstimate • Caveat yes • External refresh yes"
        )
    }

    func testCorrectionCreatesBranchWithoutDestroyingOriginalHistory() async throws {
        let engine = try makeEngine()
        let session = try await engine.createSession(title: "parser repair")
        let originalBranchID = session.headBranchId

        for index in 1...25 {
            _ = try await engine.appendUserMessage(
                sessionId: session.id,
                text: "turn \(index) user"
            )
            _ = try await engine.appendAssistantMessage(
                sessionId: session.id,
                text: "turn \(index) assistant",
                summary: "assistant \(index)"
            )
        }

        let firstEvent = try await engine.listEvents(
            sessionId: session.id,
            branchId: originalBranchID
        ).first
        XCTAssertNotNil(firstEvent)

        let correction = try await engine.appendCorrection(
            sessionId: session.id,
            targetEventId: try XCTUnwrap(firstEvent?.id),
            newText: "only fix parser, do not rewrite the module"
        )

        let updatedSession = try await engine.getSession(session.id)
        XCTAssertNotEqual(updatedSession.headBranchId, originalBranchID)
        XCTAssertEqual(updatedSession.headBranchId, correction.branch.id)
        XCTAssertEqual(correction.branch.parentBranchId, originalBranchID)
        XCTAssertNotNil(correction.checkpoint)

        let originalEvents = try await engine.listEvents(
            sessionId: session.id,
            branchId: originalBranchID
        )
        XCTAssertTrue(originalEvents.contains(where: { $0.id == firstEvent?.id }))
        XCTAssertFalse(originalEvents.contains(where: { $0.type == .correctionAdded }))

        let correctionEvents = try await engine.listEvents(
            sessionId: session.id,
            branchId: correction.branch.id
        )
        XCTAssertTrue(correctionEvents.contains(where: { $0.type == .branchCreated }))
        XCTAssertTrue(correctionEvents.contains(where: { $0.type == .correctionAdded }))

        _ = try await engine.appendAssistantMessage(
            sessionId: session.id,
            text: "continuing on correction branch",
            branchId: correction.branch.id
        )
        let continuedEvents = try await engine.listEvents(
            sessionId: session.id,
            branchId: correction.branch.id
        )
        XCTAssertTrue(continuedEvents.contains(where: { $0.type == .assistantMessage }))
    }

    func testWatchdogRecoversSessionFromIncompleteToolStep() async throws {
        let engine = try makeEngine()
        let session = try await engine.createSession(title: "tool crash")
        let checkpoint = try await engine.createCheckpoint(
            sessionId: session.id,
            draft: DecisionSessionCheckpointDraft(
                summary: DecisionSessionCheckpointSummary(
                    goal: "finish tool safely",
                    acceptedConstraints: ["keep history"],
                    confirmedFacts: ["tool call is next"],
                    openTasks: ["run tool"],
                    currentScope: ["parser"]
                ),
                runtimeState: DecisionSessionCheckpointRuntimeState(
                    workspacePath: "/project/a",
                    branchName: "feature/parser",
                    activeFiles: ["src/parser.ts"],
                    currentMode: .code
                )
            )
        )

        _ = try await engine.appendToolCallStarted(
            sessionId: session.id,
            tool: "file_write",
            argsPreview: ["path": "src/parser.ts"]
        )
        let step = try await engine.startStep(
            sessionId: session.id,
            status: .waitingTool,
            ttlMs: 50
        )

        let actions = try await engine.sweepWatchdog(
            now: Date(timeIntervalSinceNow: 1)
        )
        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions.first?.stepId, step.id)

        let recoveredSession = try await engine.getSession(session.id)
        XCTAssertEqual(recoveredSession.status, .active)
        XCTAssertNotEqual(recoveredSession.headBranchId, session.headBranchId)

        let branches = try await engine.listBranches(sessionId: session.id)
        XCTAssertEqual(branches.count, 2)

        let recoveredTimeline = try await engine.rebuildTimeline(
            sessionId: session.id,
            branchId: recoveredSession.headBranchId
        )
        XCTAssertEqual(recoveredTimeline.checkpoint?.summary.goal, checkpoint.summary.goal)
        XCTAssertEqual(
            recoveredTimeline.checkpoint?.runtimeState.branchName,
            checkpoint.runtimeState.branchName
        )
        XCTAssertTrue(recoveredTimeline.items.contains(where: { item in
            if case .event(let event) = item.kind {
                return event.type == .sessionRecovered
            }
            return false
        }))
    }

    func testTimelineCanBeRebuiltAfterEngineRestart() async throws {
        let directory = try makeTemporaryDirectory()
        var engine: DecisionSessionEngine? = try makeEngine(baseDirectoryURL: directory)
        let session = try await engine?.createSession(title: "timeline rebuild")
        let sessionId = try XCTUnwrap(session?.id)

        _ = try await engine?.appendUserMessage(sessionId: sessionId, text: "hello")
        _ = try await engine?.appendAssistantMessage(
            sessionId: sessionId,
            text: "world",
            summary: "stable output"
        )
        _ = try await engine?.createCheckpoint(sessionId: sessionId)
        await engine?.shutdown()
        engine = nil

        let reopened = try makeEngine(baseDirectoryURL: directory)
        let reopenedSession = try await reopened.getSession(sessionId)
        let timeline = try await reopened.rebuildTimeline(
            sessionId: reopenedSession.id,
            branchId: reopenedSession.headBranchId
        )

        XCTAssertGreaterThanOrEqual(timeline.items.count, 1)
        XCTAssertTrue(timeline.items.contains(where: { item in
            if case .checkpoint = item.kind {
                return true
            }
            return false
        }))
    }

    func testDatabaseReopensAtLastCommittedTransactionPoint() async throws {
        let directory = try makeTemporaryDirectory()
        let first = try makeEngine(baseDirectoryURL: directory)
        let session = try await first.createSession(title: "reopen safety")
        _ = try await first.appendUserMessage(sessionId: session.id, text: "persist me")
        _ = try await first.appendAssistantMessage(sessionId: session.id, text: "persisted")
        let snapshotBefore = try await first.snapshot()
        XCTAssertGreaterThan(snapshotBefore.events, 0)
        await first.shutdown()

        let reopened = try makeEngine(baseDirectoryURL: directory)
        let snapshotAfter = try await reopened.snapshot()
        XCTAssertEqual(snapshotAfter.sessions, snapshotBefore.sessions)
        XCTAssertEqual(snapshotAfter.events, snapshotBefore.events)

        let timeline = try await reopened.rebuildTimeline(sessionId: session.id)
        XCTAssertFalse(timeline.items.isEmpty)
    }

    func testMultipleCorrectionsNeverOverwriteOriginalBranch() async throws {
        let engine = try makeEngine()
        let session = try await engine.createSession(title: "branch fan-out")
        let originalBranchID = session.headBranchId
        let originalEvent = try await engine.appendUserMessage(
            sessionId: session.id,
            text: "keep branch history"
        )

        var currentSession = session
        for index in 1...3 {
            let correction = try await engine.appendCorrection(
                sessionId: currentSession.id,
                targetEventId: originalEvent.id,
                newText: "correction \(index)"
            )
            currentSession = try await engine.getSession(currentSession.id)
            XCTAssertEqual(currentSession.headBranchId, correction.branch.id)
        }

        let branches = try await engine.listBranches(sessionId: session.id)
        XCTAssertEqual(branches.count, 4)

        let originalEvents = try await engine.listEvents(
            sessionId: session.id,
            branchId: originalBranchID
        )
        XCTAssertEqual(originalEvents.filter { $0.type == .correctionAdded }.count, 0)

        let switched = try await engine.switchBranch(
            sessionId: session.id,
            branchId: originalBranchID
        )
        XCTAssertEqual(switched.headBranchId, originalBranchID)

        let switchedTimeline = try await engine.rebuildTimeline(
            sessionId: switched.id,
            branchId: originalBranchID
        )
        XCTAssertEqual(switchedTimeline.branchId, originalBranchID)
        XCTAssertTrue(switchedTimeline.items.allSatisfy { $0.branchId == originalBranchID })
        XCTAssertFalse(switchedTimeline.items.contains(where: { item in
            if case .event(let event) = item.kind {
                return event.type == .correctionAdded
            }
            return false
        }))
    }

    func testMergeMarksSourceMergedAndAppendsMergeEventOnTargetBranch() async throws {
        let engine = try makeEngine()
        let session = try await engine.createSession(title: "merge branches")
        let baseBranchID = session.headBranchId

        _ = try await engine.appendUserMessage(
            sessionId: session.id,
            text: "keep this main line stable"
        )

        let baseEvents = try await engine.listEvents(
            sessionId: session.id,
            branchId: baseBranchID
        )
        let baseEvent = try XCTUnwrap(baseEvents.first)

        let correction = try await engine.appendCorrection(
            sessionId: session.id,
            targetEventId: baseEvent.id,
            newText: "parser-only recovery branch"
        )
        let mergedBranch = try await engine.mergeBranch(
            sourceBranchId: correction.branch.id,
            targetBranchId: baseBranchID
        )

        XCTAssertEqual(mergedBranch.status, .merged)

        let targetEvents = try await engine.listEvents(
            sessionId: session.id,
            branchId: baseBranchID
        )
        XCTAssertTrue(targetEvents.contains(where: { $0.type == .branchMerged }))

        let targetTimeline = try await engine.rebuildTimeline(
            sessionId: session.id,
            branchId: baseBranchID
        )
        XCTAssertTrue(targetTimeline.items.contains(where: { item in
            if case .event(let event) = item.kind {
                return event.type == .branchMerged
            }
            return false
        }))
    }

    func testSnapshotIncludesRecentSessionInspectionAndRecoveryDetails() async throws {
        let engine = try makeEngine()
        let session = try await engine.createSession(title: "inspection surface")

        _ = try await engine.appendUserMessage(
            sessionId: session.id,
            text: "repair parser only",
            checkpointDraft: DecisionSessionCheckpointDraft(
                summary: DecisionSessionCheckpointSummary(
                    goal: "repair parser",
                    acceptedConstraints: ["keep branch history"],
                    confirmedFacts: ["parser is isolated"],
                    openTasks: ["write patch"],
                    currentScope: ["src/parser.ts"]
                ),
                runtimeState: DecisionSessionCheckpointRuntimeState(
                    workspacePath: "/project/session",
                    branchName: "feature/parser",
                    activeFiles: ["src/parser.ts"],
                    currentMode: .code
                )
            )
        )
        _ = try await engine.appendAssistantMessage(
            sessionId: session.id,
            text: "checkpointed reply",
            summary: "stable parser plan"
        )
        _ = try await engine.createCheckpoint(
            sessionId: session.id,
            draft: DecisionSessionCheckpointDraft(
                summary: DecisionSessionCheckpointSummary(
                    goal: "repair parser",
                    acceptedConstraints: ["keep branch history"],
                    confirmedFacts: ["checkpoint ready"],
                    openTasks: ["resume safely"],
                    currentScope: ["src/parser.ts"]
                ),
                runtimeState: DecisionSessionCheckpointRuntimeState(
                    workspacePath: "/project/session",
                    branchName: "feature/parser",
                    activeFiles: ["src/parser.ts"],
                    currentMode: .code
                )
            )
        )
        let step = try await engine.startStep(
            sessionId: session.id,
            status: .waitingTool,
            ttlMs: 50
        )
        _ = try await engine.sweepWatchdog(now: Date(timeIntervalSinceNow: 1))

        let snapshot = try await engine.snapshot()
        let inspected = try XCTUnwrap(snapshot.recentSessions.first(where: { $0.sessionID == session.id }))

        XCTAssertEqual(snapshot.layerPlacement, .foldedLung)
        XCTAssertGreaterThanOrEqual(snapshot.sessions, 1)
        XCTAssertEqual(inspected.title, "inspection surface")
        XCTAssertEqual(inspected.status, .active)
        XCTAssertNotNil(inspected.latestCheckpointID)
        XCTAssertEqual(inspected.latestCheckpointGoal, "repair parser")
        XCTAssertEqual(inspected.latestEventType, .stepRecovered)
        XCTAssertGreaterThanOrEqual(inspected.branchCount, 2)
        XCTAssertGreaterThanOrEqual(inspected.recoveryCount, 1)
        XCTAssertNotNil(inspected.latestRecoveryAt)
        XCTAssertTrue(inspected.detailLine.contains("recoveries"))
        XCTAssertNotEqual(inspected.headBranchID, session.headBranchId)
        XCTAssertFalse(inspected.headline.isEmpty)
        XCTAssertGreaterThanOrEqual(inspected.mergeableBranchCount, 1)
        XCTAssertTrue(inspected.mergeReviewLine?.contains("Merge review") == true)

        let failedStepTimeline = try await engine.rebuildTimeline(
            sessionId: session.id,
            branchId: inspected.headBranchID
        )
        XCTAssertTrue(failedStepTimeline.recoveryNotice != nil)
        XCTAssertEqual(step.status, .waitingTool)
    }

    func testExportImportRoundTripPreservesBranchRecoveryAndMergeFacts() async throws {
        let engine = try makeEngine()
        let session = try await engine.createSession(title: "export import session")
        let baseBranchID = session.headBranchId

        _ = try await engine.appendUserMessage(
            sessionId: session.id,
            text: "stabilize parser without rewriting the whole module"
        )
        _ = try await engine.appendAssistantMessage(
            sessionId: session.id,
            text: "working on the parser-only version",
            summary: "parser-only plan"
        )

        let baseEvents = try await engine.listEvents(sessionId: session.id, branchId: baseBranchID)
        let baseEvent = try XCTUnwrap(baseEvents.first)

        let correction = try await engine.appendCorrection(
            sessionId: session.id,
            targetEventId: baseEvent.id,
            newText: "branch into a correction line that only touches parser scope"
        )
        _ = try await engine.appendAssistantMessage(
            sessionId: session.id,
            text: "correction branch progress",
            branchId: correction.branch.id
        )
        _ = try await engine.mergeBranch(
            sourceBranchId: correction.branch.id,
            targetBranchId: baseBranchID
        )
        _ = try await engine.switchBranch(sessionId: session.id, branchId: baseBranchID)

        _ = try await engine.createCheckpoint(
            sessionId: session.id,
            draft: DecisionSessionCheckpointDraft(
                summary: DecisionSessionCheckpointSummary(
                    goal: "export/import stable parser work",
                    acceptedConstraints: ["keep append-only history"],
                    confirmedFacts: ["merge recorded on main branch"],
                    openTasks: ["verify recovery branch survives export"],
                    currentScope: ["src/parser.ts"]
                ),
                runtimeState: DecisionSessionCheckpointRuntimeState(
                    workspacePath: "/project/export-import",
                    branchName: "feature/parser",
                    activeFiles: ["src/parser.ts"],
                    currentMode: .code
                )
            )
        )

        _ = try await engine.startStep(
            sessionId: session.id,
            status: .waitingTool,
            ttlMs: 50
        )
        _ = try await engine.sweepWatchdog(now: Date(timeIntervalSinceNow: 1))

        let recoveredSession = try await engine.getSession(session.id)
        _ = try await engine.startStep(
            sessionId: recoveredSession.id,
            status: .waitingTool,
            ttlMs: 500
        )

        let exportURL = try await engine.exportSession(session.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        let importedSession = try await engine.importSession(from: exportURL)
        XCTAssertNotEqual(importedSession.id, session.id)
        XCTAssertEqual(importedSession.status, .paused)
        XCTAssertEqual(importedSession.title, "export import session (Imported)")

        let sourceBranches = try await engine.listBranches(sessionId: session.id)
        let importedBranches = try await engine.listBranches(sessionId: importedSession.id)
        XCTAssertEqual(importedBranches.count, sourceBranches.count)

        let importedSteps = try await engine.listAllSteps(sessionId: importedSession.id)
        XCTAssertTrue(importedSteps.contains(where: {
            $0.status == .failed && $0.errorCode == "imported_unfinished_step"
        }))

        let importedHeadTimeline = try await engine.rebuildTimeline(
            sessionId: importedSession.id,
            branchId: importedSession.headBranchId
        )
        XCTAssertTrue(importedHeadTimeline.items.contains(where: { item in
            if case .event(let event) = item.kind {
                return event.type == .sessionRecovered
            }
            return false
        }))

        let importedMainBranch = try XCTUnwrap(importedBranches.first(where: { $0.parentBranchId == nil }))
        let importedMainEvents = try await engine.listEvents(
            sessionId: importedSession.id,
            branchId: importedMainBranch.id
        )
        XCTAssertTrue(importedMainEvents.contains(where: { $0.type == .branchMerged }))

        let latestImportedCheckpoint = try await engine.getLatestCheckpoint(
            sessionId: importedSession.id,
            branchId: importedSession.headBranchId
        )
        XCTAssertNotNil(latestImportedCheckpoint)
    }

    func testRebuildTimelineSurfacesMergeNoticeWhenCheckpointFoldsMergeFact() async throws {
        let engine = try makeEngine()
        let session = try await engine.createSession(title: "merge visibility")
        let baseBranchID = session.headBranchId

        _ = try await engine.appendUserMessage(
            sessionId: session.id,
            text: "Only fix parser scope."
        )
        let baseEvents = try await engine.listEvents(sessionId: session.id, branchId: baseBranchID)
        let baseEvent = try XCTUnwrap(baseEvents.first)

        let correction = try await engine.appendCorrection(
            sessionId: session.id,
            targetEventId: baseEvent.id,
            newText: "Branch parser-only work into a correction line."
        )
        _ = try await engine.appendAssistantMessage(
            sessionId: session.id,
            text: "correction branch progress",
            branchId: correction.branch.id
        )
        _ = try await engine.mergeBranch(
            sourceBranchId: correction.branch.id,
            targetBranchId: baseBranchID
        )
        _ = try await engine.switchBranch(sessionId: session.id, branchId: baseBranchID)
        _ = try await engine.createCheckpoint(
            sessionId: session.id,
            draft: DecisionSessionCheckpointDraft(
                summary: DecisionSessionCheckpointSummary(
                    goal: "parser-only repair",
                    acceptedConstraints: ["keep append-only history"],
                    confirmedFacts: ["merge already recorded"],
                    openTasks: ["continue safely"],
                    currentScope: ["src/parser.ts"]
                ),
                runtimeState: .empty
            )
        )

        let timeline = try await engine.rebuildTimeline(
            sessionId: session.id,
            branchId: baseBranchID
        )

        XCTAssertNotNil(timeline.checkpoint)
        XCTAssertTrue(timeline.items.allSatisfy { item in
            if case .event(let event) = item.kind {
                return event.type != .branchMerged
            }
            return true
        })
        XCTAssertTrue(timeline.mergeNotice?.contains("correction-") == true)
        XCTAssertTrue(timeline.mergeNotice?.contains("folded in merge facts") == true)
    }

    func testInspectImportBundleSummarizesPausedRecoveryFactsBeforeImport() async throws {
        let engine = try makeEngine()
        let session = try await engine.createSession(title: "inspect bundle")
        _ = try await engine.appendUserMessage(sessionId: session.id, text: "keep this safe")
        _ = try await engine.appendAssistantMessage(sessionId: session.id, text: "stable answer", summary: "stable")
        _ = try await engine.startStep(sessionId: session.id, status: .waitingTool, ttlMs: 500)
        _ = try await engine.createCheckpoint(
            sessionId: session.id,
            draft: DecisionSessionCheckpointDraft(
                summary: DecisionSessionCheckpointSummary(
                    goal: "inspect bundle goal",
                    acceptedConstraints: ["preserve history"],
                    confirmedFacts: ["bundle exists"],
                    openTasks: ["resume later"],
                    currentScope: ["parser"]
                ),
                runtimeState: .empty
            )
        )

        let exportURL = try await engine.exportSession(session.id)
        let preview = try await engine.inspectImportBundle(from: exportURL)

        XCTAssertEqual(preview.sourceSessionId, session.id)
        XCTAssertEqual(preview.sourceTitle, "inspect bundle")
        XCTAssertTrue(preview.importedTitle.hasSuffix("(Imported)"))
        XCTAssertTrue(preview.countsLine.contains("Branches 1"))
        XCTAssertTrue(preview.integrityLine.contains("Validated schema v1"))
        XCTAssertTrue(preview.checkpointLine.contains("inspect bundle goal"))
        XCTAssertTrue(preview.unfinishedStepsLine.contains("failed recovery facts"))
        XCTAssertEqual(preview.branchPreviews.first?.name, "main")
    }

    func testInspectImportBundleRejectsTamperedFingerprint() async throws {
        let engine = try makeEngine()
        let session = try await engine.createSession(title: "tamper guard")
        _ = try await engine.appendUserMessage(sessionId: session.id, text: "keep this immutable")
        _ = try await engine.appendAssistantMessage(sessionId: session.id, text: "recorded", summary: "recorded")

        let exportURL = try await engine.exportSession(session.id)
        let exportData = try Data(contentsOf: exportURL)
        let bundle = try JSONDecoder().decode(DecisionSessionExportBundle.self, from: exportData)

        let tamperedBundle = DecisionSessionExportBundle(
            manifest: DecisionSessionExportManifest(
                schemaVersion: bundle.manifest.schemaVersion,
                exportedAt: bundle.manifest.exportedAt,
                layerPlacement: bundle.manifest.layerPlacement,
                sourceSessionId: bundle.manifest.sourceSessionId,
                sourceHeadBranchId: bundle.manifest.sourceHeadBranchId,
                sourceLatestCheckpointId: bundle.manifest.sourceLatestCheckpointId,
                sourceTitle: bundle.manifest.sourceTitle,
                counts: bundle.manifest.counts,
                bundleFingerprint: "tampered-fingerprint"
            ),
            session: bundle.session,
            branches: bundle.branches,
            checkpoints: bundle.checkpoints,
            events: bundle.events,
            steps: bundle.steps
        )

        let tamperedURL = exportURL.deletingLastPathComponent().appendingPathComponent("tampered.before-session.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(tamperedBundle).write(to: tamperedURL, options: .atomic)

        do {
            _ = try await engine.inspectImportBundle(from: tamperedURL)
            XCTFail("Expected tampered Session Engine bundle fingerprint to be rejected.")
        } catch {
            XCTAssertTrue(
                error.localizedDescription.contains("fingerprint validation failed"),
                "Unexpected error: \(error.localizedDescription)"
            )
        }
    }

    private func makeEngine(baseDirectoryURL: URL? = nil) throws -> DecisionSessionEngine {
        let directory = try baseDirectoryURL ?? makeTemporaryDirectory()
        return try DecisionSessionEngine(
            configuration: DecisionSessionEngineConfiguration(
                baseDirectoryURL: directory,
                defaultToolTTL: 100,
                defaultPlanningTTL: 100,
                defaultWritingTTL: 100,
                eventCompactionStride: 8
            )
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
