import XCTest
import BASHostKit
@testable import Before

final class DeveloperDecisionReplayBuilderTests: XCTestCase {
    func testLayerStackPresentationSupportRedactsInternalIdentifiersForUserSurfaces() {
        let rawLines = [
            "L3 compression runtime • fold checksum-1 • slots 2 • restore restore-1",
            "L5 host profile • host host.primary • goals 1 • no-go 1 • gate 37%",
            "L6 context • task protective review • session checkpoint-capability"
        ]

        XCTAssertEqual(
            DecisionLayerStackPresentationSupport.displayLines(for: rawLines),
            [
                "L3 compression runtime • fold active • slots 2 • restore ready",
                "L5 host profile • host aligned • goals 1 • no-go 1 • gate 37%",
                "L6 context • task protective review • state restored"
            ]
        )
    }

    func testLayerStackPresentationSupportBuildsRangeAwareTitles() {
        XCTAssertEqual(
            DecisionLayerStackPresentationSupport.title(
                for: [
                    "L1 power clock • mode GUARDED",
                    "L14 sovereign • active force_guard_mode"
                ]
            ),
            "Layers 1-14"
        )
        XCTAssertEqual(
            DecisionLayerStackPresentationSupport.title(
                for: [
                    "L6 context • task conflict",
                    "L14 sovereign • recommended require_reviewed_writes"
                ]
            ),
            "Layers 6-14"
        )
        XCTAssertEqual(
            DecisionLayerStackPresentationSupport.title(
                for: [
                    "L7-L9 cognition • recovered checkpoint lineage"
                ]
            ),
            "Layers 7-9"
        )
    }

    func testFactsBundleLayerStackLinesAreAlreadySanitizedForSharedSurfaces() {
        let factsBundle = DeveloperDecisionReplayEBrainSummary(turn: makeProtectiveTurn()).factsBundle()

        XCTAssertEqual(
            factsBundle.layerStackLines,
            expectedProtectiveLayerStackLines()
        )
    }

