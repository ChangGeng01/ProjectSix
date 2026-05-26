// MARK: - BASChapter996EndToEndTraceTests
// chapter 九百九十六 / M3690 — END-TO-END RUNTIME TRACE
//
// This is not a hermetic unit test — it's a script-runner that
// uses XCTest plumbing to actually drive the full
// BASAgentFabricHostPipeline end-to-end with all 12 live-input
// fields populated, and PRINTS every pipeline observation at
// each stage。 This is the FIRST end-to-end runtime trace beyond
// piece-by-piece XCTest assertions。

import XCTest
import Crypto
@testable import BASOrchestration
@testable import BASHostKit
@testable import BASMemory
@testable import BASSovereign
@testable import BASRuntimeCore
@testable import BASPolicy

final class BASChapter996EndToEndTraceTests: XCTestCase {

    func testEndToEndTrace_PrintsFullPipelineObservations()
        async throws
    {
        // === Banner ===
        print("=================================================")
        print("BAS Chapter 996 — END-TO-END TRACE")
        print("=================================================")

        // === Build coordinator with 9-seat fabric ===
        let traceLog = BASAgentTraceLog()
        let roster = makeNineSeatRoster()
        let fabric = BASAgentFabricRuntime(
            roster: roster,
            graph: BASSharedStateGraph(),
            traceLog: traceLog)
        let hostConstitution = BASHostConstitution(
            hostID: "trace.host.alpha",
            valueAxes: BASValueAxisSet(
                axes: ["financial", "privacy"]),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: ["legal"]),
            styleGenome: BASStyleGenome(
                structureBias: 0.75))
        let coordinator = BASEBrainRuntimeCoordinator(
            powerClockService:
                BASPlaceholderPowerClockService(),
            hostProfileService:
                BASPlaceholderHostProfileService(),
            contextService:
                BASPlaceholderContextService(),
            decomposeService:
                BASPlaceholderDecomposeService(),
            memoryService:
                BASPlaceholderMemoryService(),
            loopService:
                BASPlaceholderLoopService(),
            triSelfService:
                BASPlaceholderTriSelfService(),
            riskService:
                BASPlaceholderRiskService(),
            actionService:
                BASPlaceholderActionService(),
            evolutionService:
                BASPlaceholderEvolutionService(),
            hostConstitution: hostConstitution,
            agentFabric: fabric)

        // Placeholder warrant ledger
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        // Trace log bridge
        let memEventLog = TraceMemEventLog()
        let traceBridge = BASAgentTraceLogEventLogBridge(
            traceLog: traceLog,
            eventLog: memEventLog,
            sessionID: "sess.trace.1")

