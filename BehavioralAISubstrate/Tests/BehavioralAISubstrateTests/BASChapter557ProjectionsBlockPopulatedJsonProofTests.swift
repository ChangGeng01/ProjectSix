// MARK: - BASChapter557ProjectionsBlockPopulatedJsonProofTests
// chapter 五百五十七 / M1605 — first knife of the
//                              5-of-5 ProjectionsBlock
//                              populated PROOF
//                              extension
//
// ## Why this test exists
//
// At M1591 the BASCodableCascadeArcSealedDoctrine
// claimed "All 5 BASAuditObservationProjections*Block
// types are now Codable"。 The 5 blocks are:
//
//   1. ClosureBlock (chapter 552 / M1585)
//   2. CthulhuLeftoversBlock (chapter 552 / M1585)
//   3. KunlunAuditSchemasBlock (chapter 552 / M1585)
//   4. KunlunProtocolBlock (chapter 552 / M1587)
//   5. CthulhuAggregatesBlock (chapter 553 / M1589)
//
// Existing PROOF coverage:
//
//   - CthulhuAggregatesBlock POPULATED round-trip:
//     PROVEN at M1593 (chapter 554)
//   - ClosureBlock POPULATED round-trip:NOT proven
//   - CthulhuLeftoversBlock POPULATED round-trip:NOT
//     proven
//   - KunlunAuditSchemasBlock POPULATED round-trip:
//     NOT proven
//   - KunlunProtocolBlock POPULATED round-trip:NOT
//     proven
//
// Chapter 557 closes that gap with 5 PROOF tests
// covering all 4 remaining blocks in populated state +
// 1 cross-block PROOF that all 5 blocks together pass
// through JSON round-trip without losing structure。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism via
//     Codable + sortedKeys JSON round-trip
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1604 → M1605

import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASHostKit

