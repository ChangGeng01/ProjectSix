// MARK: - BASChapter646SovereignTrustRecordTrioProofTests
// chapter 六百四十六 / M1962 — PROOF tests for the M1961
//                              BASSovereign trust-record
//                              trio Codable extension
//                              (4th post-hexa-#5 gap-
//                              fill,multi-actor trio)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASSovereign multi-actor trio gap-fill — 3 struct
// types spanning 3 different BASSovereign actors:
//
//   BASSovereign (nested across 3 actors):
//     - BASSovereignIntegritySentinel.ArtifactClaim
//       (uses ArtifactKind from ch641)
//     - BASSovereignAuditLedger.AppendedEntry (wraps
//       BASSovereignAuditEntry — Codable via BAS
//       SchemaVersioned protocol)
//     - BASSovereignTokenAuthority.WarrantIntent (uses
//       BASSovereignCommitScope already Codable)
//
// FOURTH post-hexa-#5 gap-fill chapter。 7th BAS
// Sovereign touch overall。 MULTI-ACTOR trio (chapter
// 645 was single-actor deep-coverage)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 642 hexa #5 catalog seal precedent
//   - chapter 645 prior post-hexa-#5 precedent
//   - chapter 641 prior ArtifactKind Codable extension
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1961 → M1962

import XCTest
@testable import BASSovereign

final class BASChapter646SovereignTrustRecordTrioProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASSovereignIntegritySentinelArtifactClaimConformsToCodable() {
        assertCodable(
            BASSovereignIntegritySentinel
                .ArtifactClaim.self)
    }

    func testBASSovereignAuditLedgerAppendedEntryConformsToCodable() {
        assertCodable(
            BASSovereignAuditLedger.AppendedEntry.self)
    }

    func testBASSovereignTokenAuthorityWarrantIntentConformsToCodable() {
        assertCodable(
            BASSovereignTokenAuthority.WarrantIntent.self)
    }
}