        // === Build all 12 live-input fields ===
        let frame = BASDecomposeFrame(
            pressureSignals: ["stress.high"],
            manipulationSignals: ["guilt.trip"])
        let candidatePaths = [
            BASCandidatePath(
                candidateID: "c1",
                title: "Take a walk",
                actionSummary: "5-min outside",
                expectedBenefit: 0.75,
                expectedCost: 0.10,
                reversibility: 0.95,
                confidence: 0.85),
            BASCandidatePath(
                candidateID: "c2",
                title: "Major change",
                actionSummary: "irreversible action",
                expectedBenefit: 0.30,
                expectedCost: 0.80,
                reversibility: 0.10,
                confidence: 0.40),
        ]
        let riskCard = BASRiskCard(
            totalRisk: 0.85,
            riskLevel: .high,
            uncertainty: 0.40,
            irreversibility: 0.55,
            manipulationStrength: 0.65,
            gsiScore: 0.55,
            recommendedMode: .delay)
        // 2 tri scores, 1 vetoed
        let triScores = [
            BASTriSelfScore(
                candidateID: "c1",
                idScore: 0.5,
                egoScore: 0.6,
                superegoScore: 0.7,
                mergedScore: 0.6,
                veto: false),
            BASTriSelfScore(
                candidateID: "c2",
                idScore: 0.3,
                egoScore: 0.5,
                superegoScore: 0.1,
                mergedScore: 0.2,
                veto: true),
        ]
        let memoryInput = BASMemorySeatInput(
            episodeArcs: ["arc-2026-05"],
            conflictClusters: ["conflict-A"],
            continuityAnchors: ["anchor-1"],
            recallStrength: 0.8)
        let sovereignSentinelInput = BASSovereignSentinelInput(
            candidates: [
                BASSovereignSentinelCandidate(
                    candidateID: "c2",
                    title: "Major change",
                    reversibility: 0.10,
                    touchesAxesCount: 2,
                    touchesSovereignLockedAxis: false)
            ],
            manipulationDetected: true,
            boundaryTouched: true,
            heightenedProtection: false)
        let evolutionShadowInput = BASEvolutionShadowInput(
            updateTickets: [
                BASEvolutionUpdateTicket(
                    ticketID: "tk1",
                    targetRef: "rule.x",
                    summary: "tighten",
                    scopeImpact: 0.3)
            ],
            ruleCandidates: [
                BASEvolutionRuleCandidate(
                    candidateID: "rc1",
                    ruleBody: "if X then Y",
                    supportStrength: 0.6)
            ],
            hostChangeCandidates: [])
        // Warrant validation
        let warrantChain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.partner")
        let warrantResult = BASSovereignWarrantValidator
            .validate(
                chain: warrantChain,
                forExternalAgentID: "ext.partner",
                nowNanos: 500_000_000_000)
        // Priority context with sovereign + risk + host IDs
        let priorityContext = BASMergePriorityContext(
            sovereignAgentIDs: ["sentinel.1"],
            riskAgentIDs: ["risk.1"],
            hostAgentIDs: ["hostalign.1"],
            agentPriorities: [
                "sentinel.1": 100,
                "risk.1": 80,
                "hostalign.1": 60,
            ],
            evidenceConfidenceFloor: 0.5)

        // === Build pipeline + drive runTurn ===
        let pipeline = BASAgentFabricHostPipeline(
            coordinator: coordinator,
            sessionID: "sess.trace.1",
            warrantLedger: ledger,
            traceLogBridge: traceBridge,
            environmentOverride: [
                "BAS_AGENT_FABRIC": "enabled",
                "BAS_AGENT_TIER": "all",
                "BAS_TRANSCRIPT_MODE": "compareSelected",
                "BAS_ACTIVE_AGENTS":
                    "Planner,Critic,Memory,Risk,Surface",
            ])

        print("--- Driving pipeline.runTurn(turnID: t.trace.1) ---")
        let outcome = try await pipeline.runTurn(
            turnID: "t.trace.1",
            decomposeFrame: frame,
            candidatePaths: candidatePaths,
            acceptedCandidateID: "c1",
            riskCard: riskCard,
            triScores: triScores,
            memoryInput: memoryInput,
            sovereignSentinelInput: sovereignSentinelInput,
            evolutionShadowInput: evolutionShadowInput,
            warrantValidation: (
                result: warrantResult,
                externalAgentID: "ext.partner"),
            priorityContext: priorityContext,
            nowNanos: 1_700_000_000_000_000_000)

        // === PRINT outcome ===
        print("")
        print("=== OUTCOME (top-level) ===")
        print("outcome.activated = \(outcome.activated)")
        print("outcome.skipReason = " +
              "\(outcome.skipReason ?? "<nil>")")
        print("outcome.fabricMode?.rawValue = " +
              "\(outcome.fabricMode?.rawValue ?? "<nil>")")
        print("outcome.activation.fabricEnabled = " +
              "\(outcome.activation.fabricEnabled)")
        print("outcome.activation.tier.rawValue = " +
              "\(outcome.activation.tier.rawValue)")
        print("outcome.activation.transcriptMode.rawValue = " +
              "\(outcome.activation.transcriptMode.rawValue)")
        print("outcome.activation.activeAgents = " +
              "\(outcome.activation.activeAgents)")

        print("")
        print("=== DIAGNOSTICS DICT (\(outcome.diagnostics.count) keys) ===")
        let sortedKeys = outcome.diagnostics.keys.sorted()
        for k in sortedKeys {
            print("  \(k) = \(outcome.diagnostics[k] ?? "")")
        }

