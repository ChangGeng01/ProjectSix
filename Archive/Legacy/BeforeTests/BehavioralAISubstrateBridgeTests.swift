import Foundation
import SwiftData
import Testing
import BASHostKit
// M86 — BASMemory is @_exported from BASHostKit.
@testable import Before

@MainActor
struct BehavioralAISubstrateBridgeTests {
    @Test
    func lineageSummaryRoundTripsExtendedCheckpointFabricFacts() throws {
        let summary = BASEvolutionLineageSummary(
            recordedAt: date("2026-04-16T11:20:00Z"),
            sessionID: "session-fabric",
            runMode: .guard,
            taskType: "high_pressure",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 84,
            thoughtFoldChecksum: "fold-fabric",
            updateTicketSummaries: ["Hold before promote"],
            reviewDirectiveLine: "Review host drift",
            activeKillSwitches: ["force_guard_mode"],
            guardrailFindings: ["protective boundary held"],
            recommendedKillSwitches: ["disableHighRiskAutoAction"],
            neuralMorphID: "morph.guard",
            activeOrganIDs: ["stubCore", "riskSpine", "permitKnot"],
            headGuarantees: ["permit", "rollback"],
            frontierWidth: 3,
            bindingCount: 2,
            degradedReasonCodes: ["thermal_guard"],
            foldedLungSummary: BASEvolutionFoldedLungSummary(
                morphGraphID: "morph.guard",
                precisionProfileID: "precision.guard",
                lungStateRef: "lung.guard",
                breathMode: "guard",
                breathPhase: "exchange",
                thermalPressure: 77,
                cachePressure: 41,
                restoreReadinessPercent: 84,
                resumeID: "resume.guard",
                sourceFoldID: "fold-fabric",
                resumeDepth: 2,
                requiredOrganIDs: ["stubCore", "riskSpine", "permitKnot"],
                consistencyChecks: ["fold_checksum", "risk_permit", "host_gate"],
                fallbackMode: "rollbackAnchor",
                rollbackAnchorID: "anchor.guard",
                safeSnapshotRef: "snapshot.guard",
                foldRefs: ["fold-fabric"],
                hostVersionRef: "host.v4",
                cacheStateRef: "cache.guard",
                integrityHash: "integrity.guard",
                sovereignActuationKinds: [.rollback, .memoryFreeze],
                invalidatedResumeFrameIDs: ["resume.guard"],
                invalidatedCacheRefs: ["cache.guard", "memory-write:session-fabric"],
                invalidatedFoldRefs: ["fold-fabric"],
                quarantinedFoldRefs: [],
                resultingBreathMode: "guard",
                preservedReadOnlyRecovery: true,
                sovereignBridgeSummary: "Sovereign bridge • rollback, memoryFreeze • mode guard"
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let encoded = try encoder.encode(summary)
        let decoded = try decoder.decode(BASEvolutionLineageSummary.self, from: encoded)

        #expect(decoded.neuralMorphID == "morph.guard")
        #expect(decoded.activeOrganIDs == ["stubCore", "riskSpine", "permitKnot"])
        #expect(decoded.headGuarantees == ["permit", "rollback"])
        #expect(decoded.frontierWidth == 3)
        #expect(decoded.bindingCount == 2)
        #expect(decoded.degradedReasonCodes == ["thermal_guard"])
        #expect(decoded.foldedLungSummary?.breathMode == "guard")
        #expect(decoded.foldedLungSummary?.rollbackAnchorID == "anchor.guard")
        #expect(decoded.foldedLungSummary?.invalidatedCacheRefs == ["cache.guard", "memory-write:session-fabric"])
        #expect(decoded.foldedLungSummary?.preservedReadOnlyRecovery == true)
    }

    @Test
    func consoleSnapshotPackagesRuntimeFlightDeckAndBrainState() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let bootstrapAt = date("2026-04-10T21:15:00Z")
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: bootstrapAt)
        let brainState = CurrentBrainStateLoader.bootstrapCurrentBrainState(
            mode: .quick,
            prompt: "Should I send this tonight?",
            source: .launch,
            taskGraph: nil,
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: bootstrapAt
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: DecisionMemorySystem.fetchCheckEvents(in: context),
            balance: DecisionMemorySystem.fetchBalanceRecords(in: context),
            mirror: DecisionMemorySystem.fetchMirrorRecords(in: context),
            preferences: .default
        )

        let snapshot = BehavioralAISubstrateBridge.consoleSnapshot(
            from: export,
            currentBrainState: brainState
        )

        #expect(snapshot.reports.count == DecisionSystemLayer.allCases.count)
        #expect(snapshot.isPureLocal == true)
        #expect(snapshot.runtimeSummary?.contains(export.summary.activeProvider.title) == true)
        #expect(snapshot.brainSummary?.contains(brainState.identityProfile.role.title) == true)
        #expect(snapshot.overallSummary.contains("Behavioral substrate score"))
        #expect(snapshot.capabilityCoverage != nil)
        #expect(snapshot.capabilityCoverage?.sections.contains(where: { $0.domain == .context }) == true)
        #expect(snapshot.capabilityCoverage?.sections
            .first(where: { $0.domain == .context })?
            .items
            .contains(where: { $0.id == "context.compaction" }) == true)
        #expect(snapshot.capabilityCoverage?.sections
            .first(where: { $0.domain == .orchestration })?
            .items
            .contains(where: { $0.id == "orchestration.watch_handoff" }) == true)

        let runtimeContext = BehavioralAISubstrateBridge.runtimeContext(from: export)
        #expect(runtimeContext.taskKind == BASTaskKind.chat)

        let roleProfile = BehavioralAISubstrateBridge.roleProfile(from: brainState)
        #expect(roleProfile?.name == brainState.identityProfile.role.title)

        let substrateBrain = BehavioralAISubstrateBridge.brainSnapshot(from: brainState)
        #expect(substrateBrain?.verificationSnapshot == brainState.verificationSnapshot.fingerprint)
        #expect(substrateBrain?.activeConstraints == brainState.activeConstraints)

        let intentEnvelope = BehavioralAISubstrateBridge.entryIntentEnvelope(
            from: .quickCapture(
                entrySource: .watch,
                promptSeed: "Hold this until morning.",
                riskLevel: .medium
            )
        )
        #expect(intentEnvelope.kind == .capture)
        #expect(intentEnvelope.surface == .watch)
        #expect(intentEnvelope.taskKind == BASTaskKind.chat)
        #expect(intentEnvelope.riskLevel == .medium)

        let intentSummary = BehavioralAISubstrateBridge.entryIntentSummary(
            from: .resumeCurrentDecision(
                sourceSurface: .notification,
                entrySource: .app,
                preferredMode: .balance,
                promptSeed: "Resume the hard decision.",
                riskLevel: .high,
                triggerReason: "prediction"
            )
        )
        #expect(intentSummary.requiresResume)
        #expect(intentSummary.headline.contains("Notification"))

        let handoffSummary = BehavioralAISubstrateBridge.handoffSummary(
            from: .quickCapture(
                entrySource: .watch,
                promptSeed: "Save this for tomorrow morning.",
                riskLevel: .medium
            )
        )
        #expect(handoffSummary.surface == .watch)
        #expect(handoffSummary.taskKind == .chat)
        #expect(handoffSummary.requiresResume)
    }

    @Test
    func consoleSnapshotRecoversInspectionBundleFromPersistedCheckpointLineage() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let lineageSummary = BASEvolutionLineageSummary(
            recordedAt: date("2026-04-10T07:15:00.000Z"),
            sessionID: "before.quick.lineage",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 82,
            thoughtFoldChecksum: "fold-checkpoint",
            updateTicketSummaries: ["review after cooldown"],
            guardrailFindings: ["Checkpoint guardrail matched"],
            recommendedKillSwitches: ["host-write"]
        )
        let persistedLineage = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-1",
            createdAt: date("2026-04-10T07:16:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            diffSummary: ["Checkpoint recovery pending review"],
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: lineageSummary)
        )
        let mirrorLineage = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-2",
            createdAt: date("2026-04-10T07:20:00.000Z"),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            diffSummary: ["Newer mirror checkpoint should not win"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T07:20:00.000Z"),
                    sessionID: "before.mirror.lineage",
                    taskType: "reflection",
                    riskLevel: "medium",
                    permitMode: "compare",
                    hostGatePercent: 61,
                    thoughtFoldChecksum: "fold-mirror",
                    updateTicketSummaries: ["capture calmer follow-up"],
                    guardrailFindings: ["Recovered lineage available"],
                    recommendedKillSwitches: []
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: DecisionMemorySystem.fetchCheckEvents(in: context),
            balance: [],
            mirror: [],
            preferences: .default,
            persistedCheckpointLineages: [persistedLineage, mirrorLineage],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let snapshot = BehavioralAISubstrateBridge.consoleSnapshot(
            from: export,
            currentBrainState: nil
        )
        let runtimeContext = BehavioralAISubstrateBridge.runtimeContext(from: export)
        let dataReport = try #require(snapshot.reports.first(where: { $0.layer == .data }))

        #expect(export.effectiveEBrainSource == .persistedCheckpoint)
        #expect(snapshot.inspectionBundle != nil)
        #expect(snapshot.runtimeSummary?.contains("Recovered from checkpoint") == true)
        #expect(snapshot.brainSummary?.contains("Checkpoint recovery") == true)
        #expect(snapshot.brainSummary?.contains("session before.quick.lineage") == true)
        #expect(snapshot.brainSummary?.contains("host gate 82%") == true)
        #expect(snapshot.brainSummary?.contains("1 tickets") == true)
        #expect(snapshot.effectiveLayerStackLines == persistedLineage.factsBundle.layerStackLines)
        #expect(snapshot.effectiveLayerStackLines.first?.hasPrefix("L1 power clock") == true)
        #expect(snapshot.runtimeSummary?.contains("L6 context") != true)
        #expect(snapshot.runtimeSummary?.contains("L1 power clock") != true)
        #expect(snapshot.runtimeSummary?.contains("L13 evolution") != true)
        #expect(dataReport.summary.contains("L6 context") != true)
        #expect(dataReport.summary.contains("L1 power clock") != true)
        #expect(dataReport.summary.contains("L13 evolution") != true)
        #expect(snapshot.blockerSummary.contains("Checkpoint recovery pending review"))
        #expect(snapshot.inspectionBundle?.trace.selectedRoute.preferredModelID == "persisted.checkpoint.quick")
        #expect(snapshot.inspectionBundle?.releaseDecision.kind == .requireConfirmation)
        #expect(snapshot.inspectionBundle?.anomalySignals.contains(where: { $0.kind == "checkpoint_kill_switch" }) == true)
        #expect(snapshot.capabilityCoverage?.sections.first(where: { $0.domain == .context })?.items.first(where: { $0.id == "context.summary_layer" })?.status == .ready)
        #expect(snapshot.capabilityCoverage?.sections.first(where: { $0.domain == .observability })?.items.first(where: { $0.id == "observability.self_inspection" })?.status == .ready)
        #expect(snapshot.capabilityCoverage?.sections.first(where: { $0.domain == .delivery })?.items.first(where: { $0.id == "delivery.self_portrait" })?.status == .ready)
        #expect(runtimeContext.riskLevel == .high)
    }

    @Test
    func consoleSnapshotMergesLivePressureIntoRuntimeSummary() async throws {
        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            debugStore: DecisionIntelligenceDebugStore(),
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )
        let turn = makeProtectiveTurn()

        let snapshot = BehavioralAISubstrateBridge.consoleSnapshot(
            from: export,
            currentBrainState: nil,
            eBrainTurn: turn
        )
        let attachedExport = export.attaching(eBrainTurn: turn)
        let dataReport = try #require(snapshot.reports.first(where: { $0.layer == .data }))
        let expectedWindGateLine = try #require(
            attachedExport.effectiveLayerStackLines.first(where: { $0.hasPrefix("L11 wind gate") })
        )

        #expect(snapshot.runtimeSummary?.contains("Pressure latency 3/1400ms") == true)
        #expect(snapshot.runtimeSummary?.contains("thermal cool") == true)
        #expect(snapshot.runtimeSummary?.contains(expectedWindGateLine) == true)
        #expect(snapshot.effectiveLayerStackLines == attachedExport.effectiveLayerStackLines)
        #expect(snapshot.effectiveLayerStackLines.first?.hasPrefix("L1 power clock") == true)
        #expect(snapshot.runtimeSummary?.contains("L6 context") != true)
        #expect(snapshot.runtimeSummary?.contains("L1 power clock") != true)
        #expect(snapshot.runtimeSummary?.contains("L13 evolution") != true)
        #expect(dataReport.summary.contains("L11 wind gate") != true)
        #expect(dataReport.summary.contains("L6 context") != true)
        #expect(dataReport.summary.contains("L1 power clock") != true)
        #expect(dataReport.summary.contains("L13 evolution") != true)
    }

    @Test
    func consoleSnapshotRecoversWindGateRuntimeSummaryFromPersistedCheckpointProjection() async throws {
        let lineageSummary = BASEvolutionLineageSummary(
            recordedAt: date("2026-04-10T07:15:00.000Z"),
            sessionID: "before.quick.wind-gate",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 82,
            thoughtFoldChecksum: "fold-wind-gate",
            updateTicketSummaries: ["review after cooldown"],
            reviewDirectiveLine: "review after cooldown",
            guardrailFindings: ["Checkpoint guardrail matched"],
            recommendedKillSwitches: ["host-write"],
            stackedModes: ["draftOnly", "mirror"],
            assertionCeiling: "guarded",
            allowedDomains: ["draft.note", "text.delay"],
            blockedDomains: ["tool.write", "memory.write", "host.write"],
            delayType: "cool_down",
            substituteType: "draft",
            sovereignHintLevel: "elevated"
        )
        let persistedLineage = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-wind-gate",
            createdAt: date("2026-04-10T07:16:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            diffSummary: ["Checkpoint recovery pending review"],
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: lineageSummary)
        )
        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            persistedCheckpointLineages: [persistedLineage],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let snapshot = BehavioralAISubstrateBridge.consoleSnapshot(
            from: export,
            currentBrainState: nil
        )
        let expectedWindGateLine =
            "L11 wind gate • primary delay • assert guarded • delay cool_down • substitute draft • sovereign elevated"

        #expect(export.effectiveEBrainSource == .persistedCheckpoint)
        #expect(snapshot.runtimeSummary?.contains("Recovered from checkpoint") == true)
        #expect(snapshot.runtimeSummary?.contains(expectedWindGateLine) == true)
        #expect(snapshot.effectiveLayerStackLines.contains(expectedWindGateLine))
        #expect(snapshot.brainSummary?.contains("Checkpoint recovery") == true)
    }

    @Test
    func consoleSnapshotSurfacesGovernancePressureForLiveTurn() async throws {
        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            debugStore: DecisionIntelligenceDebugStore(),
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )
        let turn = makeGovernedProtectiveTurn()
        let snapshot = BehavioralAISubstrateBridge.consoleSnapshot(
            from: export,
            currentBrainState: nil,
            eBrainTurn: turn
        )
        let dataReport = try #require(snapshot.reports.first(where: { $0.layer == .data }))
        let expectedGovernanceLine = expectedGovernancePressureLine()

        #expect(snapshot.runtimeSummary?.contains(expectedGovernanceLine) == true)
        #expect(snapshot.runtimeSummary?.contains(expectedVersionTreeLine()) == true)
        #expect(snapshot.runtimeSummary?.contains(expectedPendingRetractionLine()) == true)
        #expect(snapshot.runtimeSummary?.contains("L13 evolution") != true)
        #expect(dataReport.summary.contains(expectedGovernanceLine) != true)
        #expect(dataReport.summary.contains("L13 evolution") != true)
    }

    @Test
    func consoleSnapshotSurfacesResolvedGovernancePressureForLiveTurn() async throws {
        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            debugStore: DecisionIntelligenceDebugStore(),
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )
        let turn = makeResolvedGovernedProtectiveTurn()
        let snapshot = BehavioralAISubstrateBridge.consoleSnapshot(
            from: export,
            currentBrainState: nil,
            eBrainTurn: turn
        )
        let dataReport = try #require(snapshot.reports.first(where: { $0.layer == .data }))
        let expectedGovernanceLine = expectedResolvedGovernancePressureLine()

        #expect(snapshot.runtimeSummary?.contains(expectedGovernanceLine) == true)
        #expect(snapshot.runtimeSummary?.contains(expectedVersionTreeLine()) == true)
        #expect(snapshot.runtimeSummary?.contains(expectedResolvedRetractionLine()) == true)
        #expect(snapshot.runtimeSummary?.contains("L13 evolution") != true)
        #expect(dataReport.summary.contains(expectedGovernanceLine) != true)
        #expect(dataReport.summary.contains("L13 evolution") != true)
    }

    @Test
    func inspectionSnapshotExposesEffectiveFactsAndLayerStackForLiveTurn() async throws {
        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            debugStore: DecisionIntelligenceDebugStore(),
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )
        let turn = makeProtectiveTurn()
        let inspection = DecisionTestingSubstrateInspectionSnapshot(
            export: export,
            eBrainTurn: turn
        )
        let foldedLung = DecisionFoldedLungCoordinator.snapshot(for: turn)

        #expect(inspection.effectiveEBrainSource == .liveRuntime)
        #expect(inspection.effectiveEBrainSummary == inspection.synchronizedExport.effectiveEBrainSummary)
        #expect(inspection.effectiveEBrainFactsBundle == inspection.synchronizedExport.effectiveEBrainFactsBundle)
        #expect(inspection.effectiveLayerStackLines == inspection.synchronizedExport.effectiveLayerStackLines)
        #expect(inspection.effectiveLayerStackLines == turn.layerStackLines)
        #expect(inspection.liveEBrainKernelFrame?.runModeID == turn.budgetFrame.runMode.rawValue)
        #expect(inspection.liveEBrainKernelFrame?.wakeIntentLevelID == turn.wakeIntent.intentLevel.rawValue)
        #expect(inspection.liveEBrainKernelFrame?.leaseID == turn.runLease?.leaseID)
        #expect(inspection.liveEBrainKernelFrame?.diagnosticsPresentation == turn.diagnosticsPresentation)
        #expect(inspection.liveEBrainKernelFrame?.policyBundleVersion == turn.policyLineage?.bundleVersion)
        #expect(
            inspection.liveEBrainKernelFrame?.sovereignVerdictLevelID
                == turn.sovereignVerdict?.verdictLevel.rawValue
        )
        #expect(
            inspection.liveEBrainKernelFrame?.sovereignReasonCodes
                == (turn.sovereignVerdict?.reasonCodes ?? [])
        )
        #expect(
            inspection.liveEBrainKernelFrame?.sovereignCommitScopeIDs
                == turn.sovereignCommitTokens.map(\.scope.rawValue)
        )
        #expect(
            inspection.liveEBrainKernelFrame?.sovereignLockScopeID
                == turn.sovereignLock?.scope.rawValue
        )
        #expect(
            inspection.liveEBrainKernelFrame?.sovereignQuarantineZoneIDs
                == turn.quarantineRecords.map(\.zone.rawValue)
        )
        #expect(
            inspection.liveEBrainKernelFrame?.sovereignAuditRuleIDs
                == (turn.sovereignAuditEntry?.ruleIDs ?? [])
        )
        #expect(
            inspection.liveEBrainKernelFrame?.sovereignAuditRef
                == (turn.sovereignAuditEntry?.auditID ?? turn.sovereignVerdict?.auditRef)
        )
        #expect(
            inspection.liveEBrainKernelFrame?.policyDecisionIDs
                == (turn.policyLineage.map {
                    [$0.providerRoutingPolicyID, $0.runtimeTuningPolicyID]
                } ?? [])
        )
        #expect(
            inspection.liveEBrainKernelFrame?.sovereignExecutionKinds
                == turn.sovereignExecutionReceipts.map(\.kind.rawValue)
        )
        #expect(inspection.liveEBrainKernelFrame?.lungState == foldedLung.lungState)
        #expect(inspection.liveEBrainKernelFrame?.organPackages == foldedLung.organPackages)
        #expect(inspection.liveEBrainKernelFrame?.resumeFrame == foldedLung.resumeFrame)
        #expect(inspection.liveEBrainKernelFrame?.rollbackAnchor == foldedLung.rollbackAnchor)
        #expect(inspection.liveEBrainKernelFrame?.sovereignBridgeResult == foldedLung.sovereignBridgeResult)
        #expect(
            inspection.liveEBrainPresentationFrame?.runModeTitle
                == turn.diagnosticsPresentation.runModeTitle
        )
        #expect(
            inspection.liveEBrainPresentationFrame?.layerStackLines
                == turn.diagnosticsPresentation.layerStackLines
        )
        #expect(
            inspection.liveEBrainPresentationFrame?.courtLine
                == DecisionEvolutionEBrainPresentationSupport.courtLine(from: turn.mergedChoice)
        )
        #expect(inspection.liveEBrainPresentationFrame?.lungLine == foldedLung.lungLine)
        #expect(inspection.liveEBrainPresentationFrame?.organPackageLine == foldedLung.organPackageLine)
        #expect(inspection.liveEBrainPresentationFrame?.resumeLine == foldedLung.resumeLine)
        #expect(inspection.liveEBrainPresentationFrame?.rollbackLine == foldedLung.rollbackLine)
        #expect(inspection.liveEBrainPresentationFrame?.sovereignBridgeLine == foldedLung.sovereignBridgeLine)
        if let verdictLevel = turn.sovereignVerdict?.verdictLevel.rawValue {
            #expect(
                inspection.liveEBrainPresentationFrame?.sovereignVerdictLine?.contains(verdictLevel)
                    == true
            )
        }
        if let lockScope = turn.sovereignLock?.scope.rawValue {
            #expect(
                inspection.liveEBrainPresentationFrame?.sovereignAuthorityLine?.contains(lockScope)
                    == true
            )
        }
        #expect(
            inspection.liveEBrainPresentationFrame?.sovereignAuthorityLine?.contains("warrants memoryWrite")
                == true
        )
        #expect(
            inspection.liveEBrainPresentationFrame?.sovereignAuthorityLine?.contains("policy policy-hash.sess")
                == true
        )
        #expect(
            inspection.liveEBrainPresentationFrame?.sovereignAuthorityLine?.contains("ttl 30s")
                == true
        )
        #expect(
            inspection.liveEBrainPresentationFrame?.sovereignAuthorityLine?.contains("witnesses 4")
                == true
        )
        if let firstAuditRule = turn.sovereignAuditEntry?.ruleIDs.first {
            #expect(
                inspection.liveEBrainPresentationFrame?.sovereignAuditLine?.contains(firstAuditRule)
                    == true
            )
        }
    }

    @Test
    func inspectionSnapshotExposesEffectiveFactsAndLayerStackForPersistedCheckpoint() async throws {
        let persistedLineage = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-layer-stack",
            createdAt: date("2026-04-10T07:16:00.000Z"),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            diffSummary: ["Checkpoint recovery pending review"],
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: BASEvolutionLineageSummary(
                    recordedAt: date("2026-04-10T07:15:00.000Z"),
                    sessionID: "before.quick.lineage",
                    taskType: "conflict",
                    riskLevel: "high",
                    permitMode: "delay",
                    hostGatePercent: 82,
                    thoughtFoldChecksum: "fold-checkpoint",
                    updateTicketSummaries: ["review after cooldown"],
                    guardrailFindings: ["Checkpoint guardrail matched"],
                    recommendedKillSwitches: ["host-write"]
                )
            )
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            persistedCheckpointLineages: [persistedLineage],
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )
        let inspection = DecisionTestingSubstrateInspectionSnapshot(
            export: export,
            eBrainTurn: nil
        )

        #expect(inspection.effectiveEBrainSource == .persistedCheckpoint)
        #expect(inspection.effectiveEBrainSummary == export.effectiveEBrainSummary)
        #expect(inspection.effectiveEBrainFactsBundle == export.effectiveEBrainFactsBundle)
        #expect(inspection.effectiveLayerStackLines == export.effectiveLayerStackLines)
        #expect(inspection.effectiveLayerStackLines == persistedLineage.factsBundle.layerStackLines)
    }

    @Test
    func inspectionSnapshotExposesLatestStructuredPersistenceIssue() async throws {
        PersistenceIssueRecorder.clear()
        defer { PersistenceIssueRecorder.clear() }

        let recorded = PersistenceIssueRecorder.record(
            category: .brainBootstrapFallback,
            severity: .warning,
            operation: "bootstrapping current brain state from projection",
            summary: "Before entered a degraded current-brain fallback while bootstrapping current brain state from projection.",
            detail: "Synthetic compiler failure",
            remediation: "Inspect the current brain compiler and keep the session in review/watch mode."
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            debugStore: DecisionIntelligenceDebugStore(),
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )
        let inspection = DecisionTestingSubstrateInspectionSnapshot(
            export: export,
            eBrainTurn: nil
        )

        #expect(inspection.latestPersistenceIssue == recorded)
        #expect(inspection.latestPersistenceNotice == recorded.displayMessage)
        #expect(inspection.latestPersistenceRemediationSnapshot?.isDegraded == true)
        #expect(inspection.latestPersistenceRemediationSnapshot?.summary == recorded.summary)
        #expect(inspection.latestPersistenceRemediationSnapshot?.remediation == recorded.remediation)
        #expect(inspection.runtimePolicyLineage == export.runtimeSnapshot.runtimePolicyLineage)
        #expect(inspection.runtimePolicyIssues == export.runtimeSnapshot.runtimePolicyIssues)
    }

    @Test
    func bridgeBootstrapCurrentBrainStateCommitsAndMaterializesHostState() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let now = date("2026-04-10T21:45:00Z")
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: now)

        let current = BehavioralAISubstrateBridge.bootstrapCurrentBrainState(
            mode: .quick,
            prompt: "Should I send this tonight?",
            source: .launch,
            envelope: .resumeCurrentDecision(
                sourceSurface: .notification,
                entrySource: .app,
                preferredMode: .quick,
                promptSeed: "Should I send this tonight?",
                riskLevel: .high,
                triggerReason: "prediction"
            ),
            taskGraph: nil,
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: now
        )

        let updates = try context.fetch(FetchDescriptor<BrainStateUpdate>())
        let checkpoints = try context.fetch(FetchDescriptor<DecisionEvolutionCheckpoint>())
        let templates = try context.fetch(FetchDescriptor<InterventionTemplateRecord>())

        #expect(current.sourceSurface == .notification)
        #expect(current.riskLevel == .high)
        #expect(!templates.isEmpty)
        #expect(checkpoints.count == 1)
        #expect(updates.count == 1)
        #expect(updates.first?.fingerprint == current.verificationSnapshot.fingerprint)
        #expect(current.identityProfile.role == .predictiveSentinel)
        #expect(current.boundaryPolicy.riskLevel == .high)
    }

    @Test
    func bridgeBootstrapCurrentBrainStateAppliesHorizonAwarePendingScreening() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(
            DecisionMemoryCandidateRecord(
                id: "situational.market.latest",
                type: .situational,
                topic: "market_latest",
                headline: "Tonight's market move",
                value: "volatile market signal",
                confidence: 0.79,
                priority: 0.76,
                source: .reflection,
                firstObservedAt: date("2026-04-09T20:00:00Z"),
                lastObservedAt: date("2026-04-09T20:00:00Z"),
                decayPolicy: .medium,
                retrievalTags: ["latest", "market", "night"],
                evidenceCount: 2,
                confirmationCount: 1,
                lastObservationFingerprint: "market-fp",
                status: .pending,
                provenanceSummary: "Fresh reflection from tonight.",
                lastWriteOperation: .noop,
                lastGovernanceDecision: .deferred,
                governanceReason: "Awaiting confirmation."
            )
        )
        try context.save()

        let now = date("2026-04-09T23:10:00Z")
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: now)
        let stableFrame = DecisionEBrainExecutionCapabilityFrame(
            activeProvider: .foundationModels,
            preferredProvider: .foundationModels,
            fallbackProvider: .gemmaE4B,
            providerTrack: .builtInSystem,
            executionTier: .systemManaged,
            foundationTier: .systemManaged,
            reasonCodes: []
        )
        let volatileFrame = DecisionEBrainExecutionCapabilityFrame(
            activeProvider: .openModel,
            preferredProvider: .openModel,
            fallbackProvider: .template,
            providerTrack: .builtInOpenModel,
            executionTier: .balancedGemma,
            foundationTier: .openModelHeuristic,
            reasonCodes: []
        )

        let stableCurrent = BehavioralAISubstrateBridge.bootstrapCurrentBrainState(
            mode: .quick,
            prompt: "Help me decide whether to cook at home tonight.",
            source: .launch,
            taskGraph: nil,
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: now,
            executionCapabilityFrame: stableFrame
        )
        let volatileCurrent = BehavioralAISubstrateBridge.bootstrapCurrentBrainState(
            mode: .quick,
            prompt: "Help me decide whether to cook at home tonight.",
            source: .launch,
            taskGraph: nil,
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: now,
            executionCapabilityFrame: volatileFrame
        )

        #expect(stableCurrent.brainState.memoryGovernance.loadedPendingMemoryCount == 1)
        #expect(volatileCurrent.brainState.memoryGovernance.loadedPendingMemoryCount == 0)
        #expect(
            volatileCurrent.brainState.memoryGovernance.screenedOutReasonCounts[.externalRefreshNoOverlap] == 1
        )
    }

    private func makeProtectiveTurn() -> BASEBrainTurnResult {
        let deviceState = BASDeviceState(
            batteryLevel: 0.66,
            thermalLevel: .warm,
            memoryFreeMB: 2_048,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.31,
            gpuLoad: 0.12,
            npuAvailable: true,
            latencyBudgetMs: 1_400
        )
        let budgetFrame = BASBudgetFrame.guardedLocal(
            maxLoops: 2,
            maxCandidates: 2,
            maxDecodeTokens: 160,
            retrievalDepth: 2
        )
        let hostContext = BASHostProfile(
            hostID: "host.primary",
            longTermGoals: ["Stay calm"],
            noGoZones: ["unsafe"]
        )
        let contextFrame = BASContextFrame(
            utterance: "Mirror body",
            taskType: .highPressure,
            emotionalLoad: 0.82,
            timePressure: 0.74,
            relationPattern: "self",
            ambiguityScore: 0.63,
            consequenceLevel: 0.81,
            manipulationHints: ["time_pressure"],
            hostRelevance: 0.91
        )
        let decomposeFrame = BASDecomposeFrame(
            facts: ["Pause first"],
            goals: ["Keep the boundary"],
            emotions: ["alert"],
            unknowns: ["best next step"],
            contradictions: [],
            pressureSignals: ["urgency"],
            manipulationSignals: ["forced-now"],
            mirrorText: "Mirror body"
        )
        let memoryAtom = BASMemoryAtom(
            memoryID: "mem-1",
            summary: "Protect the boundary first.",
            contentType: .warm,
            source: "session",
            confidence: 0.86,
            conflictFingerprint: "fp-1"
        )
        let memoryBundle = BASMemoryBundle(
            atoms: [memoryAtom],
            retrievalTags: ["boundary"],
            conflictRefs: [],
            activeHostVersion: hostContext.activeVersion
        )
        let candidate = BASCandidatePath(
            candidateID: "cand-1",
            title: "Pause and protect",
            actionSummary: "Hold for a moment before acting.",
            requiredEvidence: ["high pressure"],
            expectedBenefit: 0.9,
            expectedCost: 0.2,
            reversibility: 0.8,
            confidence: 0.87
        )
        let forecast = BASForecastItem(
            candidateID: candidate.candidateID,
            shortTermOutcome: "Less immediate pressure",
            midTermOutcome: "Better boundary clarity",
            worstCase: "Minor delay",
            uncertainty: 0.2,
            affectedRelations: ["self"]
        )
        let critique = BASCritiqueItem(
            candidateID: candidate.candidateID,
            critiqueType: .boundaryConflict,
            critiqueText: "The safer route avoids forcing the choice too early.",
            severity: 0.74
        )
        let triScore = BASTriSelfScore(
            candidateID: candidate.candidateID,
            idScore: 0.42,
            egoScore: 0.81,
            superegoScore: 0.91,
            mergedScore: 0.83,
            veto: false
        )
        let mergedChoice = BASMergedChoice(
            candidateID: candidate.candidateID,
            title: "Pause first",
            actionSummary: "Use the safer next step."
        )
        let riskCard = BASRiskCard(
            totalRisk: 0.88,
            riskLevel: .high,
            factors: ["pressure", "uncertainty"],
            uncertainty: 0.56,
            irreversibility: 0.79,
            manipulationStrength: 0.73,
            gsiScore: 0.68,
            recommendedMode: .delay
        )
        let actionPermit = BASActionPermit(
            mode: .delay,
            reasonCodes: ["risk.high", "gsi.elevated"],
            requireSecondCheck: true,
            outputLengthCap: 120,
            tonePolicy: "clear_firm",
            templatePolicy: "protective_alternative"
        )
        let thoughtFrame = BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "decomp-1",
            memoryRefs: [memoryAtom.memoryID],
            candidates: [candidate],
            forecasts: [forecast],
            critiques: [critique],
            triScores: [triScore],
            riskCard: riskCard,
            actionPermit: actionPermit,
            stabilityScore: 0.91,
            stopReason: .blocked
        )
        let thoughtFold = BASThoughtFold(
            foldID: "fold-1",
            compactSlots: ["headline": "Pause first", "body": "Mirror body"],
            candidateSignatures: [candidate.candidateID],
            riskSnapshot: riskCard,
            hostEffectSummary: "Host boundary remains primary.",
            restorePointer: "restore-1",
            checksum: "checksum-1"
        )
        let updateTicket = BASUpdateTicket(
            ticketID: "ticket-1",
            sessionRef: "session-1",
            summary: "Record a protective turn.",
            memoryWriteSuggestion: "Keep the boundary signal in warm memory.",
            hostProfileChangeSuggestion: nil,
            ruleCandidateRef: "rule-1",
            confidence: 0.84,
            conflictFlag: false,
            requiresReview: true
        )
        let runtimeTrace = BASRuntimeTrace(
            sessionID: "session-1",
            layerEvents: [
                BASRuntimeTraceEvent(
                    layerID: "L11",
                    event: "gate",
                    detail: "Protective short-circuited refinement."
                )
            ],
            latencyBreakdownMs: ["guard": 3],
            powerEstimate: 0.12,
            thermalTrace: ["cool"],
            modelRoute: "guarded",
            loopCount: 1,
            cacheHitRate: 0,
            activeKillSwitches: [.forceGuardMode],
            guardrailFindings: [
                BASRuntimeAuditFinding(
                    code: "protected_permit",
                    layerID: "L11",
                    summary: "Protective short-circuit requested.",
                    severity: .high,
                    enforced: true
                )
            ],
            recommendedKillSwitches: [.requireReviewedWrites]
        )
        let sovereignVerdict = BASSovereignVerdict(
            verdictID: "verdict.session-l14",
            verdictLevel: .quarantine,
            latched: true,
            forcedMode: .quarantine,
            reasonCodes: ["runtime.quarantine"],
            revokedPermissions: [.toolWrite, .memoryWriteCold],
            quarantineRefs: ["session-1", "fold-1"],
            rollbackRef: "snapshot.session-l14",
            userStubMode: .minimalReceipt,
            auditRef: "audit.session-l14",
            policyHash: "policy-hash.session-l14"
        )
        let sovereignCommitToken = BASSovereignCommitToken(
            tokenID: "token.session-l14.memory",
            sessionID: "session-1",
            turnID: "turn-l14",
            scope: .memoryWrite,
            allowedTargets: ["ticket-1"],
            actionDigest: "digest-l14",
            snapshotRef: "snapshot.session-l14",
            policyHash: "policy-hash.session-l14",
            ttlMs: 30_000,
            nonce: "nonce-l14",
            singleUse: true,
            signature: "signature-l14"
        )
        let sovereignLock = BASSovereignLock(
            lockID: "lock.session-l14",
            scope: .session,
            lockLevel: .quarantine,
            createdAt: Date(timeIntervalSince1970: 1_776_150_001),
            releaseCondition: "manual_review"
        )
        let quarantineRecord = BASQuarantineRecord(
            quarantineID: "quarantine.session-l14",
            zone: .session,
            sourceRef: "session-1",
            reasonCodes: ["runtime.quarantine"],
            isolatedAt: Date(timeIntervalSince1970: 1_776_150_002),
            releasePolicy: "manual_review",
            reviewState: .held
        )
        let sovereignAuditEntry = BASSovereignAuditEntry(
            auditID: "audit.session-l14",
            sessionID: "session-1",
            turnID: "turn-l14",
            verdictRef: "verdict.session-l14",
            ruleIDs: ["BR-SOV-004"],
            signalRefs: ["runtime.quarantine"],
            actionRefs: ["quarantine.session-l14"],
            snapshotRef: "snapshot.session-l14",
            actor: .system,
            signature: "signature.audit.session-l14",
            appendedAt: Date(timeIntervalSince1970: 1_776_150_003)
        )

        return BASEBrainTurnResult(
            deviceState: deviceState,
            budgetFrame: budgetFrame,
            wakeIntent: BASWakeIntent(
                intentLevel: .guard,
                estimatedValue: 0.72,
                estimatedRisk: 0.91,
                estimatedCost: 0.24,
                preferredMode: budgetFrame.runMode
            ),
            vitalState: BASVitalState(
                wakeState: budgetFrame.runMode,
                survivalMargin: 0.76,
                thermalMargin: 0.88,
                powerMargin: 0.74,
                continuityScore: 0.81,
                stabilityScore: 0.86
            ),
            sovereignVerdict: sovereignVerdict,
            sovereignCommitTokens: [sovereignCommitToken],
            sovereignWarrants: [
                {
                    var warrant = BASSovereignWarrant(
                        warrantID: "warrant.session-l14.memory",
                        scope: .memoryWrite,
                        actionDigest: sovereignCommitToken.actionDigest,
                        commitTokenRef: sovereignCommitToken.tokenID,
                        jurisdictionRef: "jurisdiction.memoryWrite",
                        snapshotRef: sovereignCommitToken.snapshotRef,
                        timeLockRef: "timelock.turn-l14.memoryWrite.ttl_30000",
                        policyHash: sovereignCommitToken.policyHash,
                        witnessRefs: [
                            "permit.turn-l14.memoryWrite",
                            "integrity.snapshot.session-l14",
                            "continuity.turn-l14",
                            "policy.policy-hash.session-l14"
                        ],
                        singleUse: true,
                        signature: "signature.warrant-l14"
                    )
                    warrant.issuedAt = Date(timeIntervalSince1970: 1_776_150_000)
                    warrant.expiresAt = Date(timeIntervalSince1970: 1_776_150_030)
                    return warrant
                }()
            ],
            sovereignLock: sovereignLock,
            quarantineRecords: [quarantineRecord],
            sovereignAuditEntry: sovereignAuditEntry,
            hostContext: hostContext,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            thoughtFrame: thoughtFrame,
            thoughtFold: thoughtFold,
            triScores: [triScore],
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit,
            hostGateValue: 0.37,
            renderedOutput: BASRenderedOutput(
                mode: .delay,
                headline: "Pause first",
                body: "Mirror body",
                alternativeActions: ["Wait 24 hours", "Draft but do not send"],
                explanationCodes: ["risk.high", "gsi.elevated"]
            ),
            updateTickets: [updateTicket],
            runtimeTrace: runtimeTrace
        )
    }

    private func makeGovernedProtectiveTurn() -> BASEBrainTurnResult {
        var turn = makeProtectiveTurn()
        turn.experienceCandidates = [
            BASExperienceCandidate(
                candidateID: "candidate-1",
                sourceRefs: ["ticket-1"],
                candidateType: .guardPattern,
                summary: "Guard-first pattern observed.",
                stabilitySignal: 0.84,
                contaminationRisk: 0.18,
                hostScope: "session",
                sovereignScope: "l14.review"
            )
        ]
        turn.shadowTrialRecords = [
            BASShadowTrialRecord(
                trialID: "trial-1",
                candidateRef: "candidate-1",
                trialScope: "single-domain",
                startAt: Date(timeIntervalSince1970: 1_776_150_010),
                observedEffects: ["guard held"],
                failConditions: ["drift"],
                completionState: "pending"
            )
        ]
        turn.versionDeltas = [
            BASVersionDelta(
                deltaID: "delta-1",
                targetType: "rule",
                beforeRef: "rule-0",
                afterRef: "rule-1",
                reason: "Guard template matured.",
                impactScope: "l13.shadow",
                rollbackRef: "rollback-1"
            )
        ]
        turn.retractionOrders = [
            BASRetractionOrder(
                orderID: "retract-1",
                targetRefs: ["rule-0"],
                cascadeRefs: ["template-0"],
                reasonCodes: ["superseded_by_shadow_trial"],
                executionState: "pending"
            )
        ]
        turn.evolutionSeals = [
            BASEvolutionSeal(
                sealID: "seal-1",
                candidateRef: "candidate-1",
                allowedScope: "checkpoint-review",
                trialRequired: true,
                approvalRequirements: ["l14.review"],
                signature: "signature-1",
                approvalState: "pending_review"
            )
        ]
        turn.workflowCandidates = [
            BASWorkflowCandidate(
                workflowID: "workflow-1",
                taskDomain: "delay_review",
                steps: ["pause", "mirror", "review"],
                observedGain: 0.62,
                safetyNotes: ["review before send"],
                hostSpecific: true,
                shadowTrialState: "pending"
            )
        ]
        turn.guardTemplateCandidates = [
            BASGuardTemplateCandidate(
                templateID: "guard-1",
                sceneType: "high_pressure",
                boundaryScriptRef: "boundary.delay.v1",
                delayPacketRef: "packet.delay.v1",
                substituteRef: "compare.v1",
                protectiveGain: 0.84,
                overreachRisk: 0.22
            )
        ]
        turn.biasRecords = [
            BASBiasRecord(
                biasID: "bias-1",
                biasType: "overreach_risk",
                sourceRefs: ["turn-1", "trial-1"],
                severity: 0.57,
                recurrenceScore: 0.41,
                affectedLayers: ["L11", "L12", "L13"]
            )
        ]
        turn.riskPatternCandidates = [
            BASRiskPatternCandidate(
                patternID: "risk-1",
                sourceRefs: ["turn-1", "ticket-1"],
                riskDomain: "high_pressure",
                triggerSignals: ["manipulation", "delay"],
                severity: 0.79,
                recurrenceScore: 0.48,
                sovereignReviewRequired: true,
                shadowTrialState: "pending"
            )
        ]
        turn.learningExportBundles = []
        return turn
    }

    private func makeResolvedGovernedProtectiveTurn() -> BASEBrainTurnResult {
        var turn = makeGovernedProtectiveTurn()
        turn.shadowTrialRecords = [
            BASShadowTrialRecord(
                trialID: "trial-1",
                candidateRef: "candidate-1",
                trialScope: "compare_only:block",
                startAt: Date(timeIntervalSince1970: 1_776_150_010),
                endAt: Date(timeIntervalSince1970: 1_776_150_011),
                observedEffects: ["guard held"],
                failConditions: ["drift"],
                promotionRecommendation: "eligible_with_seal_review",
                completionState: "passed"
            )
        ]
        turn.retractionOrders = [
            BASRetractionOrder(
                orderID: "retract-1",
                targetRefs: ["rule-0"],
                cascadeRefs: ["template-0"],
                reasonCodes: ["seal_review"],
                executionState: "cleared"
            )
        ]
        turn.workflowCandidates = [
            BASWorkflowCandidate(
                workflowID: "workflow-1",
                taskDomain: "delay_review",
                steps: ["pause", "mirror", "review"],
                observedGain: 0.62,
                safetyNotes: ["review before send"],
                hostSpecific: true,
                shadowTrialState: "passed"
            )
        ]
        turn.riskPatternCandidates = [
            BASRiskPatternCandidate(
                patternID: "risk-1",
                sourceRefs: ["turn-1", "ticket-1"],
                riskDomain: "high_pressure",
                triggerSignals: ["manipulation", "delay"],
                severity: 0.79,
                recurrenceScore: 0.48,
                sovereignReviewRequired: true,
                shadowTrialState: "passed"
            )
        ]
        return turn
    }

    @Test
    func hostKitFacadePreservesHighRiskNotificationSessionSemantics() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let now = date("2026-04-10T21:55:00Z")
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: now)
        let bridgeCurrent = BehavioralAISubstrateBridge.bootstrapCurrentBrainState(
            mode: .quick,
            prompt: "Should I send this tonight?",
            source: .notification,
            envelope: .resumeCurrentDecision(
                sourceSurface: .notification,
                entrySource: .app,
                preferredMode: .quick,
                promptSeed: "Should I send this tonight?",
                riskLevel: .high,
                triggerReason: "prediction"
            ),
            taskGraph: nil,
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: now
        )

        let runtime = BeforeProductCompatibility.makeHostRuntime()
        let hostResult = try runtime.startSession(
            BASHostSessionRequest(
                kind: .notification,
                workflowProfile: .primary,
                surface: .notification,
                prompt: "Should I send this tonight?",
                title: "Should I send this tonight?",
                riskLevel: .high,
                triggerReason: "prediction"
            ),
            now: now
        )

        let bridgeSnapshot = try #require(
            BehavioralAISubstrateBridge.brainSnapshot(from: bridgeCurrent)
        )
        let expectedProfile = BASDecisionMode(identifier: bridgeSnapshot.mode).map { mode in
            switch mode {
            case .primary:
                BASHostWorkflowProfile.primary
            case .comparative:
                BASHostWorkflowProfile.comparative
            case .reflective:
                BASHostWorkflowProfile.reflective
            }
        }
        let expectedTemplateCount = BeforeProductCompatibility.hostConfiguration
            .workflowBehavior
            .templateIDs(for: .primary)
            .count
        let expectedInterventionProfile = BeforeProductCompatibility.hostConfiguration
            .lifecycleBehavior
            .predictiveInterventionBehavior
            .highRisk
            .preferredModeID
            .flatMap {
                BeforeProductCompatibility.hostConfiguration.workflowBehavior.workflowProfile(forModeID: $0)
            }

        #expect(hostResult.currentBrain.workflowProfile == expectedProfile)
        #expect(hostResult.currentBrain.activeTemplateCount == expectedTemplateCount)
        #expect(hostResult.currentBrain.failureGuardCount > 0)
        #expect(hostResult.currentBrain.activeConstraints.contains("high-risk-confirmation"))
        #expect(hostResult.interventionSuggestion?.preferredWorkflowProfile == expectedInterventionProfile)
        #expect(hostResult.interventionSuggestion?.riskLevel.rawValue == bridgeCurrent.riskLevel.rawValue)
    }

    @Test
    func bridgePrimeCurrentBrainStateCompactsSessionFragmentsIntoCommittedBrain() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let now = date("2026-04-10T22:00:00Z")
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: now)

        let current = BehavioralAISubstrateBridge.primeCurrentBrainState(
            mode: .quick,
            promptFragments: ["  should ", "I", "wait until morning?  "],
            context: context,
            projection: projection,
            retrievalMode: .filtered,
            now: now
        )

        let updates = try context.fetch(FetchDescriptor<BrainStateUpdate>())

        #expect(current.source == .sessionBootstrap)
        #expect(current.mode == .quick)
        #expect(current.sourceSurface == .app)
        #expect(current.activeTemplateIDs.isEmpty == false)
        #expect(updates.last?.source == .sessionBootstrap)
    }

    @Test
    func bridgeActivateQuickSessionResolvesProjectionAndReturnsCommittedBrain() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let now = date("2026-04-10T22:10:00Z")
        let session = QuickCheckSession(
            entrySource: .app,
            initialNote: "Wait until tomorrow."
        )
        session.scenario = .other

        let outcome = BehavioralAISubstrateBridge.activateQuickSession(
            session,
            preferences: .default,
            context: context,
            cachedProjection: nil,
            isProjectionDirty: true,
            now: now
        )

        #expect(outcome.refreshedProjection)
        #expect(outcome.currentBrain.source == .sessionBootstrap)
        #expect(outcome.currentBrain.mode == .quick)
        #expect(outcome.currentBrain.activeTemplateIDs.isEmpty == false)
        #expect(outcome.currentBrain.verificationSnapshot.fingerprint.isEmpty == false)
    }

    @Test
    func bridgeRefreshCurrentBrainStateUsesTaskGraphFallbackWhenSessionsAreEmpty() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let now = date("2026-04-10T22:30:00Z")
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: now)
        let taskGraph = DecisionTaskGraphSnapshot(
            mode: .mirror,
            promptSeed: "resume the hard reflection",
            nextActionHint: "Return to the unresolved reflection",
            continuityFingerprint: "mirror|resume",
            tasks: [
                DecisionTaskNode(
                    kind: .evaluate,
                    title: "Re-open the reflection",
                    detail: "Return to the unresolved reflection with a slower lens.",
                    status: .inProgress
                )
            ],
            updatedAt: now
        )

        let current = BehavioralAISubstrateBridge.refreshCurrentBrainState(
            promptFragmentsByModeID: [:],
            modePriority: [
                DecisionMode.quick.substrateModeID,
                DecisionMode.balance.substrateModeID,
                DecisionMode.mirror.substrateModeID
            ],
            taskGraph: taskGraph,
            context: context,
            projection: projection,
            retrievalModesByModeID: [DecisionMode.mirror.substrateModeID: DecisionRetrievalMode.filtered.rawValue],
            source: .sceneActive,
            now: now
        )

        #expect(current.source == .sceneActive)
        #expect(current.mode == .mirror)
        #expect(current.taskGraph?.promptSeed == "resume the hard reflection")
        #expect(current.verificationSnapshot.fingerprint.isEmpty == false)
    }

    @Test
    func bridgeRefreshCurrentBrainStateResolvesProjectionCacheAndCommitsBrain() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let now = date("2026-04-10T22:35:00Z")
        let session = QuickCheckSession(
            entrySource: .app,
            initialNote: "Pause before sending."
        )
        session.scenario = .other

        let outcome = BehavioralAISubstrateBridge.refreshCurrentBrainState(
            activeQuickSession: session,
            activeBalanceSession: nil,
            activeMirrorSession: nil,
            taskGraph: nil,
            preferences: .default,
            context: context,
            cachedProjection: nil,
            isProjectionDirty: true,
            source: .explicitRefresh,
            now: now
        )

        #expect(outcome.refreshedProjection)
        #expect(outcome.currentBrain.source == .explicitRefresh)
        #expect(outcome.currentBrain.mode == .quick)
        #expect(outcome.currentBrain.brainState.boundaryPolicy.mode.isPureLocal)
    }

    @Test
    func bridgeRefreshCurrentBrainStatePrefersActiveSessionOverTaskGraphFallback() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let now = date("2026-04-10T22:45:00Z")
        let projection = DecisionMemorySystem.refreshProjection(in: context, now: now)
        let quick = QuickCheckSession(entrySource: .app, initialNote: " Wait until morning ")
        quick.scenario = .other
        quick.motivation = .avoiding

        let taskGraph = DecisionTaskGraphSnapshot(
            mode: .mirror,
            promptSeed: "resume the hard reflection",
            nextActionHint: "Return to the unresolved reflection",
            continuityFingerprint: "mirror|resume",
            tasks: [
                DecisionTaskNode(
                    kind: .evaluate,
                    title: "Re-open the reflection",
                    detail: "Return to the unresolved reflection with a slower lens.",
                    status: .inProgress
                )
            ],
            updatedAt: now
        )

        let current = BehavioralAISubstrateBridge.refreshCurrentBrainState(
            activeQuickSession: quick,
            activeBalanceSession: nil,
            activeMirrorSession: nil,
            taskGraph: taskGraph,
            preferences: .default,
            context: context,
            projection: projection,
            source: .sceneActive,
            now: now
        )

        #expect(current.mode == .quick)
        #expect(current.source == .sceneActive)
        #expect(current.taskGraph?.mode == .mirror)
        #expect(current.verificationSnapshot.fingerprint.isEmpty == false)
    }

    @Test
    func bridgeConsumeDecisionIntentEnvelopeRoutesOpenModeAndRefreshesBrain() {
        let envelope = DecisionIntentEnvelope.reopenTomorrowItem(
            sourceSurface: .notification,
            entrySource: .app,
            title: "Resume with more space.",
            riskLevel: .medium,
            preferredMode: .balance
        )

        var openedMode: DecisionMode?
        var selectedBoxTab = false
        var refreshedSource: BrainStateUpdateSource?

        BehavioralAISubstrateBridge.consumeDecisionIntentEnvelope(
            envelope,
            performCapture: { _, _, _ in
                Issue.record("Expected open-mode path, not quick capture")
            },
            performPresent: { _, mode, shouldSelectBoxTab, prompt in
                openedMode = mode
                selectedBoxTab = shouldSelectBoxTab
                #expect(prompt == "Resume with more space.")
            },
            performRoutedInput: { _, _ in
                Issue.record("Expected open-mode path, not routed input")
            },
            performPredictiveIntervention: { _ in
                Issue.record("Expected open-mode path, not predictive intervention")
            },
            performRestore: {
                Issue.record("Expected open-mode path, not workspace restore")
            },
            performOpenEvolutionControl: { _ in
                Issue.record("Expected open-mode path, not Evolution Control")
            },
            refreshCurrentBrain: { source in
                refreshedSource = source
            }
        )

        #expect(openedMode == .balance)
        #expect(selectedBoxTab)
        #expect(refreshedSource == .explicitRefresh)
    }

    @Test
    func bridgeConsumeLifecycleEntrySourcesPrefersHandoffAndRefreshesBrain() {
        let envelope = DecisionIntentEnvelope.reopenTomorrowItem(
            sourceSurface: .notification,
            entrySource: .app,
            title: "Resume with more space.",
            riskLevel: .medium,
            preferredMode: .balance
        )

        var openedMode: DecisionMode?
        var selectedBoxTab = false
        var refreshedSource: BrainStateUpdateSource?

        BehavioralAISubstrateBridge.consumeLifecycleEntrySourcesIfNeeded(
            consumeHandoff: { envelope },
            consumeDeferredEnvelope: { nil },
            performCapture: { _, _, _ in
                Issue.record("Expected open-mode handoff path")
            },
            performPresent: { mode, _, prompt in
                openedMode = mode
                #expect(prompt == "Resume with more space.")
            },
            performRoutedInput: { _, _ in
                Issue.record("Expected handoff path, not routed launch")
            },
            selectBoxTab: { selectedBoxTab = true },
            performPredictiveIntervention: { _ in
                Issue.record("Expected open-mode handoff path")
            },
            performRestore: {
                Issue.record("Expected open-mode handoff path")
            },
            performOpenEvolutionControl: { _ in
                Issue.record("Expected open-mode handoff path")
            },
            refreshCurrentBrain: { source in
                refreshedSource = source
            }
        )

        #expect(openedMode == .balance)
        #expect(selectedBoxTab)
        #expect(refreshedSource == .explicitRefresh)
    }

    @Test
    func bridgeExecuteAppLifecyclePhaseRunsBootstrapPlanWithMappedBrainTriggers() {
        var actions: [String] = []

        BehavioralAISubstrateBridge.executeAppLifecyclePhase(
            .initialAppearance,
            refreshMemoryProjection: { actions.append("projection") },
            refreshCurrentBrain: { source in
                actions.append("brain:\(source.rawValue)")
            },
            presentPendingReflection: { actions.append("reflection") },
            consumeHandoff: { nil },
            consumeDeferredEnvelope: { nil },
            performCapture: { _, _, _ in actions.append("quick") },
            performPresent: { _, _, _ in actions.append("open") },
            performRoutedInput: { _, _ in actions.append("route") },
            selectBoxTab: { actions.append("box") },
            performPredictiveIntervention: { _ in actions.append("prediction") },
            performRestore: { actions.append("restore") },
            performOpenEvolutionControl: { _ in actions.append("control") },
            refreshPredictedIntervention: { actions.append("refresh_prediction") },
            syncWidgetSnapshot: { actions.append("widget") }
        )

        #expect(
            actions == [
                "projection",
                "brain:launch"
            ]
        )
    }

    @Test
    func bridgeConsumeDecisionIntentEnvelopeCanOpenEvolutionControlFromWatch() {
        let envelope = DecisionIntentEnvelope.openEvolutionControl(
            entrySource: .watch,
            promptSeed: "Watch the pending review queue",
            triggerReason: "Watch requested evolution review.",
            controlEntryKindID: DecisionEvolutionWidgetControlEntryKind.audit.rawValue
        )

        var openedControlCenter = false
        var openedEnvelope: DecisionIntentEnvelope?
        var refreshedSource: BrainStateUpdateSource?

        BehavioralAISubstrateBridge.consumeDecisionIntentEnvelope(
            envelope,
            performCapture: { _, _, _ in
                Issue.record("Expected control-surface handoff, not quick capture")
            },
            performPresent: { _, _, _, _ in
                Issue.record("Expected control-surface handoff, not decision presentation")
            },
            performRoutedInput: { _, _ in
                Issue.record("Expected control-surface handoff, not routed input")
            },
            performPredictiveIntervention: { _ in
                Issue.record("Expected control-surface handoff, not predictive intervention")
            },
            performRestore: {
                Issue.record("Expected control-surface handoff, not workspace restore")
            },
            performOpenEvolutionControl: { envelope in
                openedControlCenter = true
                openedEnvelope = envelope
            },
            refreshCurrentBrain: { source in
                refreshedSource = source
            }
        )

        #expect(openedControlCenter)
        #expect(openedEnvelope?.controlEntryKindID == DecisionEvolutionWidgetControlEntryKind.audit.rawValue)
        #expect(refreshedSource == .watchHandoff)
    }

    @Test
    func bridgeConsumeDecisionIntentEnvelopeRoutesSharedRoutedInputAndRefreshesBrain() {
        let envelope = DecisionIntentEnvelope.routedInput(
            entrySource: .shortcut,
            promptSeed: "  Route this shared intent.  "
        )

        var routedPrompt: String?
        var routedEntrySource: EntrySource?
        var refreshedSource: BrainStateUpdateSource?

        BehavioralAISubstrateBridge.consumeDecisionIntentEnvelope(
            envelope,
            performCapture: { _, _, _ in
                Issue.record("Expected routed-input path, not capture")
            },
            performPresent: { _, _, _, _ in
                Issue.record("Expected routed-input path, not present")
            },
            performRoutedInput: { envelope, prompt in
                routedPrompt = prompt
                routedEntrySource = envelope.entrySource
            },
            performPredictiveIntervention: { _ in
                Issue.record("Expected routed-input path, not predictive intervention")
            },
            performRestore: {
                Issue.record("Expected routed-input path, not restore")
            },
            performOpenEvolutionControl: { _ in
                Issue.record("Expected routed-input path, not Evolution Control")
            },
            refreshCurrentBrain: { source in
                refreshedSource = source
            }
        )

        #expect(routedPrompt == "Route this shared intent.")
        #expect(routedEntrySource == .shortcut)
        #expect(refreshedSource == .explicitRefresh)
    }

    @Test
    func bridgeConsumeLifecycleEntrySourcesRoutesPendingRequestThroughSharedIntentContract() {
        let request = PendingLaunchRequest.routedPrompt(
            entrySource: .shortcut,
            prompt: "  Route the pending request.  "
        )

        var routedPrompt: String?
        var routedEntrySource: EntrySource?
        var refreshedSource: BrainStateUpdateSource?

        BehavioralAISubstrateBridge.consumeLifecycleEntrySourcesIfNeeded(
            consumeHandoff: { nil },
            consumeDeferredEnvelope: { request.decisionIntentEnvelope },
            performCapture: { _, _, _ in
                Issue.record("Expected pending routed-input path")
            },
            performPresent: { _, _, _ in
                Issue.record("Expected pending routed-input path")
            },
            performRoutedInput: { prompt, entrySource in
                routedPrompt = prompt
                routedEntrySource = entrySource
            },
            selectBoxTab: {
                Issue.record("Expected pending routed-input path")
            },
            performPredictiveIntervention: { _ in
                Issue.record("Expected pending routed-input path")
            },
            performRestore: {
                Issue.record("Expected pending routed-input path")
            },
            performOpenEvolutionControl: { _ in
                Issue.record("Expected pending routed-input path")
            },
            refreshCurrentBrain: { source in
                refreshedSource = source
            }
        )

        #expect(routedPrompt == "Route the pending request.")
        #expect(routedEntrySource == .shortcut)
        #expect(refreshedSource == .explicitRefresh)
    }

    @Test
    func bridgeResolveMemoryProjectionUsesCachedProjectionWhenClean() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedHistory(into: context)
        try context.save()

        let now = date("2026-04-10T23:00:00Z")
        let cached = DecisionMemorySystem.refreshProjection(in: context, now: now)

        let outcome = BehavioralAISubstrateBridge.resolveMemoryProjection(
            force: false,
            cachedProjection: cached,
            isDirty: false,
            context: context,
            now: now
        )

        #expect(outcome.refreshed == false)
        #expect(outcome.projection.diagnostics.recordCount == cached.diagnostics.recordCount)
        #expect(outcome.projection.governanceSnapshot.totalRecordCount == cached.governanceSnapshot.totalRecordCount)
    }

    @Test
    func bridgeSchedulePredictiveInterventionCancelsExpiredCandidate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let candidate = InterventionPredictionCandidate(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            riskLevel: .high,
            title: "Pause tonight",
            detail: "This likely needs a slower lens.",
            evidenceSignalCount: 3,
            suggestedMode: .mirror,
            reason: "Recent regret pattern",
            createdAt: date("2026-04-10T20:00:00Z"),
            expiresAt: date("2026-04-10T20:05:00Z")
        )

        var upserts: [(UUID, Bool)] = []
        var cancelled: [UUID] = []
        var scheduled: [UUID] = []

        BehavioralAISubstrateBridge.schedulePredictiveInterventionIfNeeded(
            candidate: candidate,
            preferences: .default,
            currentBrainState: nil,
            context: context,
            now: date("2026-04-10T21:00:00Z"),
            calendar: Calendar(identifier: .gregorian),
            upsertTrigger: { candidate, wasDelivered in
                upserts.append((candidate.id, wasDelivered))
            },
            cancelNotification: { cancelled.append($0) },
            scheduleNotification: { scheduled.append($0.id) }
        )

        #expect(upserts.count == 1)
        #expect(upserts.first?.0 == candidate.id)
        #expect(upserts.first?.1 == false)
        #expect(cancelled == [candidate.id])
        #expect(scheduled.isEmpty)
    }

    @MainActor
    @Test
    func bridgeRefreshActiveTaskGraphSnapshotPrefersQuickSnapshotAndPersistsIt() {
        let quick = QuickCheckSession(entrySource: .app, initialNote: "Wait until morning")
        quick.scenario = .other

        var savedSnapshot: DecisionTaskGraphSnapshot?
        var cleared = false

        let snapshot = BehavioralAISubstrateBridge.refreshActiveTaskGraphSnapshot(
            activeQuickSession: quick,
            activeBalanceSession: nil,
            activeMirrorSession: nil,
            saveSnapshot: { savedSnapshot = $0 },
            clearSnapshot: { cleared = true }
        )

        #expect(snapshot?.mode == .quick)
        #expect(savedSnapshot?.mode == .quick)
        #expect(cleared == false)
    }

    @MainActor
    @Test
    func bridgeReopenTomorrowBoxItemRestoresDraftAndBuildsReopenCandidate() {
        let item = TomorrowBoxItem(
            dueAt: date("2026-04-11T10:00:00Z"),
            mode: .balance,
            title: "Pause before deciding",
            detail: "Carry this into a slower balance pass.",
            prompt: "Should I do this tonight?",
            entrySource: .app,
            draft: TomorrowBoxDraft(
                prompt: "Should I do this tonight?",
                scenarioRaw: nil,
                motivationRaw: nil,
                expectedOutcomeRaw: nil,
                controlLevelRaw: nil,
                note: nil,
                desire: "Immediate relief",
                concern: "Likely regret",
                constraint: "It is late",
                longTerm: "Sleep on it",
                emotion: nil,
                relationship: nil,
                reality: nil,
                selfLens: nil
            ),
            riskLevel: .high,
            reopenHint: "Re-open slowly",
            templateHint: "Use the night cooling template",
            interventionHistorySummary: "Past late-night calls improved when delayed."
        )

        var cleared = false
        var activatedBalancePrompt: String?
        var startedPrompt: String?
        var removed = false
        var candidate: InterventionPredictionCandidate?
        var refreshedPrediction = false
        var selectedHome = false
        var persisted = false

        BehavioralAISubstrateBridge.reopenTomorrowBoxItem(
            item,
            clearActiveDecisionFlows: { cleared = true },
            activateQuick: { _ in Issue.record("Unexpected quick activation") },
            activateBalance: { session in
                activatedBalancePrompt = session.prompt
            },
            activateMirror: { _ in Issue.record("Unexpected mirror activation") },
            startQuick: { prompt in startedPrompt = prompt },
            startBalance: { prompt in startedPrompt = prompt },
            startMirror: { prompt in startedPrompt = prompt },
            removeTomorrowBoxItem: { removed = true },
            setInterventionCandidate: { candidate = $0 },
            refreshPredictedIntervention: { refreshedPrediction = true },
            selectHomeTab: { selectedHome = true },
            persistActiveWorkspaceState: { persisted = true }
        )

        #expect(cleared)
        #expect(activatedBalancePrompt == "Should I do this tonight?")
        #expect(startedPrompt == nil)
        #expect(removed)
        #expect(candidate?.riskLevel == .high)
        #expect(candidate?.suggestedMode == .balance)
        #expect(candidate?.reason == "Use the night cooling template")
        #expect(refreshedPrediction == false)
        #expect(selectedHome)
        #expect(persisted)
    }

    @MainActor
    @Test
    func bridgeReopenSupportRequestRoutesDraftedModeAndFinalizesHostState() {
        let request = SupportRequest(
            kind: .helpMeJudgeThis,
            message: "Help me slow this down.",
            mode: .mirror,
            draft: TomorrowBoxDraft(
                prompt: "Should I send this message?",
                scenarioRaw: nil,
                motivationRaw: nil,
                expectedOutcomeRaw: nil,
                controlLevelRaw: nil,
                note: nil,
                desire: nil,
                concern: nil,
                constraint: nil,
                longTerm: "Protect the relationship",
                emotion: "hurt",
                relationship: "close friend",
                reality: "It is late",
                selfLens: "Defensive"
            )
        )

        var cleared = false
        var activatedMirrorPrompt: String?
        var markedHeard = false
        var selectedHome = false
        var persisted = false

        BehavioralAISubstrateBridge.reopenSupportRequest(
            request,
            clearActiveDecisionFlows: { cleared = true },
            activateQuick: { _ in Issue.record("Unexpected quick activation") },
            activateBalance: { _ in Issue.record("Unexpected balance activation") },
            activateMirror: { session in
                activatedMirrorPrompt = session.prompt
            },
            markHeard: { markedHeard = true },
            selectHomeTab: { selectedHome = true },
            persistActiveWorkspaceState: { persisted = true }
        )

        #expect(cleared)
        #expect(activatedMirrorPrompt == "Should I send this message?")
        #expect(markedHeard)
        #expect(selectedHome)
        #expect(persisted)
    }

    @MainActor
    @Test
    func bridgeReopenSharedLifeItemRoutesDraftedModeAndMarksReviewing() {
        let item = SharedLifeBoxItem(
            title: "Shared decision",
            detail: "Revisit with more structure.",
            mode: .quick,
            prompt: "Should we commit now?",
            draft: TomorrowBoxDraft(
                prompt: "Should we commit now?",
                scenarioRaw: ScenarioType.other.rawValue,
                motivationRaw: MotivationChoice.genuineNeed.rawValue,
                expectedOutcomeRaw: OutcomeChoice.satisfied.rawValue,
                controlLevelRaw: ControlChoice.maybe.rawValue,
                note: "Need a cooler head first.",
                desire: nil,
                concern: nil,
                constraint: nil,
                longTerm: nil,
                emotion: nil,
                relationship: nil,
                reality: nil,
                selfLens: nil
            )
        )

        var cleared = false
        var activatedQuickNote: String?
        var markedReviewing = false
        var selectedHome = false
        var persisted = false

        BehavioralAISubstrateBridge.reopenSharedLifeItem(
            item,
            clearActiveDecisionFlows: { cleared = true },
            activateQuick: { session in
                activatedQuickNote = session.note
            },
            activateBalance: { _ in Issue.record("Unexpected balance activation") },
            activateMirror: { _ in Issue.record("Unexpected mirror activation") },
            markReviewing: { markedReviewing = true },
            selectHomeTab: { selectedHome = true },
            persistActiveWorkspaceState: { persisted = true }
        )

        #expect(cleared)
        #expect(activatedQuickNote == "Need a cooler head first.")
        #expect(markedReviewing)
        #expect(selectedHome)
        #expect(persisted)
    }

    @MainActor
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
    private func seedHistory(into context: ModelContext) {
        context.insert(
            CheckEvent(
                createdAt: date("2026-04-10T08:00:00Z"),
                scenario: .other,
                motivation: .genuineNeed,
                expectedOutcome: .satisfied,
                controlLevel: .maybe,
                note: "I want to reply fast.",
                currentPerspective: "You want a fast relief hit.",
                afterPerspective: "Waiting tends to clean this up.",
                verdict: .pause,
                finalAction: .decideTomorrow,
                reflectionOutcome: .betterThanExpected,
                entrySource: .app
            )
        )
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? Date(timeIntervalSince1970: 0)
    }

    private func expectedGovernancePressureLine() -> String {
        "L13 governance • candidates 1 • shadow 1 pending/1 • seal 1 pending/1 • version 1 • retract 1 pending/1 • nursery workflow 1 • guard 1 • bias 1 • risk 1 • export 0 • gate hold"
    }

    private func expectedResolvedGovernancePressureLine() -> String {
        "L13 governance • candidates 1 • shadow ready 1/1 • seal 1 pending/1 • version 1 • retract cleared 1 • nursery workflow 1 • guard 1 • bias 1 • risk 1 • export 0 • gate hold"
    }

    private func expectedVersionTreeLine() -> String {
        "L13 version tree • rule rule-1 • rollback rollback-1"
    }

    private func expectedPendingRetractionLine() -> String {
        "L13 retraction • pending rule-0 • reason superseded_by_shadow_trial"
    }

    private func expectedResolvedRetractionLine() -> String {
        "L13 retraction • cleared rule-0 • reason seal_review"
    }
}
