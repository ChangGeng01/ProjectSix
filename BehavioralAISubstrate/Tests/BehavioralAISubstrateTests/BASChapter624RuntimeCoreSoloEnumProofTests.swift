// MARK: - BASChapter624RuntimeCoreSoloEnumProofTests
// chapter 六百二十四 / M1874 — PROOF test for the M1873
//                              BASEventLogFailureInjection
//                              Scenario Codable extension
//                              (3rd post-hexa-#2 gap-fill)
//
// ## Coverage (1 compile-time conformance test)
//
// BASRuntimeCore solo enum gap-fill — 1 type:
//
//   - BASEventLogFailureInjectionScenario (4-case enum
//     with mixed associated values)
//
// THIRD post-hexa-#2 gap-fill chapter (622 + 623 + 624)。
// NEW kind 'runtime-core-solo-enum' distinct from chapter
// 622's 'cross-module-trio' and chapter 623's 'nested-in-
// actor-pair'。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 621 gap-fill hexa #2 precedent
//   - chapter 622/623 prior post-hexa-#2 precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1873 → M1874

import XCTest
@testable import BASRuntimeCore

final class BASChapter624RuntimeCoreSoloEnumProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASEventLogFailureInjectionScenarioConformsToCodable() {
        assertCodable(
            BASEventLogFailureInjectionScenario.self)
    }
}
