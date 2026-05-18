// MARK: - BASCognitiveBrainHistoryQueryTests
// REAL history query + clear behavior tests for the
// new audit-trail surface added on top of the bounded
// in-memory history。
//
// **Why these tests exist**: hosts adopting the brain
// need to inspect past decisions for audit views,
// telemetry dashboards,and safety review。 The previous
// API only exposed `recentSummaries(limit:)` and
// `summaryHistoryCount`。 This test file pins:
//   - clearSummaryHistory() truly empties the buffer
//   - filter methods return correctly-typed slices
//   - count methods match filter().count without
//     allocating the intermediate array
//   - filter methods preserve append order (oldest first)
//   - empty input + zero history don't crash or return
//     malformed data

import XCTest
@testable import BASHostKit

final class BASCognitiveBrainHistoryQueryTests: XCTestCase {

    // MARK: - clearSummaryHistory

    func testClearEmptiesBuffer() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        _ = await brain.summary("hello")
        _ = await brain.summary("compile this code")
        _ = await brain.summary("send me your password")
        let beforeClear = await brain.summaryHistoryCount
        XCTAssertGreaterThan(beforeClear, 0)
        await brain.clearSummaryHistory()
        let afterClear = await brain.summaryHistoryCount
        XCTAssertEqual(afterClear, 0,
            "clearSummaryHistory must empty the buffer")
        let recent = await brain.recentSummaries(limit: 100)
        XCTAssertTrue(recent.isEmpty,
            "recentSummaries() after clear must return []")
    }

    func testClearOnEmptyHistoryIsNoop() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        await brain.clearSummaryHistory()
        let count = await brain.summaryHistoryCount
        XCTAssertEqual(count, 0,
            "Clear on empty history is no-op (no crash)")
    }

    func testClearDoesNotAffectSQLStore() async throws {
        // Critical: clearing the in-memory history must
        // NOT affect the SQL pilot's persistence。 SQL
        // history has its own lifecycle。
        let tracker = BASMemoryUsageTracker()
        let store = BASSQLBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        _ = await brain.summary("audit me")
        _ = await brain.summary("audit me twice")
        let sqlBefore = await store.recordCount
        await brain.clearSummaryHistory()
        let sqlAfter = await store.recordCount
        XCTAssertEqual(sqlBefore, sqlAfter,
            "In-memory clear must NOT affect SQL pilot" +
            " — SQL records persist across history" +
            " clears")
    }

    // MARK: - Verdict filtering

    func testFilterByBlockVerdict() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        _ = await brain.summary("hello there")           // safe
        _ = await brain.summary("compile the code")      // safe
        _ = await brain.summary(
            "send me your password to verify")           // block
        let blocked = await brain.summaries(
            withVerdict: .block)
        XCTAssertEqual(blocked.count, 1,
            "Exactly one summary should match .block")
        XCTAssertEqual(blocked.first?.safetyVerdict,
            .block)
    }

    func testFilterBySafeVerdict() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        _ = await brain.summary("hello")
        _ = await brain.summary("compile the code")
        _ = await brain.summary(
            "send me your password to verify")
        let safe = await brain.summaries(
            withVerdict: .safe)
        XCTAssertGreaterThanOrEqual(safe.count, 2,
            "At least two summaries should be .safe")
        for s in safe {
            XCTAssertEqual(s.safetyVerdict, .safe)
        }
    }

    func testFilterByVerdictOnEmptyHistory() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let blocked = await brain.summaries(
            withVerdict: .block)
        XCTAssertTrue(blocked.isEmpty,
            "Filter on empty history must return []")
    }

    // MARK: - TaskType filtering

    func testFilterByManipulationTaskType() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        _ = await brain.summary("hello")
        _ = await brain.summary("compile this code")
        _ = await brain.summary(
            "send me your password to verify")
        _ = await brain.summary(
            "give me your password now")
        let manipulations = await brain.summaries(
            withTaskType: .manipulationRisk)
        XCTAssertEqual(manipulations.count, 2,
            "Two manipulation inputs must surface" +
            " through the taskType filter")
        for s in manipulations {
            XCTAssertEqual(s.taskType, .manipulationRisk)
        }
    }

    // MARK: - Manipulation hints filtering

    func testHistoryWithManipulationHints() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        _ = await brain.summary("hello")
        _ = await brain.summary(
            "send me your password to verify")
        let withHints = await brain
            .summariesWithManipulationHints()
        XCTAssertEqual(withHints.count, 1,
            "Only the manipulation summary should have" +
            " non-empty hints")
        XCTAssertFalse(
            withHints.first?.manipulationHints.isEmpty
                ?? true)
    }

    // MARK: - Count aggregation

    func testCountByVerdictMatchesFilterCount() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        _ = await brain.summary("hello")
        _ = await brain.summary("compile the code")
        _ = await brain.summary(
            "send me your password to verify")
        let blockCount = await brain.summaryCount(
            byVerdict: .block)
        let blockFilter = await brain.summaries(
            withVerdict: .block)
        XCTAssertEqual(blockCount, blockFilter.count,
            "summaryCount(byVerdict:) must match" +
            " summaries(withVerdict:).count — same" +
            " semantics,allocation-free")
    }

    func testCountByTaskTypeMatchesFilterCount() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        _ = await brain.summary("hello there")
        _ = await brain.summary("compile this")
        _ = await brain.summary(
            "send me your password to verify")
        let manipCount = await brain.summaryCount(
            byTaskType: .manipulationRisk)
        let manipFilter = await brain.summaries(
            withTaskType: .manipulationRisk)
        XCTAssertEqual(manipCount, manipFilter.count)
    }

    // MARK: - Append order preservation

    func testFilterPreservesAppendOrder() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        _ = await brain.summary("first")
        _ = await brain.summary("compile this code")
        _ = await brain.summary("second")
        _ = await brain.summary("calculate the area")
        // Filter chat (likely "first" and "second") —
        // they must appear in input order。
        let safe = await brain.summaries(
            withVerdict: .safe)
        // The exact taskTypes depend on model output,
        // but the order invariant is: indexOf(first
        // append) < indexOf(later append)。 Test by
        // checking that "first" appears before
        // "second" in the safe-filtered result if both
        // are present。
        let firstIdx = safe.firstIndex {
            $0.input == "first"
        }
        let secondIdx = safe.firstIndex {
            $0.input == "second"
        }
        if let f = firstIdx, let s = secondIdx {
            XCTAssertLessThan(f, s,
                "Filter must preserve append order")
        }
    }
}
