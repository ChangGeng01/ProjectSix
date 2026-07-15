// MARK: - BASChapter632CrossModuleBCMHPCScheduleErrorTrioProofTests
// chapter 六百三十二 / M1906 — PROOF tests for the M1905
//                              cross-module BCM/HPC/
//                              Schedule error trio
//                              Codable extension (4th
//                              post-hexa-#3 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// Cross-module error trio gap-fill — 3 Error enums
// across 2 modules:
//
//   BASMetalSubstrate:
//     - BASBCMMetaPlasticityError
//     - BASHierarchicalPredictiveCodingError
//
//   BASLeaseLife (nested-in-actor):
//     - BASBreathScheduler.ScheduleError
//
// FOURTH post-hexa-#3 gap-fill chapter (629-632)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 628 hexa #3 + 629-631 prior post-hexa-#3
//     precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1905 → M1906

import XCTest
@testable import BASMetalSubstrate
@testable import BASLeaseLife

final class BASChapter632CrossModuleBCMHPCScheduleErrorTrioProofTests:
    XCTestCase
{

    func testBASBCMMetaPlasticityErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASBCMMetaPlasticityError.shapeMismatch(reason: ""))
    }

    func testBASHierarchicalPredictiveCodingErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASHierarchicalPredictiveCodingError.emptyLayers)
        assertCodableRoundTrips(
            BASHierarchicalPredictiveCodingError.shapeMismatch(reason: ""))
    }

    func testBASBreathSchedulerScheduleErrorConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASBreathScheduler.ScheduleError.thermalEmergencyRejectsAll)
        assertCodableRoundTrips(
            BASBreathScheduler.ScheduleError.unknownRequest(id: ""))
    }
}