        print("")
        print("=== RESULT (turn-level) ===")
        if let result = outcome.result {
            let deltas = result.turnResult.emittedDeltas
            print("result.turnResult.emittedDeltas.count = " +
                  "\(deltas.count)")
            print("first 10 emittedDeltas[i].targetObjectRef:")
            for (i, d) in deltas.prefix(10).enumerated() {
                print("  [\(i)] agentID=\(d.agentID) " +
                      "deltaType=\(d.deltaType.rawValue) " +
                      "ref=\(d.targetObjectRef) " +
                      "confidence=\(String(format: "%.3f", d.confidence))")
            }
            if deltas.count > 10 {
                print("  ... (+\(deltas.count - 10) more)")
            }
            // Print ALL emitted refs for full visibility
            print("ALL emittedDeltas[i].targetObjectRef:")
            for (i, d) in deltas.enumerated() {
                print("  [\(i)] \(d.targetObjectRef)")
            }
            print("result.turnResult.mergeResult.acceptedDeltaIDs.count = " +
                  "\(result.turnResult.mergeResult.acceptedDeltaIDs.count)")
            print("result.turnResult.applyOutcomes.count = " +
                  "\(result.turnResult.applyOutcomes.count)")
            print("result.turnResult.finalSeq = " +
                  "\(result.turnResult.finalSeq)")
            if let audit = result.warrantAuditEntry {
                print("result.warrantAuditEntry.entry.auditID = " +
                      "\(audit.entry.auditID)")
                print("result.warrantAuditEntry.entry.sessionID = " +
                      "\(audit.entry.sessionID)")
                print("result.warrantAuditEntry.entry.turnID = " +
                      "\(audit.entry.turnID)")
                print("result.warrantAuditEntry.entry.signatureLen = " +
                      "\(audit.entry.signature.count)")
                print("result.warrantAuditEntry.entry.signalRefs.count = " +
                      "\(audit.entry.signalRefs.count)")
                if !audit.entry.signalRefs.isEmpty {
                    print("signalRefs:")
                    for (i, ref) in audit.entry.signalRefs
                        .prefix(5).enumerated()
                    {
                        // Replace U+001F so it's visible in console output
                        let visible = ref
                            .replacingOccurrences(
                                of: "\u{001F}",
                                with: "<U+001F>")
                        print("  [\(i)] \(visible)")
                    }
                }
            } else {
                print("result.warrantAuditEntry = <nil>")
            }
            if let flushed = result.flushedTraceEventCount {
                print("result.flushedTraceEventCount = \(flushed)")
            } else {
                print("result.flushedTraceEventCount = <nil>")
            }
            let fp = result.frontierProjection
            print("result.frontierProjection.frontierWidth = " +
                  "\(fp.frontierWidth)")
            print("result.frontierProjection.dominanceOrder = " +
                  "\(fp.dominanceOrder)")
            print("result.frontierProjection.candidateIDs = " +
                  "\(fp.candidateIDs)")
            print("result.frontierProjection.reversiblePaths = " +
                  "\(fp.reversiblePaths)")
            print("result.frontierProjection.guardPaths = " +
                  "\(fp.guardPaths)")
            print("result.frontierProjection.delayedPaths = " +
                  "\(fp.delayedPaths)")
            print("result.frontierProjection.diversityScore = " +
                  "\(String(format: "%.3f", fp.diversityScore))")
        } else {
            print("outcome.result = <nil>")
        }

        // === Inspect event log ===
        print("")
        print("=== EVENT LOG ENTRIES (post-flush) ===")
        let entries = await memEventLog
            .events(forSession: "sess.trace.1")
        print("event log entry count = \(entries.count)")
        for (i, e) in entries.prefix(8).enumerated() {
            print("  [\(i)] eventID=\(e.eventID) " +
                  "kind=\(e.kind.rawValue) " +
                  "source=\(e.source ?? "<nil>")")
        }
        if entries.count > 8 {
            print("  ... (+\(entries.count - 8) more)")
        }

        print("")
        print("=================================================")
        print("BAS Chapter 996 — TRACE COMPLETE")
        print("=================================================")

