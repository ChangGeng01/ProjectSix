import XCTest
@testable import BASMemory
import BASRuntimeCore

/// M513-M514 (chapter 一百三十) — pin BASCounterHostCheck schema +
/// derive-helper outcome routing per audit Point 8 doctrine.
final class BASCounterHostCheckTests: XCTestCase {

    // MARK: - 1. Outcome enum cardinality + raw values

    func testOutcomeCardinality() {
        XCTAssertEqual(
            BASCounterHostCheckOutcome.allCases.count, 4,
            "exactly 4 Counter-Host Check outcomes per audit Point 8")
    }

    func testOutcomeRawValuesStable() {
        let rawValues = Set(
            BASCounterHostCheckOutcome.allCases.map(\.rawValue))
        XCTAssertEqual(
            rawValues,
            ["genuine-host-pattern", "system-induced-drift",
             "insufficient-evidence", "not-applicable"],
            "stable kebab-case raw values for cross-module grep")
    }

    // MARK: - 2. Schema construction + Codable round-trip

    func testSchemaCodableRoundTrip() throws {
        let original = BASCounterHostCheck(
            checkID: "counter-host-check:test:c1",
            candidateRef: "candidate:c1",
            hostBaselineRef: "host-baseline:v42",
            observedDelta: 0.15,
            inducedRiskScore: 0.75,
            outcome: .systemInducedDrift,
            reasonCodes: [
                "counter-host:risk:0.750",
                "counter-host:requires-sovereign-override",
            ])
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASCounterHostCheck.self, from: encoded)
        XCTAssertEqual(decoded, original,
            "BASCounterHostCheck round-trips byte-equal")
    }

    func testFieldClampingTo01() {
        let check = BASCounterHostCheck(
            checkID: "counter-host-check:test:c2",
            candidateRef: "candidate:c2",
            hostBaselineRef: "host-baseline:v1",
            observedDelta: -0.5,    // clamps to 0
            inducedRiskScore: 1.5,  // clamps to 1
            outcome: .genuineHostPattern,
            reasonCodes: [])
        XCTAssertEqual(check.observedDelta, 0,
            "observedDelta clamps to [0, 1]")
        XCTAssertEqual(check.inducedRiskScore, 1,
            "inducedRiskScore clamps to [0, 1]")
    }

    // MARK: - 3. Doctrine invariant — requiresSovereignOverride

    func testRequiresSovereignOverridePin() {
        let inducedDrift = BASCounterHostCheck(
            checkID: "c1",
            candidateRef: "candidate:c1",
            hostBaselineRef: "host-baseline:v1",
            observedDelta: 0.5,
            inducedRiskScore: 0.8,
            outcome: .systemInducedDrift,
            reasonCodes: [])
        XCTAssertTrue(
            inducedDrift.requiresSovereignOverride,
            "systemInducedDrift outcome MUST require sovereign override (audit Point 8 doctrine)")
        let genuine = BASCounterHostCheck(
            checkID: "c2",
            candidateRef: "candidate:c2",
            hostBaselineRef: "host-baseline:v1",
            observedDelta: 0.05,
            inducedRiskScore: 0.1,
            outcome: .genuineHostPattern,
            reasonCodes: [])
        XCTAssertFalse(
            genuine.requiresSovereignOverride,
            "genuineHostPattern does NOT require sovereign override")
    }

    // MARK: - 4. Derive helper — systemInducedDrift path

    func testDeriveResolvesSystemInducedDrift() {
        let check = BASCounterHostCheckProtocol.derive(
            candidateRef: "candidate:c1",
            hostBaselineRef: "host-baseline:v1",
            observedDelta: 0.4,
            inducedRiskScore: 0.7,  // above 0.6 threshold
            appliesToHostConstitution: true,
            turnID: "turn-1")
        XCTAssertEqual(check.outcome, .systemInducedDrift,
            "inducedRiskScore >= 0.6 → systemInducedDrift")
        XCTAssertTrue(check.requiresSovereignOverride)
        XCTAssertTrue(
            check.reasonCodes.contains(
                "counter-host:requires-sovereign-override"),
            "systemInducedDrift outcome MUST emit override reason code")
    }

    // MARK: - 5. Derive helper — genuineHostPattern path

    func testDeriveResolvesGenuineHostPattern() {
        let check = BASCounterHostCheckProtocol.derive(
            candidateRef: "candidate:c1",
            hostBaselineRef: "host-baseline:v1",
            observedDelta: 0.1,  // below 0.2 ceiling
            inducedRiskScore: 0.3,  // below 0.6 threshold
            appliesToHostConstitution: true,
            turnID: "turn-1")
        XCTAssertEqual(check.outcome, .genuineHostPattern,
            "low delta + low risk + has baseline → genuineHostPattern")
        XCTAssertFalse(check.requiresSovereignOverride)
    }

    // MARK: - 6. Derive helper — insufficientEvidence paths

    func testDeriveResolvesInsufficientEvidenceWithoutBaseline() {
        let check = BASCounterHostCheckProtocol.derive(
            candidateRef: "candidate:c1",
            hostBaselineRef: "",  // empty baseline
            observedDelta: 0.1,
            inducedRiskScore: 0.3,
            appliesToHostConstitution: true,
            turnID: "turn-1")
        XCTAssertEqual(check.outcome, .insufficientEvidence,
            "empty baseline → insufficientEvidence")
    }

    func testDeriveResolvesInsufficientEvidenceMidBand() {
        let check = BASCounterHostCheckProtocol.derive(
            candidateRef: "candidate:c1",
            hostBaselineRef: "host-baseline:v1",
            observedDelta: 0.5,  // above 0.2 ceiling, below threshold
            inducedRiskScore: 0.4,  // below 0.6 threshold
            appliesToHostConstitution: true,
            turnID: "turn-1")
        XCTAssertEqual(check.outcome, .insufficientEvidence,
            "mid-band delta + sub-threshold risk → insufficientEvidence")
    }

    // MARK: - 7. Derive helper — notApplicable path

    func testDeriveResolvesNotApplicableWhenNonHostCandidate() {
        let check = BASCounterHostCheckProtocol.derive(
            candidateRef: "tool-call:c1",
            hostBaselineRef: "host-baseline:v1",
            observedDelta: 0.9,  // would be drift if applicable
            inducedRiskScore: 0.9,  // would be drift if applicable
            appliesToHostConstitution: false,
            turnID: "turn-1")
        XCTAssertEqual(check.outcome, .notApplicable,
            "non-host-constitution candidate → notApplicable regardless of risk")
        XCTAssertFalse(check.requiresSovereignOverride)
    }

    // MARK: - 8. Threshold pinning

    func testThresholdsAreNamedConstants() {
        XCTAssertEqual(
            BASCounterHostCheckProtocol
                .systemInducedRiskThreshold, 0.6,
            "anti-magic-number: threshold pinned at 0.6")
        XCTAssertEqual(
            BASCounterHostCheckProtocol
                .genuinePatternDeltaCeiling, 0.2,
            "anti-magic-number: ceiling pinned at 0.2")
    }

    // MARK: - 9. Schema version stability

    func testSchemaVersionIsCurrent() {
        XCTAssertEqual(
            BASCounterHostCheck.currentSchemaVersion, "1.0.0",
            "chapter 一百三十 ships v1.0.0 baseline")
    }

    // MARK: - 10. Reason code emission stability

    func testReasonCodesIncludeOutcomeAndScalars() {
        let check = BASCounterHostCheckProtocol.derive(
            candidateRef: "candidate:c1",
            hostBaselineRef: "host-baseline:v1",
            observedDelta: 0.123,
            inducedRiskScore: 0.456,
            appliesToHostConstitution: true,
            turnID: "turn-1")
        XCTAssertTrue(
            check.reasonCodes.contains(where: {
                $0.hasPrefix("counter-host:outcome:")
            }),
            "reasonCodes MUST include outcome code")
        XCTAssertTrue(
            check.reasonCodes.contains(where: {
                $0.hasPrefix("counter-host:risk:")
            }),
            "reasonCodes MUST include risk scalar")
        XCTAssertTrue(
            check.reasonCodes.contains(where: {
                $0.hasPrefix("counter-host:delta:")
            }),
            "reasonCodes MUST include delta scalar")
    }
}
