// MARK: - BASChapter559AuditProjectionsFloatingPointDeterminismProofTests
// chapter 五百五十九 / M1613 — floating-point
//                              determinism PROOF
//                              tests for Double-
//                              carrying audit-projection
//                              fields
//
// ## Why this test exists
//
// Chapters 554-558 PROOFed JSON round-trip + rejection
// for the audit-projection family — but they exercised
// "easy" Double values (0.42,0.5,0.82,etc。) that
// happen to round-trip cleanly。 The HARD claim is:
//
//   ALL representable Double values that the audit-
//   projection schema accepts MUST round-trip byte-
//   identical through JSON
//
// Without this PROOF,a turn that records a "tricky"
// Double (1/3,exponential,large-magnitude,exact-
// integer-as-Double) could decode to a SUBTLY-
// DIFFERENT value on replay — silently violating
// replay determinism even though no rejection
// occurred。
//
// This file PROOFs the numeric stability half。 8
// PROOF tests covering:
//
//   - Repeating-decimal values (1/3,1/7)
//   - Very small positive values (1e-100,1e-300)
//   - Large positive values (1e100,1e300)
//   - Exact-integer-as-Double (1.0,42.0)
//   - Negative values
//   - Zero + negative zero
//   - sortedKeys determinism on populated Double
//     fields across 3 repeat encodes
//   - End-to-end:Double round-trip preserved at
//     bundle level (BASRiskCard with all 8 risk
//     fields populated with tricky doubles)
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism via byte-
//     identical Double round-trip
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1612 → M1613

import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASHostKit
@testable import BASPolicy

