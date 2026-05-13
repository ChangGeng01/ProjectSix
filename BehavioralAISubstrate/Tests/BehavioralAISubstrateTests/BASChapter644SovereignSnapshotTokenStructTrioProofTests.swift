// MARK: - BASChapter644SovereignSnapshotTokenStructTrioProofTests
// chapter 六百四十四 / M1954 — PROOF tests for the M1953
//                              BASSovereign snapshot+
//                              token struct-trio Codable
//                              extension (2nd post-hexa-
//                              #5 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASSovereign struct-trio gap-fill — 3 BASSovereign
// struct types covering snapshot manager + token
// authority subsystems:
//
//   BASSovereign (nested-in-actor):
//     - BASSovereignSnapshotManager.SnapshotAnchor
//       (6-field)
//     - BASSovereignSnapshotManager.RegisteredSnapshot
//       (3-field,wraps SnapshotAnchor)
//     - BASSovereignTokenAuthority.CommitIntent
//       (8-field)
//
// SECOND post-hexa-#5 gap-fill chapter。 5th BAS
// Sovereign touch overall。 PURE STRUCT TRIO (chapter
// 643 was MIXED enum+struct trio)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 642 hexa #5 catalog seal precedent
//   - chapter 643 prior post-hexa-#5 (mixed) precedent
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1953 → M1954

import XCTest
@testable import BASSovereign

final class BASChapter644SovereignSnapshotTokenStructTrioProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASSovereignSnapshotManagerSnapshotAnchorConformsToCodable() {
        assertCodable(
            BASSovereignSnapshotManager
                .SnapshotAnchor.self)
    }

    func testBASSovereignSnapshotManagerRegisteredSnapshotConformsToCodable() {
        assertCodable(
            BASSovereignSnapshotManager
                .RegisteredSnapshot.self)
    }

    func testBASSovereignTokenAuthorityCommitIntentConformsToCodable() {
        assertCodable(
            BASSovereignTokenAuthority.CommitIntent.self)
    }
}
