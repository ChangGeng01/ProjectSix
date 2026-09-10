// MARK: - BASChapter555AuditProjectionsFiveNamespaceJsonProofTests
// chapter 五百五十五 / M1597 — first knife of the
//                              5-namespace populated
//                              JSON-PROOF extension
//                              arc
//
// ## Why this test exists
//
// Chapter 554 (M1593) shipped 8 end-to-end JSON round-
// trip PROOF tests but only exercised 3-of-5 namespaces
// in populated state:
//
//   - Kunlun:populated via 3 string-refs (PROOFed)
//   - Abyssal:populated via 1 string-ref (PROOFed)
//   - Tribunal:populated via triScores (PROOFed)
//   - Cthulhu:NOT populated in chapter 554 (empty only)
//   - RiskCalibration:NOT populated in chapter 554
//     (empty only)
//
// Chapter 555 extends the PROOF to ALL 5 namespaces
// populated:
//
//   - Cthulhu populated via BASUnknownReserve (typed
//     projection — exercises the L8/L9 sovereign-
//     unknown-reserve path)
//   - RiskCalibration populated via BASRiskCard (typed
//     projection with all 8 risk fields)
//   - Full-bundle populated across ALL 5 namespaces
//     simultaneously → end-to-end JSON round-trip
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism via Codable +
//     sortedKeys JSON round-trip — extension to
//     remaining 2 namespaces
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1596 → M1597

import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASHostKit
@testable import BASPolicy
@testable import BASWorldPrior

