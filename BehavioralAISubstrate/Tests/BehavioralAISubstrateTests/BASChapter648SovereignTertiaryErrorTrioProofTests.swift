// MARK: - BASChapter648SovereignTertiaryErrorTrioProofTests
// chapter 六百四十八 / M1970 — PROOF tests for the M1969
//                              BASSovereign tertiary
//                              error trio Codable
//                              extension (6th and FINAL
//                              post-hexa-#5 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// BASSovereign tertiary error trio gap-fill — 3 Error
// enums across reboot-coordinator + verdict-engine +
// dual-key-commit subsystems:
//
//   BASSovereign (nested-in-actor):
//     - BASSovereignCleanRebootCoordinator.CoordinatorError
//       (5-case)
//     - BASSovereignVerdictEngine.EngineError (1-case)
//     - BASSovereignDualKeyCommit.SigningError (1-case)
//
// SIXTH and FINAL post-hexa-#5 gap-fill chapter。 9th
// BASSovereign touch overall。 THIRD BASSovereign error
// trio (after ch633 primary + ch638 secondary)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 642 hexa #5 catalog seal precedent
//   - chapter 633 primary + chapter 638 secondary BAS
//     Sovereign error-trio precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1969 → M1970

import XCTest
@testable import BASSovereign

final class BASChapter648SovereignTertiaryErrorTrioProofTests:
    XCTestCase
{

    func testBASSovereignCleanRebootCoordinatorCoordinatorErrorConformsToCodable() {
        // #18: real round-trip (non-CaseIterable enum, representative case)
        assertCodableRoundTrips(
            BASSovereignCleanRebootCoordinator.CoordinatorError
                .currentVersionUnknown(id: ""))
        assertCodableRoundTrips(
            BASSovereignCleanRebootCoordinator.CoordinatorError
                .verdictDoesNotRequireReboot(level: .pass))
    }

    func testBASSovereignVerdictEngineEngineErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSovereignVerdictEngine.EngineError.auditAppendFailed(""))
    }

    func testBASSovereignDualKeySigningSigningErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASSovereignDualKeySigning.SigningError
                .sameKeyIDForBothSlots(""))
    }
}
