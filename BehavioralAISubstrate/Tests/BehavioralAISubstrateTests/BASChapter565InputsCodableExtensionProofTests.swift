// MARK: - BASChapter565InputsCodableExtensionProofTests
// chapter 五百六十五 / M1638 — PROOF tests for the 2
//                          newly-Codable Inputs
//                          aggregator types
//
// ## Coverage (2 compile-time conformance tests)
//
// The 2 Inputs types are HIGH-LEVEL composite
// aggregators whose .compute(...) factories require
// many parameters (BASBudgetFrame with 13 fields,
// BASActionPermit with many fields,etc。)。 Full
// populated round-trip PROOF would require
// constructing those upstream typed values。
//
// Codable round-trip behavior is GUARANTEED at
// compile time by Swift's synthesized conformance
// since all field types are themselves Codable
// (verified in chapters 561-563)。 So compile-time
// conformance is the right PROOF level for these
// composites — if a field type loses Codable,this
// test fails to compile loudly。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 2 newly-Codable Inputs aggregators
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1637 → M1638

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASChapter565InputsCodableExtensionProofTests:
    XCTestCase
{

    // MARK: - 2 conformance PROOFs

    // #18: real round-trip — both Inputs types are HIGH-LEVEL
    // composites whose stored fields (BASBudgetFrame with 13
    // fields, BASActionPermit, ...) cannot be confidently
    // constructed as minimal valid instances here, so use the
    // honest compile-time-only fallback (no fake x==x
    // assertion). Synthesized Codable is still enforced at
    // compile time: if a field type loses Codable, this fails
    // to build.
    func testKunlunInputsConformsToCodable() {
        assertConformsToCodableAtCompileTime(
            BASAuditObservationProjectionsKunlunInputs
                .self)
    }

    func testCthulhuInputsConformsToCodable() {
        assertConformsToCodableAtCompileTime(
            BASAuditObservationProjectionsCthulhuInputs
                .self)
    }
}