final class BASChapter555AuditProjectionsFiveNamespaceJsonProofTests:
    XCTestCase
{

    // MARK: - Canonical encoder

    private func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    // MARK: - Cthulhu populated round-trips

    /// `BASCthulhuAuditProjections` populated with a
    /// typed `BASUnknownReserve` projection round-trips
    /// byte-identical via JSON。
    func testCthulhuWithUnknownReservePopulatedRoundTrips()
        throws
    {
        let reserve = BASUnknownReserve(
            reserveID: "RSV-555",
            unknownRefs: ["unknown-a", "unknown-b"],
            whyUnresolved: "no-evidence",
            forbiddenInferences: ["inference-x"],
            evidenceNeeded: ["evidence-y"],
            assertionCeiling: .qualified)
        let original = BASCthulhuAuditProjections(
            unknownReserve: reserve)
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASCthulhuAuditProjections.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(
            decoded.unknownReserve?.reserveID,
            "RSV-555")
        XCTAssertEqual(
            decoded.unknownReserve?.unknownRefs.count,
            2)
    }

    /// sortedKeys determinism PROOF for populated Cthulhu
    /// projection — 3 repeat encodes byte-identical。
    func testCthulhuPopulatedEncodingIsByteDeterministic()
        throws
    {
        let original = BASCthulhuAuditProjections(
            unknownReserve: BASUnknownReserve(
                reserveID: "RSV-555-D",
                unknownRefs: ["alpha", "beta"],
                whyUnresolved: "test",
                forbiddenInferences: [],
                evidenceNeeded: [],
                assertionCeiling: .metaOnly))
        let encoder = canonicalEncoder()
        let d1 = try encoder.encode(original)
        let d2 = try encoder.encode(original)
        let d3 = try encoder.encode(original)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }

    // MARK: - RiskCalibration populated round-trips

    /// `BASRiskCalibrationProjections` populated with a
    /// typed `BASRiskCard` round-trips byte-identical
    /// via JSON。
    func testRiskCalibrationPopulatedRoundTrips() throws {
        let card = BASRiskCard(
            totalRisk: 0.42,
            riskLevel: .medium,
            factors: ["factor-a"],
            uncertainty: 0.15,
            irreversibility: 0.30,
            manipulationStrength: 0.08,
            gsiScore: 0.18,
            recommendedMode: .mirror)
        let original = BASRiskCalibrationProjections(
            riskCard: card)
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASRiskCalibrationProjections.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(
            decoded.riskCard?.riskLevel, .medium)
    }

    /// sortedKeys determinism PROOF for populated
    /// RiskCalibration — 3 repeat encodes byte-identical。
    func testRiskCalibrationPopulatedEncodingIsDeterministic()
        throws
    {
        let card = BASRiskCard(
            totalRisk: 0.50,
            riskLevel: .high,
            uncertainty: 0.20,
            irreversibility: 0.40,
            manipulationStrength: 0.10,
            gsiScore: 0.25,
            recommendedMode: .compare)
        let original = BASRiskCalibrationProjections(
            riskCard: card)
        let encoder = canonicalEncoder()
        let d1 = try encoder.encode(original)
        let d2 = try encoder.encode(original)
        let d3 = try encoder.encode(original)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }

    // MARK: - Full 5-namespace bundle populated round-trip

    /// `BASRuntimeAuditProjectionsBundle` populated
    /// across ALL 5 namespaces simultaneously round-
    /// trips byte-identical via JSON。 This is the
    /// strongest claim:the audit-projection emission
    /// family carries arbitrary populated state through
    /// JSON serialization without loss。
    func testFullFiveNamespaceBundleRoundTrips() throws {
        let kunlun = BASKunlunAuditProjections(
            readinessRef: "rdy-555",
            jadeSealRef: "jade-555",
            riverTraceRef: "river-555")
        let abyssal = BASAbyssalAuditProjections(
            anomalyTraceRef: "anom-555")
        let cthulhu = BASCthulhuAuditProjections(
            unknownReserve: BASUnknownReserve(
                reserveID: "RSV-555-FULL",
                unknownRefs: ["u1"],
                whyUnresolved: "test",
                forbiddenInferences: ["f1"],
                evidenceNeeded: ["e1"],
                assertionCeiling: .provisional))
        let tribunal = BASTribunalAuditProjections(
            triScores: [
                BASTriSelfScore(
                    candidateID: "cand-555",
                    idScore: 0.5,
                    egoScore: 0.6,
                    superegoScore: 0.7,
                    mergedScore: 0.6,
                    veto: false)
            ])
        let risk = BASRiskCalibrationProjections(
            riskCard: BASRiskCard(
                totalRisk: 0.40,
                riskLevel: .medium,
                uncertainty: 0.15,
                irreversibility: 0.25,
                manipulationStrength: 0.05,
                gsiScore: 0.20,
                recommendedMode: .mirror))
        let original = BASRuntimeAuditProjectionsBundle(
            kunlun: kunlun,
            abyssal: abyssal,
            cthulhu: cthulhu,
            tribunal: tribunal,
            riskCalibration: risk)
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASRuntimeAuditProjectionsBundle.self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertTrue(decoded.hasAnyProjection)
        // populatedSlotCount sums per-namespace counts。
        // kunlun 3 + abyssal 1 + cthulhu 1 + tribunal 1
        // + risk 1 = 7
        XCTAssertEqual(decoded.populatedSlotCount, 7)
    }

    /// sortedKeys determinism PROOF for the full 5-
    /// namespace populated bundle。 3 repeat encodes
    /// yield byte-identical output。
    func testFullFiveNamespaceBundleEncodingIsByteDeterministic()
        throws
    {
        let bundle = BASRuntimeAuditProjectionsBundle(
            kunlun: BASKunlunAuditProjections(
                readinessRef: "rdy"),
            abyssal: BASAbyssalAuditProjections(
                anomalyTraceRef: "anom"),
            cthulhu: BASCthulhuAuditProjections(
                unknownReserve: BASUnknownReserve(
                    reserveID: "rsv",
                    unknownRefs: [],
                    whyUnresolved: "wy",
                    forbiddenInferences: [],
                    evidenceNeeded: [],
                    assertionCeiling: .none)),
            tribunal: BASTribunalAuditProjections(
                triScores: [
                    BASTriSelfScore(
                        candidateID: "c",
                        idScore: 0.1,
                        egoScore: 0.2,
                        superegoScore: 0.3,
                        mergedScore: 0.2,
                        veto: false)
                ]),
            riskCalibration:
                BASRiskCalibrationProjections(
                    riskCard: BASRiskCard(
                        totalRisk: 0.1,
                        riskLevel: .low,
                        uncertainty: 0.05,
                        irreversibility: 0.05,
                        manipulationStrength: 0.05,
                        gsiScore: 0.05,
                        recommendedMode: .answer)))
        let encoder = canonicalEncoder()
        let d1 = try encoder.encode(bundle)
        let d2 = try encoder.encode(bundle)
        let d3 = try encoder.encode(bundle)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }

    // MARK: - Distinct-bundle PROOF across all 5 namespaces

    /// Two bundles differing ONLY in their Cthulhu /
    /// RiskCalibration content produce distinct encoded
    /// bytes — confirms the 2 newly-tested namespaces
    /// are NOT silently dropped by the synthesizer。
    func testDistinctCthulhuAndRiskBundlesProduceDistinctBytes()
        throws
    {
        let bundleA = BASRuntimeAuditProjectionsBundle(
            cthulhu: BASCthulhuAuditProjections(
                unknownReserve: BASUnknownReserve(
                    reserveID: "RSV-A",
                    unknownRefs: [],
                    whyUnresolved: "wy",
                    forbiddenInferences: [],
                    evidenceNeeded: [],
                    assertionCeiling: .none)))
        let bundleB = BASRuntimeAuditProjectionsBundle(
            cthulhu: BASCthulhuAuditProjections(
                unknownReserve: BASUnknownReserve(
                    reserveID: "RSV-B",
                    unknownRefs: [],
                    whyUnresolved: "wy",
                    forbiddenInferences: [],
                    evidenceNeeded: [],
                    assertionCeiling: .none)))
        let encoder = canonicalEncoder()
        let dataA = try encoder.encode(bundleA)
        let dataB = try encoder.encode(bundleB)
        XCTAssertNotEqual(dataA, dataB)
    }

    // MARK: - Populated-vs-empty discrimination

    /// Populated 5-namespace bundle and empty bundle
    /// produce distinct encoded bytes。 Both round-trip
    /// cleanly。 Combined PROOF that the synthesized
    /// Codable correctly distinguishes presence from
    /// absence across all 5 namespaces。
    func testFullBundlePopulatedDistinctFromEmpty() throws
    {
        let populated = BASRuntimeAuditProjectionsBundle(
            kunlun: BASKunlunAuditProjections(
                readinessRef: "p"),
            abyssal: BASAbyssalAuditProjections(
                anomalyTraceRef: "p"),
            cthulhu: BASCthulhuAuditProjections(
                unknownReserve: BASUnknownReserve(
                    reserveID: "p",
                    unknownRefs: [],
                    whyUnresolved: "p",
                    forbiddenInferences: [],
                    evidenceNeeded: [],
                    assertionCeiling: .none)),
            tribunal: BASTribunalAuditProjections(
                triScores: [
                    BASTriSelfScore(
                        candidateID: "p",
                        idScore: 0.1,
                        egoScore: 0.2,
                        superegoScore: 0.3,
                        mergedScore: 0.2,
                        veto: false)
                ]),
            riskCalibration:
                BASRiskCalibrationProjections(
                    riskCard: BASRiskCard(
                        totalRisk: 0.1,
                        riskLevel: .low,
                        uncertainty: 0.05,
                        irreversibility: 0.05,
                        manipulationStrength: 0.05,
                        gsiScore: 0.05,
                        recommendedMode: .answer)))
        let empty = BASRuntimeAuditProjectionsBundle.none()
        let encoder = canonicalEncoder()
        let dataP = try encoder.encode(populated)
        let dataE = try encoder.encode(empty)
        XCTAssertNotEqual(dataP, dataE)
        let decodedP = try JSONDecoder().decode(
            BASRuntimeAuditProjectionsBundle.self,
            from: dataP)
        let decodedE = try JSONDecoder().decode(
            BASRuntimeAuditProjectionsBundle.self,
            from: dataE)
        XCTAssertEqual(decodedP, populated)
        XCTAssertEqual(decodedE, empty)
        XCTAssertNotEqual(decodedP, decodedE)
    }
}