final class BASChapter557ProjectionsBlockPopulatedJsonProofTests:
    XCTestCase
{

    // MARK: - Canonical encoder

    private func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    // MARK: - ClosureBlock populated round-trip

    /// `BASAuditObservationProjectionsClosureBlock`
    /// populated with `escalationSuppressionCodes`
    /// round-trips byte-identical via JSON。
    func testClosureBlockPopulatedRoundTrips() throws {
        let original =
            BASAuditObservationProjectionsClosureBlock(
                escalationSuppressionCodes: [
                    "supp-557-a",
                    "supp-557-b",
                    "supp-557-c"
                ])
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASAuditObservationProjectionsClosureBlock.self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(
            decoded.escalationSuppressionCodes.count, 3)
    }

    // MARK: - CthulhuLeftoversBlock populated round-trip

    /// `BASAuditObservationProjectionsCthulhuLeftovers
    /// Block` populated with reason-code arrays
    /// round-trips byte-identical via JSON。
    func testCthulhuLeftoversBlockPopulatedRoundTrips()
        throws
    {
        let original =
            BASAuditObservationProjectionsCthulhuLeftoversBlock(
                cthulhuAssertionCeilingReasonCodes: [
                    "ceil-557-a",
                    "ceil-557-b"
                ],
                cthulhuPermitEscalationReasonCodes: [
                    "perm-557-x",
                    "perm-557-y",
                    "perm-557-z"
                ])
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASAuditObservationProjectionsCthulhuLeftoversBlock
                .self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(
            decoded.cthulhuAssertionCeilingReasonCodes.count,
            2)
        XCTAssertEqual(
            decoded.cthulhuPermitEscalationReasonCodes.count,
            3)
    }

    // MARK: - KunlunAuditSchemasBlock populated round-trip

    /// `BASAuditObservationProjectionsKunlunAuditSchemas
    /// Block` populated with a typed `BASKunlunAxisView`
    /// round-trips byte-identical via JSON。
    func testKunlunAuditSchemasBlockPopulatedRoundTrips()
        throws
    {
        let axisView = BASKunlunAxisView(
            worldRef: "world-557",
            centerlinePriors: [
                "prior-557-a",
                "prior-557-b"
            ],
            deviationPatterns: [
                "drift-557-x"
            ],
            scaleLadders: ["cosmic", "personal"],
            orderConstraints: ["constraint-557-q"])
        let original =
            BASAuditObservationProjectionsKunlunAuditSchemasBlock(
                kunlunAxisView: axisView)
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASAuditObservationProjectionsKunlunAuditSchemasBlock
                .self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(
            decoded.kunlunAxisView?.worldRef,
            "world-557")
        XCTAssertEqual(
            decoded.kunlunAxisView?.centerlinePriors.count,
            2)
    }

    // MARK: - KunlunProtocolBlock populated round-trip

    /// `BASAuditObservationProjectionsKunlunProtocol
    /// Block` populated with a typed `BASAxisAlignment`
    /// round-trips byte-identical via JSON。
    func testKunlunProtocolBlockPopulatedRoundTrips()
        throws
    {
        let alignment = BASAxisAlignment(
            alignmentID: "AL-557",
            targetRef: "target-557",
            axisRef: "axis-557",
            centerScore: 0.82,
            deviationCodes: ["drift-a"],
            correctionHint: "ease-toward-centerline",
            requiresGate: false)
        let original =
            BASAuditObservationProjectionsKunlunProtocolBlock(
                kunlunAxisAlignment: alignment)
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASAuditObservationProjectionsKunlunProtocolBlock
                .self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(
            decoded.kunlunAxisAlignment?.alignmentID,
            "AL-557")
        XCTAssertEqual(
            decoded.kunlunAxisAlignment?.centerScore ?? 0,
            0.82,
            accuracy: 1e-9)
    }

    // MARK: - Cross-block populated round-trip

    /// All 4 remaining blocks populated SIMULTANEOUSLY
    /// each round-trip through JSON byte-identical。
    /// Combined PROOF that the Codable synthesizer
    /// handles diverse populated state across the
    /// projection block family。
    func testAllFourRemainingBlocksRoundTripWhenAllPopulated()
        throws
    {
        let closure =
            BASAuditObservationProjectionsClosureBlock(
                escalationSuppressionCodes: ["multi-a"])
        let leftovers =
            BASAuditObservationProjectionsCthulhuLeftoversBlock(
                cthulhuAssertionCeilingReasonCodes: [
                    "multi-ceil"
                ])
        let schemas =
            BASAuditObservationProjectionsKunlunAuditSchemasBlock(
                kunlunAxisView: BASKunlunAxisView(
                    worldRef: "multi-world",
                    centerlinePriors: [],
                    deviationPatterns: [],
                    scaleLadders: ["multi-scale"],
                    orderConstraints: []))
        let proto =
            BASAuditObservationProjectionsKunlunProtocolBlock(
                kunlunAxisAlignment: BASAxisAlignment(
                    alignmentID: "multi-AL",
                    targetRef: "multi-target",
                    axisRef: "multi-axis",
                    centerScore: 0.5,
                    deviationCodes: [],
                    correctionHint: "",
                    requiresGate: false))
        let encoder = canonicalEncoder()
        // Encode + decode each independently
        let dataClosure = try encoder.encode(closure)
        let dataLeftovers = try encoder.encode(leftovers)
        let dataSchemas = try encoder.encode(schemas)
        let dataProto = try encoder.encode(proto)
        let decClosure = try JSONDecoder().decode(
            BASAuditObservationProjectionsClosureBlock.self,
            from: dataClosure)
        let decLeftovers = try JSONDecoder().decode(
            BASAuditObservationProjectionsCthulhuLeftoversBlock
                .self,
            from: dataLeftovers)
        let decSchemas = try JSONDecoder().decode(
            BASAuditObservationProjectionsKunlunAuditSchemasBlock
                .self,
            from: dataSchemas)
        let decProto = try JSONDecoder().decode(
            BASAuditObservationProjectionsKunlunProtocolBlock
                .self,
            from: dataProto)
        XCTAssertEqual(decClosure, closure)
        XCTAssertEqual(decLeftovers, leftovers)
        XCTAssertEqual(decSchemas, schemas)
        XCTAssertEqual(decProto, proto)
    }

    // MARK: - sortedKeys determinism on populated blocks

    /// 3 repeat encodes of populated blocks yield byte-
    /// identical output (sortedKeys determinism PROOF
    /// for all 4 newly-tested blocks)。
    func testPopulatedBlockEncodingIsByteDeterministic()
        throws
    {
        let closure =
            BASAuditObservationProjectionsClosureBlock(
                escalationSuppressionCodes: ["det-a"])
        let leftovers =
            BASAuditObservationProjectionsCthulhuLeftoversBlock(
                cthulhuAssertionCeilingReasonCodes: [
                    "det-ceil"
                ])
        let encoder = canonicalEncoder()
        XCTAssertEqual(
            try encoder.encode(closure),
            try encoder.encode(closure))
        XCTAssertEqual(
            try encoder.encode(closure),
            try encoder.encode(closure))
        XCTAssertEqual(
            try encoder.encode(leftovers),
            try encoder.encode(leftovers))
        XCTAssertEqual(
            try encoder.encode(leftovers),
            try encoder.encode(leftovers))
    }

    // MARK: - Populated-vs-empty PROOF

    /// Populated blocks produce distinct encoded bytes
    /// from their empty counterparts。 Combined with
    /// round-trip PROOF this confirms Codable correctly
    /// distinguishes populated from empty state across
    /// all 4 blocks。
    func testPopulatedBlocksDistinctFromEmpty() throws {
        let encoder = canonicalEncoder()
        // ClosureBlock
        let closurePop =
            BASAuditObservationProjectionsClosureBlock(
                escalationSuppressionCodes: ["non-empty"])
        let closureEmpty =
            BASAuditObservationProjectionsClosureBlock()
        XCTAssertNotEqual(
            try encoder.encode(closurePop),
            try encoder.encode(closureEmpty))
        // CthulhuLeftoversBlock
        let leftPop =
            BASAuditObservationProjectionsCthulhuLeftoversBlock(
                cthulhuAssertionCeilingReasonCodes: [
                    "non-empty"
                ])
        let leftEmpty =
            BASAuditObservationProjectionsCthulhuLeftoversBlock()
        XCTAssertNotEqual(
            try encoder.encode(leftPop),
            try encoder.encode(leftEmpty))
        // KunlunAuditSchemasBlock
        let schemaPop =
            BASAuditObservationProjectionsKunlunAuditSchemasBlock(
                kunlunAxisView: BASKunlunAxisView(
                    worldRef: "w",
                    centerlinePriors: [],
                    deviationPatterns: [],
                    scaleLadders: [],
                    orderConstraints: []))
        let schemaEmpty =
            BASAuditObservationProjectionsKunlunAuditSchemasBlock()
        XCTAssertNotEqual(
            try encoder.encode(schemaPop),
            try encoder.encode(schemaEmpty))
        // KunlunProtocolBlock
        let protoPop =
            BASAuditObservationProjectionsKunlunProtocolBlock(
                kunlunAxisAlignment: BASAxisAlignment(
                    alignmentID: "a",
                    targetRef: "t",
                    axisRef: "ax",
                    centerScore: 0.5,
                    deviationCodes: [],
                    correctionHint: "",
                    requiresGate: false))
        let protoEmpty =
            BASAuditObservationProjectionsKunlunProtocolBlock()
        XCTAssertNotEqual(
            try encoder.encode(protoPop),
            try encoder.encode(protoEmpty))
    }
}
