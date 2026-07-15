// MARK: - BASChapter641CategorizationEnumTrioProofTests
// chapter 六百四十一 / M1942 — PROOF tests for the M1941
//                              categorization-enum trio
//                              Codable extension (6th
//                              post-hexa-#4 FINAL gap-
//                              fill — last before hexa
//                              #5 catalog opportunity)
//
// ## Coverage (3 compile-time conformance tests)
//
// Cross-module categorization enum trio gap-fill —
// 3 non-Error "kind / strategy" enums spanning 2
// modules:
//
//   BASSovereign (nested-in-actor):
//     - BASSovereignIntegritySentinel.ArtifactKind
//       (5-case String enum,maps BR-01..BR-07)
//     - BASSovereignContaminationGuard.ArtifactKind
//       (4-case String enum)
//
//   BASOrgan (nested-in-actor):
//     - BASRoutingOrganAdapter.Strategy (3-case)
//
// SIXTH and FINAL post-hexa-#4 gap-fill chapter。 SECOND
// non-Error-trio in the post-hexa-#4 run (after chapter
// 640 runtime-step-enum-trio)。 3rd BASSovereign touch
// overall + 4th BASOrgan touch overall。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 635 hexa #4 catalog seal precedent
//   - chapter 640 prior non-Error-trio precedent
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1941 → M1942

import XCTest
@testable import BASSovereign
@testable import BASOrgan

final class BASChapter641CategorizationEnumTrioProofTests:
    XCTestCase
{

    // #18 测试诚实 (2026-07-08): real encode→decode→re-encode round-trips replace the old
    // XCTAssertEqual(describing, describing) tautology. CaseIterable enums round-trip every
    // case; the non-CaseIterable Strategy round-trips a representative case.

    func testBASSovereignIntegritySentinelArtifactKindRoundTrips() {
        assertCodableRoundTripsAllCases(
            BASSovereignIntegritySentinel.ArtifactKind.self)
    }

    func testBASSovereignContaminationGuardArtifactKindRoundTrips() {
        assertCodableRoundTripsAllCases(
            BASSovereignContaminationGuard.ArtifactKind.self)
    }

    func testBASRoutingOrganAdapterStrategyRoundTrips() {
        assertCodableRoundTrips(BASRoutingOrganAdapter.Strategy.primaryWithFallback)
        assertCodableRoundTrips(BASRoutingOrganAdapter.Strategy.primaryOnly)
        assertCodableRoundTrips(BASRoutingOrganAdapter.Strategy.secondaryOnly)
    }
}
