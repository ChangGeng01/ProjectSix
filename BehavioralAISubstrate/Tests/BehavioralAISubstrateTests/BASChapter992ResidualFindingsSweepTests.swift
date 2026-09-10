// MARK: - BASChapter992ResidualFindingsSweepTests
// chapter 九百九十二 / M3665 — Cross-Module Integration Arc ch11
//
// 「全面 剩余 一次性 解决掉」 — comprehensive sweep of all
// remaining MED + LOW findings from Round-9 reviewers that were
// not addressed in ch 991.5。 Closes the cascade for the arc。
//
// Covers:
//   - Reviewer 1 MED-1: enrichRiskInput defensive clamp on wrong
//     operand (FIXED in ch 992 source — now clamps merged result)
//   - Reviewer 1 MED-2: enrichCriticInput clamp test too weak
//   - Reviewer 1 MED-3: hostAlignmentInput only takes hardNoGo
//     (FIXED in ch 992 source — new includeSoftAxes flag)
//   - Reviewer 2 GAP-3: concurrent recordEvent race test
//   - Reviewer 2 GAP-4: hostAlignmentInput override clamp test
//   - Reviewer 2 GAP-5: enrichCriticInput negative-clamp test
//   - Reviewer 2 GAP-6: U+001F in agentID/deltaID actions
//   - Reviewer 2 GAP-8: synthesize empty sessionID
//   - Reviewer 2 GAP-9: diversityScore exact 0.0
//   - Reviewer 2 GAP-10: delayedPaths empty pin
//   - Reviewer 2 GAP-11: source field correctness for mixed stream