    func testBuildSortsNewestEntriesAcrossModesAndLimitsResults() {
        let now = Date()
        let quick = makeQuickEvent(createdAt: now.addingTimeInterval(-120), title: "Quick")
        let balance = makeBalanceRecord(updatedAt: now.addingTimeInterval(-60), prompt: "Balance")
        let mirror = makeMirrorRecord(updatedAt: now.addingTimeInterval(-10), prompt: "Mirror")

        let entries = DeveloperDecisionReplayBuilder.build(
            quick: [quick],
            balance: [balance],
            mirror: [mirror],
            traces: [],
            limit: 2
        )

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].mode, .mirror)
        XCTAssertEqual(entries[0].title, "Mirror")
        XCTAssertEqual(entries[1].mode, .balance)
        XCTAssertEqual(entries[1].title, "Balance")
    }

    func testBuildLinksNewestMatchingTraceForEachMode() {
        let now = Date()
        let quick = makeQuickEvent(createdAt: now, title: "Quick")
        let balance = makeBalanceRecord(updatedAt: now.addingTimeInterval(-30), prompt: "Balance")
        let mirror = makeMirrorRecord(updatedAt: now.addingTimeInterval(-60), prompt: "Mirror")

        let quickTrace = DecisionIntelligenceTrace(
            createdAt: now.addingTimeInterval(-5),
            kind: .quick,
            preferredProvider: .gemmaE4B,
            activeProvider: .foundationModels,
            attemptedProviders: [.gemmaE4B, .foundationModels],
            allowFallbacks: true,
            usedFallback: true,
            prompt: "Quick prompt",
            outputPreview: "Quick output",
            detail: "Quick detail"
        )
        let balanceTrace = DecisionIntelligenceTrace(
            createdAt: now.addingTimeInterval(-35),
            kind: .balance,
            preferredProvider: .foundationModels,
            activeProvider: .foundationModels,
            attemptedProviders: [.foundationModels],
            allowFallbacks: false,
            usedFallback: false,
            prompt: "Balance prompt",
            outputPreview: "Balance output",
            detail: "Balance detail"
        )
        let staleMirrorTrace = DecisionIntelligenceTrace(
            createdAt: now.addingTimeInterval(-(BeforePolicy.Settings.developerReplayTraceLookbackInterval + 180)),
            kind: .mirror,
            preferredProvider: .gemmaE4B,
            activeProvider: .gemmaE4B,
            attemptedProviders: [.gemmaE4B],
            allowFallbacks: true,
            usedFallback: false,
            prompt: "Mirror prompt",
            outputPreview: "Mirror output",
            detail: "Mirror detail"
        )

        let entries = DeveloperDecisionReplayBuilder.build(
            quick: [quick],
            balance: [balance],
            mirror: [mirror],
            traces: [staleMirrorTrace, balanceTrace, quickTrace]
        )

        XCTAssertEqual(entries.first(where: { $0.mode == .quick })?.trace?.prompt, "Quick prompt")
        XCTAssertEqual(entries.first(where: { $0.mode == .balance })?.trace?.prompt, "Balance prompt")
        XCTAssertNil(entries.first(where: { $0.mode == .mirror })?.trace)
    }

    func testBuildDoesNotReuseTheSameTraceTwice() {
        let now = Date()
        let newestQuick = makeQuickEvent(createdAt: now, title: "Newest")
        let olderQuick = makeQuickEvent(createdAt: now.addingTimeInterval(-20), title: "Older")
        let sharedTrace = DecisionIntelligenceTrace(
            createdAt: now.addingTimeInterval(-4),
            kind: .quick,
            preferredProvider: .gemmaE4B,
            activeProvider: .gemmaE4B,
            attemptedProviders: [.gemmaE4B],
            allowFallbacks: true,
            usedFallback: false,
            prompt: "Shared prompt",
            outputPreview: "Shared output",
            detail: "Shared detail"
        )

        let entries = DeveloperDecisionReplayBuilder.build(
            quick: [olderQuick, newestQuick],
            balance: [],
            mirror: [],
            traces: [sharedTrace]
        )

        XCTAssertEqual(entries[0].title, "Newest")
        XCTAssertEqual(entries[0].trace?.prompt, "Shared prompt")
        XCTAssertNil(entries[1].trace)
    }

    func testBuildFallsBackToPersistedCheckpointLineageWhenLiveTurnIsMissing() {
        let now = Date()
        let quick = makeQuickEvent(createdAt: now, title: "Quick")
        let lineage = BASEvolutionLineageSummary(
            recordedAt: now.addingTimeInterval(-5),
            sessionID: "before.quick.lineage",
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 82,
            thoughtFoldChecksum: "fold-checksum",
            updateTicketSummaries: ["Hold before sending"],
            guardrailFindings: ["Guardrail matched"],
            recommendedKillSwitches: ["host-write"]
        )
        let persisted = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-1",
            createdAt: now.addingTimeInterval(-4),
            mode: .quick,
            approvalState: .automatic,
            rollbackReady: true,
            diffSummary: ["Recovered from checkpoint"],
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: lineage)
        )

        let entries = DeveloperDecisionReplayBuilder.build(
            quick: [quick],
            balance: [],
            mirror: [],
            traces: [],
            eBrainTurns: [],
            persistedLineages: [persisted]
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries[0].trace)
        XCTAssertEqual(entries[0].diagnosticsPresentation.sourceTitle, "Checkpoint recovery")
        XCTAssertEqual(entries[0].eBrain?.sessionID, lineage.sessionID)
        XCTAssertEqual(entries[0].eBrain?.riskLevel, lineage.riskLevel)
        XCTAssertEqual(entries[0].eBrain?.permitMode, lineage.permitMode)
        XCTAssertEqual(entries[0].eBrain?.hostGatePercent, lineage.hostGatePercent)
        XCTAssertEqual(entries[0].eBrain?.thoughtFoldChecksum, lineage.thoughtFoldChecksum)
        XCTAssertEqual(entries[0].eBrain?.updateTicketSummaries, lineage.updateTicketSummaries)
        XCTAssertEqual(entries[0].eBrain?.guardrailFindings, lineage.guardrailFindings)
        XCTAssertEqual(entries[0].eBrain?.killSwitches, lineage.recommendedKillSwitches)
        XCTAssertEqual(entries[0].matchedPersistedCheckpointID, "checkpoint-1")
    }

    func testPersistedCheckpointLineageUsesStructuredL6ToL12SummariesWhenAvailable() {
        let summary = BASEvolutionLineageSummary(
            recordedAt: .now,
            sessionID: "checkpoint-rich",
            runMode: .guard,
            taskType: "conflict",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 82,
            thoughtFoldChecksum: "fold-rich",
            updateTicketSummaries: ["Hold before sending"],
            guardrailFindings: ["Guardrail matched"],
            recommendedKillSwitches: ["host-write"],
            neuralMorphID: "guard",
            activeOrganIDs: ["coreCortex", "criticBlade", "riskSpine", "permitKnot"],
            headGuarantees: ["risk_binding", "permit_gate", "stub_ready"],
            frontierWidth: 2,
            bindingCount: 2,
            projectionLeadCandidateID: "cand-2",
            projectionCandidateCount: 2,
            projectionForecastCount: 2,
            projectionCritiqueCount: 1,
            contextSummary: BASEvolutionLineageSummary.ContextSummary(
                emotionalLoadPercent: 82,
                timePressurePercent: 74,
                relationPattern: "self",
                ambiguityPercent: 63,
                consequencePercent: 81,
                manipulationHintCount: 1
            ),
            cognitionSummary: BASEvolutionLineageSummary.CognitionSummary(
                factCount: 4,
                goalCount: 2,
                unknownCount: 1,
                contradictionCount: 0,
                memoryAtomCount: 3,
                candidateCount: 2,
                forecastCount: 2,
                critiqueCount: 1,
                stopReasonID: "candidate_stable"
            ),
            adjudicationSummary: BASEvolutionLineageSummary.AdjudicationSummary(
                triScoreCount: 3,
                vetoCount: 1,
                gsiPercent: 68,
                alternativeActionCount: 2,
                emergencyBrakeLevelID: "cooldown"
            )
        )

        let eBrain = DeveloperDecisionReplayEBrainSummary(lineageSummary: summary)

        XCTAssertTrue(eBrain.layerStackLines.contains("L2 neural core • morph guard • organs coreCortex, criticBlade, riskSpine, permitKnot • heads risk_binding, permit_gate, stub_ready • frontier 2 • bindings 2 • projection cand-2/2/1 • recovered checkpoint fabric summary"))
        XCTAssertTrue(eBrain.layerStackLines.contains("L6 context • task conflict • load 82% • time 74% • relation self • ambiguity 63% • consequence 81% • manipulation 1"))
        XCTAssertTrue(eBrain.layerStackLines.contains("L7-L9 cognition • facts 4 • goals 2 • unknowns 1 • contradictions 0 • memory 3 • candidates 2/forecasts 2/critiques 1 • stop candidate_stable"))
        XCTAssertTrue(eBrain.layerStackLines.contains("L10-L12 adjudication • tri 3 scored/1 veto • HIGH → DELAY • GSI 68% • alternatives 2 • brake cooldown"))
    }

    func testLiveAndPersistedStructuredLayerStacksStayAlignedForL2ToL12() throws {
        let turn = makeProtectiveTurn()
        let live = DeveloperDecisionReplayEBrainSummary(turn: turn)
        let persisted = DeveloperDecisionReplayEBrainSummary(lineageSummary: turn.evolutionLineageSummary)

        let liveL2 = try XCTUnwrap(
            live.layerStackLines.first(where: { $0.hasPrefix("L2 neural core") })
        )
        let persistedL2 = try XCTUnwrap(
            persisted.layerStackLines.first(where: { $0.hasPrefix("L2 neural core") })
        )

        XCTAssertEqual(
            sharedNeuralCorePrefix(in: liveL2),
            sharedNeuralCorePrefix(in: persistedL2)
        )

        ["L6 context", "L7-L9 cognition", "L10-L12 adjudication"].forEach { prefix in
            XCTAssertEqual(
                live.layerStackLines.first(where: { $0.hasPrefix(prefix) }),
                persisted.layerStackLines.first(where: { $0.hasPrefix(prefix) })
            )
        }
    }

    func testBuildConsumesPersistedLineageMatchedToLiveTurnAnchor() {
        let now = Date()
        let quick = makeQuickEvent(createdAt: now, title: "Quick")
        let turn = makeProtectiveTurn()
        let matchingLineage = makeLineageSnapshot(
            sessionID: "session-1",
            mode: .quick,
            recordedAt: now.addingTimeInterval(-4),
            riskLevel: "high",
            permitMode: "delay",
            updateTicketSummaries: ["matching lineage"],
            diffSummary: ["Matching persisted lineage"],
            activeKillSwitches: [],
            recommendedKillSwitches: ["host-write"],
            thoughtFoldChecksum: "checksum-1"
        )
        let unrelatedLineage = makeLineageSnapshot(
            sessionID: "session-unrelated",
            mode: .quick,
            recordedAt: now.addingTimeInterval(-2),
            riskLevel: "medium",
            permitMode: "compare",
            updateTicketSummaries: ["unrelated lineage"],
            diffSummary: ["Unrelated persisted lineage"],
            activeKillSwitches: [],
            recommendedKillSwitches: [],
            thoughtFoldChecksum: "checksum-unrelated"
        )

        let entries = DeveloperDecisionReplayBuilder.build(
            quick: [quick],
            balance: [],
            mirror: [],
            traces: [],
            eBrainTurns: [turn],
            persistedLineages: [matchingLineage, unrelatedLineage]
        )

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].matchedPersistedCheckpointID, matchingLineage.checkpointID)
        XCTAssertEqual(
            entries.compactMap { entry -> String? in
                if case .checkpoint(let lineage) = entry.record {
                    return lineage.checkpointID
                }
                return nil
            },
            [unrelatedLineage.checkpointID]
        )
    }

    func testBuildPrefersPersistedLineageSharingRollbackAnchor() {
        let now = Date()
        let quick = makeQuickEvent(createdAt: now, title: "Quick")
        let turn = makeProtectiveTurn()
        let liveRollbackAnchorID = DecisionFoldedLungCoordinator.snapshot(for: turn).rollbackAnchor.anchorID

        let wrongAnchorSummary = BASEvolutionLineageSummary(
            recordedAt: now.addingTimeInterval(-1),
            sessionID: "session-1",
            taskType: "high_pressure",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 82,
            thoughtFoldChecksum: "checksum-1",
            updateTicketSummaries: ["closer but wrong anchor"],
            guardrailFindings: ["Guardrail matched"],
            recommendedKillSwitches: ["host-write"],
            foldedLungSummary: BASEvolutionFoldedLungSummary(
                breathMode: "guard",
                breathPhase: "exchange",
                thermalPressure: 63,
                cachePressure: 48,
                restoreReadinessPercent: 84,
                resumeID: "resume-wrong",
                sourceFoldID: "fold-1",
                resumeDepth: 1,
                requiredOrganIDs: ["stubCore", "riskSpine", "permitKnot"],
                consistencyChecks: ["fold_checksum", "host_gate"],
                fallbackMode: "rollbackAnchor",
                rollbackAnchorID: "rollback.session-1.other-fold",
                safeSnapshotRef: "snapshot-wrong",
                foldRefs: ["fold-1"],
                hostVersionRef: "host.v1",
                cacheStateRef: "cache-wrong",
                integrityHash: "checksum-1"
            )
        )
        let matchingAnchorSummary = BASEvolutionLineageSummary(
            recordedAt: now.addingTimeInterval(-4),
            sessionID: "session-1",
            taskType: "high_pressure",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 82,
            thoughtFoldChecksum: "checksum-1",
            updateTicketSummaries: ["older but matching anchor"],
            guardrailFindings: ["Guardrail matched"],
            recommendedKillSwitches: ["host-write"],
            foldedLungSummary: BASEvolutionFoldedLungSummary(
                breathMode: "guard",
                breathPhase: "exchange",
                thermalPressure: 63,
                cachePressure: 48,
                restoreReadinessPercent: 84,
                resumeID: "resume-match",
                sourceFoldID: "fold-1",
                resumeDepth: 1,
                requiredOrganIDs: ["stubCore", "riskSpine", "permitKnot"],
                consistencyChecks: ["fold_checksum", "host_gate"],
                fallbackMode: "rollbackAnchor",
                rollbackAnchorID: liveRollbackAnchorID,
                safeSnapshotRef: "snapshot-match",
                foldRefs: ["fold-1"],
                hostVersionRef: "host.v1",
                cacheStateRef: "cache-match",
                integrityHash: "checksum-1"
            )
        )
        let wrongAnchorLineage = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-wrong-anchor",
            createdAt: wrongAnchorSummary.recordedAt,
            mode: .quick,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Closer timestamp but mismatched rollback anchor"],
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: wrongAnchorSummary)
        )
        let matchingAnchorLineage = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-matching-anchor",
            createdAt: matchingAnchorSummary.recordedAt,
            mode: .quick,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: ["Older timestamp but matching rollback anchor"],
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: matchingAnchorSummary)
        )

        let entries = DeveloperDecisionReplayBuilder.build(
            quick: [quick],
            balance: [],
            mirror: [],
            traces: [],
            eBrainTurns: [turn],
            persistedLineages: [wrongAnchorLineage, matchingAnchorLineage]
        )

        XCTAssertEqual(entries.first?.matchedPersistedCheckpointID, matchingAnchorLineage.checkpointID)
    }

    func testPersistedLineageRestoresMorphGraphAndPrecisionProfileFacts() throws {
        let summary = BASEvolutionLineageSummary(
            recordedAt: Date(timeIntervalSince1970: 1_776_100_000),
            sessionID: "session-l3",
            taskType: "high_pressure",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 79,
            thoughtFoldChecksum: "checksum-l3",
            updateTicketSummaries: ["Preserve folded runtime policy"],
            guardrailFindings: ["Guardrail matched"],
            recommendedKillSwitches: ["host-write"],
            foldedLungSummary: BASEvolutionFoldedLungSummary(
                morphGraphID: "morph.session-l3",
                hotColdMapID: "hotcold.session-l3",
                precisionProfileID: "precision.session-l3",
                lungStateRef: "lung.session-l3",
                breathSchedulerID: "scheduler.session-l3",
                breathMode: "guard",
                breathPhase: "resume",
                thermalPressure: 73,
                cachePressure: 42,
                restoreReadinessPercent: 88,
                resumeID: "resume.session-l3",
                sourceFoldID: "fold.session-l3",
                resumeDepth: 2,
                requiredOrganIDs: ["stubCore", "riskSpine", "permitKnot"],
                consistencyChecks: ["fold_checksum", "risk_permit"],
                fallbackMode: "rollbackAnchor",
                rollbackAnchorID: "rollback.session-l3",
                safeSnapshotRef: "snapshot.session-l3",
                foldRefs: ["fold.session-l3"],
                hostVersionRef: "host.v3",
                cacheStateRef: "cache.session-l3",
                integrityHash: "hash.session-l3",
                morphActiveOrganIDs: ["stubCore", "riskSpine", "permitKnot"],
                morphExecutionOrder: ["stubCore", "riskSpine", "permitKnot"],
                morphPrecisionRecords: [
                    .init(organID: "stubCore", tierID: "full"),
                    .init(organID: "riskSpine", tierID: "protected"),
                    .init(organID: "permitKnot", tierID: "protected")
                ],
                morphDeviceRouteMap: [
                    "stubCore": "coreNPU",
                    "riskSpine": "coreNPU",
                    "permitKnot": "scoutCPU"
                ],
                morphThermalProfile: ["thermal.hot", "latency.192", "cadence.resume_guarded"],
                morphSovereignConstraints: ["rollback", "memoryFreeze"],
                hotOrganIDs: ["stubCore", "riskSpine", "permitKnot"],
                warmOrganIDs: ["memoryCodecRidge", "hostModulationMesh", "toolIntentMesh"],
                coldOrganIDs: ["scoutStrip", "simuRing", "criticBlade", "consistencyLattice", "tissueRouter"],
                hotColdPreloadPolicy: "guard_preload",
                hotColdEvictionPolicy: "protective_retain",
                schedulerCadenceTag: "guard_resume",
                schedulerCheckpointCadence: "anchor_each_turn",
                schedulerMicroSleepWindowMs: 180,
                schedulerBackgroundMaintenanceWindowMs: 0,
                schedulerAllowsBackgroundMaintenance: false,
                schedulerAllowsMicroSleep: true,
                schedulerResumeBudgetClass: "rollback_hot",
                schedulerReasonCodes: ["risk_guard", "restore_ready"],
                precisionOrganPrecisionRecords: [
                    .init(organID: "stubCore", tierID: "full"),
                    .init(organID: "riskSpine", tierID: "protected"),
                    .init(organID: "permitKnot", tierID: "protected")
                ],
                precisionLockedOrganIDs: ["riskSpine", "permitKnot", "stubCore"],
                precisionDegradationOrder: ["full", "protected", "balanced", "minimal"],
                precisionGuardSafeFloorID: "protected"
            )
        )

        let eBrain = DeveloperDecisionReplayEBrainSummary(lineageSummary: summary)

        XCTAssertEqual(eBrain.morphGraph?.graphID, "morph.session-l3")
        XCTAssertEqual(eBrain.morphGraph?.executionOrder, ["stubCore", "riskSpine", "permitKnot"])
        XCTAssertEqual(eBrain.morphGraph?.deviceRouteMap["permitKnot"], "scoutCPU")
        XCTAssertEqual(
            eBrain.hotColdMap?.hotOrgans,
            [.stubCore, .riskSpine, .permitKnot]
        )
        XCTAssertEqual(
            eBrain.hotColdMap?.warmOrgans,
            [.memoryCodecRidge, .hostModulationMesh, .toolIntentMesh]
        )
        XCTAssertEqual(eBrain.hotColdMap?.preloadPolicy, "guard_preload")
        XCTAssertEqual(eBrain.hotColdMap?.evictionPolicy, "protective_retain")
        XCTAssertTrue(eBrain.hotColdLine?.contains("Hot pack stubCore, riskSpine, permitKnot") == true)
        XCTAssertEqual(eBrain.breathScheduler?.schedulerID, "scheduler.session-l3")
        XCTAssertEqual(eBrain.breathScheduler?.cadenceTag, "guard_resume")
        XCTAssertEqual(eBrain.breathScheduler?.checkpointCadence, "anchor_each_turn")
        XCTAssertEqual(eBrain.breathScheduler?.microSleepWindowMs, 180)
        XCTAssertEqual(eBrain.breathScheduler?.resumeBudgetClass, "rollback_hot")
        XCTAssertTrue(eBrain.schedulerLine?.contains("guard_resume") == true)
        XCTAssertEqual(eBrain.precisionProfile?.guardSafeFloor, .protected)
        XCTAssertEqual(
            eBrain.precisionProfile?.lockedPrecisions,
            [
                BASNeuralOrgan.riskSpine,
                BASNeuralOrgan.permitKnot,
                BASNeuralOrgan.stubCore
            ]
        )
    }

    func testPersistedLineageSurfaceIncludesStructuredL14SovereignFacts() {
        let summary = BASEvolutionLineageSummary(
            recordedAt: Date(timeIntervalSince1970: 1_776_150_000),
            sessionID: "session-l14",
            taskType: "high_pressure",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 81,
            thoughtFoldChecksum: "checksum-l14",
            updateTicketSummaries: ["Freeze the unsafe mutation path."],
            guardrailFindings: ["Guardrail matched"],
            recommendedKillSwitches: [],
            sovereignVerdict: BASSovereignVerdict(
                verdictID: "verdict.session-l14",
                verdictLevel: .quarantine,
                latched: true,
                forcedMode: .quarantine,
                reasonCodes: ["runtime.quarantine"],
                revokedPermissions: [.toolWrite, .memoryWriteCold],
                quarantineRefs: ["session-l14", "fold.session-l14"],
                rollbackRef: "snapshot.session-l14",
                userStubMode: .minimalReceipt,
                auditRef: "audit.session-l14",
                policyHash: "policy-hash.session-l14"
            ),
            sovereignCommitTokens: [
                BASSovereignCommitToken(
                    tokenID: "token.session-l14.memory",
                    sessionID: "session-l14",
                    turnID: "turn-l14",
                    scope: .memoryWrite,
                    allowedTargets: ["ticket-l14"],
                    actionDigest: "digest-l14",
                    snapshotRef: "snapshot.session-l14",
                    policyHash: "policy-hash.session-l14",
                    ttlMs: 30_000,
                    nonce: "nonce-l14",
                    singleUse: true,
                    signature: "signature-l14"
                )
            ],
            sovereignLock: BASSovereignLock(
                lockID: "lock.session-l14",
                scope: .session,
                lockLevel: .quarantine,
                createdAt: Date(timeIntervalSince1970: 1_776_150_001),
                releaseCondition: "manual_review"
            ),
            quarantineRecords: [
                BASQuarantineRecord(
                    quarantineID: "quarantine.session-l14",
                    zone: .session,
                    sourceRef: "session-l14",
                    reasonCodes: ["runtime.quarantine"],
                    isolatedAt: Date(timeIntervalSince1970: 1_776_150_002),
                    releasePolicy: "manual_review",
                    reviewState: .held
                )
            ],
            sovereignAuditEntry: BASSovereignAuditEntry(
                auditID: "audit.session-l14",
                sessionID: "session-l14",
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
        )

        let replaySummary = DeveloperDecisionReplayEBrainSummary(lineageSummary: summary)

        XCTAssertEqual(
            replaySummary.layerStackLines.last,
            "L14 sovereign • verdict quarantine • tokens memoryWrite • lock session • quarantine session • audit BR-SOV-004"
        )
    }

    func testBuildIncludesCheckpointOnlyReplayEntriesWhenNoMatchingRecordExists() {
        let now = Date()
        let lineage = BASEvolutionLineageSummary(
            recordedAt: now,
            sessionID: "before.mirror.lineage",
            taskType: "reflection",
            riskLevel: "medium",
            permitMode: "compare",
            hostGatePercent: 61,
            thoughtFoldChecksum: "fold-checkpoint",
            updateTicketSummaries: ["capture calmer follow-up"],
            guardrailFindings: ["Recovered lineage available"],
            recommendedKillSwitches: []
        )
        let persisted = DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-standalone",
            createdAt: now.addingTimeInterval(5),
            mode: .mirror,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            diffSummary: ["Recovered persisted checkpoint without matching replay record"],
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: lineage)
        )

        let entries = DeveloperDecisionReplayBuilder.build(
            quick: [],
            balance: [],
            mirror: [],
            traces: [],
            eBrainTurns: [],
            persistedLineages: [persisted]
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].mode, .mirror)
        XCTAssertEqual(entries[0].title, "Recovered Mirror lineage")
        XCTAssertEqual(entries[0].statusTitle, "Review Suggested")
        XCTAssertEqual(entries[0].summaryLine, "Recovered persisted checkpoint without matching replay record")
        XCTAssertEqual(entries[0].diagnosticsPresentation.sourceTitle, "Checkpoint recovery")
        XCTAssertEqual(entries[0].eBrain?.source, .persistedCheckpoint)
        XCTAssertEqual(entries[0].eBrain?.sessionID, lineage.sessionID)
    }

    func testDecisionSystemEBrainSummarySourceDescriptorReflectsSummarySource() {
        let liveSummary = makeSystemEBrainSummary(source: .liveRuntime)
        XCTAssertEqual(liveSummary.sourceDescriptor.kind, .liveRuntime)
        XCTAssertEqual(liveSummary.sourceDescriptor.title, "Live runtime")

        let checkpointSummary = makeSystemEBrainSummary(source: .persistedCheckpoint)
        XCTAssertEqual(checkpointSummary.sourceDescriptor.kind, .checkpointRecovery)
        XCTAssertEqual(checkpointSummary.sourceDescriptor.title, "Checkpoint recovery")
    }

    func testDecisionSystemEBrainSummaryPresentationDerivesSharedRuntimeLines() {
        let summary = makeSystemEBrainSummary(source: .persistedCheckpoint)

        let presentation = summary.presentation

        XCTAssertEqual(presentation.sourceDescriptor.kind, .checkpointRecovery)
        XCTAssertEqual(
            presentation.statusLine,
            "GUARDED • high pressure • HIGH → DELAY"
        )
        XCTAssertEqual(
            presentation.routeLine,
            "Route guarded • Loops 1 • Cache 0% • Tickets 1"
        )
        XCTAssertNil(presentation.pressureLine)
        XCTAssertEqual(
            presentation.hostLine,
            "Host gate 37% • Fold checksum-1 • Audit 1"
        )
        XCTAssertEqual(
            presentation.inspectionHeadline,
            "Protective runtime turn attached."
        )
        XCTAssertNil(presentation.primaryGuardrailText)
        XCTAssertEqual(
            presentation.detailLines,
            [
                "GUARDED • high pressure • HIGH → DELAY",
                "Route guarded • Loops 1 • Cache 0% • Tickets 1",
                "Host gate 37% • Fold checksum-1 • Audit 1",
                "Protective runtime turn attached."
            ]
        )
        XCTAssertNil(presentation.alertLine)
    }

    func testDecisionSystemEBrainSummaryPresentationCarriesLivePressureLine() {
        let summary = makeSystemEBrainSummary(
            source: .liveRuntime,
            pressureLine: "Pressure latency 3/1400ms • power 12% • cache 0% • thermal cool"
        )

        let presentation = summary.presentation

        XCTAssertEqual(presentation.sourceDescriptor.kind, .liveRuntime)
        XCTAssertEqual(
            presentation.pressureLine,
            "Pressure latency 3/1400ms • power 12% • cache 0% • thermal cool"
        )
        XCTAssertEqual(
            presentation.detailLines,
            [
                "GUARDED • high pressure • HIGH → DELAY",
                "Route guarded • Loops 1 • Cache 0% • Tickets 1",
                "Pressure latency 3/1400ms • power 12% • cache 0% • thermal cool",
                "Host gate 37% • Fold checksum-1 • Audit 1",
                "Protective runtime turn attached."
            ]
        )
    }

    func testDecisionSystemEBrainSummaryPresentationCarriesStructuredSovereignLines() {
        let summary = makeSystemEBrainSummary(
            source: .persistedCheckpoint,
            sovereignVerdictLine: "Sovereign verdict quarantine • latched • mode quarantine • reasons runtime.quarantine",
            sovereignAuthorityLine: "tokens memoryWrite • lock session • quarantine session",
            sovereignAuditLine: "Sovereign audit • BR-SOV-004 • ref audit.session-l14"
        )

        let presentation = summary.presentation

        XCTAssertEqual(
            presentation.sovereignVerdictLine,
            "Sovereign verdict quarantine • latched • mode quarantine • reasons runtime.quarantine"
        )
        XCTAssertEqual(
            presentation.sovereignAuthorityLine,
            "tokens memoryWrite • lock session • quarantine session"
        )
        XCTAssertEqual(
            presentation.sovereignAuditLine,
            "Sovereign audit • BR-SOV-004 • ref audit.session-l14"
        )
        XCTAssertEqual(
            presentation.detailLines,
            [
                "GUARDED • high pressure • HIGH → DELAY",
                "Route guarded • Loops 1 • Cache 0% • Tickets 1",
                "Host gate 37% • Fold checksum-1 • Audit 1",
                "Sovereign verdict quarantine • latched • mode quarantine • reasons runtime.quarantine",
                "tokens memoryWrite • lock session • quarantine session",
                "Sovereign audit • BR-SOV-004 • ref audit.session-l14",
                "Protective runtime turn attached."
            ]
        )
    }

    func testDecisionSystemFlightDeckEBrainDigestPresentationDerivesSharedHomeAndPortraitLines() throws {
        let summary = makeSystemEBrainSummary(source: .persistedCheckpoint)
        let flightDeck = DecisionSystemFlightDeck(
            generatedAt: .now,
            overallScore: 92,
            overallHealth: .watch,
            layerReports: [],
            sessionEngineSummary: nil,
            localModelLibrarySummary: nil,
            isPureLocalClosedLoop: true,
            dominantBlockers: [],
            eBrainSummary: summary,
            releaseControlSummary: DecisionSystemReleaseControlSummary(
                state: .watch,
                headline: "Guarded release watch",
                reasons: ["Recommended controls pending."],
                activeKillSwitches: ["force_guard_mode", "disable_fast_path"],
                recommendedKillSwitches: ["require_reviewed_writes", "tool_call"],
                killSwitches: [
                    "force_guard_mode",
                    "disable_fast_path",
                    "require_reviewed_writes",
                    "tool_call"
                ],
                pendingReviewCount: 1,
                rollbackReadyCount: 0,
                canRestoreActiveCheckpoint: false,
                canRollbackActiveCheckpoint: false,
                activeCheckpointID: nil,
                activeCheckpointSource: .none,
                reviewCheckpointID: nil
            ),
            evolutionControlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil
            ),
            pendingReviewCheckpointCount: 0,
            pendingReviewQueue: []
        )

        let presentation = try XCTUnwrap(flightDeck.eBrainDigestPresentation)

        XCTAssertEqual(presentation.digest.sourceDescriptor.kind, .checkpointRecovery)
        XCTAssertEqual(presentation.digest.compactStatusLine, "GUARDED • HIGH → DELAY")
        XCTAssertEqual(presentation.digest.taskTitle, "high pressure")
        XCTAssertEqual(
            presentation.digest.operationsLine,
            "Audit 1 • Active kill switches 2 • Recommended 2 • Host gate 37%"
        )
        XCTAssertEqual(
            presentation.statusLine,
            "GUARDED • high pressure • HIGH → DELAY"
        )
        XCTAssertEqual(
            presentation.routeLine,
            "Route guarded • Loops 1 • Cache 0% • Tickets 1"
        )
        XCTAssertEqual(
            presentation.hostLine,
            "Host gate 37% • Fold checksum-1 • Audit 1"
        )
        XCTAssertEqual(
            presentation.inspectionHeadline,
            "Protective runtime turn attached."
        )
        XCTAssertNil(presentation.primaryGuardrailText)
        XCTAssertEqual(
            presentation.detailLines,
            [
                "GUARDED • high pressure • HIGH → DELAY",
                "Route guarded • Loops 1 • Cache 0% • Tickets 1",
                "Host gate 37% • Fold checksum-1 • Audit 1",
                "Protective runtime turn attached."
            ]
        )
        XCTAssertEqual(presentation.layerStackLines, summary.layerStackLines)
        XCTAssertEqual(
            [presentation.digest.operationsLine] + Array(presentation.detailLines.dropFirst()),
            [
                "Audit 1 • Active kill switches 2 • Recommended 2 • Host gate 37%",
                "Route guarded • Loops 1 • Cache 0% • Tickets 1",
                "Host gate 37% • Fold checksum-1 • Audit 1",
                "Protective runtime turn attached."
            ]
        )
        XCTAssertNil(presentation.alertLine)
    }

    func testDecisionSystemFlightDeckEBrainDigestPresentationCarriesLivePressureIntoSharedHomeSummaryLines() throws {
        let summary = makeSystemEBrainSummary(
            source: .liveRuntime,
            pressureLine: "Pressure latency 3/1400ms • power 12% • cache 0% • thermal cool"
        )
        let flightDeck = DecisionSystemFlightDeck(
            generatedAt: .now,
            overallScore: 92,
            overallHealth: .watch,
            layerReports: [],
            sessionEngineSummary: nil,
            localModelLibrarySummary: nil,
            isPureLocalClosedLoop: true,
            dominantBlockers: [],
            eBrainSummary: summary,
            releaseControlSummary: DecisionSystemReleaseControlSummary(
                state: .watch,
                headline: "Guarded release watch",
                reasons: ["Recommended controls pending."],
                activeKillSwitches: ["force_guard_mode", "disable_fast_path"],
                recommendedKillSwitches: ["require_reviewed_writes", "tool_call"],
                killSwitches: [
                    "force_guard_mode",
                    "disable_fast_path",
                    "require_reviewed_writes",
                    "tool_call"
                ],
                pendingReviewCount: 1,
                rollbackReadyCount: 0,
                canRestoreActiveCheckpoint: false,
                canRollbackActiveCheckpoint: false,
                activeCheckpointID: nil,
                activeCheckpointSource: .none,
                reviewCheckpointID: nil
            ),
            evolutionControlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil
            ),
            pendingReviewCheckpointCount: 0,
            pendingReviewQueue: []
        )

        let presentation = try XCTUnwrap(flightDeck.eBrainDigestPresentation)

        XCTAssertEqual(
            [presentation.digest.operationsLine] + Array(presentation.detailLines.dropFirst()),
            [
                "Audit 1 • Active kill switches 2 • Recommended 2 • Host gate 37%",
                "Route guarded • Loops 1 • Cache 0% • Tickets 1",
                "Pressure latency 3/1400ms • power 12% • cache 0% • thermal cool",
                "Host gate 37% • Fold checksum-1 • Audit 1",
                "Protective runtime turn attached."
            ]
        )
        XCTAssertFalse(presentation.summaryLines.contains(where: { $0.contains("L6 context") }))
        XCTAssertFalse(presentation.summaryLines.contains(where: { $0.contains("L13 evolution") }))
        XCTAssertEqual(presentation.layerStackLines, summary.layerStackLines)
    }

    func testDecisionSystemFlightDeckEBrainDigestPresentationElevatesHorizonDiagnosticsIntoAlertLine() throws {
        let summary = makeSystemEBrainSummary(
            source: .liveRuntime,
            riskFactorsLine: "Factors: evidence_caveat_load",
            reasonCodesLine: "Reason codes: evidence.caveat"
        )
        let flightDeck = DecisionSystemFlightDeck(
            generatedAt: .now,
            overallScore: 92,
            overallHealth: .watch,
            layerReports: [],
            sessionEngineSummary: nil,
            localModelLibrarySummary: nil,
            isPureLocalClosedLoop: true,
            dominantBlockers: [],
            eBrainSummary: summary,
            releaseControlSummary: DecisionSystemReleaseControlSummary(
                state: .watch,
                headline: "Guarded release watch",
                reasons: ["Recommended controls pending."],
                activeKillSwitches: ["force_guard_mode", "disable_fast_path"],
                recommendedKillSwitches: ["require_reviewed_writes", "tool_call"],
                killSwitches: [
                    "force_guard_mode",
                    "disable_fast_path",
                    "require_reviewed_writes",
                    "tool_call"
                ],
                pendingReviewCount: 1,
                rollbackReadyCount: 0,
                canRestoreActiveCheckpoint: false,
                canRollbackActiveCheckpoint: false,
                activeCheckpointID: nil,
                activeCheckpointSource: .none,
                reviewCheckpointID: nil
            ),
            evolutionControlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil
            ),
            pendingReviewCheckpointCount: 0,
            pendingReviewQueue: []
        )

        let presentation = try XCTUnwrap(flightDeck.eBrainDigestPresentation)

        XCTAssertEqual(presentation.alertLine, "Horizon diagnostics active")
        XCTAssertEqual(presentation.primaryGuardrailText, "Horizon diagnostics active")
        XCTAssertTrue(presentation.summaryLines.contains("Factors: evidence_caveat_load"))
        XCTAssertTrue(presentation.summaryLines.contains("Reason codes: evidence.caveat"))
    }

    func testDecisionSystemFlightDeckDigestPresentationCarriesFoldedLungReceiptDetailsAndResumeOrgans() throws {
        let summary = DecisionSystemEBrainSummary(
            source: .persistedCheckpoint,
            runMode: "guarded",
            taskType: "high_pressure",
            riskLevel: "high",
            permitMode: "delay",
            deviceRoute: "guarded",
            loopCount: 1,
            cacheHitRate: 0,
            hostGatePercent: 37,
            pressureLine: nil,
            foldChecksum: "checksum-1",
            updateTicketCount: 1,
            auditFindingCount: 1,
            activeKillSwitches: ["force_guard_mode"],
            recommendedKillSwitches: ["require_reviewed_writes"],
            killSwitches: ["force_guard_mode", "require_reviewed_writes"],
            inspectionHeadline: "Protective runtime turn attached.",
            blockers: [],
            layerStackLines: expectedProtectiveLayerStackLines(),
            checkpointID: nil,
            checkpointApprovalState: nil,
            checkpointRollbackReady: nil,
            checkpointApplyReady: nil,
            lungState: BASLungState(
                breathMode: .guard,
                breathPhase: .resume,
                thermalPressure: 23,
                cachePressure: 12,
                restoreReadiness: 0.91,
                rollbackAnchorRef: "anchor-safe"
            ),
            resumeFrame: BASResumeFrame(
                resumeID: "resume-safe",
                sourceFoldID: "fold-capability",
                resumeDepth: 2,
                requiredOrgans: [.riskSpine, .permitKnot, .stubCore],
                consistencyChecks: ["hash"],
                fallbackMode: .rollbackAnchor
            ),
            rollbackAnchor: BASRollbackAnchor(
                anchorID: "anchor-safe",
                safeSnapshotRef: "snapshot-safe",
                foldRefs: ["fold-capability"],
                hostVersionRef: "host-v1",
                cacheStateRef: "cache-safe",
                integrityHash: "hash-safe"
            ),
            sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult(
                actuationKinds: [.rollback],
                invalidatedResumeFrameIDs: ["resume-safe"],
                invalidatedCacheRefs: ["cache-safe"],
                invalidatedFoldRefs: ["fold-capability"],
                quarantinedFoldRefs: [],
                resultingBreathMode: .guard,
                preservedReadOnlyRecovery: true,
                summary: "rollback -> snapshot-safe • guard breath"
            )
        )
        let flightDeck = DecisionSystemFlightDeck(
            generatedAt: .now,
            overallScore: 92,
            overallHealth: .watch,
            layerReports: [],
            sessionEngineSummary: nil,
            localModelLibrarySummary: nil,
            isPureLocalClosedLoop: true,
            dominantBlockers: [],
            eBrainSummary: summary,
            releaseControlSummary: DecisionSystemReleaseControlSummary(
                state: .watch,
                headline: "Guarded release watch",
                reasons: ["Recommended controls pending."],
                activeKillSwitches: ["force_guard_mode", "disable_fast_path"],
                recommendedKillSwitches: ["require_reviewed_writes", "tool_call"],
                killSwitches: [
                    "force_guard_mode",
                    "disable_fast_path",
                    "require_reviewed_writes",
                    "tool_call"
                ],
                pendingReviewCount: 1,
                rollbackReadyCount: 0,
                canRestoreActiveCheckpoint: false,
                canRollbackActiveCheckpoint: false,
                activeCheckpointID: nil,
                activeCheckpointSource: .none,
                reviewCheckpointID: nil
            ),
            evolutionControlSurface: DecisionEvolutionControlSurface(
                activeCheckpoint: nil,
                reviewCheckpoint: nil,
                pendingReviewQueue: [],
                latestPersistedLineage: nil
            ),
            pendingReviewCheckpointCount: 0,
            pendingReviewQueue: []
        )

        let presentation = try XCTUnwrap(flightDeck.eBrainDigestPresentation)

        XCTAssertTrue(
            presentation.detailLines.contains(
                "Resume frame resume-safe • source fold-capability • depth 2 • organs riskSpine, permitKnot, stubCore"
            )
        )
        XCTAssertTrue(presentation.detailLines.contains("rollback -> snapshot-safe • guard breath"))
        XCTAssertTrue(presentation.detailLines.contains("Sovereign invalidated resume resume-safe"))
        XCTAssertTrue(presentation.detailLines.contains("Sovereign invalidated cache cache-safe"))
        XCTAssertTrue(presentation.detailLines.contains("Sovereign invalidated fold fold-capability"))
        XCTAssertTrue(presentation.detailLines.contains("Sovereign readonly recovery"))
        XCTAssertTrue(presentation.detailLines.contains("Sovereign mode guard"))
        XCTAssertTrue(presentation.summaryLines.contains("Sovereign invalidated fold fold-capability"))
        XCTAssertTrue(presentation.summaryLines.contains("Sovereign readonly recovery"))
        XCTAssertTrue(presentation.summaryLines.contains("Sovereign mode guard"))
    }

    func testDecisionSystemFlightDeckBuilderRemovesLayerStackSignalsFromSummarySurfaces() {
        let layerStackLines = [
            "L6 context • task high pressure • load 82%",
            "L13 evolution • 1 tickets • Review memory write: Keep the boundary signal in warm memory."
        ]

        XCTAssertEqual(
            DecisionSystemFlightDeckBuilder.removingLayerStackSignals(
                from: [
                    "Audit 1 • Active kill switches 2 • Recommended 2 • Host gate 37%",
                    layerStackLines[0],
                    layerStackLines.joined(separator: " | "),
                    "L13 evolution • replayed from persisted checkpoint",
                    "Route guarded • Loops 1 • Cache 0% • Tickets 1"
                ],
                layerStackLines: layerStackLines
            ),
            [
                "Audit 1 • Active kill switches 2 • Recommended 2 • Host gate 37%",
                "Route guarded • Loops 1 • Cache 0% • Tickets 1"
            ]
        )
    }

    func testBaseBrainTurnBuildsSystemFlightDeckSummaryFromSharedFacts() {
        let turn = makeProtectiveTurn()
        let inspection = BASEBrainConsoleSupport.inspectionBundle(for: turn)

        let summary = turn.systemFlightDeckSummary

        XCTAssertEqual(summary.source, .liveRuntime)
        XCTAssertEqual(summary.runMode, turn.budgetFrame.runMode.displayTitle)
        XCTAssertEqual(summary.taskType, turn.contextFrame.taskType.rawValue)
        XCTAssertEqual(summary.riskLevel, turn.riskCard.riskLevel.rawValue)
        XCTAssertEqual(summary.permitMode, turn.actionPermit.mode.rawValue)
        XCTAssertEqual(summary.deviceRoute, turn.runtimeTrace.modelRoute)
        XCTAssertEqual(summary.loopCount, turn.runtimeTrace.loopCount)
        XCTAssertEqual(summary.cacheHitRate, Int((turn.runtimeTrace.cacheHitRate * 100).rounded()))
        XCTAssertEqual(summary.hostGatePercent, Int((turn.hostGateValue * 100).rounded()))
        XCTAssertEqual(summary.pressureLine, turn.replayCheckpointFacts.pressureLine)
        XCTAssertEqual(summary.updateTicketCount, turn.updateTickets.count)
        XCTAssertEqual(summary.auditFindingCount, turn.runtimeTrace.guardrailFindings.count)
        XCTAssertEqual(summary.activeKillSwitches, ["force_guard_mode"])
        XCTAssertEqual(summary.recommendedKillSwitches, ["require_reviewed_writes"])
        XCTAssertEqual(summary.killSwitches, ["force_guard_mode", "require_reviewed_writes"])
        XCTAssertEqual(
            summary.sovereignVerdictLine,
            "Sovereign verdict quarantine • latched • mode quarantine • reasons runtime.quarantine"
        )
        XCTAssertEqual(
            summary.sovereignAuthorityLine,
            "tokens memoryWrite • lock session • quarantine session"
        )
        XCTAssertEqual(
            summary.sovereignAuditLine,
            "Sovereign audit • BR-SOV-004 • ref audit.session-l14"
        )
        XCTAssertEqual(summary.inspectionHeadline, inspection.summary)
        XCTAssertEqual(summary.blockers, [])
        XCTAssertEqual(summary.layerStackLines, turn.replayCheckpointFacts.layerStackLines)
    }

    func testLineageBuildsSystemFlightDeckSummaryFromSharedFacts() {
        let lineage = makeLineageSnapshot(
            sessionID: "lineage-flightdeck",
            mode: .mirror,
            recordedAt: .now,
            riskLevel: "high",
            permitMode: "delay",
            updateTicketSummaries: ["Review checkpoint lineage."],
            diffSummary: ["Recovered persisted checkpoint without matching replay record"],
            activeKillSwitches: ["force_guard_mode"],
            recommendedKillSwitches: ["require_reviewed_writes"]
        )

        let summary = lineage.systemFlightDeckSummary

        XCTAssertEqual(summary.source, .persistedCheckpoint)
        XCTAssertEqual(summary.runMode, "checkpoint")
        XCTAssertEqual(summary.taskType, lineage.eBrain.taskType)
        XCTAssertEqual(summary.riskLevel, lineage.eBrain.riskLevel)
        XCTAssertEqual(summary.permitMode, lineage.eBrain.permitMode)
        XCTAssertEqual(summary.deviceRoute, "persisted")
        XCTAssertEqual(summary.hostGatePercent, lineage.eBrain.hostGatePercent)
        XCTAssertEqual(summary.pressureLine, nil)
        XCTAssertEqual(summary.activeKillSwitches, ["force_guard_mode"])
        XCTAssertEqual(summary.recommendedKillSwitches, ["require_reviewed_writes"])
        XCTAssertEqual(summary.killSwitches, ["force_guard_mode", "require_reviewed_writes"])
        XCTAssertEqual(summary.sovereignVerdictLine, nil)
        XCTAssertEqual(summary.sovereignAuthorityLine, nil)
        XCTAssertEqual(summary.sovereignAuditLine, nil)
        XCTAssertTrue(summary.inspectionHeadline.contains("Recovered from checkpoint"))
        XCTAssertTrue(summary.inspectionHeadline.contains(lineage.approvalState.rawValue))
        XCTAssertEqual(summary.blockers, lineage.diffSummary)
        XCTAssertEqual(summary.checkpointID, lineage.checkpointID)
        XCTAssertEqual(summary.checkpointApprovalState, lineage.approvalState.rawValue)
        XCTAssertEqual(summary.checkpointRollbackReady, lineage.rollbackReady)
        XCTAssertEqual(summary.checkpointApplyReady, lineage.hasBrainStateSnapshot)
        XCTAssertEqual(summary.layerStackLines, lineage.factsBundle.layerStackLines)
    }

    @MainActor
    func testRuntimeExportAttachedLiveEBrainSummaryCarriesPressureLine() async {
        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            replayLimit: 0,
            debugStore: DecisionIntelligenceDebugStore(),
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let attached = export.attaching(eBrainTurn: makeProtectiveTurn())

        XCTAssertEqual(attached.flightDeck.eBrainSummary?.source, .liveRuntime)
        XCTAssertEqual(
            attached.flightDeck.eBrainSummary?.pressureLine,
            expectedProtectivePressureLine()
        )
        XCTAssertEqual(
            attached.flightDeck.eBrainSummary?.presentation.pressureLine,
            expectedProtectivePressureLine()
        )
        XCTAssertEqual(
            attached.effectiveLayerStackLines,
            expectedProtectiveLayerStackLines()
        )
        XCTAssertTrue(
            attached.flightDeck.layerReports.first(where: { $0.layer == .data })?.signals.contains(where: {
                $0.contains("Pressure latency 3/1400ms") && $0.contains("thermal cool")
            }) == true
        )
    }

    @MainActor
    func testRuntimeExportAttachedLiveFlightDeckKeepsLayerStackOutOfDataSignalsAndDigestSummary() async throws {
        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            replayLimit: 0,
            debugStore: DecisionIntelligenceDebugStore(),
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let attached = export.attaching(eBrainTurn: makeProtectiveTurn())
        let dataReport = try XCTUnwrap(attached.flightDeck.layerReports.first(where: { $0.layer == .data }))
        let digest = try XCTUnwrap(attached.flightDeck.eBrainDigestPresentation)

        XCTAssertFalse(dataReport.signals.contains(where: { $0.contains("L6 context") }))
        XCTAssertFalse(dataReport.signals.contains(where: { $0.contains("L13 evolution") }))
        XCTAssertFalse(digest.summaryLines.contains(where: { $0.contains("L6 context") }))
        XCTAssertFalse(digest.summaryLines.contains(where: { $0.contains("L13 evolution") }))
        XCTAssertEqual(digest.layerStackLines, attached.effectiveLayerStackLines)
    }

    @MainActor
    func testRuntimeExportPersistedCheckpointFlightDeckKeepsLayerStackOutOfDataSignalsAndDigestSummary() async throws {
        let lineage = makeLineageSnapshot(
            sessionID: "persisted-flightdeck",
            mode: .quick,
            recordedAt: Date(timeIntervalSince1970: 1_776_508_800),
            riskLevel: "high",
            permitMode: "delay",
            updateTicketSummaries: ["Review checkpoint lineage."],
            diffSummary: ["Recovered persisted checkpoint without matching replay record"],
            activeKillSwitches: ["force_guard_mode"],
            recommendedKillSwitches: ["require_reviewed_writes"]
        )

        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            traceLimit: 0,
            replayLimit: 0,
            persistedCheckpointLineages: [lineage],
            debugStore: DecisionIntelligenceDebugStore(),
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let dataReport = try XCTUnwrap(export.flightDeck.layerReports.first(where: { $0.layer == .data }))
        let digest = try XCTUnwrap(export.flightDeck.eBrainDigestPresentation)

        XCTAssertEqual(export.effectiveEBrainSource, .persistedCheckpoint)
        XCTAssertEqual(export.flightDeck.eBrainSummary?.source, .persistedCheckpoint)
        XCTAssertFalse(dataReport.signals.contains(where: { $0.contains("L6 context") }))
        XCTAssertFalse(dataReport.signals.contains(where: { $0.contains("L13 evolution") }))
        XCTAssertFalse(digest.summaryLines.contains(where: { $0.contains("L6 context") }))
        XCTAssertFalse(digest.summaryLines.contains(where: { $0.contains("L13 evolution") }))
        XCTAssertEqual(digest.layerStackLines, lineage.factsBundle.layerStackLines)
        XCTAssertEqual(digest.layerStackLines, export.effectiveLayerStackLines)
    }

    @MainActor
    func testRuntimeExportAttachedLiveEBrainSummaryCarriesExecutionCapabilityLine() async {
        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: foundationManagedPreferences,
            runtimeSnapshot: makeFoundationManagedRuntimeSnapshot(),
            traceLimit: 0,
            replayLimit: 0,
            debugStore: DecisionIntelligenceDebugStore(),
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let attached = export.attaching(eBrainTurn: makeProtectiveTurn())
        let expectedHorizonLine =
            "Horizon worldPriorFabric • Stability invariant • Evidence grounded • Host hostIsolated • Session sessionIsolated • Tool toolRefreshRequired"
        let expectedTemporalLine =
            "Temporal invariant • Refresh embedded • Decay none • Scope crossSession"
        let expectedEvidenceLine =
            "Evidence grounded • Claim worldStructure • Caveat no • External refresh no"
        let expectedPersistenceLine =
            "Persistence volatile admitDirectly • contaminated quarantineCandidate • min durable evidence 0 • force stage no • pending tags evidence_caveat"

        XCTAssertTrue(
            attached.flightDeck.eBrainSummary?.presentation.detailLines.contains(
                "Capability systemManaged • Foundation systemManaged • Posture trustedProduction • Boundary externalTraining • Active Apple Foundation Model • Preferred Apple Foundation Model • Track builtInSystem • Fallback Gemma 4 E4B"
            ) == true
        )
        XCTAssertEqual(attached.effectiveEBrainFactsBundle?.horizonLine, expectedHorizonLine)
        XCTAssertEqual(attached.effectiveEBrainFactsBundle?.temporalLine, expectedTemporalLine)
        XCTAssertEqual(attached.effectiveEBrainFactsBundle?.evidenceLine, expectedEvidenceLine)
        XCTAssertEqual(attached.effectiveEBrainFactsBundle?.persistenceLine, expectedPersistenceLine)
        XCTAssertEqual(attached.effectiveEBrainFactsBundle?.worldPriorContract?.priorID, "worldPriorFabric")
        XCTAssertEqual(attached.effectiveEBrainFactsBundle?.worldPriorContract?.boundaryID, "externalTraining")
        XCTAssertEqual(attached.effectiveEBrainFactsBundle?.temporalKnowledgeContract?.refreshRequirement, .embedded)
        XCTAssertEqual(attached.effectiveEBrainFactsBundle?.temporalKnowledgeContract?.timeScope, .crossSession)
        XCTAssertEqual(attached.effectiveEBrainFactsBundle?.evidenceContract?.claimType, .worldStructure)
        XCTAssertEqual(attached.effectiveEBrainFactsBundle?.evidenceContract?.requiresExternalRefresh, false)
        XCTAssertEqual(attached.effectiveEBrainFactsBundle?.persistenceContract?.minimumDurableEvidenceCount, 0)
        XCTAssertEqual(attached.flightDeck.eBrainSummary?.presentation.horizonLine, expectedHorizonLine)
        XCTAssertEqual(attached.flightDeck.eBrainSummary?.presentation.temporalLine, expectedTemporalLine)
        XCTAssertEqual(attached.flightDeck.eBrainSummary?.presentation.evidenceLine, expectedEvidenceLine)
        XCTAssertEqual(attached.flightDeck.eBrainSummary?.presentation.persistenceLine, expectedPersistenceLine)
        XCTAssertEqual(attached.flightDeck.eBrainSummary?.presentation.worldPriorContract?.posture, .trustedProduction)
        XCTAssertEqual(attached.flightDeck.eBrainSummary?.presentation.worldPriorContract?.toolTruthModeID, "toolRefreshRequired")
        XCTAssertEqual(attached.flightDeck.eBrainSummary?.presentation.temporalKnowledgeContract?.tier, .invariant)
        XCTAssertEqual(attached.flightDeck.eBrainSummary?.presentation.evidenceContract?.gradient, .grounded)
        XCTAssertEqual(attached.flightDeck.eBrainSummary?.presentation.persistenceContract?.contaminatedWriteModeID, "quarantineCandidate")
        XCTAssertEqual(attached.liveEBrainPresentationFrame?.horizonLine, expectedHorizonLine)
        XCTAssertEqual(attached.liveEBrainPresentationFrame?.temporalLine, expectedTemporalLine)
        XCTAssertEqual(attached.liveEBrainPresentationFrame?.evidenceLine, expectedEvidenceLine)
        XCTAssertEqual(attached.liveEBrainPresentationFrame?.persistenceLine, expectedPersistenceLine)
        XCTAssertEqual(attached.liveEBrainPresentationFrame?.worldPriorContract?.hostIsolationID, "hostIsolated")
        XCTAssertEqual(
            attached.liveEBrainPresentationFrame?.temporalKnowledgeContract?.decayPolicy,
            DecisionEBrainTemporalDecayPolicy.none
        )
        XCTAssertEqual(attached.liveEBrainPresentationFrame?.evidenceContract?.requiresCaveat, false)
        XCTAssertEqual(attached.liveEBrainPresentationFrame?.persistenceContract?.evidencePendingTagIDs, ["evidence_caveat"])
        XCTAssertTrue(
            attached.flightDeck.eBrainSummary?.presentation.detailLines.contains(expectedHorizonLine) == true
        )
        XCTAssertTrue(
            attached.flightDeck.eBrainSummary?.presentation.detailLines.contains(expectedTemporalLine) == true
        )
        XCTAssertTrue(
            attached.flightDeck.eBrainSummary?.presentation.detailLines.contains(expectedEvidenceLine) == true
        )
        XCTAssertTrue(
            attached.flightDeck.eBrainSummary?.presentation.detailLines.contains(expectedPersistenceLine) == true
        )
    }

    @MainActor
    func testRuntimeExportAttachedLiveEBrainSummaryCarriesFoldedLungFacts() async {
        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: foundationManagedPreferences,
            runtimeSnapshot: makeFoundationManagedRuntimeSnapshot(),
            traceLimit: 0,
            replayLimit: 0,
            debugStore: DecisionIntelligenceDebugStore(),
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        let attached = export.attaching(eBrainTurn: makeProtectiveTurn())

        XCTAssertEqual(attached.liveEBrainKernelFrame?.runModeID, BASEBrainRunMode.guard.rawValue)
        XCTAssertEqual(attached.liveEBrainKernelFrame?.permitModeID, BASActionPermitMode.delay.rawValue)
        XCTAssertEqual(
            attached.liveEBrainKernelFrame?.lungState?.breathMode,
            .guard
        )
        XCTAssertEqual(
            attached.liveEBrainKernelFrame?.resumeFrame?.resumeDepth,
            1
        )
        XCTAssertEqual(
            attached.liveEBrainKernelFrame?.rollbackAnchor?.safeSnapshotRef,
            "snapshot.session-1.fold-1"
        )
        XCTAssertEqual(
            attached.liveEBrainKernelFrame?.layerStackLines,
            expectedProtectiveLayerStackLines()
        )
        XCTAssertEqual(
            attached.liveEBrainPresentationFrame?.layerStackLines,
            expectedProtectiveLayerStackLines()
        )
        XCTAssertEqual(
            attached.liveEBrainPresentationFrame?.lungLine,
            "Breath guard • Phase exchange • Restore 84%"
        )
        XCTAssertEqual(
            attached.liveEBrainPresentationFrame?.resumeLine,
            "Resume frame resume.session-1.fold-1 • source fold-1 • depth 1 • organs coreCortex, criticBlade, riskSpine, permitKnot, consistencyLattice, stubCore, tissueRouter"
        )
        XCTAssertEqual(
            attached.liveEBrainPresentationFrame?.rollbackLine,
            "Rollback anchor rollback.session-1.fold-1 • snapshot snapshot.session-1.fold-1 • cache cache.session-1.precision.session-1.fold-1"
        )
        XCTAssertEqual(
            attached.flightDeck.eBrainSummary?.presentation.layerStackLines,
            expectedProtectiveLayerStackLines()
        )
    }

    @MainActor
    func testRuntimeExportAttachedLiveEBrainPresentationFrameCarriesSovereignReceiptDetailLines() async {
        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: foundationManagedPreferences,
            runtimeSnapshot: makeFoundationManagedRuntimeSnapshot(),
            traceLimit: 0,
            replayLimit: 0,
            debugStore: DecisionIntelligenceDebugStore(),
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        )

        var turn = makeProtectiveTurn()
        turn.sovereignActuationCommands = [
            BASSovereignActuationCommand(
                commandID: "rollback-live-1",
                kind: .rollback,
                reasonCodes: ["runtime.rollback"],
                issuedAt: Date(timeIntervalSince1970: 1_776_508_801),
                forcedMode: .guard
            )
        ]

        let attached = export.attaching(eBrainTurn: turn)

        XCTAssertTrue(
            attached.liveEBrainPresentationFrame?.sovereignBridgeLine?.contains("rollback") == true
        )
        XCTAssertEqual(
            attached.liveEBrainPresentationFrame?.sovereignBridgeDetailLines,
            [
                "Sovereign invalidated resume resume.session-1.fold-1",
                "Sovereign invalidated cache cache.session-1.precision.session-1.fold-1",
                "Sovereign invalidated fold fold-1",
                "Sovereign readonly recovery",
                "Sovereign mode guard"
            ]
        )
    }

    func testReplayDiagnosticsOverviewKeepsPersistedExecutionCapabilityLine() {
        let summary = DeveloperDecisionReplayEBrainSummary(
            source: .persistedCheckpoint,
            recordedAt: Date(timeIntervalSince1970: 1_776_508_800),
            sessionID: "checkpoint-capability",
            taskType: "protective_review",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 61,
            thoughtFoldChecksum: "fold-capability",
            updateTicketSummaries: ["Review capability persistence."],
            reviewDirectiveLine: "Review capability persistence.",
            activeKillSwitches: ["force_guard_mode"],
            guardrailFindings: ["Capability path audit"],
            killSwitches: ["force_guard_mode", "require_reviewed_writes"],
            layerStackLines: [
                "L6 context • task protective review • session checkpoint-capability"
            ],
            checkpointBudgetLine: nil,
            checkpointPressureLine: nil,
            checkpointTaskLine: "Review capability persistence.",
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
                    "preferred:\(DecisionModelProviderPreference.foundationModels.rawValue)"
                ]
            )
        )
        let entry = DeveloperDecisionReplayEntry(
            record: .checkpoint(
                DecisionEvolutionLineageSnapshot(
                    checkpointID: "checkpoint-capability",
                    createdAt: summary.recordedAt,
                    mode: .quick,
                    approvalState: .automatic,
                    rollbackReady: true,
                    diffSummary: ["Recovered capability-bearing checkpoint."],
                    eBrain: summary
                )
            ),
            trace: nil,
            eBrain: summary,
            matchedPersistedCheckpointID: "checkpoint-capability"
        )

        let presentation = entry.diagnosticsPresentation

        XCTAssertTrue(
            presentation.overviewPresentation.detailLines.contains(
                "Capability systemManaged • Foundation systemManaged • Posture trustedProduction • Boundary externalTraining • Active Apple Foundation Model • Preferred Apple Foundation Model • Track builtInSystem • Fallback Gemma 4 E4B"
            )
        )
        XCTAssertTrue(
            presentation.overviewPresentation.detailLines.contains(
                "Horizon worldPriorFabric • Stability invariant • Evidence grounded • Host hostIsolated • Session sessionIsolated • Tool toolRefreshRequired"
            )
        )
    }

    func testReplayDiagnosticsOverviewKeepsPersistedFoldedLungLines() {
        let summary = DeveloperDecisionReplayEBrainSummary(
            source: .persistedCheckpoint,
            recordedAt: Date(timeIntervalSince1970: 1_776_508_800),
            sessionID: "checkpoint-capability",
            taskType: "protective_review",
            riskLevel: "high",
            permitMode: "delay",
            hostGatePercent: 61,
            thoughtFoldChecksum: "fold-capability",
            updateTicketSummaries: ["Review capability persistence."],
            reviewDirectiveLine: "Review capability persistence.",
            activeKillSwitches: ["force_guard_mode"],
            guardrailFindings: ["Capability path audit"],
            killSwitches: ["force_guard_mode", "require_reviewed_writes"],
            layerStackLines: [
                "L3 compression runtime • breath guard • phase resume • anchor anchor-safe"
            ],
            checkpointBudgetLine: nil,
            checkpointPressureLine: nil,
            checkpointTaskLine: "Review capability persistence.",
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
                    "preferred:\(DecisionModelProviderPreference.foundationModels.rawValue)"
                ]
            ),
            lungState: BASLungState(
                breathMode: .guard,
                breathPhase: .resume,
                thermalPressure: 23,
                cachePressure: 12,
                restoreReadiness: 0.91,
                rollbackAnchorRef: "anchor-safe"
            ),
            resumeFrame: BASResumeFrame(
                resumeID: "resume-safe",
                sourceFoldID: "fold-capability",
                resumeDepth: 2,
                requiredOrgans: [.riskSpine, .permitKnot, .stubCore],
                consistencyChecks: ["hash"],
                fallbackMode: .rollbackAnchor
            ),
            rollbackAnchor: BASRollbackAnchor(
                anchorID: "anchor-safe",
                safeSnapshotRef: "snapshot-safe",
                foldRefs: ["fold-capability"],
                hostVersionRef: "host-v1",
                cacheStateRef: "cache-safe",
                integrityHash: "hash-safe"
            ),
            sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult(
                actuationKinds: [.rollback],
                invalidatedResumeFrameIDs: ["resume-safe"],
                invalidatedCacheRefs: ["cache-safe"],
                invalidatedFoldRefs: ["fold-capability"],
                quarantinedFoldRefs: [],
                resultingBreathMode: .guard,
                preservedReadOnlyRecovery: true,
                summary: "rollback -> snapshot-safe • guard breath"
            )
        )
        let entry = DeveloperDecisionReplayEntry(
            record: .checkpoint(
                DecisionEvolutionLineageSnapshot(
                    checkpointID: "checkpoint-capability",
                    createdAt: summary.recordedAt,
                    mode: .quick,
                    approvalState: .automatic,
                    rollbackReady: true,
                    diffSummary: ["Recovered capability-bearing checkpoint."],
                    eBrain: summary
                )
            ),
            trace: nil,
            eBrain: summary,
            matchedPersistedCheckpointID: "checkpoint-capability"
        )

        let presentation = entry.diagnosticsPresentation
        let expectedLungLine = "Breath guard • Phase resume • Restore 91%"
        let expectedResumeLine =
            "Resume frame resume-safe • source fold-capability • depth 2 • organs riskSpine, permitKnot, stubCore"
        let expectedRollbackLine =
            "Rollback anchor anchor-safe • snapshot snapshot-safe • cache cache-safe"
        let expectedSovereignLine = "rollback -> snapshot-safe • guard breath"

        XCTAssertEqual(presentation.layerStackLines, summary.layerStackLines)
        XCTAssertTrue(
            presentation.overviewPresentation.detailLines.contains(where: {
                $0.contains("Capability systemManaged")
            })
        )
        XCTAssertTrue(presentation.overviewPresentation.detailLines.contains(expectedLungLine))
        XCTAssertTrue(presentation.overviewPresentation.detailLines.contains(expectedResumeLine))
        XCTAssertTrue(presentation.overviewPresentation.detailLines.contains(expectedRollbackLine))
        XCTAssertTrue(presentation.overviewPresentation.detailLines.contains(expectedSovereignLine))
        XCTAssertTrue(
            presentation.overviewPresentation.detailLines.contains(
                "Sovereign invalidated resume resume-safe"
            )
        )
        XCTAssertTrue(
            presentation.overviewPresentation.detailLines.contains(
                "Sovereign invalidated cache cache-safe"
            )
        )
        XCTAssertTrue(
            presentation.overviewPresentation.detailLines.contains(
                "Sovereign invalidated fold fold-capability"
            )
        )
        XCTAssertTrue(
            presentation.overviewPresentation.detailLines.contains(
                "Sovereign readonly recovery"
            )
        )
        XCTAssertTrue(
            presentation.overviewPresentation.detailLines.contains(
                "Sovereign mode guard"
            )
        )
        XCTAssertTrue(presentation.compactDiagnosticsLines.contains { $0.text == expectedLungLine })
        XCTAssertTrue(presentation.compactDiagnosticsLines.contains { $0.text == expectedResumeLine })
        XCTAssertTrue(presentation.compactDiagnosticsLines.contains { $0.text == expectedRollbackLine })
        XCTAssertTrue(presentation.compactDiagnosticsLines.contains { $0.text == expectedSovereignLine })
    }

    func testFactsBundleNormalizesSessionCheckpointPressureFactLine() {
        let factsBundle = DeveloperDecisionReplayEBrainSummary(turn: makeProtectiveTurn()).factsBundle()

        XCTAssertEqual(
            factsBundle.sessionCheckpointPressureFactLine(),
            "eBrain pressure: \(expectedProtectivePressureLine().replacingOccurrences(of: "Pressure ", with: ""))"
        )
    }

    func testBaseBrainTurnSessionCheckpointFactsReuseSharedPressureLine() {
        let turn = makeProtectiveTurn()
        let checkpointFacts = turn.sessionCheckpointFacts

        XCTAssertTrue(checkpointFacts.budgetConstraintLine.hasPrefix("eBrain budget:"))
        XCTAssertTrue(checkpointFacts.budgetConstraintLine.contains("loops 2"))
        XCTAssertTrue(checkpointFacts.budgetConstraintLine.contains("decode 160"))
        XCTAssertTrue(checkpointFacts.routeConstraintLine.hasPrefix("eBrain route:"))
        XCTAssertEqual(
            checkpointFacts.decisionFactLines,
            DecisionEvolutionEBrainPresentationSupport.checkpointDecisionFactLines(
                riskLevel: turn.riskCard.riskLevel.rawValue,
                permitMode: turn.actionPermit.mode.rawValue,
                hostGatePercent: Int((turn.hostGateValue * 100).rounded()),
                foldChecksum: String(turn.thoughtFold.checksum.prefix(12))
            )
        )
        XCTAssertEqual(
            checkpointFacts.pressureFactLine,
            "eBrain pressure: latency 3/1400ms • power 12% • cache 0% • thermal cool • vital 86%"
        )
        XCTAssertEqual(checkpointFacts.auditFactLine, "eBrain audit findings: 1")
        XCTAssertEqual(
            checkpointFacts.activeKillSwitchesFactLine,
            "eBrain active kill switches: force_guard_mode"
        )
        XCTAssertEqual(
            checkpointFacts.recommendedKillSwitchesFactLine,
            "eBrain recommended kill switches: require_reviewed_writes"
        )
        XCTAssertTrue(checkpointFacts.openTaskLines.contains("Review memory write: Keep the boundary signal in warm memory."))
        XCTAssertTrue(checkpointFacts.openTaskLines.contains("Review protective path: delay"))
        XCTAssertTrue(checkpointFacts.currentScope.contains("ebrain"))
        XCTAssertTrue(checkpointFacts.currentScope.contains(turn.contextFrame.taskType.rawValue))
    }

    func testCheckpointDecisionLineUsesSharedOrderedPrefixes() {
        let confirmedFacts = [
            "eBrain fold: fold-checksum",
            "other fact: ignore",
            "eBrain risk: high",
            "eBrain audit findings: 2",
            "eBrain host gate: 37%",
            "eBrain permit: delay"
        ]

        XCTAssertEqual(
            DecisionEvolutionEBrainPresentationSupport.checkpointDecisionLine(from: confirmedFacts),
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "eBrain risk: high",
                "eBrain permit: delay",
                "eBrain host gate: 37%",
                "eBrain fold: fold-checksum",
                "eBrain audit findings: 2"
            ])
        )
    }

    func testSessionCheckpointFactsApplyIntoDraftThroughSharedHelper() {
        let checkpointFacts = makeProtectiveTurn().sessionCheckpointFacts
        let applied = checkpointFacts.applied(
            to: DecisionSessionCheckpointDraft(
                summary: DecisionSessionCheckpointSummary(
                    goal: "repair parser",
                    acceptedConstraints: ["keep history"],
                    confirmedFacts: ["parser isolated"],
                    openTasks: ["write tests"],
                    currentScope: ["src/parser.ts"]
                ),
                runtimeState: DecisionSessionCheckpointRuntimeState(
                    workspacePath: "/tmp/project",
                    branchName: "feature/parser",
                    activeFiles: ["src/parser.ts"],
                    currentMode: .chat
                )
            )
        )

        XCTAssertTrue(applied.summary.acceptedConstraints.contains("keep history"))
        XCTAssertTrue(applied.summary.acceptedConstraints.contains(where: { $0.hasPrefix("eBrain budget:") }))
        XCTAssertTrue(applied.summary.acceptedConstraints.contains(where: { $0.hasPrefix("eBrain route:") }))
        XCTAssertTrue(applied.summary.confirmedFacts.contains("parser isolated"))
        XCTAssertTrue(applied.summary.confirmedFacts.contains("eBrain risk: high"))
        XCTAssertTrue(applied.summary.confirmedFacts.contains("eBrain permit: delay"))
        XCTAssertTrue(applied.summary.confirmedFacts.contains(where: { $0.hasPrefix("eBrain pressure:") }))
        XCTAssertTrue(applied.summary.confirmedFacts.contains("eBrain audit findings: 1"))
        XCTAssertTrue(applied.summary.confirmedFacts.contains("eBrain active kill switches: force_guard_mode"))
        XCTAssertTrue(applied.summary.confirmedFacts.contains("eBrain recommended kill switches: require_reviewed_writes"))
        XCTAssertTrue(applied.summary.openTasks.contains("write tests"))
        XCTAssertTrue(applied.summary.openTasks.contains("Review memory write: Keep the boundary signal in warm memory."))
        XCTAssertTrue(applied.summary.openTasks.contains("Review protective path: delay"))
        XCTAssertTrue(applied.summary.currentScope.contains("src/parser.ts"))
        XCTAssertTrue(applied.summary.currentScope.contains("ebrain"))
        XCTAssertEqual(applied.runtimeState.currentMode, .review)
    }

    func testBaseBrainTurnReplayCheckpointFactsReuseSharedPressureLine() {
        let turn = makeProtectiveTurn()
        let replayCheckpointFacts = turn.replayCheckpointFacts

        XCTAssertEqual(
            replayCheckpointFacts.budgetLine,
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "Budget GUARD",
                "route guarded",
                "loops 2",
                "candidates 2",
                "decode 160"
            ])
        )
        XCTAssertEqual(
            replayCheckpointFacts.pressureLine,
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "Pressure latency 3/1400ms",
                "power 12%",
                "cache 0%",
                "thermal cool",
                "vital 86%"
            ])
        )
        XCTAssertEqual(
            replayCheckpointFacts.taskLine,
            expectedProtectiveTaskLine()
        )
    }

    func testFactsBundleBuildsOrderedDataLayerSignals() {
        let turn = makeProtectiveTurn()
        let factsBundle = DeveloperDecisionReplayEBrainSummary(turn: turn).factsBundle()
        let killSwitches = turn.runtimeTrace.activeKillSwitches.map(\.rawValue)
            + turn.runtimeTrace.recommendedKillSwitches.map(\.rawValue)

        XCTAssertEqual(
            factsBundle.layerStackLines,
            expectedProtectiveLayerStackLines()
        )
        XCTAssertEqual(
            factsBundle.dataLayerSignals,
            [
                factsBundle.summaryLine,
                turn.replayCheckpointFacts.budgetLine,
                turn.replayCheckpointFacts.pressureLine,
                turn.replayCheckpointFacts.taskLine,
                factsBundle.riskFactorsLine,
                factsBundle.reasonCodesLine,
                turn.runtimeTrace.guardrailFindings.first.map { "Audit: \($0.summary)" },
                DecisionEvolutionKillSwitchPresentationSupport.activeLine(
                    killSwitches: turn.runtimeTrace.activeKillSwitches.map(\.rawValue)
                ),
                DecisionSessionReviewPresentationSupport.killSwitchesLine(
                    killSwitches: killSwitches
                ),
                factsBundle.lungLine,
                factsBundle.morphLine,
                factsBundle.hotColdLine,
                factsBundle.precisionLine,
                factsBundle.resumeLine,
                factsBundle.schedulerLine,
                factsBundle.rollbackLine
            ]
            .compactMap { $0 }
        )
    }

    func testFactsBundleApplyingExecutionCapabilityFrameAddsHorizonDataLayerSignal() {
        let turn = makeProtectiveTurn()
        let executionCapabilityFrame = makeFoundationManagedRuntimeSnapshot().executionCapabilityFrame
        let factsBundle = DeveloperDecisionReplayEBrainSummary(turn: turn)
            .factsBundle()
            .applying(executionCapabilityFrame: executionCapabilityFrame)
        let killSwitches = turn.runtimeTrace.activeKillSwitches.map(\.rawValue)
            + turn.runtimeTrace.recommendedKillSwitches.map(\.rawValue)

        XCTAssertEqual(
            factsBundle.horizonLine,
            "Horizon worldPriorFabric • Stability invariant • Evidence grounded • Host hostIsolated • Session sessionIsolated • Tool toolRefreshRequired"
        )
        XCTAssertEqual(
            factsBundle.temporalLine,
            "Temporal invariant • Refresh embedded • Decay none • Scope crossSession"
        )
        XCTAssertEqual(
            factsBundle.evidenceLine,
            "Evidence grounded • Claim worldStructure • Caveat no • External refresh no"
        )
        XCTAssertEqual(
            factsBundle.persistenceLine,
            executionCapabilityFrame.persistenceLine
        )
        XCTAssertEqual(factsBundle.worldPriorContract, executionCapabilityFrame.worldPriorContract)
        XCTAssertEqual(factsBundle.temporalKnowledgeContract, executionCapabilityFrame.temporalKnowledgeContract)
        XCTAssertEqual(factsBundle.evidenceContract, executionCapabilityFrame.evidenceContract)
        XCTAssertEqual(
            factsBundle.dataLayerSignals,
            [
                factsBundle.summaryLine,
                turn.replayCheckpointFacts.budgetLine,
                turn.replayCheckpointFacts.pressureLine,
                turn.replayCheckpointFacts.taskLine,
                factsBundle.riskFactorsLine,
                factsBundle.reasonCodesLine,
                factsBundle.executionCapabilityLine,
                factsBundle.horizonLine,
                factsBundle.temporalLine,
                factsBundle.evidenceLine,
                executionCapabilityFrame.persistenceLine,
                turn.runtimeTrace.guardrailFindings.first.map { "Audit: \($0.summary)" },
                DecisionEvolutionKillSwitchPresentationSupport.activeLine(
                    killSwitches: turn.runtimeTrace.activeKillSwitches.map(\.rawValue)
                ),
                DecisionSessionReviewPresentationSupport.killSwitchesLine(
                    killSwitches: killSwitches
                ),
                factsBundle.lungLine,
                factsBundle.morphLine,
                factsBundle.hotColdLine,
                factsBundle.precisionLine,
                factsBundle.resumeLine,
                factsBundle.schedulerLine,
                factsBundle.rollbackLine
            ]
            .compactMap { $0 }
        )
    }

    @MainActor
    func testFactsBundleAndReplayDiagnosticsCarryEvidenceCaveatRuntimeSignals() async {
        var turn = makeProtectiveTurn()
        turn.riskCard.factors.append("evidence_caveat_load")
        turn.renderedOutput.explanationCodes.append("evidence.caveat")

        let summary = DeveloperDecisionReplayEBrainSummary(turn: turn)
        let factsBundle = summary.factsBundle()
        let export = await DecisionTestingInterface.runtimeExport(
            quick: [],
            balance: [],
            mirror: [],
            preferences: .default,
            replayLimit: 0,
            debugStore: DecisionIntelligenceDebugStore(),
            eBrainStore: EBrainTurnDebugStore(),
            telemetryStore: DecisionIntelligenceTelemetryStore(),
            cache: DecisionIntelligenceResponseCache(limit: 2),
            circuitBreaker: DecisionIntelligenceCircuitBreaker()
        ).attaching(eBrainTurn: turn)
        let entry = DeveloperDecisionReplayEntry(
            record: .quick(makeQuickEvent(createdAt: .now, title: "Caveated quick")),
            trace: nil,
            eBrain: summary
        )
        let presentation = entry.diagnosticsPresentation

        XCTAssertEqual(
            factsBundle.riskFactorsLine,
            "Factors: pressure • uncertainty • evidence_caveat_load"
        )
        XCTAssertEqual(
            factsBundle.reasonCodesLine,
            "Reason codes: risk.high • gsi.elevated • evidence.caveat"
        )
        XCTAssertTrue(
            factsBundle.dataLayerSignals.contains("Factors: pressure • uncertainty • evidence_caveat_load")
        )
        XCTAssertTrue(
            factsBundle.dataLayerSignals.contains("Reason codes: risk.high • gsi.elevated • evidence.caveat")
        )
        XCTAssertEqual(
            export.effectiveEBrainFactsBundle?.riskFactorsLine,
            "Factors: pressure • uncertainty • evidence_caveat_load"
        )
        XCTAssertEqual(
            export.effectiveEBrainFactsBundle?.reasonCodesLine,
            "Reason codes: risk.high • gsi.elevated • evidence.caveat"
        )
        XCTAssertTrue(
            export.flightDeck.eBrainSummary?.presentation.detailLines.contains(
                "Factors: pressure • uncertainty • evidence_caveat_load"
            ) == true
        )
        XCTAssertTrue(
            export.flightDeck.eBrainSummary?.presentation.detailLines.contains(
                "Reason codes: risk.high • gsi.elevated • evidence.caveat"
            ) == true
        )
        XCTAssertTrue(
            presentation.overviewPresentation.detailLines.contains(
                "Factors: pressure • uncertainty • evidence_caveat_load"
            )
        )
        XCTAssertTrue(
            presentation.overviewPresentation.detailLines.contains(
                "Reason codes: risk.high • gsi.elevated • evidence.caveat"
            )
        )
        XCTAssertTrue(
            presentation.diagnosticsLines.contains {
                $0.kind == .riskFactors
                    && $0.text == "Factors: pressure • uncertainty • evidence_caveat_load"
            }
        )
        XCTAssertTrue(
            presentation.diagnosticsLines.contains {
                $0.kind == .reasonCodes
                    && $0.text == "Reason codes: risk.high • gsi.elevated • evidence.caveat"
            }
        )
    }

    func testReplayEBrainSummarySourceDescriptorReflectsLineageSource() {
        let liveSummary = DeveloperDecisionReplayEBrainSummary(turn: makeProtectiveTurn())
        XCTAssertEqual(liveSummary.sourceDescriptor.kind, .liveRuntime)
        XCTAssertEqual(liveSummary.sourceDescriptor.title, "Live runtime")

        let checkpointSummary = DeveloperDecisionReplayEBrainSummary(
            lineageSummary: makeLineageSummary(
                sessionID: "lineage-1",
                riskLevel: "high",
                permitMode: "delay",
                activeKillSwitches: ["force_guard_mode"],
                recommendedKillSwitches: ["require_reviewed_writes"]
            )
        )
        XCTAssertEqual(checkpointSummary.sourceDescriptor.kind, .checkpointRecovery)
        XCTAssertEqual(checkpointSummary.sourceDescriptor.title, "Checkpoint recovery")
    }

    func testReplayRecoverySummaryDerivesSharedLinesFromReplayEBrainSummary() {
        let liveSummary = DeveloperDecisionReplayEBrainSummary(turn: makeProtectiveTurn())
        let livePresentation = liveSummary.replayRecoverySummary
        XCTAssertEqual(livePresentation.sourceDescriptor.kind, .liveRuntime)
        XCTAssertEqual(livePresentation.title, "Live runtime")
        XCTAssertTrue(livePresentation.replayLine.contains("Replay session session-1"))
        XCTAssertEqual(
            livePresentation.recoveryLine,
            DecisionEvolutionEBrainPresentationSupport.riskPermitHostFoldLine(
                riskLevel: "high",
                permitMode: "delay",
                hostGatePercent: 37,
                foldChecksum: "checksum-1"
            )
        )
        XCTAssertEqual(
            livePresentation.budgetLine,
            expectedProtectiveBudgetLine()
        )
        XCTAssertEqual(
            livePresentation.pressureLine,
            expectedProtectivePressureLine()
        )
        XCTAssertEqual(
            livePresentation.taskLine,
            expectedProtectiveTaskLine()
        )
        XCTAssertNil(livePresentation.actionLine)
        XCTAssertEqual(
            livePresentation.detailLine,
            "Review memory write: Keep the boundary signal in warm memory."
        )
        XCTAssertEqual(
            livePresentation.auditLine,
            DecisionSessionReviewPresentationSupport.auditLine(
                guardrailFindings: ["Protective short-circuit requested."]
            )
        )
        XCTAssertEqual(livePresentation.activeKillSwitchesLine, "Active kill switches: force_guard_mode")
        XCTAssertEqual(
            livePresentation.killSwitchesLine,
            DecisionSessionReviewPresentationSupport.killSwitchesLine(
                killSwitches: ["force_guard_mode", "require_reviewed_writes"]
            )
        )

        let checkpointSummary = DeveloperDecisionReplayEBrainSummary(
            lineageSummary: makeLineageSummary(
                sessionID: "lineage-2",
                riskLevel: "medium",
                permitMode: "compare",
                activeKillSwitches: ["force_guard_mode"],
                recommendedKillSwitches: ["require_reviewed_writes"]
            )
        )
        let checkpointPresentation = checkpointSummary.replayRecoverySummary
        XCTAssertEqual(checkpointPresentation.sourceDescriptor.kind, .checkpointRecovery)
        XCTAssertEqual(checkpointPresentation.title, "Checkpoint recovery")
        XCTAssertTrue(checkpointPresentation.replayLine.contains("Replay session lineage-2"))
        XCTAssertEqual(
            checkpointPresentation.recoveryLine,
            DecisionEvolutionEBrainPresentationSupport.riskPermitHostFoldLine(
                riskLevel: "medium",
                permitMode: "compare",
                hostGatePercent: 82,
                foldChecksum: "fold-checksum"
            )
        )
        XCTAssertNil(checkpointPresentation.budgetLine)
        XCTAssertNil(checkpointPresentation.pressureLine)
        XCTAssertEqual(
            checkpointPresentation.taskLine,
            "Review: Hold before sending"
        )
        XCTAssertNil(checkpointPresentation.actionLine)
        XCTAssertEqual(checkpointPresentation.detailLine, "Hold before sending")
        XCTAssertEqual(
            checkpointPresentation.auditLine,
            DecisionSessionReviewPresentationSupport.auditLine(
                guardrailFindings: ["Guardrail matched"]
            )
        )
        XCTAssertEqual(
            checkpointPresentation.activeKillSwitchesLine,
            "Active kill switches: force_guard_mode"
        )
        XCTAssertEqual(
            checkpointPresentation.killSwitchesLine,
            DecisionSessionReviewPresentationSupport.killSwitchesLine(
                killSwitches: ["force_guard_mode", "require_reviewed_writes"]
            )
        )
    }

    func testReplayRecoverySummaryFallsBackWhenReviewDirectiveLineIsBlank() {
        let checkpointSummary = DeveloperDecisionReplayEBrainSummary(
            lineageSummary: makeLineageSummary(
                sessionID: "lineage-blank-directive",
                riskLevel: "medium",
                permitMode: "compare",
                activeKillSwitches: [],
                recommendedKillSwitches: ["require_reviewed_writes"],
                reviewDirectiveLine: "   "
            )
        )

        let checkpointPresentation = checkpointSummary.replayRecoverySummary

        XCTAssertEqual(checkpointSummary.reviewDirectiveLine, nil)
        XCTAssertEqual(checkpointSummary.checkpointTaskLine, "Review: Hold before sending")
        XCTAssertEqual(checkpointPresentation.taskLine, "Review: Hold before sending")
        XCTAssertEqual(checkpointPresentation.detailLine, "Hold before sending")
    }

    func testReplayEBrainFactsBundleDerivesSharedBrainSummaryLine() {
        let liveFactsBundle = DeveloperDecisionReplayEBrainSummary(turn: makeProtectiveTurn())
            .factsBundle(modeTitle: "Mirror")
        XCTAssertEqual(
            liveFactsBundle.pressureLine,
            expectedProtectivePressureLine()
        )

        let checkpointSummary = DeveloperDecisionReplayEBrainSummary(
            lineageSummary: makeLineageSummary(
                sessionID: "lineage-2",
                riskLevel: "medium",
                permitMode: "compare",
                activeKillSwitches: ["force_guard_mode"],
                recommendedKillSwitches: ["require_reviewed_writes"]
            )
        )

        let factsBundle = checkpointSummary.factsBundle(modeTitle: "Quick")

        XCTAssertEqual(factsBundle.sourceDescriptor.kind, .checkpointRecovery)
        XCTAssertEqual(
            factsBundle.runtimeSummaryLine,
            DecisionEvolutionEBrainPresentationSupport.runtimeSummaryLine(
                sourceDescriptor: checkpointSummary.sourceDescriptor,
                modeTitle: "Quick",
                permitMode: "compare",
                riskLevel: "medium",
                foldChecksum: "fold-checksum"
            )
        )
        XCTAssertEqual(
            factsBundle.brainSummaryLine,
            DecisionEvolutionEBrainPresentationSupport.brainSummaryLine(
                sourceTitle: checkpointSummary.sourceDescriptor.title,
                sessionID: "lineage-2",
                hostGatePercent: 82,
                ticketCount: 1
            )
        )
        XCTAssertNil(factsBundle.pressureLine)
    }

    func testBaseBrainTurnDiagnosticsPresentationDerivesSharedFields() {
        let turn = makeProtectiveTurn()
        let support = turn.turnDiagnosticsSupport

        let presentation = turn.diagnosticsPresentation

        XCTAssertEqual(presentation.sourceDescriptor.kind, .liveRuntime)
        XCTAssertEqual(presentation.runModeTitle, turn.budgetFrame.runMode.rawValue.uppercased())
        XCTAssertEqual(
            presentation.taskTitle,
            DecisionEvolutionEBrainPresentationSupport.taskTitle(turn.contextFrame.taskType.rawValue)
        )
        XCTAssertEqual(presentation.riskTitle, turn.riskCard.riskLevel.rawValue.uppercased())
        XCTAssertEqual(presentation.permitTitle, turn.actionPermit.mode.rawValue.uppercased())
        XCTAssertEqual(presentation.mirrorText, turn.decomposeFrame.mirrorText)
        XCTAssertEqual(presentation.routeText, support.routeText)
        XCTAssertEqual(presentation.hostText, support.hostText)
        XCTAssertEqual(presentation.replayText, support.replayText)
        XCTAssertTrue(presentation.routeText.contains("Route: guarded"))
        XCTAssertTrue(presentation.hostText.contains("Host gate 37%"))
        XCTAssertTrue(presentation.hostText.contains("Fold active"))
        XCTAssertFalse(presentation.hostText.contains("checksum-1"))
        XCTAssertTrue(presentation.replayText.contains("Replay state restored"))
        XCTAssertFalse(presentation.replayText.contains(turn.runtimeTrace.sessionID))
        XCTAssertEqual(presentation.candidateTitles, ["Pause and protect"])
        XCTAssertEqual(presentation.memorySummaries, ["Protect the boundary first."])
        XCTAssertEqual(presentation.alternativeActions, ["Wait 24 hours", "Draft but do not send"])
        XCTAssertEqual(presentation.ticketSummary, support.ticketSummary)
        XCTAssertEqual(presentation.activeKillSwitchesLine, support.activeKillSwitchesLine)
        XCTAssertEqual(presentation.recommendedKillSwitchesLine, support.recommendedKillSwitchesLine)
        XCTAssertEqual(
            presentation.layerStackLines,
            expectedProtectiveLayerStackLines()
        )
        XCTAssertEqual(presentation.riskFactorsLine, support.riskFactorsLine)
        XCTAssertEqual(presentation.reasonCodesLine, support.reasonCodesLine)
        XCTAssertEqual(presentation.thoughtFoldLines, ["• body: Mirror body", "• headline: Pause first"])
        XCTAssertEqual(presentation.replayTraceLines, ["• L11 gate: Protective short-circuited refinement."])
        XCTAssertEqual(presentation.auditLines, support.auditLines)
        XCTAssertEqual(
            presentation.triScoreLines,
            ["• cand-1: id 42 / ego 81 / superego 91"]
        )
    }

    func testBaseBrainTurnDiagnosticsPresentationPrioritizesCrossLayerReplayTraceLines() {
        var turn = makeProtectiveTurn()
        turn.runtimeTrace = BASRuntimeTrace(
            sessionID: turn.runtimeTrace.sessionID,
            layerEvents: [
                BASRuntimeTraceEvent(layerID: "L1", event: "budget", detail: "L1 detail"),
                BASRuntimeTraceEvent(layerID: "L2", event: "neural_core", detail: "L2 detail"),
                BASRuntimeTraceEvent(layerID: "L3", event: "compression_runtime", detail: "L3 detail"),
                BASRuntimeTraceEvent(layerID: "L4", event: "foundation", detail: "L4 detail"),
                BASRuntimeTraceEvent(layerID: "L10", event: "triself", detail: "L10 detail"),
                BASRuntimeTraceEvent(layerID: "L11", event: "risk_gate", detail: "L11 detail"),
                BASRuntimeTraceEvent(layerID: "L13", event: "evolution", detail: "L13 detail")
            ],
            latencyBreakdownMs: turn.runtimeTrace.latencyBreakdownMs,
            powerEstimate: turn.runtimeTrace.powerEstimate,
            thermalTrace: turn.runtimeTrace.thermalTrace,
            modelRoute: turn.runtimeTrace.modelRoute,
            loopCount: turn.runtimeTrace.loopCount,
            cacheHitRate: turn.runtimeTrace.cacheHitRate,
            activeKillSwitches: turn.runtimeTrace.activeKillSwitches,
            guardrailFindings: turn.runtimeTrace.guardrailFindings,
            recommendedKillSwitches: turn.runtimeTrace.recommendedKillSwitches
        )

        let presentation = turn.diagnosticsPresentation

        XCTAssertEqual(
            presentation.replayTraceLines,
            [
                "• L2 neural_core: L2 detail",
                "• L3 compression_runtime: L3 detail",
                "• L10 triself: L10 detail",
                "• L11 risk_gate: L11 detail",
                "• L13 evolution: L13 detail"
            ]
        )
    }

    func testBaseBrainTurnDiagnosticsPresentationSurfacesTriSelfVetoExplanation() {
        var turn = makeProtectiveTurn()
        turn.triScores = [
            BASTriSelfScore(
                candidateID: "path.direct",
                idScore: 0.58,
                egoScore: 0.39,
                superegoScore: 0.11,
                mergedScore: 0.34,
                veto: true
            )
        ]
        turn.mergedChoice = BASMergedChoice(
            candidateID: "path.bounded",
            title: "Pause first",
            actionSummary: "Use the safer next step.",
            vetoApplied: true,
            vetoReasonCodes: [
                "triself.superego_veto",
                "triself.high_risk_direct_path",
                "triself.protective_boundary"
            ]
        )
        turn.renderedOutput = BASRenderedOutput(
            mode: .delay,
            headline: "Pause first",
            body: "Mirror body",
            alternativeActions: ["Wait 24 hours", "Draft but do not send"],
            explanationCodes: [
                "risk.high",
                "gsi.elevated",
                "triself.superego_veto",
                "triself.high_risk_direct_path",
                "triself.protective_boundary"
            ]
        )

        let presentation = turn.diagnosticsPresentation

        XCTAssertEqual(
            presentation.triScoreLines,
            ["• path.direct: id 58 / ego 39 / superego 11 • vetoed (high-risk direct path, protective boundary)"]
        )
        XCTAssertEqual(
            presentation.reasonCodesLine,
            "Reason codes: risk.high • gsi.elevated • triself.superego_veto • triself.high_risk_direct_path • triself.protective_boundary"
        )
    }

    func testBaseBrainTurnDiagnosticsSupportBuildsSharedLines() {
        let turn = makeProtectiveTurn()

        let support = turn.turnDiagnosticsSupport

        XCTAssertEqual(
            support.routeText,
            "Route: guarded • Loops: 1 • Power: 12%"
        )
        XCTAssertEqual(
            support.hostText,
            "Host gate 37% • Fold active • Device warm/2048MB • wake guard • value 72% • risk 91%"
        )
        XCTAssertTrue(support.replayText.contains("Replay state restored"))
        XCTAssertTrue(support.replayText.contains("Recorded"))
        XCTAssertFalse(support.replayText.contains(turn.runtimeTrace.sessionID))
        XCTAssertEqual(
            support.auditLines,
            ["• L11 protected_permit: Protective short-circuit requested."]
        )
        XCTAssertEqual(
            support.activeKillSwitchesLine,
            "Active kill switches: force_guard_mode"
        )
        XCTAssertEqual(
            support.recommendedKillSwitchesLine,
            "Recommended kill switches: require_reviewed_writes"
        )
        XCTAssertEqual(
            support.riskFactorsLine,
            DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: "Factors",
                values: ["pressure", "uncertainty"]
            )
        )
        XCTAssertEqual(
            support.reasonCodesLine,
            DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: "Reason codes",
                values: ["risk.high", "gsi.elevated"]
            )
        )
        XCTAssertEqual(
            support.ticketSummary,
            "Review memory write: Keep the boundary signal in warm memory."
        )
    }

    func testReplayEntryDiagnosticsPresentationPrefersEBrainAndFallsBackToTraceWhenMissing() {
        let trace = DecisionIntelligenceTrace(
            createdAt: .now,
            kind: .quick,
            preferredProvider: .gemmaE4B,
            activeProvider: .foundationModels,
            attemptedProviders: [.gemmaE4B, .foundationModels],
            allowFallbacks: true,
            usedFallback: true,
            prompt: "Trace prompt",
            outputPreview: "Trace output",
            detail: "Trace detail"
        )

        let entryWithEBrain = DeveloperDecisionReplayEntry(
            record: .quick(makeQuickEvent(createdAt: .now, title: "Quick")),
            trace: DeveloperDecisionReplayTraceSummary(trace: trace),
            eBrain: DeveloperDecisionReplayEBrainSummary(
                lineageSummary: makeLineageSummary(
                    sessionID: "lineage-eBrain",
                    riskLevel: "high",
                    permitMode: "delay",
                    activeKillSwitches: ["force_guard_mode"],
                    recommendedKillSwitches: ["require_reviewed_writes"]
                )
            )
        )

        let eBrainPresentation = entryWithEBrain.diagnosticsPresentation
        XCTAssertEqual(
            eBrainPresentation.digest?.sourceDescriptor.kind,
            .checkpointRecovery
        )
        XCTAssertEqual(
            eBrainPresentation.digest?.compactStatusLine,
            "QUICK • HIGH → DELAY"
        )
        XCTAssertEqual(
            eBrainPresentation.digest?.taskTitle,
            "high pressure"
        )
        XCTAssertEqual(
            eBrainPresentation.digest?.operationsLine,
            "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 82%"
        )
        XCTAssertEqual(
            eBrainPresentation.digestHeadlineLine,
            "Checkpoint recovery • QUICK • HIGH → DELAY"
        )
        XCTAssertEqual(
            eBrainPresentation.overviewPresentation,
            DecisionEvolutionReplayOverviewPresentation(
                labelLine: "Checkpoint recovery • QUICK • HIGH → DELAY",
                titleLine: "high pressure",
                detailLines: [
                    "Hold before sending",
                    "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 82%"
                ]
            )
        )
        XCTAssertEqual(
            eBrainPresentation.replayCardCopy,
            DecisionEvolutionReplayCardCopy(
                titleLine: "high pressure",
                secondaryLine: "Buy • Wait 90 seconds",
                supplementaryLine: "Hold before sending"
            )
        )
        XCTAssertEqual(
            eBrainPresentation.overviewCardCopy,
            DecisionEvolutionReplayOverviewCardCopy(
                labelLine: "Checkpoint recovery • QUICK • HIGH → DELAY",
                titleLine: "high pressure",
                detailLines: [
                    "Buy • Wait 90 seconds",
                    "Hold before sending",
                    "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 82%"
                ]
            )
        )
        XCTAssertEqual(
            eBrainPresentation.overviewCardCopy.primaryDetailLine,
            "Buy • Wait 90 seconds"
        )
        XCTAssertEqual(
            eBrainPresentation.overviewCardCopy.secondaryDetailLine,
            "Hold before sending"
        )
        XCTAssertEqual(
            eBrainPresentation.overviewCardCopy.remainingDetailLines,
            ["Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 82%"]
        )
        XCTAssertEqual(
            eBrainPresentation.diagnosticsHeaderCopy,
            DecisionEvolutionReplayDiagnosticsHeaderCopy(
                eyebrowLine: "Checkpoint recovery",
                statusLine: "QUICK • HIGH → DELAY",
                titleLine: "high pressure",
                detailLines: [
                    "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 82%",
                    "Buy • Wait 90 seconds"
                ]
            )
        )
        XCTAssertEqual(
            eBrainPresentation.compactDiagnosticsLines.first?.text,
            "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 82%"
        )
        XCTAssertFalse(
            eBrainPresentation.compactDiagnosticsLines.contains { $0.text == "Hold before sending" }
        )
        XCTAssertNil(eBrainPresentation.budgetLine)
        XCTAssertNotNil(eBrainPresentation.eBrainLine)
        XCTAssertNotNil(eBrainPresentation.taskLine)
        XCTAssertNotNil(eBrainPresentation.auditLine)
        XCTAssertNotNil(eBrainPresentation.activeKillSwitchesLine)
        XCTAssertNotNil(eBrainPresentation.killSwitchesLine)
        XCTAssertNil(eBrainPresentation.traceLine)

        let traceOnlyEntry = DeveloperDecisionReplayEntry(
            record: .quick(makeQuickEvent(createdAt: .now, title: "Trace only")),
            trace: DeveloperDecisionReplayTraceSummary(trace: trace),
            eBrain: nil
        )

        let tracePresentation = traceOnlyEntry.diagnosticsPresentation
        XCTAssertNil(tracePresentation.digestHeadlineLine)
        XCTAssertEqual(
            tracePresentation.overviewPresentation,
            DecisionEvolutionReplayOverviewPresentation(
                labelLine: "Trace fallback",
                titleLine: tracePresentation.summaryLine,
                detailLines: ["Trace: Quick refinement • Apple Foundation Model"]
            )
        )
        XCTAssertNil(tracePresentation.digest)
        XCTAssertNil(tracePresentation.budgetLine)
        XCTAssertNil(tracePresentation.eBrainLine)
        XCTAssertNil(tracePresentation.taskLine)
        XCTAssertNil(tracePresentation.auditLine)
        XCTAssertNil(tracePresentation.activeKillSwitchesLine)
        XCTAssertNil(tracePresentation.killSwitchesLine)
        XCTAssertEqual(
            tracePresentation.traceLine,
            "Trace: Quick refinement • Apple Foundation Model"
        )
        XCTAssertEqual(
            tracePresentation.replayCardCopy,
            DecisionEvolutionReplayCardCopy(
                titleLine: tracePresentation.summaryLine,
                secondaryLine: "Trace: Quick refinement • Apple Foundation Model",
                supplementaryLine: nil
            )
        )
        XCTAssertEqual(
            tracePresentation.overviewCardCopy,
            DecisionEvolutionReplayOverviewCardCopy(
                labelLine: "Trace fallback",
                titleLine: tracePresentation.summaryLine,
                detailLines: ["Trace: Quick refinement • Apple Foundation Model"]
            )
        )
        XCTAssertEqual(
            tracePresentation.overviewCardCopy.primaryDetailLine,
            "Trace: Quick refinement • Apple Foundation Model"
        )
        XCTAssertNil(tracePresentation.overviewCardCopy.secondaryDetailLine)
        XCTAssertTrue(tracePresentation.overviewCardCopy.remainingDetailLines.isEmpty)
        XCTAssertEqual(
            tracePresentation.diagnosticsHeaderCopy,
            DecisionEvolutionReplayDiagnosticsHeaderCopy(
                eyebrowLine: "Trace fallback",
                statusLine: nil,
                titleLine: tracePresentation.summaryLine,
                detailLines: []
            )
        )
        XCTAssertTrue(tracePresentation.compactDiagnosticsLines.isEmpty)
    }

    func testReplayEntryDiagnosticsPresentationCarriesLiveBudgetAndTaskLines() {
        let protectiveTurn = makeProtectiveTurn()
        let eBrain = DeveloperDecisionReplayEBrainSummary(turn: protectiveTurn)
        let schedulerLine = eBrain.schedulerLine
        let entry = DeveloperDecisionReplayEntry(
            record: .quick(makeQuickEvent(createdAt: .now, title: "Quick")),
            trace: nil,
            eBrain: eBrain
        )

        let presentation = entry.diagnosticsPresentation

        XCTAssertEqual(
            presentation.digest?.sourceDescriptor.kind,
            .liveRuntime
        )
        XCTAssertEqual(
            presentation.digest?.compactStatusLine,
            "QUICK • HIGH → DELAY"
        )
        XCTAssertEqual(
            presentation.digest?.taskTitle,
            "high pressure"
        )
        XCTAssertEqual(
            presentation.digest?.operationsLine,
            "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 37%"
        )
        XCTAssertEqual(
            presentation.digestHeadlineLine,
            "Live runtime • QUICK • HIGH → DELAY"
        )
        XCTAssertEqual(
            presentation.overviewPresentation,
            DecisionEvolutionReplayOverviewPresentation(
                labelLine: "Live runtime • QUICK • HIGH → DELAY",
                titleLine: "high pressure",
                detailLines: [
                    "Review memory write: Keep the boundary signal in warm memory.",
                    "Factors: pressure • uncertainty",
                    "Reason codes: risk.high • gsi.elevated",
                    "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 37%",
                    "Breath guard • Phase exchange • Restore 84%",
                    schedulerLine,
                    "Hot pack stubCore, riskSpine, permitKnot, consistencyLattice • Warm coreCortex, criticBlade, tissueRouter, memoryCodecRidge, hostModulationMesh, toolIntentMesh • Cold 2 • preload guard_preload • eviction protective_retain",
                    "Resume frame resume.session-1.fold-1 • source fold-1 • depth 1 • organs coreCortex, criticBlade, riskSpine, permitKnot, consistencyLattice, stubCore, tissueRouter",
                    "Rollback anchor rollback.session-1.fold-1 • snapshot snapshot.session-1.fold-1 • cache cache.session-1.precision.session-1.fold-1"
                ].compactMap { $0 }
            )
        )
        XCTAssertEqual(
            presentation.replayCardCopy,
            DecisionEvolutionReplayCardCopy(
                titleLine: "high pressure",
                secondaryLine: "Buy • Wait 90 seconds",
                supplementaryLine: "Review memory write: Keep the boundary signal in warm memory."
            )
        )
        XCTAssertEqual(
            presentation.overviewCardCopy,
            DecisionEvolutionReplayOverviewCardCopy(
                labelLine: "Live runtime • QUICK • HIGH → DELAY",
                titleLine: "high pressure",
                detailLines: [
                    "Buy • Wait 90 seconds",
                    "Review memory write: Keep the boundary signal in warm memory.",
                    "Factors: pressure • uncertainty",
                    "Reason codes: risk.high • gsi.elevated",
                    "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 37%",
                    "Breath guard • Phase exchange • Restore 84%",
                    schedulerLine,
                    "Hot pack stubCore, riskSpine, permitKnot, consistencyLattice • Warm coreCortex, criticBlade, tissueRouter, memoryCodecRidge, hostModulationMesh, toolIntentMesh • Cold 2 • preload guard_preload • eviction protective_retain",
                    "Resume frame resume.session-1.fold-1 • source fold-1 • depth 1 • organs coreCortex, criticBlade, riskSpine, permitKnot, consistencyLattice, stubCore, tissueRouter",
                    "Rollback anchor rollback.session-1.fold-1 • snapshot snapshot.session-1.fold-1 • cache cache.session-1.precision.session-1.fold-1"
                ].compactMap { $0 }
            )
        )
        XCTAssertEqual(
            presentation.overviewCardCopy.primaryDetailLine,
            "Buy • Wait 90 seconds"
        )
        XCTAssertEqual(
            presentation.overviewCardCopy.secondaryDetailLine,
            "Review memory write: Keep the boundary signal in warm memory."
        )
        XCTAssertEqual(
            presentation.overviewCardCopy.remainingDetailLines,
            [
                "Factors: pressure • uncertainty",
                "Reason codes: risk.high • gsi.elevated",
                "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 37%",
                "Breath guard • Phase exchange • Restore 84%",
                schedulerLine,
                "Hot pack stubCore, riskSpine, permitKnot, consistencyLattice • Warm coreCortex, criticBlade, tissueRouter, memoryCodecRidge, hostModulationMesh, toolIntentMesh • Cold 2 • preload guard_preload • eviction protective_retain",
                "Resume frame resume.session-1.fold-1 • source fold-1 • depth 1 • organs coreCortex, criticBlade, riskSpine, permitKnot, consistencyLattice, stubCore, tissueRouter",
                "Rollback anchor rollback.session-1.fold-1 • snapshot snapshot.session-1.fold-1 • cache cache.session-1.precision.session-1.fold-1"
            ].compactMap { $0 }
        )
        XCTAssertEqual(
            presentation.diagnosticsHeaderCopy,
            DecisionEvolutionReplayDiagnosticsHeaderCopy(
                eyebrowLine: "Live runtime",
                statusLine: "QUICK • HIGH → DELAY",
                titleLine: "high pressure",
                detailLines: [
                    "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 37%",
                    "Buy • Wait 90 seconds"
                ]
            )
        )
        XCTAssertEqual(
            Array(presentation.compactDiagnosticsLines.map(\.text).prefix(3)),
            [
                "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 37%",
                expectedProtectiveBudgetLine(),
                expectedProtectivePressureLine()
            ]
        )
        XCTAssertTrue(
            presentation.compactDiagnosticsLines.contains {
                $0.text == "Breath guard • Phase exchange • Restore 84%"
            }
        )
        XCTAssertEqual(
            presentation.compactDiagnosticsLines.first(where: { $0.text == schedulerLine })?.text,
            schedulerLine
        )
        XCTAssertTrue(
            presentation.compactDiagnosticsLines.contains {
                $0.text == "Resume frame resume.session-1.fold-1 • source fold-1 • depth 1 • organs coreCortex, criticBlade, riskSpine, permitKnot, consistencyLattice, stubCore, tissueRouter"
            }
        )
        XCTAssertTrue(
            presentation.compactDiagnosticsLines.contains {
                $0.text == "Rollback anchor rollback.session-1.fold-1 • snapshot snapshot.session-1.fold-1 • cache cache.session-1.precision.session-1.fold-1"
            }
        )
        XCTAssertFalse(
            presentation.fullDiagnosticsLines(excludingHeaderSummary: true).contains {
                $0.text == "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 37%"
            }
        )
        XCTAssertTrue(
            presentation.fullDiagnosticsLines(excludingHeaderSummary: false).contains {
                $0.text == "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 37%"
            }
        )
        XCTAssertFalse(
            presentation.fullDiagnosticsLines(
                excludingHeaderSummary: false,
                excludingOverviewSummary: true
            ).contains {
                $0.text == "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 37%"
            }
        )
        XCTAssertFalse(
            presentation.fullDiagnosticsLines(
                excludingHeaderSummary: false,
                excludingOverviewSummary: true
            ).contains {
                $0.text == "Breath guard • Phase exchange • Restore 84%"
            }
        )
        XCTAssertFalse(
            presentation.fullDiagnosticsLines(
                excludingHeaderSummary: false,
                excludingOverviewSummary: true
            ).contains {
                $0.text == schedulerLine
            }
        )
        XCTAssertFalse(
            presentation.fullDiagnosticsLines(
                excludingHeaderSummary: false,
                excludingOverviewSummary: true
            ).contains {
                $0.text == "Resume frame resume.session-1.fold-1 • source fold-1 • depth 1 • organs coreCortex, criticBlade, riskSpine, permitKnot, consistencyLattice, stubCore, tissueRouter"
            }
        )
        XCTAssertFalse(
            presentation.fullDiagnosticsLines(
                excludingHeaderSummary: false,
                excludingOverviewSummary: true
            ).contains {
                $0.text == "Rollback anchor rollback.session-1.fold-1 • snapshot snapshot.session-1.fold-1 • cache cache.session-1.precision.session-1.fold-1"
            }
        )
        XCTAssertFalse(
            presentation.fullDiagnosticsLines(
                excludingHeaderSummary: false,
                excludingOverviewSummary: true
            ).contains {
                $0.text == "Review memory write: Keep the boundary signal in warm memory."
            }
        )
        XCTAssertFalse(
            presentation.compactDiagnosticsLines.contains {
                $0.text == "Review memory write: Keep the boundary signal in warm memory."
            }
        )
        XCTAssertEqual(
            presentation.budgetLine,
            expectedProtectiveBudgetLine()
        )
        XCTAssertEqual(
            presentation.pressureLine,
            expectedProtectivePressureLine()
        )
        XCTAssertEqual(
            presentation.taskLine,
            expectedProtectiveTaskLine()
        )
        XCTAssertEqual(
            presentation.layerStackLines,
            expectedProtectiveLayerStackLines()
        )
        XCTAssertTrue(presentation.eBrainLine?.contains("HIGH → DELAY") == true)
    }

    func testDiagnosticsHeaderCopyDoesNotRepeatSummaryWhenItMatchesTaskTitle() throws {
        let basePresentation = DeveloperDecisionReplayEntry(
            record: .quick(makeQuickEvent(createdAt: .now, title: "Quick")),
            trace: nil,
            eBrain: DeveloperDecisionReplayEBrainSummary(turn: makeProtectiveTurn())
        ).diagnosticsPresentation

        let digest = try XCTUnwrap(basePresentation.digest)
        let presentation = DecisionEvolutionReplayEntryPresentation(
            sourceTitle: basePresentation.sourceTitle,
            modeTitle: basePresentation.modeTitle,
            statusTitle: basePresentation.statusTitle,
            timestamp: basePresentation.timestamp,
            title: basePresentation.title,
            summaryLine: digest.taskTitle,
            digest: digest,
            overviewPresentation: basePresentation.overviewPresentation,
            layerStackLines: basePresentation.layerStackLines,
            budgetLine: basePresentation.budgetLine,
            pressureLine: basePresentation.pressureLine,
            eBrainLine: basePresentation.eBrainLine,
            taskLine: basePresentation.taskLine,
            actionLine: basePresentation.actionLine,
            auditLine: basePresentation.auditLine,
            activeKillSwitchesLine: basePresentation.activeKillSwitchesLine,
            killSwitchesLine: basePresentation.killSwitchesLine,
            traceLine: basePresentation.traceLine
        )

        XCTAssertEqual(
            presentation.diagnosticsHeaderCopy,
            DecisionEvolutionReplayDiagnosticsHeaderCopy(
                eyebrowLine: "Live runtime",
                statusLine: "QUICK • HIGH → DELAY",
                titleLine: "high pressure",
                detailLines: [
                    "Audit 1 • Active kill switches 1 • Recommended 1 • Host gate 37%"
                ]
            )
        )
    }

    func testHistoryDetailSelectionMatchesReplayRecordByStableIdentity() {
        let quick = makeQuickEvent(createdAt: .now, title: "Quick")
        let balance = makeBalanceRecord(updatedAt: .now, prompt: "Balance")
        let mirror = makeMirrorRecord(updatedAt: .now, prompt: "Mirror")

        XCTAssertTrue(HistoryDetailSelection.quick(quick).matches(.quick(quick)))
        XCTAssertFalse(HistoryDetailSelection.quick(quick).matches(.balance(balance)))

        XCTAssertTrue(HistoryDetailSelection.balance(balance).matches(.balance(balance)))
        XCTAssertFalse(HistoryDetailSelection.balance(balance).matches(.mirror(mirror)))

        XCTAssertTrue(HistoryDetailSelection.mirror(mirror).matches(.mirror(mirror)))
        XCTAssertFalse(HistoryDetailSelection.mirror(mirror).matches(.quick(quick)))
    }

    private func makeQuickEvent(createdAt: Date, title: String) -> CheckEvent {
        CheckEvent(
            createdAt: createdAt,
            scenario: .buy,
            motivation: .reward,
            expectedOutcome: .temporaryRelief,
            controlLevel: .maybe,
            note: "",
            currentPerspective: title,
            afterPerspective: "After \(title)",
            verdict: .pause,
            finalAction: .wait90s,
            entrySource: .app
        )
    }

    private func makeBalanceRecord(updatedAt: Date, prompt: String) -> BalanceDecisionRecord {
        BalanceDecisionRecord(
            createdAt: updatedAt,
            updatedAt: updatedAt,
            prompt: prompt,
            desire: "Want",
            concern: "Concern",
            constraint: "Constraint",
            longTerm: "Long-term",
            focusTitle: "Focus",
            focusSummary: "Summary",
            nextAction: "Next action",
            entrySource: .app
        )
    }

    private func makeMirrorRecord(updatedAt: Date, prompt: String) -> MirrorDecisionRecord {
        MirrorDecisionRecord(
            createdAt: updatedAt,
            updatedAt: updatedAt,
            prompt: prompt,
            emotion: "Emotion",
            relationship: "Relationship",
            reality: "Reality",
            longTerm: "Long-term",
            selfLens: "Self",
            coreTension: "Tension",
            nextActionTitle: "Action",
            nextAction: "Next step",
            entrySource: .app
        )
    }

    private func makeSystemEBrainSummary(
        source: DecisionTestingEBrainSource,
        pressureLine: String? = nil,
        riskFactorsLine: String? = nil,
        reasonCodesLine: String? = nil,
        sovereignVerdictLine: String? = nil,
        sovereignAuthorityLine: String? = nil,
        sovereignAuditLine: String? = nil
    ) -> DecisionSystemEBrainSummary {
        DecisionSystemEBrainSummary(
            source: source,
            runMode: "guarded",
            taskType: "high_pressure",
            riskLevel: "high",
            permitMode: "delay",
            deviceRoute: "guarded",
            loopCount: 1,
            cacheHitRate: 0,
            hostGatePercent: 37,
            pressureLine: pressureLine,
            riskFactorsLine: riskFactorsLine,
            reasonCodesLine: reasonCodesLine,
            foldChecksum: "checksum-1",
            updateTicketCount: 1,
            auditFindingCount: 1,
            activeKillSwitches: ["force_guard_mode"],
            recommendedKillSwitches: ["require_reviewed_writes"],
            killSwitches: ["force_guard_mode", "require_reviewed_writes"],
            sovereignVerdictLine: sovereignVerdictLine,
            sovereignAuthorityLine: sovereignAuthorityLine,
            sovereignAuditLine: sovereignAuditLine,
            inspectionHeadline: "Protective runtime turn attached.",
            blockers: [],
            layerStackLines: expectedProtectiveLayerStackLines(),
            checkpointID: nil,
            checkpointApprovalState: nil,
            checkpointRollbackReady: nil,
            checkpointApplyReady: nil
        )
    }

    private var foundationManagedPreferences: BeforePreferences {
        var preferences = BeforePreferences.default
        preferences.onDeviceIntelligenceMode = .assistive
        preferences.preferredIntelligenceProvider = .foundationModels
        preferences.allowModelFallbacks = true
        return preferences
    }

    private func expectedProtectiveLayerStackLines() -> [String] {
        [
            "L1 power clock • mode GUARD • wake guard • value 72% • risk 91% • route guarded • loops 2 • candidates 2 • decode 160",
            "L2 neural core • morph guard • organs coreCortex, criticBlade, riskSpine, permitKnot • heads risk_binding, permit_gate, stub_ready • frontier 1 • bindings 1 • projection cand-1/1/1 • route guarded • battery 66% • thermal warm • cpu 31% • npu on",
            "L3 compression runtime • fold active • slots 2 • restore ready",
            "L4 foundation • task high pressure • goals 1 • pressure 1 • ambiguity 63%",
            "L5 host profile • host aligned • goals 1 • no-go 1 • gate 37%",
            "L6 context • task high pressure • load 82% • time 74% • relation self • ambiguity 63% • consequence 81% • manipulation 1",
            "L7-L9 cognition • facts 1 • goals 1 • unknowns 1 • contradictions 0 • memory 1 • candidates 1/forecasts 1/critiques 1 • stop blocked",
            "L10-L12 adjudication • tri 1 scored/0 veto • HIGH → DELAY • GSI 68% • alternatives 2",
            "L13 evolution • 1 tickets • Review memory write: Keep the boundary signal in warm memory.",
            "L14 sovereign • constraints tool_cut, memory_freeze • verdict quarantine • tokens memoryWrite • lock session • quarantine session • audit BR-SOV-004 • active force_guard_mode • recommended require_reviewed_writes"
        ]
    }

    private func expectedProtectiveBudgetLine() -> String {
        "Budget GUARD • route guarded • loops 2 • candidates 2 • decode 160"
    }

    private func expectedProtectivePressureLine() -> String {
        "Pressure latency 3/1400ms • power 12% • cache 0% • thermal cool • vital 86%"
    }

    private func expectedProtectiveTaskLine() -> String {
        "Review memory write: Keep the boundary signal in warm memory. • wake guard • value 72% • risk 91%"
    }

    private func sharedNeuralCorePrefix(in line: String) -> String {
        line
            .components(separatedBy: " • ")
            .prefix(7)
            .joined(separator: " • ")
    }

    private func makeFoundationManagedRuntimeSnapshot() -> DecisionTestingRuntimeSnapshot {
        let preferences = foundationManagedPreferences
        let baseSnapshot = DecisionTestingInterface.runtimeSnapshot(
            preferences: preferences,
            environment: [:]
        )
        let foundationStatus = DecisionModelProviderStatus(
            kind: .foundationModels,
            isAvailable: true,
            title: "Available",
            detail: "Apple is ready."
        )
        let gemmaStatus = DecisionModelProviderStatus(
            kind: .gemmaE4B,
            isAvailable: true,
            title: "Ready",
            detail: "Gemma can cover heavier local work."
        )
        let executionProfile = DecisionIntelligenceExecutionProfileResolver.resolve(
            preferences: preferences,
            device: baseSnapshot.deviceCapabilities,
            openModelStatus: baseSnapshot.openModelProviderStatus,
            foundationStatus: foundationStatus,
            gemmaStatus: gemmaStatus,
            preferredLanguages: ["en-AU"]
        )

        return DecisionTestingRuntimeSnapshot(
            preferences: preferences,
            testingStubProfile: nil,
            executionProfile: executionProfile,
            runtimePolicyResolution: baseSnapshot.runtimePolicyResolution,
            activeTaskGraph: nil,
            inferenceBackendPolicy: baseSnapshot.inferenceBackendPolicy,
            deviceCapabilities: baseSnapshot.deviceCapabilities,
            gemmaBackendResolution: baseSnapshot.gemmaBackendResolution,
            runtimeStatus: DecisionModelRuntimeStatus(
                preferred: .foundationModels,
                active: .foundationModels,
                fallback: .gemmaE4B,
                detail: "System-managed foundation runtime is active.",
                policyLineage: baseSnapshot.runtimePolicyLineage
            ),
            foundationStatus: foundationStatus,
            gemmaProviderStatus: gemmaStatus,
            openModelProviderStatus: baseSnapshot.openModelProviderStatus,
            openModelRuntimeStatus: baseSnapshot.openModelRuntimeStatus,
            gemmaBundleStatus: baseSnapshot.gemmaBundleStatus,
            gemmaRuntimeStatus: baseSnapshot.gemmaRuntimeStatus,
            registeredProviders: baseSnapshot.registeredProviders,
            localModelLibrary: baseSnapshot.localModelLibrary
        )
    }

    private func makeLineageSummary(
        sessionID: String,
        riskLevel: String,
        permitMode: String,
        activeKillSwitches: [String],
        recommendedKillSwitches: [String],
        reviewDirectiveLine: String? = nil
    ) -> BASEvolutionLineageSummary {
        BASEvolutionLineageSummary(
            recordedAt: .now,
            sessionID: sessionID,
            taskType: "high_pressure",
            riskLevel: riskLevel,
            permitMode: permitMode,
            hostGatePercent: 82,
            thoughtFoldChecksum: "fold-checksum",
            updateTicketSummaries: ["Hold before sending"],
            reviewDirectiveLine: reviewDirectiveLine,
            activeKillSwitches: activeKillSwitches,
            guardrailFindings: ["Guardrail matched"],
            recommendedKillSwitches: recommendedKillSwitches,
            neuralMorphID: "guard",
            activeOrganIDs: ["coreCortex", "criticBlade", "riskSpine", "permitKnot"],
            headGuarantees: ["risk_binding", "permit_gate", "stub_ready"],
            frontierWidth: 1,
            bindingCount: 1,
            projectionLeadCandidateID: "cand-1",
            projectionCandidateCount: 1,
            projectionForecastCount: 1,
            projectionCritiqueCount: 1
        )
    }

    private func makeLineageSnapshot(
        sessionID: String,
        mode: DecisionMode,
        recordedAt: Date,
        riskLevel: String,
        permitMode: String,
        updateTicketSummaries: [String],
        diffSummary: [String],
        activeKillSwitches: [String],
        recommendedKillSwitches: [String],
        thoughtFoldChecksum: String = "fold-checksum"
    ) -> DecisionEvolutionLineageSnapshot {
        let summary = BASEvolutionLineageSummary(
            recordedAt: recordedAt,
            sessionID: sessionID,
            taskType: "high_pressure",
            riskLevel: riskLevel,
            permitMode: permitMode,
            hostGatePercent: 82,
            thoughtFoldChecksum: thoughtFoldChecksum,
            updateTicketSummaries: updateTicketSummaries,
            activeKillSwitches: activeKillSwitches,
            guardrailFindings: ["Guardrail matched"],
            recommendedKillSwitches: recommendedKillSwitches
        )

        return DecisionEvolutionLineageSnapshot(
            checkpointID: "checkpoint-\(sessionID)",
            createdAt: recordedAt,
            mode: mode,
            approvalState: .reviewSuggested,
            rollbackReady: true,
            hasBrainStateSnapshot: true,
            diffSummary: diffSummary,
            eBrain: DeveloperDecisionReplayEBrainSummary(lineageSummary: summary)
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
        let organMap = BASNeuralOrganMap(
            morph: .guard,
            activeOrgans: [.coreCortex, .criticBlade, .riskSpine, .permitKnot, .consistencyLattice, .stubCore, .tissueRouter],
            precisionMap: [
                BASNeuralOrganPrecision(organ: .coreCortex, tier: .protected),
                BASNeuralOrganPrecision(organ: .riskSpine, tier: .protected),
                BASNeuralOrganPrecision(organ: .permitKnot, tier: .protected),
                BASNeuralOrganPrecision(organ: .stubCore, tier: .full)
            ],
            routingPolicy: .protectiveThrottle,
            leaseRef: "lease-1",
            sovereignConstraints: ["tool_cut", "memory_freeze"],
            headGuarantees: ["risk_binding", "permit_gate", "stub_ready"]
        )
        let frontier = BASCandidateFrontier(
            candidateIDs: [candidate.candidateID],
            dominanceOrder: [candidate.candidateID],
            reversiblePaths: [candidate.candidateID],
            guardPaths: [candidate.candidateID],
            frontierWidth: 1
        )
        let counterfactualBundle = BASCounterfactualBundle(
            candidateID: candidate.candidateID,
            shortTerm: forecast.shortTermOutcome,
            midTerm: forecast.midTermOutcome,
            worstCase: forecast.worstCase,
            uncertainty: forecast.uncertainty,
            affectedDomains: forecast.affectedRelations
        )
        let riskBinding = BASRiskPermitBinding(
            candidateID: candidate.candidateID,
            riskLevel: .high,
            totalRisk: riskCard.totalRisk,
            uncertainty: riskCard.uncertainty,
            irreversibility: riskCard.irreversibility,
            manipulationStrength: riskCard.manipulationStrength,
            gsiScore: riskCard.gsiScore,
            recommendedMode: riskCard.recommendedMode,
            permitMode: actionPermit.mode,
            requireSecondCheck: actionPermit.requireSecondCheck,
            outputLengthCap: actionPermit.outputLengthCap,
            tonePolicy: actionPermit.tonePolicy,
            templatePolicy: actionPermit.templatePolicy,
            reasonCodes: actionPermit.reasonCodes,
            allowedDomains: ["bounded_reply"],
            forbiddenDomains: ["tool_commit", "memory_commit"]
        )
        let neuralLeaseReceipt = BASNeuralLeaseReceipt(
            leaseID: "lease-1",
            organsUsed: organMap.activeOrgans,
            loopsUsed: 1,
            energyUsed: 0.12,
            decodeTokensUsed: 96,
            degraded: false
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
            organMap: organMap,
            candidateFrontier: frontier,
            counterfactualBundles: [counterfactualBundle],
            riskBindings: [riskBinding],
            neuralLeaseReceipt: neuralLeaseReceipt,
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
            checksum: "checksum-1",
            morphID: BASNeuralMorph.guard.rawValue,
            organChecksum: "organ-checksum-1",
            frontierChecksum: "frontier-checksum-1",
            bindingChecksum: "binding-checksum-1",
            degradedReasonCodes: []
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
}
