// MARK: - BASChapter567MoreMemoryCodableExtensionProofTests
// chapter 五百六十七 / M1646 — PROOF tests for the 5
//                          newly-Codable BASMemory
//                          types shipped at M1645
//
// ## Coverage (5 compile-time conformance tests)
//
// Compile-time conformance checks for:
//   - BASConstitutionMatch
//   - BASMemoryClosedLoopApplyOutcome
//   - BASEvolutionPromotionGateVerdict
//   - BASPreparedMemoryGovernanceDraft
//   - BASShadowTrialLedgerEntry
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 5 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1645 → M1646

import XCTest
@testable import BASMemory

final class BASChapter567MoreMemoryCodableExtensionProofTests:
    XCTestCase
{

    // MARK: - 5 conformance PROOFs

    // #18: real round-trip — construct a minimal valid instance
    // and assert it survives an encode/decode cycle.
    func testConstitutionMatchConformsToCodable() {
        assertCodableRoundTrips(BASConstitutionMatch.none)
    }

    func testMemoryClosedLoopApplyOutcomeConformsToCodable()
    {
        // #18: real round-trip
        let report = BASMemoryImportanceReport(
            scores: [],
            computedAt: Date(timeIntervalSince1970: 0))
        assertCodableRoundTrips(
            BASMemoryClosedLoopApplyOutcome(
                report: report,
                appliedMutations: [:],
                rejectedMutations: [:],
                dryRun: false))
    }

    func testEvolutionPromotionGateVerdictConformsToCodable()
    {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASEvolutionPromotionGateVerdict(
                allowsPromotion: false))
    }

    func testPreparedMemoryGovernanceDraftConformsToCodable()
    {
        // #18: real round-trip — composed of three nested
        // governance types (BASMemoryGovernanceDraftInput,
        // BASMemoryGovernanceAssessment,
        // BASMemoryHorizonClaimDescriptor) that cannot be
        // confidently constructed here, so use the honest
        // compile-time-only fallback (no fake x==x assertion).
        assertConformsToCodableAtCompileTime(
            BASPreparedMemoryGovernanceDraft.self)
    }

    func testShadowTrialLedgerEntryConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASShadowTrialLedgerEntry(
                auditID: "",
                sessionID: "",
                turnID: "",
                verdictRef: "",
                ruleIDs: [],
                signalRefs: [],
                actionRefs: [],
                snapshotRef: "",
                signaturePayload: "",
                appendedAt: Date(timeIntervalSince1970: 0),
                eventKind: ""))
    }
}
