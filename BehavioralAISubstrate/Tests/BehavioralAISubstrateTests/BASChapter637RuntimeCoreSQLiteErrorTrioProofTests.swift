// MARK: - BASChapter637RuntimeCoreSQLiteErrorTrioProofTests
// chapter 六百三十七 / M1926 — PROOF tests for the M1925
//                              BASRuntimeCore SQLite
//                              storage error trio
//                              Codable extension (2nd
//                              post-hexa-#4 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASRuntimeCore SQLite storage error trio gap-fill —
// 3 nested-in-actor StorageError enums forming a
// structural triple-mirror:
//
//   BASRuntimeCore (nested-in-actor):
//     - BASSQLiteEventLogStorage.StorageError (7-case)
//     - BASSQLiteEvalRunStorage.StorageError (7-case)
//     - BASSQLiteKnowledgeGraphStorage.StorageError
//       (8-case)
//
// PARALLEL STRUCTURALLY to chapter 629 BASMemory SQLite
// triple-mirror (3 SQLite storage actors with shared
// shape)。 This chapter is the BASRuntimeCore-side
// mirror of that pattern。
//
// SECOND post-hexa-#4 gap-fill chapter。 2nd BAS
// RuntimeCore touch overall (after chapter 624 runtime-
// core-solo-enum)。 1st post-hexa-#4 BASRuntimeCore
// touch。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 635 hexa #4 catalog seal precedent
//   - chapter 629 BASMemory SQLite triple-mirror parallel
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1925 → M1926

import XCTest
@testable import BASRuntimeCore

final class BASChapter637RuntimeCoreSQLiteErrorTrioProofTests:
    XCTestCase
{

    func testBASSQLiteEventLogStorageStorageErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSQLiteEventLogStorage.StorageError
                .openFailed(code: 0, message: ""))
        assertCodableRoundTrips(
            BASSQLiteEventLogStorage.StorageError
                .corruptedRow(eventID: "", reason: ""))
    }

    func testBASSQLiteEvalRunStorageStorageErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSQLiteEvalRunStorage.StorageError
                .openFailed(code: 0, message: ""))
        assertCodableRoundTrips(
            BASSQLiteEvalRunStorage.StorageError
                .corruptedRow(runID: "", reason: ""))
    }

    func testBASSQLiteKnowledgeGraphStorageStorageErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSQLiteKnowledgeGraphStorage.StorageError
                .openFailed(code: 0, message: ""))
        assertCodableRoundTrips(
            BASSQLiteKnowledgeGraphStorage.StorageError
                .corruptedRow(id: "", reason: ""))
    }
}