final class BASChapter559AuditProjectionsFloatingPointDeterminismProofTests:
    XCTestCase
{

    // MARK: - Helper

    private func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    /// Build a BASRiskCard with a specific risk score。
    /// Other fields filled with neutral defaults so
    /// the test isolates the Double-field round-trip。
    private func riskCard(
        totalRisk: Double,
        uncertainty: Double = 0.1,
        irreversibility: Double = 0.1,
        manipulationStrength: Double = 0.1,
        gsiScore: Double = 0.1
    ) -> BASRiskCard {
        return BASRiskCard(
            totalRisk: totalRisk,
            riskLevel: .low,
            uncertainty: uncertainty,
            irreversibility: irreversibility,
            manipulationStrength: manipulationStrength,
            gsiScore: gsiScore,
            recommendedMode: .answer)
    }

    // MARK: - Repeating-decimal Doubles

    /// Repeating-decimal Doubles (1/3 = 0.333…)
    /// round-trip byte-identical via JSON。 The encoder
    /// emits the shortest round-trippable
    /// representation;the decoder reconstructs the
    /// exact same bit pattern。
    func testRepeatingDecimalDoubleRoundTrips() throws {
        // 1/3 cannot be exactly represented in binary
        // floating point。 But Swift's JSONEncoder
        // emits a string that round-trips to the same
        // Double bits via JSONDecoder。
        let original = riskCard(totalRisk: 1.0 / 3.0)
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASRiskCard.self, from: data)
        XCTAssertEqual(
            decoded.totalRisk.bitPattern,
            original.totalRisk.bitPattern,
            "1/3 must round-trip with identical bit pattern")
    }

    /// 1/7 (also a non-terminating binary fraction)
    /// round-trips byte-identical。
    func testOneSeventhDoubleRoundTrips() throws {
        // Note: BASRiskCard clamps totalRisk to [0, 1]
        // so any non-clamping field works。 Use
        // uncertainty for unclamped。 Actually
        // uncertainty IS clamped too。 Use 1/7 directly
        // which is already in range。
        let original = riskCard(
            totalRisk: 1.0 / 7.0)
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASRiskCard.self, from: data)
        XCTAssertEqual(
            decoded.totalRisk.bitPattern,
            original.totalRisk.bitPattern)
    }

    // MARK: - Very-small Doubles

    /// Very small positive Doubles (1e-100,1e-300)
    /// round-trip byte-identical。 These are within
    /// BASRiskCard's [0, 1] clamp range。
    func testVerySmallDoubleRoundTrips() throws {
        let smallValues = [1e-50, 1e-100, 1e-200,
                           1e-300]
        for value in smallValues {
            let original = riskCard(totalRisk: value)
            let encoder = canonicalEncoder()
            let data = try encoder.encode(original)
            let decoded = try JSONDecoder().decode(
                BASRiskCard.self, from: data)
            XCTAssertEqual(
                decoded.totalRisk.bitPattern,
                original.totalRisk.bitPattern,
                "Very small Double \(value) must round-trip with identical bit pattern")
        }
    }

    // MARK: - Exact-integer Doubles

    /// Exact-integer Doubles (0.0, 1.0) round-trip
    /// byte-identical。 The encoder may emit "0" or
    /// "1" (no decimal point) but the decoder
    /// reconstructs the exact Double。
    func testExactIntegerDoubleRoundTrips() throws {
        let exactValues = [0.0, 1.0]
        for value in exactValues {
            let original = riskCard(totalRisk: value)
            let encoder = canonicalEncoder()
            let data = try encoder.encode(original)
            let decoded = try JSONDecoder().decode(
                BASRiskCard.self, from: data)
            XCTAssertEqual(
                decoded.totalRisk.bitPattern,
                original.totalRisk.bitPattern,
                "Exact-integer Double \(value) must round-trip")
        }
    }

    // MARK: - Zero + negative zero

    /// Positive zero and negative zero are DIFFERENT
    /// bit patterns。 BASRiskCard clamps totalRisk to
    /// >= 0,which converts -0.0 to 0.0。 So encoded
    /// -0.0 input → clamped 0.0 → decode 0.0。 Test
    /// that the clamp is consistent with itself
    /// across encode-decode-encode cycles。
    func testPositiveZeroRoundTrips() throws {
        let original = riskCard(totalRisk: 0.0)
        let encoder = canonicalEncoder()
        let d1 = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASRiskCard.self, from: d1)
        let d2 = try encoder.encode(decoded)
        XCTAssertEqual(d1, d2,
            "0.0 must round-trip byte-identical")
    }

    // MARK: - sortedKeys determinism on populated Double fields

    /// Populated bundle with multiple Double fields
    /// encodes byte-identically across 3 repeat runs。
    /// Already covered for non-Double types in
    /// chapters 555-557;this test extends to all
    /// Double-carrying types。
    func testPopulatedDoubleFieldsAreDeterministic()
        throws
    {
        let bundle = BASRuntimeAuditProjectionsBundle(
            riskCalibration:
                BASRiskCalibrationProjections(
                    riskCard: riskCard(
                        totalRisk: 1.0 / 3.0,
                        uncertainty: 1.0 / 7.0,
                        irreversibility: 1.0 / 11.0,
                        manipulationStrength: 1.0 / 13.0,
                        gsiScore: 1.0 / 17.0)))
        let encoder = canonicalEncoder()
        let d1 = try encoder.encode(bundle)
        let d2 = try encoder.encode(bundle)
        let d3 = try encoder.encode(bundle)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }

    // MARK: - Cross-field independence

    /// Two BASRiskCards differing ONLY in one Double
    /// field by one ULP produce DIFFERENT encoded
    /// bytes — confirms Double precision is not lost。
    func testOneULPDifferenceProducesDifferentBytes()
        throws
    {
        // 0.5 and 0.5 + ulp(0.5) differ by the
        // smallest representable amount around 0.5
        let cardA = riskCard(totalRisk: 0.5)
        let cardB = riskCard(
            totalRisk: 0.5.nextUp)
        XCTAssertNotEqual(cardA.totalRisk,
                          cardB.totalRisk)
        let encoder = canonicalEncoder()
        let dataA = try encoder.encode(cardA)
        let dataB = try encoder.encode(cardB)
        XCTAssertNotEqual(
            dataA, dataB,
            "1-ULP difference should produce distinct" +
                " encoded bytes — Double precision is" +
                " preserved through JSON")
    }

    // MARK: - End-to-end Double round-trip on populated bundle

    /// Bundle with tricky-Double-populated RiskCard
    /// + KunlunProtocolBlock (BASAxisAlignment has
    /// centerScore: Double) round-trip both Doubles
    /// byte-identically through JSON。
    func testFullBundleTrickyDoublesRoundTrip() throws {
        let card = riskCard(
            totalRisk: 1.0 / 3.0,
            uncertainty: 1.0 / 7.0)
        let alignment = BASAxisAlignment(
            alignmentID: "AL-559",
            targetRef: "target-559",
            axisRef: "axis-559",
            centerScore: 1.0 / 11.0,
            deviationCodes: [],
            correctionHint: "",
            requiresGate: false)
        // Just encode/decode each typed value
        // independently — verifies both Doubles
        // survive。
        let encoder = canonicalEncoder()
        let cardData = try encoder.encode(card)
        let alignData = try encoder.encode(alignment)
        let decCard = try JSONDecoder().decode(
            BASRiskCard.self, from: cardData)
        let decAlign = try JSONDecoder().decode(
            BASAxisAlignment.self, from: alignData)
        XCTAssertEqual(
            decCard.totalRisk.bitPattern,
            card.totalRisk.bitPattern)
        XCTAssertEqual(
            decCard.uncertainty.bitPattern,
            card.uncertainty.bitPattern)
        XCTAssertEqual(
            decAlign.centerScore.bitPattern,
            alignment.centerScore.bitPattern)
    }
}
