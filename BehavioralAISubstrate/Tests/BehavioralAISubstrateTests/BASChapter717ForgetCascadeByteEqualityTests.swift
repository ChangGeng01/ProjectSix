// MARK: - BASChapter717ForgetCascadeByteEqualityTests
// chapter 七百十七 第一刀 / M2256
//
// SAFETY-CRITICAL test:proves that
// BASMemoryForgetCascadeRunner.apply() produces byte-IDENTICAL
// (remainingRecords, removedIDs) regardless of which partition
// path is selected by `useRoutedFilter`。
//
// Mirrors the chapter 七百十六 第三刀 chain-parity test pattern:
// build same field+cascade twice (one with each flag value),
// assert outputs match。 Both paths are O(N+M) Set/Map
// membership;byte-equality is mathematically guaranteed by
// virtue of identical partition semantics — this test pins it
// empirically across diverse cascade shapes。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter717ForgetCascadeByteEqualityTests:
    XCTestCase
{
    override func tearDown() {
        BASMemoryForgetCascadeRunner.useRoutedFilter = false
        super.tearDown()
    }

    private func makeRecord(
        _ id: String
    ) -> BASTemporalMemoryRecord {
        return BASTemporalMemoryRecord(
            memoryID: id,
            summary: "summary-\(id)",
            memoryType: .episode,
            sourceClass: "test",
            timestamp: Date(
                timeIntervalSince1970: 1_700_000_000),
            certainty: 0.8,
            evidenceStrength: 0.5,
            hostScope: "host.v1",
            sovereignScope: "sov.v1")
    }

    private func makeField(
        _ ids: [String]
    ) -> BASTemporalMemoryField {
        return BASTemporalMemoryField(
            records: ids.map { makeRecord($0) })
    }

    private func makeCascade(
        rootTargets: [String] = [],
        dependentRefs: [String] = []
    ) -> BASMemoryForgetCascade {
        return BASMemoryForgetCascade(
            cascadeID: "cascade-1",
            rootTargets: rootTargets,
            dependentRefs: dependentRefs,
            executionState:
                BASForgetCascadeExecutionState.queued.rawValue)
    }

    /// Run apply() once with each flag value;return both
    /// outcomes for comparison。
    private func runBoth(
        cascade: BASMemoryForgetCascade,
        field: BASTemporalMemoryField
    ) -> (
        legacy: (
            field: BASTemporalMemoryField,
            outcome: BASForgetCascadeOutcome),
        routed: (
            field: BASTemporalMemoryField,
            outcome: BASForgetCascadeOutcome))
    {
        let runner = BASMemoryForgetCascadeRunner()
        BASMemoryForgetCascadeRunner.useRoutedFilter = false
        let legacy = runner.apply(
            cascade, to: field,
            now: { Date(timeIntervalSince1970: 1_700_000_001) })
        BASMemoryForgetCascadeRunner.useRoutedFilter = true
        let routed = runner.apply(
            cascade, to: field,
            now: { Date(timeIntervalSince1970: 1_700_000_001) })
        return (legacy, routed)
    }

    private func assertEqual(
        _ legacy: (field: BASTemporalMemoryField,
            outcome: BASForgetCascadeOutcome),
        _ routed: (field: BASTemporalMemoryField,
            outcome: BASForgetCascadeOutcome),
        _ msg: String
    ) {
        XCTAssertEqual(
            legacy.field.records.map { $0.memoryID },
            routed.field.records.map { $0.memoryID },
            msg + " — remainingRecords IDs")
        XCTAssertEqual(
            legacy.outcome.removedRecordIDs,
            routed.outcome.removedRecordIDs,
            msg + " — removedRecordIDs")
        XCTAssertEqual(
            legacy.outcome.terminalState,
            routed.outcome.terminalState,
            msg + " — terminalState")
        XCTAssertEqual(
            legacy.outcome.reasonCodes,
            routed.outcome.reasonCodes,
            msg + " — reasonCodes")
    }

    // MARK: - Cases

    func testEmptyCascadeBothPathsFail() {
        let field = makeField(["a", "b", "c"])
        let cascade = makeCascade()
        let (legacy, routed) = runBoth(
            cascade: cascade, field: field)
        assertEqual(legacy, routed,
            "empty cascade")
        XCTAssertEqual(
            legacy.outcome.terminalState, .failed)
    }

    func testNoMatchBothPathsSkip() {
        let field = makeField(["a", "b", "c"])
        let cascade = makeCascade(
            rootTargets: ["nonexistent"])
        let (legacy, routed) = runBoth(
            cascade: cascade, field: field)
        assertEqual(legacy, routed, "no-match")
        XCTAssertEqual(
            legacy.outcome.terminalState, .skipped)
    }

    func testSingleMatch() {
        let field = makeField(["a", "b", "c", "d"])
        let cascade = makeCascade(rootTargets: ["b"])
        let (legacy, routed) = runBoth(
            cascade: cascade, field: field)
        assertEqual(legacy, routed, "single-match")
        XCTAssertEqual(
            legacy.field.records.map { $0.memoryID },
            ["a", "c", "d"])
        XCTAssertEqual(
            legacy.outcome.removedRecordIDs, ["b"])
    }

    func testMultiMatchPreservesOrder() {
        let field = makeField(["a", "b", "c", "d", "e"])
        let cascade = makeCascade(
            rootTargets: ["d"],
            dependentRefs: ["b"])
        let (legacy, routed) = runBoth(
            cascade: cascade, field: field)
        assertEqual(legacy, routed,
            "multi-match preserves order")
        XCTAssertEqual(
            legacy.outcome.removedRecordIDs, ["b", "d"],
            "removed IDs must be in record-insertion order")
    }

    func testFullRemoval() {
        let field = makeField(["x", "y", "z"])
        let cascade = makeCascade(
            rootTargets: ["x", "y", "z"])
        let (legacy, routed) = runBoth(
            cascade: cascade, field: field)
        assertEqual(legacy, routed, "full removal")
        XCTAssertTrue(legacy.field.records.isEmpty)
        XCTAssertEqual(
            legacy.outcome.removedRecordIDs.count, 3)
    }

    func testLargeCascadeFiftyRecords() {
        let recordIDs = (0..<50).map { "rec-\($0)" }
        let field = makeField(recordIDs)
        // Remove every 3rd record
        let targets = stride(from: 0, to: 50, by: 3).map {
            "rec-\($0)" }
        let cascade = makeCascade(rootTargets: targets)
        let (legacy, routed) = runBoth(
            cascade: cascade, field: field)
        assertEqual(legacy, routed, "50-record cascade")
        XCTAssertEqual(
            legacy.outcome.removedRecordIDs.count,
            targets.count)
    }

    func testUnicodeIds() {
        let field = makeField([
            "普通-id", "中文-id", "ascii-id"])
        let cascade = makeCascade(
            rootTargets: ["中文-id"])
        let (legacy, routed) = runBoth(
            cascade: cascade, field: field)
        assertEqual(legacy, routed, "unicode")
        XCTAssertEqual(
            legacy.outcome.removedRecordIDs, ["中文-id"])
    }

    func testRootAndDependentOverlap() {
        // Same ID in both rootTargets and dependentRefs —
        // both paths should dedup automatically (Swift via
        // Set,Rust via HashSet)。 The removedRecordIDs
        // list should contain the ID exactly once。
        let field = makeField(["a", "b", "c"])
        let cascade = makeCascade(
            rootTargets: ["b"],
            dependentRefs: ["b"])
        let (legacy, routed) = runBoth(
            cascade: cascade, field: field)
        assertEqual(legacy, routed,
            "root/dependent overlap")
        XCTAssertEqual(
            legacy.outcome.removedRecordIDs, ["b"])
    }
}
