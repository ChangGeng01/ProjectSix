import XCTest
import BASHostKit
@testable import Before

final class DeveloperDecisionReplayBuilderTests: XCTestCase {
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
        XCTAssertEqual(
            presentation.hostLine,
            "Host gate 37% • Fold checksum-1 • Audit 1"
        )
        XCTAssertEqual(
            presentation.inspectionHeadline,
            "Protective runtime turn attached."
        )
        XCTAssertNil(presentation.primaryGuardrailText)
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
            "HIGH → DELAY • host gate 37% • fold checksum-1"
        )
        XCTAssertEqual(
            livePresentation.budgetLine,
            "Budget GUARDED • route guarded • loops 2 • candidates 2 • decode 160"
        )
        XCTAssertEqual(
            livePresentation.taskLine,
            "Review: Record a protective turn."
        )
        XCTAssertNil(livePresentation.actionLine)
        XCTAssertEqual(livePresentation.detailLine, "Record a protective turn.")
        XCTAssertEqual(livePresentation.auditLine, "Audit: Protective short-circuit requested.")
        XCTAssertEqual(livePresentation.activeKillSwitchesLine, "Active kill switches: force_guard_mode")
        XCTAssertEqual(
            livePresentation.killSwitchesLine,
            "Kill switches: force_guard_mode • require_reviewed_writes"
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
            "MEDIUM → COMPARE • host gate 82% • fold fold-checksum"
        )
        XCTAssertNil(checkpointPresentation.budgetLine)
        XCTAssertEqual(
            checkpointPresentation.taskLine,
            "Review: Hold before sending"
        )
        XCTAssertNil(checkpointPresentation.actionLine)
        XCTAssertEqual(checkpointPresentation.detailLine, "Hold before sending")
        XCTAssertEqual(checkpointPresentation.auditLine, "Audit: Guardrail matched")
        XCTAssertEqual(
            checkpointPresentation.activeKillSwitchesLine,
            "Active kill switches: force_guard_mode"
        )
        XCTAssertEqual(
            checkpointPresentation.killSwitchesLine,
            "Kill switches: force_guard_mode • require_reviewed_writes"
        )
    }

    func testReplayEBrainFactsBundleDerivesSharedBrainSummaryLine() {
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
            "Recovered from checkpoint • Quick • permit compare • risk medium • fold fold-checksum"
        )
        XCTAssertEqual(
            factsBundle.brainSummaryLine,
            "Checkpoint recovery • session lineage-2 • host gate 82% • 1 tickets"
        )
    }

    func testBaseBrainTurnDiagnosticsPresentationDerivesSharedFields() {
        let turn = makeProtectiveTurn()

        let presentation = turn.diagnosticsPresentation

        XCTAssertEqual(presentation.sourceDescriptor.kind, .liveRuntime)
        XCTAssertEqual(presentation.runModeTitle, turn.budgetFrame.runMode.rawValue.uppercased())
        XCTAssertEqual(presentation.taskTitle, turn.contextFrame.taskType.rawValue.replacingOccurrences(of: "_", with: " "))
        XCTAssertEqual(presentation.riskTitle, turn.riskCard.riskLevel.rawValue.uppercased())
        XCTAssertEqual(presentation.permitTitle, turn.actionPermit.mode.rawValue.uppercased())
        XCTAssertEqual(presentation.mirrorText, turn.decomposeFrame.mirrorText)
        XCTAssertTrue(presentation.routeText.contains("Route: guarded"))
        XCTAssertTrue(presentation.hostText.contains("Host gate 37%"))
        XCTAssertTrue(presentation.replayText.contains(turn.runtimeTrace.sessionID))
        XCTAssertEqual(presentation.candidateTitles, ["Pause and protect"])
        XCTAssertEqual(presentation.memorySummaries, ["Protect the boundary first."])
        XCTAssertEqual(presentation.alternativeActions, ["Wait 24 hours", "Draft but do not send"])
        XCTAssertEqual(presentation.ticketSummary, "Record a protective turn.")
        XCTAssertEqual(presentation.activeKillSwitchesLine, "Active kill switches: force_guard_mode")
        XCTAssertEqual(presentation.recommendedKillSwitchesLine, "Recommended kill switches: require_reviewed_writes")
        XCTAssertEqual(presentation.riskFactorsLine, "Factors: pressure • uncertainty")
        XCTAssertEqual(presentation.reasonCodesLine, "Reason codes: risk.high • gsi.elevated")
        XCTAssertEqual(presentation.thoughtFoldLines, ["• body: Mirror body", "• headline: Pause first"])
        XCTAssertEqual(presentation.replayTraceLines, ["• L11 gate: Protective short-circuited refinement."])
        XCTAssertEqual(presentation.auditLines, ["• L11 protected_permit: Protective short-circuit requested."])
        XCTAssertEqual(
            presentation.triScoreLines,
            ["• cand-1: id 42 / ego 81 / superego 91"]
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
    }

    func testReplayEntryDiagnosticsPresentationCarriesLiveBudgetAndTaskLines() {
        let entry = DeveloperDecisionReplayEntry(
            record: .quick(makeQuickEvent(createdAt: .now, title: "Quick")),
            trace: nil,
            eBrain: DeveloperDecisionReplayEBrainSummary(turn: makeProtectiveTurn())
        )

        let presentation = entry.diagnosticsPresentation

        XCTAssertEqual(
            presentation.budgetLine,
            "Budget GUARDED • route guarded • loops 2 • candidates 2 • decode 160"
        )
        XCTAssertEqual(
            presentation.taskLine,
            "Review: Record a protective turn."
        )
        XCTAssertTrue(presentation.eBrainLine?.contains("HIGH → DELAY") == true)
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
        source: DecisionTestingEBrainSource
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
            foldChecksum: "checksum-1",
            updateTicketCount: 1,
            auditFindingCount: 1,
            activeKillSwitches: ["force_guard_mode"],
            recommendedKillSwitches: ["require_reviewed_writes"],
            killSwitches: ["force_guard_mode", "require_reviewed_writes"],
            inspectionHeadline: "Protective runtime turn attached.",
            blockers: [],
            checkpointID: nil,
            checkpointApprovalState: nil,
            checkpointRollbackReady: nil,
            checkpointApplyReady: nil
        )
    }

    private func makeLineageSummary(
        sessionID: String,
        riskLevel: String,
        permitMode: String,
        activeKillSwitches: [String],
        recommendedKillSwitches: [String]
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
            activeKillSwitches: activeKillSwitches,
            guardrailFindings: ["Guardrail matched"],
            recommendedKillSwitches: recommendedKillSwitches
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

        return BASEBrainTurnResult(
            deviceState: deviceState,
            budgetFrame: budgetFrame,
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
