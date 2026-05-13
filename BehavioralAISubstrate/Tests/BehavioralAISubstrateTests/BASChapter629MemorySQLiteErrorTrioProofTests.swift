// MARK: - BASChapter629MemorySQLiteErrorTrioProofTests
// chapter 六百二十九 / M1894 — PROOF tests for the M1893
//                              BASMemory SQLite storage
//                              error trio Codable
//                              extension (1st post-
//                              hexa-#3 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASMemory SQLite storage error trio gap-fill — 3
// nested-in-actor StorageError enums with structurally
// identical 6-case shape:
//
//   - BASSQLiteMemoryAtomStore.StorageError
//   - BASSQLiteUserStateStorage.StorageError
//   - BASHostConstitutionSQLiteStorage.StorageError
//
// FIRST post-hexa-#3 gap-fill chapter — begins 4th
// hexa run toward chapter 634 hexa #4 opportunity。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 628 hexa #3 precedent (most recent hexa)
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1893 → M1894

import XCTest
@testable import BASMemory

final class BASChapter629MemorySQLiteErrorTrioProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASSQLiteMemoryAtomStoreStorageErrorConformsToCodable() {
        assertCodable(
            BASSQLiteMemoryAtomStore.StorageError.self)
    }

    func testBASSQLiteUserStateStorageStorageErrorConformsToCodable() {
        assertCodable(
            BASSQLiteUserStateStorage.StorageError.self)
    }

    func testBASHostConstitutionSQLiteStorageStorageErrorConformsToCodable() {
        assertCodable(
            BASHostConstitutionSQLiteStorage.StorageError.self)
    }
}