        // Assertion: trace ran (we got an outcome back without
        // throwing)。 No deeper assertions — this is a script
        // runner, not an oracle test。
        XCTAssertNotNil(outcome,
            "ch 996 trace: pipeline produced an outcome")
    }

    // MARK: - Helpers

    private func makeNineSeatRoster() -> BASAgentTurnRoster {
        BASAgentTurnRoster(
            scout: BASAgentSpec(
                agentID: "scout.1",
                role: .scout,
                writeDomains: [.situationField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            planner: BASAgentSpec(
                agentID: "planner.1",
                role: .planner,
                writeDomains: [.candidateFrontier],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            risk: BASAgentSpec(
                agentID: "risk.1",
                role: .risk,
                writeDomains: [.riskField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            surface: BASAgentSpec(
                agentID: "surface.1",
                role: .surface,
                writeDomains: [.renderFrame],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            memory: BASAgentSpec(
                agentID: "memory.1",
                role: .memory,
                writeDomains: [.memoryBundle],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            critic: BASAgentSpec(
                agentID: "critic.1",
                role: .critic,
                writeDomains: [.critiqueField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            hostAlignment: BASAgentSpec(
                agentID: "hostalign.1",
                role: .hostAlignment,
                writeDomains: [.alignmentField],
                defaultLeaseProfile: .hotSeat,
                visibility: .medium),
            sovereignSentinel: BASAgentSpec(
                agentID: "sentinel.1",
                role: .sovereignSentinel,
                writeDomains: [.sovereignVerdict],
                defaultLeaseProfile: .sovereign,
                visibility: .low),
            evolutionShadow: BASAgentSpec(
                agentID: "evolution.1",
                role: .evolutionShadow,
                writeDomains: [.evolutionProposal],
                defaultLeaseProfile: .coldSeat,
                visibility: .medium))
    }
}

// MARK: - In-memory test event log for trace

private actor TraceMemEventLog: BASEventLogStorage {
    private var entries: [String: BASEventLogEntry] = [:]
    private var nextSeq: Int64 = 0

    func append(
        _ entry: BASEventLogEntry
    ) async throws -> (
        wasNew: Bool, assignedSequenceNumber: Int64)
    {
        if entries[entry.eventID] != nil {
            return (
                wasNew: false,
                assignedSequenceNumber:
                    entries[entry.eventID]!.sequenceNumber)
        }
        nextSeq += 1
        let stamped = BASEventLogEntry(
            eventID: entry.eventID,
            timestampMs: entry.timestampMs,
            kind: entry.kind,
            sessionID: entry.sessionID,
            sequenceNumber: nextSeq,
            source: entry.source,
            turnRef: entry.turnRef,
            rawInputDigest: entry.rawInputDigest,
            intent: entry.intent,
            emotion: entry.emotion,
            riskBand: entry.riskBand,
            project: entry.project,
            memoryRefs: entry.memoryRefs,
            stateBeforeID: entry.stateBeforeID,
            stateAfterID: entry.stateAfterID,
            actions: entry.actions,
            confidence: entry.confidence,
            payloadJson: entry.payloadJson)
        entries[entry.eventID] = stamped
        return (wasNew: true, assignedSequenceNumber: nextSeq)
    }

    func events(
        forSession sessionID: String
    ) async -> [BASEventLogEntry] {
        entries.values
            .filter { $0.sessionID == sessionID }
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
    }

    func events(
        sinceTimestampMs since: Int64,
        limit: Int
    ) async -> [BASEventLogEntry] {
        entries.values
            .filter { $0.timestampMs >= since }
            .sorted {
                ($0.timestampMs, $0.sequenceNumber) <
                ($1.timestampMs, $1.sequenceNumber)
            }
            .prefix(limit)
            .map { $0 }
    }

    var totalCount: Int { get async { entries.count } }

    @discardableResult
    func pruneEventsBefore(
        timestampMs cutoff: Int64
    ) async throws -> Int {
        let before = entries.count
        entries = entries.filter {
            $0.value.timestampMs >= cutoff
        }
        return before - entries.count
    }
}
