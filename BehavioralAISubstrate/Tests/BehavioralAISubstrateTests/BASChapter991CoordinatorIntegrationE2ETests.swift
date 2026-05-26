// MARK: - BASChapter991CoordinatorIntegrationE2ETests
// chapter 九百九十一 / M3660 — Cross-Module Integration Arc ch9
//
// Closes the sub-finding inside ch 982.5 META-REVIEW Gap 8:
// **"ZERO integration tests through EBrainRuntimeCoordinator —
// all 663 arc tests dispatch directly through
// BASAgentTurnDispatcher"**。
//
// Ch 991 is the FIRST end-to-end test that:
//   1. Uses an EBrainRuntimeCoordinator with all 9 seat roster
//      slots filled (incl. ch 965 EvolutionShadow)
//   2. Builds the 5 optional seat DTOs via the new cross-module
//      adapters (ch 986 hostAlignment / ch 987 risk / ch 988
//      critic enrichment)
//   3. Invokes `coordinator.runAgentFabricObservation(...)` with
//      all 5 optional pre-built DTOs (per ch 985 API extension)
//   4. After dispatch:exercises the post-turn integration paths
//      - Validates a warrant + appends to ledger (ch 983)
//      - Flushes trace log to event log storage (ch 984)
//      - Projects candidate frontier (ch 989)
//      - Validates MCP invocation against permit (ch 990)
//   5. Asserts the pipeline produced expected outputs at every
//      composition boundary
//
// This is the "is everything wired together correctly" test。
// Each individual adapter has its own ch 983-990 tests;this
// chapter pins the COMPOSITION。

import XCTest
import Crypto
@testable import BASMemory
@testable import BASOrchestration
@testable import BASHostKit
@testable import BASSovereign
@testable import BASRuntimeCore
@testable import BASPolicy