import XCTest
@testable import BASOrchestration
@testable import BASMemory
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASChapter992ResidualFindingsSweepTests:
    XCTestCase
{

    // MARK: - MED-1: enrichRiskInput merged-result clamp

    /// Pre-fix the clamp was on `card.totalRisk` (already clamped
    /// by `BASRiskCard.init`),so the clamp was dead code。 The
    /// caller's `base.pressureLevel` was NOT clamped。 Now the
    /// merged-result clamp catches out-of-range base input。
    func testCRITICAL_MED1_ClampMergedResultNotJustCard() {
        // Caller passes out-of-range base (BASRiskInput.init
        // doesn't clamp pressureLevel)
        let base = BASRiskInput(
            candidates: [],
            pressureLevel: 5.0,  // out of range
            manipulationDetected: false,
            boundaryTouched: false)
        let card = sampleCard(totalRisk: 0.3)
        let enriched = BASAgentFabricAdapters
            .enrichRiskInput(from: card, baseRiskInput: base)
        XCTAssertEqual(enriched.pressureLevel, 1.0,
            accuracy: 0.001,
            "ch 992 MED-1: out-of-range base.pressureLevel MUST " +
            "be clamped at adapter boundary。 Pre-fix clamped " +
            "only the card (which BASRiskCard.init already " +
            "clamped) — base passed through unchecked。")
    }

    // MARK: - MED-2: enrichCriticInput clamp test strengthening

    /// Replaces the weak `XCTAssertLessThanOrEqual(level, 1.0)`
    /// in ch 988 (would pass even for 0.5 from a broken impl)
    /// with exact-equality assertion。
    func testMED2_FractionVetoed_ExactlyOnePin() {
        let base = BASCriticSeatInput(
            candidates: [],
            superegoActiveLevel: 0.0)
        // All vetoed → fraction == 1.0 exactly
        let scores = [
            BASTriSelfScore(
                candidateID: "c.1",
                idScore: 0.5, egoScore: 0.5,
                superegoScore: 0.1,
                mergedScore: 0.3, veto: true),
            BASTriSelfScore(
                candidateID: "c.2",
                idScore: 0.5, egoScore: 0.5,
                superegoScore: 0.05,
                mergedScore: 0.3, veto: true),
        ]
        let enriched = BASAgentFabricAdapters
            .enrichCriticInput(
                from: scores, baseCriticInput: base)
        XCTAssertEqual(enriched.superegoActiveLevel, 1.0,
            accuracy: 0.001,
            "ch 992 MED-2: all-vetoed MUST produce exactly 1.0 " +
            "(strengthens ch 988 weak `≤1.0` assertion which " +
            "would pass even with broken 0.5 impl)")
    }

    // MARK: - MED-3 + GAP-4: hostAlignmentInput broader fields

    func testMED3_IncludeSoftAxes_UnionsAllFiveBoundaryFields() {
        let constitution = BASHostConstitution(
            hostID: "u",
            valueAxes: BASValueAxisSet(axes: ["v.1"]),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: ["h.1"],
                softCaution: ["s.1"],
                confirmRequired: ["cf.1"],
                restrictedMemoryDomains: ["rm.1"],
                restrictedToolDomains: ["rt.1"]))
        // Default false:only valueAxes + hardNoGo (2 fields)
        let narrow = BASAgentFabricAdapters
            .hostAlignmentInput(from: constitution)
        XCTAssertEqual(narrow.hostBoundaryAxes,
            ["h.1", "v.1"],
            "ch 992 MED-3: includeSoftAxes=false (default) " +
            "preserves ch 986 byte-equal narrow union")
        // True:all 5 fields
        let broad = BASAgentFabricAdapters
            .hostAlignmentInput(
                from: constitution,
                includeSoftAxes: true)
        XCTAssertEqual(broad.hostBoundaryAxes,
            ["cf.1", "h.1", "rm.1", "rt.1", "s.1", "v.1"],
            "ch 992 MED-3: includeSoftAxes=true unions all 5 " +
            "BASBoundaryVeil fields + valueAxes + sorts lex")
    }

    /// GAP-4: out-of-range override clamp at adapter boundary
    /// (caller might supply a styleStrictnessOverride from a
    /// computed measure that doesn't enforce [0,1] internally)。
    func testGAP4_StyleStrictnessOverride_OutOfRangeClampHigh() {
        let constitution = BASHostConstitution(hostID: "u")
        let input = BASAgentFabricAdapters
            .hostAlignmentInput(
                from: constitution,
                styleStrictnessOverride: 1.5)
        XCTAssertEqual(input.styleStrictness, 1.0,
            accuracy: 0.001,
            "ch 992 GAP-4: out-of-range override MUST clamp at " +
            "upper bound 1.0 (outer clamp in adapter)")
    }

    func testGAP4_StyleStrictnessOverride_OutOfRangeClampLow() {
        let constitution = BASHostConstitution(hostID: "u")
        let input = BASAgentFabricAdapters
            .hostAlignmentInput(
                from: constitution,
                styleStrictnessOverride: -0.5)
        XCTAssertEqual(input.styleStrictness, 0.0,
            accuracy: 0.001,
            "ch 992 GAP-4: negative override MUST clamp at 0.0")
    }

    // MARK: - GAP-3: concurrent recordEvent race test

    /// 50 concurrent recordEvent calls produce 50 unique
    /// eventIDs with sequence numbers [1..50] in the event log。
    /// Verifies actor isolation holds + idempotency works under
    /// concurrent load。
    func testGAP3_ConcurrentRecordEvent_AllLandUniquely()
        async throws
    {
        let trace = BASAgentTraceLog()
        let memEventLog = MemEventLog()
        let bridge = BASAgentTraceLogEventLogBridge(
            traceLog: trace,
            eventLog: memEventLog,
            sessionID: "sess.race")
        // 50 concurrent recordEvent calls
        try await withThrowingTaskGroup(
            of: Void.self
        ) { group in
            for i in 0..<50 {
                group.addTask {
                    let event = BASAgentTraceEvent(
                        turnID: "t.race",
                        createdAtNanos: Int64(i * 1_000_000),
                        kind: .deltaEmitted,
                        agentID: "agent.\(i)",
                        deltaID: "d.\(i)",
                        payloadJson: "{}")
                    _ = try await bridge.recordEvent(event)
                }
            }
            try await group.waitForAll()
        }
        let entries = await memEventLog
            .events(forSession: "sess.race")
        XCTAssertEqual(entries.count, 50,
            "ch 992 GAP-3: 50 concurrent recordEvent calls " +
            "MUST produce exactly 50 distinct event-log entries")
        let uniqueIDs = Set(entries.map { $0.eventID })
        XCTAssertEqual(uniqueIDs.count, 50,
            "ch 992 GAP-3: all eventIDs MUST be unique under " +
            "concurrent load (actor isolation holds)")
        // Sequence numbers should be dense [1..50] (assigned by
        // event log on append)
        let seqs = entries.map { $0.sequenceNumber }.sorted()
        XCTAssertEqual(seqs, (1...50).map { Int64($0) },
            "ch 992 GAP-3: sequenceNumbers MUST be dense " +
            "[1..50] (no gaps despite concurrent appends)")
    }

    // MARK: - GAP-5: enrichCriticInput negative-clamp

    /// Defensive lower-bound clamp:if caller somehow supplied
    /// a baseCriticInput with negative superegoActiveLevel,the
    /// `max()` would propagate it。 But `max(0, ...)` on the
    /// fraction-vetoed already clamps positive,and the
    /// monotonic raise might preserve a negative base。 Verify
    /// the merged result is well-formed。
    func testGAP5_NegativeBaseLevel_ClampedByMonotonicRaise() {
        // Base level negative (degenerate input)
        let base = BASCriticSeatInput(
            candidates: [],
            superegoActiveLevel: -0.5)
        let scores = [
            BASTriSelfScore(
                candidateID: "c.1",
                idScore: 0.5, egoScore: 0.5,
                superegoScore: 0.5,
                mergedScore: 0.5, veto: false),
        ]
        // 0 vetoed / 1 total = 0 fraction
        // max(-0.5, 0.0) = 0.0
        let enriched = BASAgentFabricAdapters
            .enrichCriticInput(
                from: scores, baseCriticInput: base)
        XCTAssertGreaterThanOrEqual(
            enriched.superegoActiveLevel, 0.0,
            "ch 992 GAP-5: monotonic raise of (negative base, " +
            "clamped fraction ≥ 0) MUST produce non-negative " +
            "output")
        XCTAssertEqual(enriched.superegoActiveLevel, 0.0,
            accuracy: 0.001,
            "ch 992 GAP-5: max(-0.5, 0.0) = 0.0 exact")
    }

    // MARK: - GAP-6: U+001F in agentID/deltaID action strings

    /// The ch 982.5 escape fix protects payloadJson but the
    /// trace event's actions array is built via string
    /// interpolation。 If agentID or deltaID contain U+001F (e.g.
    /// from an external-agent ID per ch 981.9 separator
    /// convention),the sentinel must survive verbatim in the
    /// synthesized event log entry's actions list。
    func testCRITICAL_GAP6_U001F_ActionsRoundTrip() {
        let event = BASAgentTraceEvent(
            sequenceNumber: 1,
            turnID: "t.1",
            createdAtNanos: 1_000,
            kind: .deltaEmitted,
            agentID: "ext.alpha\u{001F}variant",
            deltaID: "d.1\u{001F}sub",
            payloadJson: "{}")
        let entry = BASAgentTraceLogEventLogBridge
            .synthesizeEventLogEntry(
                traceEvent: event, sessionID: "s")
        // agent action contains the agentID verbatim
        let agentAction = entry.actions.first {
            $0.hasPrefix("agentTrace.agent=")
        }
        XCTAssertNotNil(agentAction)
        XCTAssertTrue(
            agentAction?.contains("\u{001F}") ?? false,
            "ch 992 GAP-6 CRITICAL: U+001F in agentID MUST " +
            "survive verbatim in agentTrace.agent action string")
        // delta action contains the deltaID verbatim
        let deltaAction = entry.actions.first {
            $0.hasPrefix("agentTrace.delta=")
        }
        XCTAssertNotNil(deltaAction)
        XCTAssertTrue(
            deltaAction?.contains("\u{001F}") ?? false,
            "ch 992 GAP-6 CRITICAL: U+001F in deltaID MUST " +
            "survive verbatim in agentTrace.delta action string")
        // memoryRefs ALSO carries deltaID with sentinel
        XCTAssertEqual(entry.memoryRefs,
            ["d.1\u{001F}sub"],
            "ch 992 GAP-6: U+001F MUST survive in memoryRefs")
    }

    // MARK: - GAP-8: synthesize empty sessionID

    func testGAP8_SynthesizeEmptySessionID_NoThrow() {
        let event = BASAgentTraceEvent(
            sequenceNumber: 1,
            turnID: "t.1",
            createdAtNanos: 1_000,
            kind: .deltaEmitted,
            agentID: "a",
            deltaID: "d",
            payloadJson: "{}")
        let entry = BASAgentTraceLogEventLogBridge
            .synthesizeEventLogEntry(
                traceEvent: event, sessionID: "")
        XCTAssertEqual(entry.sessionID, "",
            "ch 992 GAP-8: synthesize is pure-fn — empty " +
            "sessionID propagates without throw (downstream " +
            "ledger validates non-empty)")
    }

    // MARK: - GAP-9: diversityScore exact 0.0 at maximum spread

    func testGAP9_MaximumSpread_DiversityExactlyZero() {
        // Two candidates at extremes [0.0, 1.0]
        let candidates = [
            BASPlannerCandidate(
                candidateID: "a",
                title: "t",
                actionSummary: "a",
                confidence: 0.0),
            BASPlannerCandidate(
                candidateID: "b",
                title: "t",
                actionSummary: "a",
                confidence: 1.0),
        ]
        let frontier = BASAgentFabricAdapters
            .candidateFrontierProjection(from: candidates)
        // std-dev of [0.0, 1.0] = 0.5
        // normalized = min(1.0, 0.5/0.5) = 1.0
        // diversity = 1 - 1.0 = 0.0
        XCTAssertEqual(frontier.diversityScore, 0.0,
            accuracy: 0.001,
            "ch 992 GAP-9: maximum confidence spread [0.0, 1.0] " +
            "MUST produce diversity == 0.0 exact (mutation pin " +
            "for the /0.5 normalizer + 1-x inversion)")
    }

    // MARK: - GAP-10: delayedPaths empty pin

    func testGAP10_DelayedPaths_AlwaysEmpty() {
        let candidates = [
            BASPlannerCandidate(
                candidateID: "a",
                title: "t",
                actionSummary: "a",
                confidence: 0.5),
        ]
        let frontier = BASAgentFabricAdapters
            .candidateFrontierProjection(from: candidates)
        XCTAssertTrue(frontier.delayedPaths.isEmpty,
            "ch 992 GAP-10: delayedPaths classification is L11 " +
            "risk-domain semantics,not derivable from planner " +
            "output alone — projection MUST emit empty。")
    }

    // MARK: - GAP-11: source field correctness for mixed stream

    func testGAP11_E2E_MixedStream_SourceFieldPerEntry()
        async throws
    {
        let trace = BASAgentTraceLog()
        let memEventLog = MemEventLog()
        let bridge = BASAgentTraceLogEventLogBridge(
            traceLog: trace,
            eventLog: memEventLog,
            sessionID: "sess.gap11")
        // 4 agent events + 1 merge event (nil agentID)
        for i in 1...4 {
            _ = await trace.append(BASAgentTraceEvent(
                turnID: "t",
                createdAtNanos: Int64(i * 1000),
                kind: .deltaEmitted,
                agentID: "agent.\(i)",
                deltaID: "d.\(i)",
                payloadJson: "{}"))
        }
        _ = await trace.append(BASAgentTraceEvent(
            turnID: "t",
            createdAtNanos: 5000,
            kind: .mergeCompleted,
            agentID: nil,
            deltaID: nil,
            payloadJson: "{}"))
        _ = try await bridge.flush(forTurn: "t")
        let entries = await memEventLog
            .events(forSession: "sess.gap11")
        let agentSourced = entries.filter {
            ($0.source ?? "").hasPrefix("agentFabric.agent.")
        }
        let mergeSourced = entries.filter {
            $0.source == "agentFabric.merge"
        }
        XCTAssertEqual(agentSourced.count, 4,
            "ch 992 GAP-11: 4 entries MUST have agent-prefix " +
            "source (not all mapped to merge incorrectly)")
        XCTAssertEqual(mergeSourced.count, 1,
            "ch 992 GAP-11: 1 entry MUST have merge source " +
            "(nil agentID flow)")
    }

    // MARK: - Helpers

    private func sampleCard(
        totalRisk: Double,
        manipulationStrength: Double = 0.0
    ) -> BASRiskCard {
        BASRiskCard(
            totalRisk: totalRisk,
            riskLevel: .medium,
            uncertainty: 0.5,
            irreversibility: 0.5,
            manipulationStrength: manipulationStrength,
            gsiScore: 0.5,
            recommendedMode: .answer)
    }
}

// MARK: - In-memory event log (mirrors ch 984/991 stubs)

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
