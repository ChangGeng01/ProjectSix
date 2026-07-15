// MARK: - BASChapter873AuditAggregationMeasurementTests
// chapter 八百七十三 第一刀 / M3031 — measurement-first audit
// aggregation perf bench before deciding migration scope。
//
// Per 「亏的不要硬上」: before spinning up a new bas-audit-aggregator
// Rust crate + C ABI + Swift bridge,measure how heavy the current
// Swift aggregation actually is at production session sizes。 If
// Swift already completes in < 1ms at 5000 records,FFI overhead
// alone (~50μs/call) would erode any Rust gain — same scenario
// chapter 八百七十二 hit at 1K cosine corpus。
//
// 3 aggregation functions measured:
//   - aggregatePresence (sum + dedupe + count by channel)
//   - aggregateUnknowns (count by kind + dedupe + count unparseable)
//   - aggregateContradictions (resolved/unresolved + max/avg salience)
//
// Production sizes per chapter scout (agent 1):
//   - 100 records (typical session)
//   - 1000 records (large session)
//   - 5000 records (rare,multi-hour session)

import XCTest
@testable import BASOrchestration
@testable import BASSovereign

final class BASChapter873AuditAggregationMeasurementTests:
    XCTestCase
{

    private func makePresenceRecords(
        count: Int, sessionID: String
    ) -> [BASPresenceObservationRecord] {
        var records: [BASPresenceObservationRecord] = []
        records.reserveCapacity(count)
        let channels = [
            "task", "risk",
            "manipulation", "environment", "bodyRhythm"
        ]
        for i in 0..<count {
            records.append(BASPresenceObservationRecord(
                eventID: "evt-\(i)",
                sessionID: sessionID,
                turnID: "turn-\(i / 7)",
                channelKind: channels[i % channels.count],
                salience: Double(i % 100) / 100.0,
                confidence: Double((i * 13) % 100) / 100.0,
                observedAtMs: Int64(1_700_000_000_000 + i)))
        }
        return records
    }

    private func timeMedianNs(
        warmup: Int, iterations: Int,
        op: () -> Void
    ) -> Double {
        for _ in 0..<warmup { op() }
        var samples: [Double] = []
        for _ in 0..<iterations {
            let s = DispatchTime.now().uptimeNanoseconds
            op()
            let e = DispatchTime.now().uptimeNanoseconds
            samples.append(Double(e - s))
        }
        samples.sort()
        return samples[samples.count / 2]
    }

    func testPresenceAggregationCurrentSwiftPerfAt100() {
        let records = makePresenceRecords(
            count: 100, sessionID: "bench")
        let ns = timeMedianNs(
            warmup: 5, iterations: 100
        ) {
            _ = BASRoutedAuditAggregation
                .aggregatePresence(
                    records: records,
                    sessionID: "bench")
        }
        print(String(format:
            "BENCH aggregatePresence(100 records) = %.0f ns " +
            "(%.3f μs)", ns, ns / 1000.0))
        // #18: assertion — perf number alone is no oracle; assert the
        // aggregation it timed produced the exact, non-degenerate roll-up
        // derivable from the deterministic generator (100 rows, 5 channels
        // round-robin ⇒ 20 each, turnIDs = i/7 ⇒ 15 distinct turns).
        let summary100 = BASRoutedAuditAggregation.aggregatePresence(
            records: records, sessionID: "bench")
        XCTAssertGreaterThanOrEqual(ns, 0)
        XCTAssertTrue(ns.isFinite)
        XCTAssertEqual(summary100.totalObservations, 100)
        XCTAssertEqual(summary100.turnCount, 15)
        XCTAssertEqual(summary100.observationCountByChannel.count, 5)
        XCTAssertEqual(
            summary100.observationCountByChannel.values.reduce(0, +), 100)
        XCTAssertEqual(summary100.observationCountByChannel["task"], 20)
    }

    func testPresenceAggregationCurrentSwiftPerfAt1K() {
        let records = makePresenceRecords(
            count: 1000, sessionID: "bench")
        let ns = timeMedianNs(
            warmup: 5, iterations: 50
        ) {
            _ = BASRoutedAuditAggregation
                .aggregatePresence(
                    records: records,
                    sessionID: "bench")
        }
        print(String(format:
            "BENCH aggregatePresence(1K records) = %.0f ns " +
            "(%.3f μs)", ns, ns / 1000.0))
        // #18: assertion — assert the timed aggregation produced the exact,
        // non-degenerate roll-up derivable from the generator (1000 rows, 5
        // channels ⇒ 200 each, turnIDs = i/7 ⇒ (999/7)+1 = 143 turns).
        let summary1K = BASRoutedAuditAggregation.aggregatePresence(
            records: records, sessionID: "bench")
        XCTAssertGreaterThanOrEqual(ns, 0)
        XCTAssertTrue(ns.isFinite)
        XCTAssertEqual(summary1K.totalObservations, 1000)
        XCTAssertEqual(summary1K.turnCount, 143)
        XCTAssertEqual(summary1K.observationCountByChannel.count, 5)
        XCTAssertEqual(
            summary1K.observationCountByChannel.values.reduce(0, +), 1000)
        XCTAssertEqual(summary1K.observationCountByChannel["task"], 200)
    }

    func testPresenceAggregationCurrentSwiftPerfAt5K() {
        let records = makePresenceRecords(
            count: 5000, sessionID: "bench")
        let ns = timeMedianNs(
            warmup: 5, iterations: 20
        ) {
            _ = BASRoutedAuditAggregation
                .aggregatePresence(
                    records: records,
                    sessionID: "bench")
        }
        print(String(format:
            "BENCH aggregatePresence(5K records) = %.0f ns " +
            "(%.3f μs)", ns, ns / 1000.0))
        // #18: assertion — assert the timed aggregation produced the exact,
        // non-degenerate roll-up derivable from the generator (5000 rows, 5
        // channels ⇒ 1000 each, turnIDs = i/7 ⇒ (4999/7)+1 = 715 turns).
        let summary5K = BASRoutedAuditAggregation.aggregatePresence(
            records: records, sessionID: "bench")
        XCTAssertGreaterThanOrEqual(ns, 0)
        XCTAssertTrue(ns.isFinite)
        XCTAssertEqual(summary5K.totalObservations, 5000)
        XCTAssertEqual(summary5K.turnCount, 715)
        XCTAssertEqual(summary5K.observationCountByChannel.count, 5)
        XCTAssertEqual(
            summary5K.observationCountByChannel.values.reduce(0, +), 5000)
        XCTAssertEqual(summary5K.observationCountByChannel["task"], 1000)
    }
}