final class BASChapter991CoordinatorIntegrationE2ETests:
    XCTestCase
{

    /// CRITICAL: full 9-seat pipeline through coordinator with
    /// all post-turn integration adapters。 This is the test the
    /// ch 982.5 META-REVIEW Gap 8 sub-finding said was missing。
    func testCRITICAL_FullNineSeatPipelineThroughCoordinator()
        async throws
    {
        // ===== Setup =====

        // 1. Build a live BASHostConstitution
        let hostConstitution = BASHostConstitution(
            hostID: "user.alpha",
            valueAxes: BASValueAxisSet(
                axes: ["financial", "privacy"]),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: ["legal"]),
            styleGenome: BASStyleGenome(
                structureBias: 0.75))

        // 2. Build a live BASRiskCard (simulating
        // riskService.calibrateRisk output)
        let riskCard = BASRiskCard(
            totalRisk: 0.7,
            riskLevel: .high,
            uncertainty: 0.4,
            irreversibility: 0.3,
            manipulationStrength: 0.6,  // >= 0.5 triggers
            gsiScore: 0.65,
            recommendedMode: .compare)

        // 3. Build a live BASActionPermit (simulating
        // riskService.gateAction output)
        let permit = BASActionPermit(
            mode: .answer,
            allowedDomains: ["mcp.fs", "mcp.calendar"],
            toolScope: "bounded")

        // 4. Build a live BASTriSelfScore[] (simulating
        // triSelfService.mergeChoice output)。
        // chapter 九百九十一.5 HIGH-1 fix:was both non-vetoed,
        // which after the semantic fix produces 0-concern (correct
        // intent),but then the downstream Critic seat doesn't emit
        // any delta (level stays at base 0.5)。 For the E2E
        // composition test we want Critic to BE REACHABLE +
        // emit ≥1 delta,so include 1 vetoed candidate to lift
        // fraction-vetoed enough that the corrected adapter
        // produces a non-trivial concern signal。
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
                superegoScore: 0.1,  // low safety
                mergedScore: 0.2,
                veto: true),  // vetoed (irreversible candidate)
        ]

        // 5. Build candidate paths (simulating
        // loopService.proposePaths output)
        let candidatePaths = [
            BASCandidatePath(
                candidateID: "c1",
                title: "Take a walk",
                actionSummary: "5-min outside",
                expectedBenefit: 0.7,
                expectedCost: 0.1,
                reversibility: 0.95,
                confidence: 0.85),
            BASCandidatePath(
                candidateID: "c2",
                title: "Major change",
                actionSummary: "irreversible action",
                expectedBenefit: 0.3,
                expectedCost: 0.8,
                reversibility: 0.1,
                confidence: 0.4),
        ]

        // 6. Decompose frame (L7 output)
        let frame = BASDecomposeFrame(
            pressureSignals: ["stress.high"],
            manipulationSignals: ["guilt.trip"])

        // ===== Cross-module adapter composition =====

        // 7. Build risk + critic via enrichment adapters
        let baseRiskInput = BASAgentFabricAdapters.riskInput(
            from: frame, candidates: candidatePaths)
        let enrichedRiskInput = BASAgentFabricAdapters
            .enrichRiskInput(
                from: riskCard,
                baseRiskInput: baseRiskInput)
        // Verify ch 987: enrichment monotonically raised pressure
        XCTAssertGreaterThanOrEqual(
            enrichedRiskInput.pressureLevel,
            baseRiskInput.pressureLevel,
            "ch 991 E2E: ch 987 enrichment MUST monotonic-raise")

        let baseCriticInput = BASAgentFabricAdapters
            .criticInput(from: candidatePaths)
        let enrichedCriticInput = BASAgentFabricAdapters
            .enrichCriticInput(
                from: triScores,
                baseCriticInput: baseCriticInput)
        // chapter 九百九十一.5 META-REVIEW HIGH-1 fix:was
        // asserting `superegoActiveLevel == 0.8` based on
        // INVERTED semantics (average superego score of safe
        // candidates)。 Round-9 caught the inversion。 Corrected:
        // 1 vetoed / 2 total = 0.5 fraction → max with base 0.5
        // = 0.5。 Mixed scenario (above) was changed from
        // both-safe to 1-vetoed so Critic seat is reachable
        // through this E2E composition test。
        XCTAssertEqual(
            enrichedCriticInput.superegoActiveLevel,
            0.5,
            accuracy: 0.001,
            "ch 991.5 HIGH-1 fix: 1 vetoed / 2 total = 0.5 " +
            "fraction-vetoed → max(base 0.5, 0.5) = 0.5。 " +
            "Pre-fix version froze inverted avg-superego at 0.8。")

        // 8. Build host alignment via ch 986 adapter
        let hostInput = BASAgentFabricAdapters
            .hostAlignmentInput(
                from: hostConstitution,
                candidates: [
                    BASHostAlignmentCandidate(
                        candidateID: "c1",
                        title: "Take a walk",
                        touchesAxes: ["privacy"])])
        XCTAssertEqual(hostInput.hostID, "user.alpha")
        XCTAssertEqual(hostInput.hostBoundaryAxes,
            ["financial", "legal", "privacy"],
            "ch 991 E2E: ch 986 derives sorted union")
        XCTAssertEqual(hostInput.styleStrictness, 0.75,
            accuracy: 0.001)

        // 9. Build sovereign sentinel + evolution shadow inputs
        let sentinelInput = BASSovereignSentinelInput(
            candidates: [
                BASSovereignSentinelCandidate(
                    candidateID: "c2",
                    title: "Major change",
                    reversibility: 0.1,
                    touchesSovereignLockedAxis: false)])
        let evolutionInput = BASEvolutionShadowInput(
            updateTickets: [
                BASEvolutionUpdateTicket(
                    ticketID: "tk1",
                    targetRef: "rule.x",
                    summary: "tighten",
                    scopeImpact: 0.3)])

        // 10. Memory input (simulating memoryService output)
        let memoryInput = BASMemorySeatInput(
            episodeArcs: ["arc-2026-05"],
            conflictClusters: [],
            continuityAnchors: ["anchor-1"],
            recallStrength: 0.8)

        // ===== Coordinator with 9-seat roster =====

        let traceLog = BASAgentTraceLog()
        let roster = makeNineSeatRoster()
        let fabric = BASAgentFabricRuntime(
            roster: roster,
            graph: BASSharedStateGraph(),
            traceLog: traceLog)
        let coordinator = makeCoordinator(fabric: fabric)

        // ===== Dispatch =====

        let result = await coordinator
            .runAgentFabricObservation(
                turnID: "t.e2e.1",
                decomposeFrame: frame,
                candidatePaths: candidatePaths,
                acceptedCandidateID: "c1",
                memory: memoryInput,
                critic: enrichedCriticInput,
                hostAlignment: hostInput,
                sovereignSentinel: sentinelInput,
                evolutionShadow: evolutionInput)

        // ===== Assertions on dispatch result =====

        XCTAssertNotNil(result,
            "ch 991 CRITICAL E2E: 9-seat coordinator MUST " +
            "produce a non-nil BASAgentTurnResult")
        let emitted = result?.emittedDeltas ?? []
        XCTAssertGreaterThan(emitted.count, 4,
            "ch 991 E2E: 9-seat dispatch MUST produce more " +
            "deltas than the 4-seat path (5 optional seats " +
            "now contribute)")

        // Verify each optional seat contributed
        let memoryDelta = emitted.first {
            $0.targetObjectRef.hasPrefix("memoryBundle#")
        }
        XCTAssertNotNil(memoryDelta,
            "ch 991 E2E: Memory seat MUST emit ≥1 delta")
        let criticDelta = emitted.first {
            $0.targetObjectRef.hasPrefix("critiqueField#")
        }
        XCTAssertNotNil(criticDelta,
            "ch 991 E2E: Critic seat MUST emit ≥1 delta " +
            "(superego level 0.8 from ch 988 enrichment " +
            "triggers ≥1 critique)")
        let alignmentDelta = emitted.first {
            $0.targetObjectRef.hasPrefix("alignmentField#")
        }
        XCTAssertNotNil(alignmentDelta,
            "ch 991 E2E: HostAlignment seat MUST emit ≥1 delta")
        let evolutionDelta = emitted.first {
            $0.targetObjectRef.hasPrefix("evolutionProposal#")
        }
        XCTAssertNotNil(evolutionDelta,
            "ch 991 E2E: EvolutionShadow seat MUST emit ≥1 delta " +
            "(closes ch 982.5 H1 — the 9th seat was unreachable " +
            "through coordinator before ch 985 + ch 991)")

        // ===== POST-DISPATCH: warrant audit (ch 983) =====

        let ledger = makeAuditLedger()
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
        XCTAssertTrue(warrantResult.valid)
        let appended = try await BASSovereignWarrantAuditBridge
            .appendToLedger(
                validationResult: warrantResult,
                sessionID: "sess.e2e",
                turnID: "t.e2e.1",
                externalAgentID: "ext.partner",
                ledger: ledger)
        XCTAssertEqual(appended.entry.turnID, "t.e2e.1",
            "ch 991 E2E: ch 983 warrant audit MUST land with " +
            "matching turnID")
        XCTAssertFalse(appended.entry.signature.isEmpty,
            "ch 991 E2E: ledger MUST auto-sign appended entry")

        // ===== POST-DISPATCH: trace log → event log (ch 984) =====

        let memEventLog = MemEventLog()
        let traceBridge = BASAgentTraceLogEventLogBridge(
            traceLog: traceLog,
            eventLog: memEventLog,
            sessionID: "sess.e2e")
        let flushedCount = try await traceBridge
            .flush(forTurn: "t.e2e.1")
        XCTAssertGreaterThan(flushedCount, 0,
            "ch 991 E2E: ch 984 flush MUST write ≥1 event " +
            "to event-log storage")
        let logEntries = await memEventLog
            .events(forSession: "sess.e2e")
        XCTAssertEqual(logEntries.count, flushedCount,
            "ch 991 E2E: event-log entry count MUST match " +
            "flushed count (idempotent + lossless)")

        // ===== POST-DISPATCH: candidate frontier (ch 989) =====

        let plannerCands = BASAgentFabricAdapters
            .plannerCandidates(from: candidatePaths)
        let projectedFrontier = BASAgentFabricAdapters
            .candidateFrontierProjection(
                from: plannerCands)
        XCTAssertEqual(projectedFrontier.frontierWidth, 2)
        XCTAssertEqual(
            projectedFrontier.dominanceOrder.first, "c1",
            "ch 991 E2E: ch 989 dominance order MUST place " +
            "higher-confidence candidate first")
        XCTAssertTrue(
            projectedFrontier.reversiblePaths.contains("c1"),
            "ch 991 E2E: c1 reversibility 0.95 → reversiblePaths")
        XCTAssertTrue(
            projectedFrontier.guardPaths.contains("c2"),
            "ch 991 E2E: c2 reversibility 0.1 → guardPaths")

        // ===== POST-DISPATCH: MCP permit validation (ch 990) =====

        let mcpInvocation = BASMCPInvocation(
            mcpServerID: "mcp.fs",
            toolID: "read-file",
            invocationID: "inv.1",
            rawOutput: "test",
            permitID: "p.1",
            allowedToolDomains: ["mcp.fs"],
            nowNanos: 1_000_000_000)
        let (accepted, mcpAuditRefs) = BASAgentFabricAdapters
            .validateMCPInvocation(
                mcpInvocation, against: permit)
        XCTAssertTrue(accepted,
            "ch 991 E2E: ch 990 validates allowed mcp.fs " +
            "invocation against permit")
        XCTAssertTrue(mcpAuditRefs.first?.hasPrefix(
            "agentMCP.permit:granted:") ?? false)
    }

    /// Defense:fabric in MED-RISK scenario — verify monotonic
    /// raise is composed correctly。 Card says HIGH risk; fabric
    /// risk must not LOWER the manipulation flag even after the
    /// risk seat runs。
    func testCRITICAL_MonotonicRaiseHoldsAcrossPipeline()
        async throws
    {
        let frame = BASDecomposeFrame()  // empty — no L7 signals

        let riskCard = BASRiskCard(
            totalRisk: 0.95,  // high
            riskLevel: .high,
            uncertainty: 0.5,
            irreversibility: 0.5,
            manipulationStrength: 0.85,  // strong
            gsiScore: 0.5,
            recommendedMode: .delay)

        let baseRisk = BASAgentFabricAdapters.riskInput(
            from: frame, candidates: [])
        XCTAssertEqual(baseRisk.pressureLevel, 0.0,
            "Empty L7 frame → zero pressure base")
        XCTAssertFalse(baseRisk.manipulationDetected,
            "Empty L7 frame → no base manipulation")

        let enriched = BASAgentFabricAdapters.enrichRiskInput(
            from: riskCard, baseRiskInput: baseRisk)
        XCTAssertGreaterThanOrEqual(
            enriched.pressureLevel, 0.95,
            "ch 991 CRITICAL: enrichment MUST raise empty " +
            "L7 pressure to match card's 0.95")
        XCTAssertTrue(enriched.manipulationDetected,
            "ch 991 CRITICAL: enrichment MUST flip manipulation " +
            "ON when card's manipulationStrength >= 0.5")
    }

    /// Defense:warrant audit DEAD-LETTER fix actually wires
    /// the U+001F sentinel through into the live ledger end-to-end。
    func testCRITICAL_U001F_SentinelRoundTripsThroughLedger()
        async throws
    {
        let chain = BASSovereignWarrantChain(
            hostRootWarrantID: "host-w-1",
            perAgentWarrantID: "agent-w-1",
            expiresAtNanos: 1_000_000_000_000,
            externalAgentID: "ext.alpha")
        let result = BASSovereignWarrantValidator.validate(
            chain: chain,
            forExternalAgentID: "ext.alpha",
            nowNanos: 500_000_000_000)
        XCTAssertTrue(result.valid)
        // Validator's audit refs contain the U+001F sentinel
        // per ch 981.9 + ch 982.5 C1
        XCTAssertTrue(result.auditRefs.contains { ref in
            ref.contains("\u{001F}")
        }, "ch 991 E2E: validator MUST emit U+001F sentinel " +
           "in granted ref (ch 981.9 separator)")
        // Ledger append preserves it
        let ledger = makeAuditLedger()
        let appended = try await BASSovereignWarrantAuditBridge
            .appendToLedger(
                validationResult: result,
                sessionID: "sess.1",
                turnID: "t.1",
                externalAgentID: "ext.alpha",
                ledger: ledger)
        XCTAssertTrue(appended.entry.signalRefs.contains { ref in
            ref.contains("\u{001F}")
        }, "ch 991 CRITICAL E2E: U+001F sentinel MUST survive " +
           "validator → bridge → ledger round trip unchanged " +
           "(closes ch 982.5 DEAD-LETTER + C1 cascade)")
    }

    // MARK: - Helpers

    private func makeCoordinator(
        fabric: BASAgentFabricRuntime
    ) -> BASEBrainRuntimeCoordinator {
        BASEBrainRuntimeCoordinator(
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
            agentFabric: fabric)
    }

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

    private func makeAuditLedger() -> BASSovereignAuditLedger {
        let key = SymmetricKey(size: .bits256)
        return BASSovereignAuditLedger(signingSecret: key)
    }
}

// MARK: - In-memory test event log (mirrors ch 984 test stub)

private actor MemEventLog: BASEventLogStorage {
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
