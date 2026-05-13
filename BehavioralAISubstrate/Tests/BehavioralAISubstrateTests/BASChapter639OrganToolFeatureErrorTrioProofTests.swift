// MARK: - BASChapter639OrganToolFeatureErrorTrioProofTests
// chapter 六百三十九 / M1934 — PROOF tests for the M1933
//                              organ/tool/feature-builder
//                              error trio Codable
//                              extension (4th post-hexa-
//                              #4 gap-fill)
//
// ## Coverage (3 compile-time conformance tests)
//
// Cross-module error trio gap-fill — 3 Error enums
// across 2 modules covering organ registry / tool
// calling / feature ref building domains:
//
//   BASOrgan:
//     - BASOrganRegistry.RegistryError (2-case nested-
//       in-actor)
//     - BASToolCallingPlanError (3-case top-level)
//
//   BASAppleAdapters:
//     - BASChengluFeatureRefBuilderError (1-case
//       top-level)
//
// FOURTH post-hexa-#4 gap-fill chapter。 2nd BASOrgan
// touch overall (after chapter 634 organ-observability-
// orchestration) + 3rd BASAppleAdapters touch overall
// (after chapter 627 cross-module-error-trio + chapter
// 636 world-prior-coreml)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends
//   - chapter 634 prior BASOrgan extension precedent
//   - chapter 636 prior BASAppleAdapters extension
//     precedent
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1933 → M1934

import XCTest
@testable import BASOrgan
@testable import BASAppleAdapters

final class BASChapter639OrganToolFeatureErrorTrioProofTests:
    XCTestCase
{

    private func assertCodable<T: Codable>(_ type: T.Type) {
        XCTAssertEqual(
            String(describing: type),
            String(describing: type))
    }

    func testBASOrganRegistryRegistryErrorConformsToCodable() {
        assertCodable(
            BASOrganRegistry.RegistryError.self)
    }

    func testBASToolCallingPlanErrorConformsToCodable() {
        assertCodable(BASToolCallingPlanError.self)
    }

    func testBASChengluFeatureRefBuilderErrorConformsToCodable() {
        assertCodable(
            BASChengluFeatureRefBuilderError.self)
    }
}
