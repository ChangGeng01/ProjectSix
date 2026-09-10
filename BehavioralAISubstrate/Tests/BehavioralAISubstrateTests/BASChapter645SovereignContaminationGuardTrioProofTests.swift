// MARK: - BASChapter645SovereignContaminationGuardTrioProofTests
// chapter 六百四十五 / M1958 — PROOF tests for the M1957
//                              BASSovereign contamination-
//                              guard trio Codable
//                              extension (3rd post-hexa-
//                              #5 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASSovereign deep-coverage trio gap-fill — 3 struct
// types all nested in BASSovereignContaminationGuard
// actor:
//
//   BASSovereign (BASSovereignContaminationGuard
//   nested):
//     - Key (2-field struct,uses ArtifactKind already
//       Codable from ch641)
//     - QuarantineRecord (4-field struct,wraps Key
//       — recursive proof)
//     - ProbeReport (2 [String] fields + computed)
//
// THIRD post-hexa-#5 gap-fill chapter。 6th BASSovereign
// touch overall。 DEEP-COVERAGE trio — all 3 types in
// the same actor,completing BASSovereignContamination
// Guard's typed-surface Codable coverage。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 642 hexa #5 catalog seal precedent
//   - chapter 643 + 644 prior post-hexa-#5 precedents
//   - chapter 641 prior ArtifactKind Codable extension
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1957 → M1958

import XCTest
import Foundation
@testable import BASSovereign

final class BASChapter645SovereignContaminationGuardTrioProofTests:
    XCTestCase
{

    func testBASSovereignContaminationGuardKeyConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSovereignContaminationGuard.Key(
                id: "", kind: .memoryAtom))
    }

    func testBASSovereignContaminationGuardQuarantineRecordConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSovereignContaminationGuard.QuarantineRecord(
                key: BASSovereignContaminationGuard.Key(
                    id: "", kind: .memoryAtom),
                reasonCode: "",
                originatingVerdictID: nil,
                quarantinedAt: Date(timeIntervalSince1970: 0)))
    }

    func testBASSovereignContaminationGuardProbeReportConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSovereignContaminationGuard.ProbeReport(
                quarantinedIDs: [], cleanIDs: []))
    }
}
