// MARK: - BASChapter643SovereignClockTreeTypedTrioProofTests
// chapter 六百四十三 / M1950 — PROOF tests for the M1949
//                              BASSovereign clock+tree
//                              typed-trio Codable
//                              extension (1st post-hexa-
//                              #5 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASSovereign typed-trio gap-fill — MIXED enum +
// struct trio (1 enum + 2 structs) all nested in
// BASSovereign actors:
//
//   BASSovereign (nested-in-actor):
//     - BASSovereignCrossDeviceClock.Order (4-case enum)
//     - BASSovereignHostVersionTree.Node (6-field struct)
//     - BASSovereignHostVersionTree.LineagePath (5-field
//       struct)
//
// FIRST post-hexa-#5 gap-fill chapter。 4th BASSovereign
// touch overall (after ch633 primary trio,ch638
// secondary trio,ch641 ArtifactKind)。 Round out BAS
// SovereignHostVersionTree coverage:chapter 633
// extended TreeError,this chapter extends Node +
// LineagePath。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 642 hexa #5 catalog seal precedent
//   - chapter 633 prior BASSovereign HostVersionTree
//     extension precedent
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1949 → M1950

import XCTest
@testable import BASSovereign

final class BASChapter643SovereignClockTreeTypedTrioProofTests:
    XCTestCase
{

    func testBASSovereignCrossDeviceClockOrderConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSovereignCrossDeviceClock.Order.before)
    }

    func testBASSovereignHostVersionTreeNodeConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSovereignHostVersionTree.Node(
                versionID: "",
                parentID: nil,
                diffSummary: "",
                recordedAt: Date(timeIntervalSince1970: 0)))
    }

    func testBASSovereignHostVersionTreeLineagePathConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSovereignHostVersionTree.LineagePath(
                from: "",
                to: "",
                commonAncestor: nil,
                up: [],
                down: []))
    }
}
