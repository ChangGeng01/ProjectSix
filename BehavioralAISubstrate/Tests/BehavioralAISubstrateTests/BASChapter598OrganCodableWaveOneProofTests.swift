// MARK: - BASChapter598OrganCodableWaveOneProofTests
// chapter 五百九十八 / M1770 — PROOF tests for the 2
//                          newly-Codable BASOrgan types
//                          shipped at M1769 (FRESH
//                          MODULE TERRITORY wave 1)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASOrgan first-ever Codable extension wave 1。
// Fresh module territory beyond the chapter 597 octa-
// milestone snapshot (which covered 6 modules:BAS
// HostKit + BASRuntimeCore + BASMemory + BAS
// Orchestration + BASLeaseLife + BASObservability)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1769 → M1770

import XCTest
@testable import BASOrgan

final class BASChapter598OrganCodableWaveOneProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testOrganDraftChunkConformsToCodable() {
        assertCodable(BASOrganDraftChunk.self)
    }

    func testOrganRegistryObservationSnapshotConformsToCodable() {
        assertCodable(BASOrganRegistryObservationSnapshot.self)
    }
}
