// MARK: - BASAuditEmissionFailureLogTests
// chapter 五百三十九 / M1535 — PROOF tests for the
//                              cross-module typed
//                              observability sink
//                              shipped at M1533 + wired
//                              at M1534

import XCTest
@testable import BASRuntimeCore

final class BASAuditEmissionFailureLogTests:
    XCTestCase
{

    // MARK: - Empty state

    func testFreshLogHasZeroRecords() async {
        let log = BASAuditEmissionFailureLog()
        let count = await log.recordedCount
        XCTAssertEqual(count, 0)
        let snapshot = await log.snapshot()
        XCTAssertTrue(snapshot.isEmpty)
    }

    // MARK: - Kind enum

    func testKindEnumHasTwoCases() {
        XCTAssertEqual(
            BASAuditEmissionFailureKind
                .allCases.count,
            2,
            "2 documented audit-emission silent-swallow " +
            "paths = 2 Kind cases (turnEnvelopeAppend + " +
            "sovereignRebootAuditAppend)")
    }

    func testKindRawValuesAreStable() {
        XCTAssertEqual(
            BASAuditEmissionFailureKind
                .turnEnvelopeAppend.rawValue,
            "turnEnvelopeAppend")
        XCTAssertEqual(
            BASAuditEmissionFailureKind
                .sovereignRebootAuditAppend.rawValue,
            "sovereignRebootAuditAppend")
    }

    // MARK: - Recording

    func testRecordCapturesAllFields() async {
        let fixedDate = Date(timeIntervalSince1970: 5500)
        let log = BASAuditEmissionFailureLog(
            clock: { fixedDate })
        struct FakeError: Error {}
        await log.record(
            kind: .turnEnvelopeAppend,
            error: FakeError(),
            turnID: "turn-Z",
            sessionID: "sess-Q")
        let snapshot = await log.snapshot()
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertEqual(snapshot[0].kind,
            .turnEnvelopeAppend)
        XCTAssertEqual(snapshot[0].turnID, "turn-Z")
        XCTAssertEqual(snapshot[0].sessionID, "sess-Q")
        XCTAssertEqual(snapshot[0].recordedAt, fixedDate)
        XCTAssertTrue(
            snapshot[0].errorMessage.contains("FakeError"))
    }

    func testRecordAcceptsNilTurnAndSessionIDs() async {
        let log = BASAuditEmissionFailureLog()
        struct E: Error {}
        await log.record(
            kind: .sovereignRebootAuditAppend,
            error: E(),
            turnID: nil,
            sessionID: nil)
        let snapshot = await log.snapshot()
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertNil(snapshot[0].turnID)
        XCTAssertNil(snapshot[0].sessionID)
    }

    // MARK: - Per-kind count

    func testRecordedCountPerKindFiltersCorrectly() async {
        let log = BASAuditEmissionFailureLog()
        struct E: Error {}
        await log.record(
            kind: .turnEnvelopeAppend,
            error: E(),
            turnID: "t1", sessionID: "s")
        await log.record(
            kind: .turnEnvelopeAppend,
            error: E(),
            turnID: "t2", sessionID: "s")
        await log.record(
            kind: .turnEnvelopeAppend,
            error: E(),
            turnID: "t3", sessionID: "s")
        await log.record(
            kind: .sovereignRebootAuditAppend,
            error: E(),
            turnID: "tR", sessionID: "s")
        let envelopeCount = await log.recordedCount(
            of: .turnEnvelopeAppend)
        let rebootCount = await log.recordedCount(
            of: .sovereignRebootAuditAppend)
        XCTAssertEqual(envelopeCount, 3)
        XCTAssertEqual(rebootCount, 1)
    }

    // MARK: - Value semantics

    func testRecordEqualityHoldsForIdenticalFields() {
        let now = Date(timeIntervalSince1970: 3300)
        let a = BASAuditEmissionFailureRecord(
            kind: .turnEnvelopeAppend,
            errorMessage: "err",
            turnID: "tA",
            sessionID: "sA",
            recordedAt: now)
        let b = BASAuditEmissionFailureRecord(
            kind: .turnEnvelopeAppend,
            errorMessage: "err",
            turnID: "tA",
            sessionID: "sA",
            recordedAt: now)
        XCTAssertEqual(a, b)
    }

    func testRecordInequalityWhenKindDiffers() {
        let now = Date(timeIntervalSince1970: 3300)
        let a = BASAuditEmissionFailureRecord(
            kind: .turnEnvelopeAppend,
            errorMessage: "err",
            turnID: "tA", sessionID: "sA",
            recordedAt: now)
        let b = BASAuditEmissionFailureRecord(
            kind: .sovereignRebootAuditAppend,
            errorMessage: "err",
            turnID: "tA", sessionID: "sA",
            recordedAt: now)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Codable round-trip

    func testRecordIsCodableRoundTrip() throws {
        let original = BASAuditEmissionFailureRecord(
            kind: .sovereignRebootAuditAppend,
            errorMessage: "round-trip-msg",
            turnID: "tX",
            sessionID: "sX",
            recordedAt: Date(timeIntervalSince1970: 6000))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASAuditEmissionFailureRecord.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Sendable concurrency PROOF

    func testConcurrentRecordingPreservesAllEntries()
        async
    {
        let log = BASAuditEmissionFailureLog()
        struct E: Error {}
        let total = 30
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<total {
                let kind: BASAuditEmissionFailureKind =
                    i.isMultiple(of: 3)
                    ? .sovereignRebootAuditAppend
                    : .turnEnvelopeAppend
                group.addTask {
                    await log.record(
                        kind: kind,
                        error: E(),
                        turnID: "t-\(i)",
                        sessionID: "s")
                }
            }
        }
        let count = await log.recordedCount
        XCTAssertEqual(count, total)
        let rebootCount = await log.recordedCount(
            of: .sovereignRebootAuditAppend)
        let envelopeCount = await log.recordedCount(
            of: .turnEnvelopeAppend)
        XCTAssertEqual(
            rebootCount + envelopeCount,
            total,
            "Sum across kinds must equal total")
    }
}
