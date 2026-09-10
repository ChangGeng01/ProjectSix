// MARK: - BASTurnRuntimeEngineObservationFailureLogTests
// chapter 五百三十七 / M1527 — PROOF tests for the typed
//                              engine observation
//                              failure log shipped at
//                              M1525 + wired at M1526

import XCTest
@testable import BASHostKit

final class BASTurnRuntimeEngineObservationFailureLogTests:
    XCTestCase
{

    // MARK: - Empty state

    func testFreshLogHasZeroRecords() async {
        let log = BASTurnRuntimeEngineObservationFailureLog()
        let count = await log.recordedCount
        XCTAssertEqual(count, 0)
        let snapshot = await log.snapshot()
        XCTAssertTrue(snapshot.isEmpty)
    }

    // MARK: - Kind enum

    func testKindEnumHasFourCases() {
        XCTAssertEqual(
            BASTurnRuntimeEngineObservationFailureKind
                .allCases.count,
            4,
            "4 silent-swallow paths in the engine,one " +
            "Kind case per path")
    }

    func testKindRawValuesAreStable() {
        XCTAssertEqual(
            BASTurnRuntimeEngineObservationFailureKind
                .biomimeticObserverObserve.rawValue,
            "biomimeticObserverObserve")
        XCTAssertEqual(
            BASTurnRuntimeEngineObservationFailureKind
                .autoCheckpointEventLogAppend.rawValue,
            "autoCheckpointEventLogAppend")
        XCTAssertEqual(
            BASTurnRuntimeEngineObservationFailureKind
                .nativeStageDispatchEventLogAppend.rawValue,
            "nativeStageDispatchEventLogAppend")
        XCTAssertEqual(
            BASTurnRuntimeEngineObservationFailureKind
                .planAssignmentEventLogAppend.rawValue,
            "planAssignmentEventLogAppend")
    }

    // MARK: - Recording

    func testRecordCapturesAllFields() async {
        let fixedDate = Date(timeIntervalSince1970: 9999)
        let log = BASTurnRuntimeEngineObservationFailureLog(
            clock: { fixedDate })
        struct FakeError: Error {}
        await log.record(
            kind: .biomimeticObserverObserve,
            error: FakeError(),
            sessionID: "sess-A")
        let snapshot = await log.snapshot()
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertEqual(
            snapshot[0].kind,
            .biomimeticObserverObserve)
        XCTAssertEqual(snapshot[0].sessionID, "sess-A")
        XCTAssertEqual(snapshot[0].recordedAt, fixedDate)
        XCTAssertTrue(
            snapshot[0].errorMessage.contains("FakeError"))
    }

    func testRecordAcceptsNilSessionID() async {
        let log = BASTurnRuntimeEngineObservationFailureLog()
        struct E: Error {}
        await log.record(
            kind: .autoCheckpointEventLogAppend,
            error: E(),
            sessionID: nil)
        let snapshot = await log.snapshot()
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertNil(snapshot[0].sessionID)
    }

    // MARK: - Per-kind count

    func testRecordedCountPerKindFiltersCorrectly() async {
        let log = BASTurnRuntimeEngineObservationFailureLog()
        struct E: Error {}
        await log.record(
            kind: .biomimeticObserverObserve,
            error: E(),
            sessionID: nil)
        await log.record(
            kind: .biomimeticObserverObserve,
            error: E(),
            sessionID: nil)
        await log.record(
            kind: .planAssignmentEventLogAppend,
            error: E(),
            sessionID: nil)
        let biomimeticCount = await log.recordedCount(
            of: .biomimeticObserverObserve)
        let planCount = await log.recordedCount(
            of: .planAssignmentEventLogAppend)
        let dispatchCount = await log.recordedCount(
            of: .nativeStageDispatchEventLogAppend)
        XCTAssertEqual(biomimeticCount, 2)
        XCTAssertEqual(planCount, 1)
        XCTAssertEqual(dispatchCount, 0)
    }

    // MARK: - Value semantics

    func testRecordEqualityHoldsForIdenticalFields() {
        let now = Date(timeIntervalSince1970: 7000)
        let a =
            BASTurnRuntimeEngineObservationFailureRecord(
                kind: .planAssignmentEventLogAppend,
                errorMessage: "err-A",
                sessionID: "sess-1",
                recordedAt: now)
        let b =
            BASTurnRuntimeEngineObservationFailureRecord(
                kind: .planAssignmentEventLogAppend,
                errorMessage: "err-A",
                sessionID: "sess-1",
                recordedAt: now)
        XCTAssertEqual(a, b)
    }

    // MARK: - Codable round-trip

    func testRecordIsCodableRoundTrip() throws {
        let original =
            BASTurnRuntimeEngineObservationFailureRecord(
                kind: .nativeStageDispatchEventLogAppend,
                errorMessage: "round-trip",
                sessionID: "sess-X",
                recordedAt: Date(timeIntervalSince1970: 4000))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASTurnRuntimeEngineObservationFailureRecord.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Sendable concurrency PROOF

    func testConcurrentRecordingPreservesAllEntries()
        async
    {
        let log = BASTurnRuntimeEngineObservationFailureLog()
        struct E: Error {}
        let total = 40
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<total {
                let kind:
                    BASTurnRuntimeEngineObservationFailureKind
                    = i.isMultiple(of: 2)
                    ? .biomimeticObserverObserve
                    : .planAssignmentEventLogAppend
                group.addTask {
                    await log.record(
                        kind: kind,
                        error: E(),
                        sessionID: "sess-\(i)")
                }
            }
        }
        let count = await log.recordedCount
        XCTAssertEqual(count, total)
        let biomimeticHalf = await log.recordedCount(
            of: .biomimeticObserverObserve)
        let planHalf = await log.recordedCount(
            of: .planAssignmentEventLogAppend)
        XCTAssertEqual(biomimeticHalf, total / 2)
        XCTAssertEqual(planHalf, total / 2)
    }
}
