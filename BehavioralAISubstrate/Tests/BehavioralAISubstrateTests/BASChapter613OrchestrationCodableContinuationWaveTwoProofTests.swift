// MARK: - BASChapter613OrchestrationCodableContinuationWaveTwoProofTests
// chapter 六百一十三 / M1830 — PROOF tests for the M1829
//                              BASOrchestration Codable
//                              extension continuation
//                              wave 2 (gap-fill)
//
// ## Coverage (2 compile-time conformance tests)
//
// BASOrchestration gap-fill wave 2 — 2 nested-in-actor
// inner types within BASWorldAwareRiskBridge become Codable:
//
//   - BASWorldAwareRiskBridge.ProposedIntent (7-field
//     value:sessionID + turnID + operation +
//     matchedTemplateID + consentAcknowledged +
//     baselineSignals + baselineObservations +
//     snapshotRef — 8 fields)
//   - BASWorldAwareRiskBridge.Decision (3-field value:
//     verdict + assessment + branches)
//
// All field types are already Codable (verified at
// M1829 第一刀):
//   - String / Bool (built-in)
//   - BASSovereignVerdictEngine.OperationDomain (chapter
//     606 wave 1)
//   - BASSovereignVerdictEngine.SoftSignals (chapter 612
//     wave 3)
//   - BASSovereignVerdictEngine.HardObservations (chapter
//     612 wave 3)
//   - BASSovereignVerdict (BASSchemaVersioned →
//     Codable via root protocol)
//   - BASWorldPriorRiskAssessment (Hashable, Codable,
//     Sendable)
//   - BASWorldPriorCounterfactualBranch (Hashable,
//     Codable, Sendable)
//
// SIXTH consecutive gap-fill chapter (608 + 609 + 610
// + 611 + 612 + 613) — TRIGGERS hexa catalog meta-meta
// opportunity at chapter 614 (parallel to chapter 607
// post-octa fresh-module hexa pattern)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these newly-Codable types
//   - chapter 610 BASOrchestration continuation
//     precedent (the original gap-fill wave 1)
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1829 → M1830

import XCTest
@testable import BASOrchestration

final class BASChapter613OrchestrationCodableContinuationWaveTwoProofTests:
    XCTestCase
{

    func testProposedIntentConformsToCodable() {
        // #18: real round-trip (operation .pureInference; other
        // fields defaulted — baselineSignals/.calm, .clean, "")
        assertCodableRoundTrips(
            BASWorldAwareRiskBridge.ProposedIntent(
                sessionID: "",
                turnID: "",
                operation: .pureInference,
                matchedTemplateID: ""))
    }

    func testDecisionConformsToCodable() {
        // #18: HONEST compile-time fallback — Decision requires a
        // BASSovereignVerdict + BASWorldPriorRiskAssessment, both
        // deeply-nested types not cheaply constructible here.
        assertConformsToCodableAtCompileTime(
            BASWorldAwareRiskBridge.Decision.self)
    }
}
