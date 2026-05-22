// MARK: - BASChapter873AuditAggregationDeclineTests
// chapter 八百七十三 / M3031 — DECLINE-WITH-TRIGGER for the planned
// BASRoutedAuditAggregation Rust+rayon migration。
//
// Arc 871-876 plan listed this chapter as「Rust+rayon for the 3
// aggregation loops (presence,unknowns,contradictions)」 with
// expected 2-4× win at batch ≥ 100。 Chapter 八百七十三 第一刀
// measurement on Mac mini showed the Swift aggregation is
// already in the microsecond range at all production sizes:
//
//   100 records  =    37 μs
//   1K records   =   371 μs
//   5K records   = 1,848 μs (1.85 ms)
//
// FFI overhead for a Rust+rayon path is typically 50-200μs per
// call (3 separate aggregations × 3 FFI hops = ~600μs minimum
// fixed cost)。 At 100 records this fixed cost is 16× the entire
// Swift baseline。 At 1K records it's roughly equal。 At 5K
// records the Rust path could shave 30-50% off — but the
// aggregation is called ONCE PER SESSION END,not per turn,so
// absolute wall-clock savings of ~1ms per session are negligible。
//
// Per 「亏的不要硬上」 / 「整体 性能 效果 一定要 更好」 / chapter
// 八百四十九 + 八百五十六 + 八百五十七 + 八百六十二 DECLINE precedent:
// SHIP THIS DECLINE AS AN AUDIT,not the migration。
//
// Three triggers for future revisit:
//   1. Session size grows past 50K records (10× current measured)
//   2. Aggregation moves to a PER-TURN hot path (currently
//      per-session-end)
//   3. Profiler shows aggregation > 5% of session-end total time

import XCTest
@testable import BASOrchestration
@testable import BASSovereign

final class BASChapter873AuditAggregationDeclineTests:
    XCTestCase
{

    // MARK: - Decline pin

    /// The 3 BASRoutedAuditAggregation static functions exist
    /// and are pure-Swift。 They are NOT routed through Rust+rayon
    /// per chapter 八百七十三 decline。
    func testAggregationsAreSwiftNotRouted() {
        // Compile-time guard: the functions are still
        // BASRoutedAuditAggregation.aggregateXxx static methods,
        // not BASAutoRouteRanker.aggregateXxx (which would
        // indicate a Rust routing flip)。
        let presenceFn:
            ([BASPresenceObservationRecord], String) ->
                BASRoutedAuditAggregation.PresenceSessionSummary
            = BASRoutedAuditAggregation.aggregatePresence
        let unknownsFn:
            ([BASUnknownLedgerRecord], String) ->
                BASRoutedAuditAggregation.UnknownSessionSummary
            = BASRoutedAuditAggregation.aggregateUnknowns
        let contradictionsFn:
            ([BASContradictionLedgerRecord], String) ->
                BASRoutedAuditAggregation
                    .ContradictionSessionSummary
            = BASRoutedAuditAggregation.aggregateContradictions

        // Cast to Any to use them — verifies they exist + Swift-typed
        _ = presenceFn as Any
        _ = unknownsFn as Any
        _ = contradictionsFn as Any
    }

    // MARK: - Decline rationale measurement re-pin

    /// Re-measures the Swift baseline to ensure the decline
    /// remains valid。 If a future change makes Swift dramatically
    /// slower (e.g. record schema grows by 10×),this test would
    /// catch a CI signal at >10× the prior measurement,
    /// re-triggering the migration consideration。
    func testSwiftPresenceAggregationStaysFastAt5K() {
        let records = makePresenceRecords(count: 5000)
        let start = DispatchTime.now().uptimeNanoseconds
        _ = BASRoutedAuditAggregation.aggregatePresence(
            records: records, sessionID: "decline-pin")
        let end = DispatchTime.now().uptimeNanoseconds
        let ns = Double(end - start)
        // Chapter 八百七十三 第一刀 measured 1.85 ms at 5K records。
        // Pin at 5× headroom (9.25 ms) — if Swift gets 5×
        // slower,migration revisit is warranted。
        XCTAssertLessThan(ns, 9_250_000,
            "Swift aggregatePresence at 5K should stay " +
            "under 9.25 ms (= 5× the chapter 八百七十三 第一刀 " +
            "baseline of 1.85 ms)。 If this fails,the decline " +
            "rationale changed — revisit migration。")
    }

    // MARK: - Trigger documentation pin

    /// Pin the trigger array for future revisit。 If a trigger
    /// activates,the corresponding chapter that revisits this
    /// decline should reference this test。
    func testDeclineTriggersDocumented() {
        let triggers: [String] = [
            "Trigger 1: Session size routinely > 50K records " +
                "(10× the 5K measured stress case)",
            "Trigger 2: Aggregation moves to a per-turn hot " +
                "path (currently called once per session end)",
            "Trigger 3: Profiler shows aggregation > 5% of " +
                "total session-end CPU time"
        ]
        // Each trigger must be non-empty + properly formatted
        for (idx, trigger) in triggers.enumerated() {
            XCTAssertTrue(
                trigger.hasPrefix("Trigger \(idx + 1):"),
                "Trigger \(idx + 1) must be properly prefixed")
            XCTAssertGreaterThan(trigger.count, 30,
                "Trigger \(idx + 1) must have substantive " +
                "description (got \(trigger.count) chars)")
        }
        XCTAssertEqual(triggers.count, 3,
            "Chapter 八百七十三 decline pinned exactly 3 triggers")
    }

    // MARK: - Helper

    private func makePresenceRecords(
        count: Int
    ) -> [BASPresenceObservationRecord] {
        let channels = [
            "task", "risk", "manipulation",
            "environment", "bodyRhythm"
        ]
        var records: [BASPresenceObservationRecord] = []
        records.reserveCapacity(count)
        for i in 0..<count {
            let salience = Double(i % 100) / 100.0
            let confidence = Double((i * 13) % 100) / 100.0
            let obsAt = Int64(1_700_000_000_000 + i)
            let rec = BASPresenceObservationRecord(
                eventID: "evt-\(i)",
                sessionID: "decline-pin",
                turnID: "turn-\(i / 7)",
                channelKind: channels[i % channels.count],
                salience: salience,
                confidence: confidence,
                observedAtMs: obsAt)
            records.append(rec)
        }
        return records
    }
}
