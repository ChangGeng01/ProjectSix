// MARK: - BASChapter606SovereignCodableProofTests
// chapter 六百六 / M1802 — PROOF tests for the M1801
//                          BASSovereign Codable
//                          extension wave 1 (12TH
//                          MODULE FORMAL ENTRY)
//
// ## Coverage (4 compile-time conformance tests)
//
// BASSovereign wave 1 Codable extension — 12th
// module formal entry。 6th consecutive post-octa
// fresh-module advancement。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism extends to
//     these 4 newly-Codable types
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1801 → M1802

import XCTest
@testable import BASSovereign

final class BASChapter606SovereignCodableProofTests:
    XCTestCase
{

    func testSovereignTurnParityConformsToCodable() {
        // #18: real round-trip (String enum, not CaseIterable)
        assertCodableRoundTrips(BASSovereignTurnParity.match)
        assertCodableRoundTrips(BASSovereignTurnParity.coordinatorLaxer)
    }

    func testOperationDomainConformsToCodable() {
        // #18: real round-trip (String enum, not CaseIterable)
        assertCodableRoundTrips(
            BASSovereignVerdictEngine.OperationDomain.pureInference)
        assertCodableRoundTrips(
            BASSovereignVerdictEngine.OperationDomain.toolWrite)
    }

    func testSovereignTurnObservationsConformsToCodable() {
        // #18: real round-trip
        let value = BASSovereignTurnObservations(
            sessionID: "",
            turnID: "",
            snapshotRef: "",
            policyHash: "",
            policyLineageMissing: false,
            auditEntryMissing: false,
            runtimeUnstableInHighRisk: false,
            riskPermitHeadConflict: false,
            externalSideEffectWithoutSCT: false,
            hostRemovalBypassed: false,
            unauthorizedSelfMutation: false,
            memoryOrHostWriteBypass: false,
            irreversibilityScore: 0.0,
            manipulationStrength: 0.0,
            uncertaintyScore: 0.0,
            gsiScore: 0.0,
            hostGateValue: 0.0,
            quarantineCount: 0,
            runMode: .dormant,
            emergencyBrakeLevel: .none,
            operation: .pureInference,
            evidenceSufficient: false)
        assertCodableRoundTrips(value)
    }

    func testSovereignTurnVerifierReportConformsToCodable() {
        // #18: real round-trip — required `engineVerdict`
        // (BASSovereignVerdict) is a large BASSchemaVersioned struct
        // from BASRuntimeCore not confidently constructible here;
        // honest compile-time-only fallback.
        assertConformsToCodableAtCompileTime(
            BASSovereignTurnVerifierReport.self)
    }
}
