// MARK: - BASChapter618OrganCodableWaveFiveProofTests
// chapter 六百一十八 / M1850 — PROOF tests for the M1849
//                              BASOrgan Codable
//                              extension wave 5
//                              (gap-fill,2 sibling
//                              enums)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASOrgan gap-fill wave 5 — 2 sibling enums:
//
//   - BASFoundationModelsToolBridgeStatus (3-case
//     enum with associated values:audited(traceID),
//     bridgedRuntimeSchema(toolCount),
//     bridgedCompiledGenerable(toolCount))
//   - BASToolInvocationDecision (2-case enum:allow
//     + reject(reasonCodes:[String]))
//
// FOURTH post-hexa-catalog gap-fill chapter (615 +
// 616 + 617 + 618)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 614 gap-fill hexa catalog precedent
//   - chapter 615/616/617 prior post-hexa precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1849 → M1850

import XCTest
@testable import BASOrgan

final class BASChapter618OrganCodableWaveFiveProofTests:
    XCTestCase
{

    func testBASFoundationModelsToolBridgeStatusConformsToCodable() {
        // #18: real round-trip (non-CaseIterable enum, representative cases)
        assertCodableRoundTrips(
            BASFoundationModelsToolBridgeStatus.audited(traceID: ""))
        assertCodableRoundTrips(
            BASFoundationModelsToolBridgeStatus
                .bridgedRuntimeSchema(toolCount: 0))
    }

    func testBASToolInvocationDecisionConformsToCodable() {
        // #18: real round-trip (non-CaseIterable enum, both cases)
        assertCodableRoundTrips(BASToolInvocationDecision.allow)
        assertCodableRoundTrips(
            BASToolInvocationDecision.reject(reasonCodes: []))
    }
}
