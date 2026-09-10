// MARK: - BASHostStorageInitialAtomAdmitFailureLogTests
// chapter 五百三十六 / M1523 — PROOF tests for the typed
//                              observability sink
//                              shipped at M1521 + wired
//                              at M1522

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASHostStorageInitialAtomAdmitFailureLogTests:
    XCTestCase
{

    // MARK: - Empty state

    func testFreshLogHasZeroRecords() async {
        let log = BASHostStorageInitialAtomAdmitFailureLog()
        let count = await log.recordedCount
        XCTAssertEqual(count, 0,
            "Newly-constructed log must have 0 records")
        let snapshot = await log.snapshot()
        XCTAssertTrue(snapshot.isEmpty,
            "Newly-constructed log snapshot must be empty")
    }

    // MARK: - Recording

    func testRecordAppendsSingleFailure() async {
        let fixedDate = Date(timeIntervalSince1970: 1700)
        let log = BASHostStorageInitialAtomAdmitFailureLog(
            clock: { fixedDate })
        let atomID = UUID(uuidString:
            "00000000-0000-4000-8000-000000000001")!
        struct FakeError: Error, Equatable {}
        await log.record(
            atomID: atomID,
            error: FakeError())
        let count = await log.recordedCount
        XCTAssertEqual(count, 1)
        let snapshot = await log.snapshot()
        XCTAssertEqual(snapshot.count, 1)
        XCTAssertEqual(snapshot[0].atomID, atomID)
        XCTAssertEqual(snapshot[0].recordedAt, fixedDate)
        XCTAssertTrue(
            snapshot[0].errorMessage.contains("FakeError"),
            "errorMessage must capture the error " +
            "via String(describing:)")
    }

    func testMultipleRecordsArePreservedInOrder() async {
        // Single fixed date keeps the @Sendable closure
        // pure;chronological-order PROOF comes from
        // record insertion order in `records: [...]`。
        let fixedDate = Date(timeIntervalSince1970: 1700)
        let log = BASHostStorageInitialAtomAdmitFailureLog(
            clock: { fixedDate })
        struct E1: Error {}
        struct E2: Error {}
        let id1 = UUID(uuidString:
            "00000000-0000-4000-8000-000000000001")!
        let id2 = UUID(uuidString:
            "00000000-0000-4000-8000-000000000002")!
        await log.record(atomID: id1, error: E1())
        await log.record(atomID: id2, error: E2())
        let snapshot = await log.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot[0].atomID, id1)
        XCTAssertEqual(snapshot[1].atomID, id2)
        XCTAssertEqual(snapshot[0].recordedAt, fixedDate)
        XCTAssertEqual(snapshot[1].recordedAt, fixedDate)
    }

    // MARK: - Record value semantics

    func testRecordEqualityHoldsForIdenticalFields() {
        let now = Date(timeIntervalSince1970: 2000)
        let id = UUID(uuidString:
            "00000000-0000-4000-8000-000000000003")!
        let a = BASHostStorageInitialAtomAdmitFailureRecord(
            atomID: id,
            errorMessage: "msg",
            recordedAt: now)
        let b = BASHostStorageInitialAtomAdmitFailureRecord(
            atomID: id,
            errorMessage: "msg",
            recordedAt: now)
        XCTAssertEqual(a, b)
    }

    func testRecordInequalityWhenAtomIDDiffers() {
        let now = Date(timeIntervalSince1970: 2000)
        let a = BASHostStorageInitialAtomAdmitFailureRecord(
            atomID: UUID(),
            errorMessage: "msg",
            recordedAt: now)
        let b = BASHostStorageInitialAtomAdmitFailureRecord(
            atomID: UUID(),
            errorMessage: "msg",
            recordedAt: now)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Codable round-trip

    func testRecordIsCodableRoundTrip() throws {
        let original =
            BASHostStorageInitialAtomAdmitFailureRecord(
                atomID: UUID(uuidString:
                    "00000000-0000-4000-8000-000000000004")!,
                errorMessage: "round-trip",
                recordedAt: Date(timeIntervalSince1970: 5000))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASHostStorageInitialAtomAdmitFailureRecord.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Sendable concurrency PROOF

    func testConcurrentRecordingProducesAllEntries() async {
        let log = BASHostStorageInitialAtomAdmitFailureLog()
        struct E: Error {}
        let total = 50
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<total {
                let id = UUID(uuidString: String(
                    format:
                        "00000000-0000-4000-8000-%012d",
                    i))!
                group.addTask {
                    await log.record(
                        atomID: id, error: E())
                }
            }
        }
        let count = await log.recordedCount
        XCTAssertEqual(count, total,
            "Actor isolation must preserve every " +
            "concurrent record() call")
    }
}
