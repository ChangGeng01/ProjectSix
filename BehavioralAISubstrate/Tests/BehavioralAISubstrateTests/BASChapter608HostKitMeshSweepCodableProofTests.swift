// MARK: - BASChapter608HostKitMeshSweepCodableProofTests
// chapter 六百八 / M1810 — PROOF tests for the M1809
//                          BASHostKit mesh-sweep
//                          Codable extension wave 1
//
// ## Coverage (3 compile-time conformance tests)
//
// BASHostKit mesh-sweep chain Codable extension。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 3 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1809 → M1810

import XCTest
@testable import BASHostKit

final class BASChapter608HostKitMeshSweepCodableProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testHostMeshConsultationResultConformsToCodable() {
        assertCodable(BASHostMeshConsultationResult.self)
    }

    func testHostMeshSweepLayerEntryConformsToCodable() {
        assertCodable(BASHostMeshSweepLayerEntry.self)
    }

    func testHostMeshSweepResultConformsToCodable() {
        assertCodable(BASHostMeshSweepResult.self)
    }
}
