// MARK: - BASChapter638SovereignSecondaryErrorTrioProofTests
// chapter 六百三十八 / M1930 — PROOF tests for the M1929
//                              BASSovereign ledger /
//                              snapshot / sentinel error
//                              trio Codable extension
//                              (3rd post-hexa-#4 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASSovereign secondary error trio gap-fill — 3 Error
// enums covering ledger storage / snapshot manager /
// integrity sentinel domains:
//
//   BASSovereign (nested):
//     - BASSovereignLedgerSQLiteStorage.StorageError
//       (5-case nested-in-class)
//     - BASSovereignSnapshotManager.ManagerError
//       (5-case nested-in-actor)
//     - BASSovereignIntegritySentinel.SentinelError
//       (1-case nested-in-actor)
//
// THIRD post-hexa-#4 gap-fill chapter。 2nd BASSovereign
// touch overall (1st was chapter 633 sovereign-error-
// trio covering trust anchor / fingerprint store /
// token authority / host version tree)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 633 prior BASSovereign extension precedent
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1929 → M1930

import XCTest
@testable import BASSovereign

final class BASChapter638SovereignSecondaryErrorTrioProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASSovereignLedgerSQLiteStorageStorageErrorConformsToCodable() {
        assertCodable(
            BASSovereignLedgerSQLiteStorage
                .StorageError.self)
    }

    func testBASSovereignSnapshotManagerManagerErrorConformsToCodable() {
        assertCodable(
            BASSovereignSnapshotManager.ManagerError.self)
    }

    func testBASSovereignIntegritySentinelSentinelErrorConformsToCodable() {
        assertCodable(
            BASSovereignIntegritySentinel
                .SentinelError.self)
    }
}
