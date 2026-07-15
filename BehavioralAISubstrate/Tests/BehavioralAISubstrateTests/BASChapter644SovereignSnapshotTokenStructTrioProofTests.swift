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
import Foundation
@testable import BASSovereign
@testable import BASRuntimeCore

final class BASChapter644SovereignSnapshotTokenStructTrioProofTests:
    XCTestCase
{

    func testBASSovereignSnapshotManagerSnapshotAnchorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSovereignSnapshotManager.SnapshotAnchor(
                anchorID: "",
                safeSnapshotRef: "",
                integrityHash: ""))
    }

    func testBASSovereignSnapshotManagerRegisteredSnapshotConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSovereignSnapshotManager.RegisteredSnapshot(
                anchor: BASSovereignSnapshotManager.SnapshotAnchor(
                    anchorID: "",
                    safeSnapshotRef: "",
                    integrityHash: ""),
                payloadHash: "",
                registeredAt: Date(timeIntervalSince1970: 0)))
    }

    func testBASSovereignTokenAuthorityCommitIntentConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSovereignTokenAuthority.CommitIntent(
                sessionID: "",
                turnID: "",
                scope: .toolRead,
                allowedTargets: [],
                actionDigest: "",
                snapshotRef: ""))
    }
}
