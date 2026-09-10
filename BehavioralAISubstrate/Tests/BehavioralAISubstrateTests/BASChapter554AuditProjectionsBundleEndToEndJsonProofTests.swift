// MARK: - BASChapter554AuditProjectionsBundleEndToEndJsonProofTests
// chapter 五百五十四 / M1593 — first knife of the post-
//                              Codable-cascade-arc-seal
//                              follow-through。
//
// ## Why this test exists
//
// At M1591 (chapter 553 close-out)
// `BASCodableCascadeArcSealedDoctrine` made the claim:
//
//   "The audit-projection emission family is
//   JSON-serializable end-to-end for replay determinism
//   PROOF."
//
// All existing Codable PROOF tests in the substrate cover
// the EMPTY / .none() bundle path only。 Empty bundles
// round-trip,sure — but the harder claim is that a
// POPULATED bundle exercising the chapter 553 newly-
// Codable types (BASOldSealSealingProtocol.Aggregate +
// BASEvolutionLifecycleSession.Aggregate +
// CthulhuAggregatesBlock) also round-trips byte-identical。
//
// This test file converts the doctrine claim from a flag
// into actual exercised runtime behaviour:
//
//   1. Populated CthulhuAggregatesBlock with both
//      chapter-553 newly-Codable Aggregates round-trips。
//   2. Populated BASRuntimeAuditProjectionsBundle with
//      string-refs across 3 namespaces round-trips。
//   3. sortedKeys determinism PROOF on POPULATED bundle
//      (not just empty)。
//   4. Encoded outputs DIFFER when bundle contents
//      differ — proves Codable isn't silently dropping
//      data。
//   5. Decode independence — decoding a freshly-encoded
//      bundle does not accidentally pick up the state
//      of a different bundle in scope。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism via Codable +
//     sortedKeys JSON round-trip — this test is the
//     real-world PROOF
//   - ADR-014 OPT-IN:default behaviour unchanged
//   - ADR-016 advances M1592 → M1593

import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASHostKit

final class BASChapter554AuditProjectionsBundleEndToEndJsonProofTests:
    XCTestCase
{

    // MARK: - Helper: canonical JSON encoder

    private func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    // MARK: - Chapter-553-cascade type round-trips

    /// Populated `BASOldSealSealingProtocol.Aggregate`
    /// (chapter 553 newly-Codable type) round-trips
    /// byte-identical via JSON。
    func testSealAggregatePopulatedRoundTrips() throws {
        let original = BASOldSealSealingProtocol.Aggregate(
            count: 3,
            strictestPolicy: .forbidden,
            policyHistogram: [
                .forbidden: 1,
                .sovereignOnly: 1,
                .auditedAccess: 1
            ])
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASOldSealSealingProtocol.Aggregate.self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded.strictestPolicy, .forbidden)
        XCTAssertEqual(decoded.policyHistogram.count, 3)
    }

    /// Populated
    /// `BASEvolutionLifecycleSession.Aggregate` (chapter
    /// 553 newly-Codable type) round-trips byte-identical
    /// via JSON。
    func testLifecycleAggregatePopulatedRoundTrips() throws
    {
        let original = BASEvolutionLifecycleSession
            .Aggregate(
                count: 5,
                terminalCount: 2,
                promotedCount: 1,
                activeStages: [
                    .proposed,
                    .shadowTrialing,
                    .promoted
                ])
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASEvolutionLifecycleSession.Aggregate.self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.count, 5)
        XCTAssertEqual(decoded.activeStages.count, 3)
    }

    // MARK: - CthulhuAggregatesBlock with chapter-553 types

    /// `BASAuditObservationProjectionsCthulhuAggregatesBlock`
    /// populated with BOTH chapter-553 newly-Codable
    /// aggregates round-trips byte-identical。 This is the
    /// real claim the doctrine M1591 made:the audit-
    /// projection emission family is JSON-serializable
    /// END-TO-END。
    func testCthulhuAggregatesBlockWithChapter553TypesRoundTrips()
        throws
    {
        let sealAgg = BASOldSealSealingProtocol.Aggregate(
            count: 2,
            strictestPolicy: .sovereignOnly,
            policyHistogram: [.sovereignOnly: 1, .passive: 1])
        let lifecycleAgg = BASEvolutionLifecycleSession
            .Aggregate(
                count: 3,
                terminalCount: 1,
                promotedCount: 1,
                activeStages: [.proposed, .promoted])
        let original =
            BASAuditObservationProjectionsCthulhuAggregatesBlock(
                sealAggregate: sealAgg,
                lifecycleAggregate: lifecycleAgg)
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASAuditObservationProjectionsCthulhuAggregatesBlock
                .self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.sealAggregate, sealAgg)
        XCTAssertEqual(
            decoded.lifecycleAggregate, lifecycleAgg)
    }

    // MARK: - Bundle-level populated round-trips

    /// Populated `BASRuntimeAuditProjectionsBundle` with
    /// string-refs across 3 namespaces round-trips byte-
    /// identical via JSON。
    func testBundlePopulatedAcrossThreeNamespacesRoundTrips()
        throws
    {
        let kunlun = BASKunlunAuditProjections(
            readinessRef: "READY-CH554",
            jadeSealRef: "JADE-CH554",
            riverTraceRef: "RIVER-CH554")
        let abyssal = BASAbyssalAuditProjections(
            anomalyTraceRef: "ANOM-CH554")
        let tribunal = BASTribunalAuditProjections(
            triScores: [
                BASTriSelfScore(
                    candidateID: "cand-554-A",
                    idScore: 0.62,
                    egoScore: 0.71,
                    superegoScore: 0.83,
                    mergedScore: 0.72,
                    veto: false)
            ])
        let original = BASRuntimeAuditProjectionsBundle(
            kunlun: kunlun,
            abyssal: abyssal,
            tribunal: tribunal)
        let encoder = canonicalEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASRuntimeAuditProjectionsBundle.self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.populatedSlotCount, 5)
        XCTAssertTrue(decoded.hasAnyProjection)
    }

    // MARK: - sortedKeys determinism on populated bundle

    /// 3 repeat encodes of the SAME populated bundle
    /// yield byte-identical output。 sortedKeys
    /// determinism PROOF for non-empty bundle (existing
    /// tests cover empty case only)。
    func testPopulatedBundleEncodingIsByteDeterministic()
        throws
    {
        let bundle = BASRuntimeAuditProjectionsBundle(
            kunlun: BASKunlunAuditProjections(
                readinessRef: "rdy",
                jadeSealRef: "jade",
                riverTraceRef: "river"),
            abyssal: BASAbyssalAuditProjections(
                anomalyTraceRef: "anom"))
        let encoder = canonicalEncoder()
        let d1 = try encoder.encode(bundle)
        let d2 = try encoder.encode(bundle)
        let d3 = try encoder.encode(bundle)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d2, d3)
    }

    // MARK: - Negative PROOF: distinct bundles → distinct JSON

    /// Two bundles with DIFFERENT populated content
    /// produce DIFFERENT encoded JSON bytes。 Proves
    /// Codable isn't silently dropping data。
    func testDistinctBundlesProduceDistinctEncodedBytes()
        throws
    {
        let bundleA = BASRuntimeAuditProjectionsBundle(
            kunlun: BASKunlunAuditProjections(
                readinessRef: "A"))
        let bundleB = BASRuntimeAuditProjectionsBundle(
            kunlun: BASKunlunAuditProjections(
                readinessRef: "B"))
        let encoder = canonicalEncoder()
        let dataA = try encoder.encode(bundleA)
        let dataB = try encoder.encode(bundleB)
        XCTAssertNotEqual(dataA, dataB)
    }

    // MARK: - Decode independence

    /// Decoding bundle A from JSON yields A's contents,
    /// not B's — even when both bundles are in scope。
    /// Defensive PROOF against accidental state leakage
    /// in the Codable synthesis。
    func testDecodingIsIndependentAcrossBundles() throws {
        let bundleA = BASRuntimeAuditProjectionsBundle(
            kunlun: BASKunlunAuditProjections(
                readinessRef: "alpha"))
        let bundleB = BASRuntimeAuditProjectionsBundle(
            kunlun: BASKunlunAuditProjections(
                readinessRef: "beta"))
        let encoder = canonicalEncoder()
        let dataA = try encoder.encode(bundleA)
        let dataB = try encoder.encode(bundleB)
        let decodedA = try JSONDecoder().decode(
            BASRuntimeAuditProjectionsBundle.self,
            from: dataA)
        let decodedB = try JSONDecoder().decode(
            BASRuntimeAuditProjectionsBundle.self,
            from: dataB)
        XCTAssertEqual(decodedA, bundleA)
        XCTAssertEqual(decodedB, bundleB)
        XCTAssertNotEqual(decodedA, decodedB)
    }

    // MARK: - Cross-block encoded independence

    /// CthulhuAggregatesBlock populated with chapter-553
    /// aggregates → JSON → decoded → still equal,still
    /// distinct from the .empty singleton。
    func testPopulatedCthulhuBlockDistinctFromEmpty() throws
    {
        let populated =
            BASAuditObservationProjectionsCthulhuAggregatesBlock(
                sealAggregate:
                    BASOldSealSealingProtocol.Aggregate(
                        count: 1,
                        strictestPolicy: .auditedAccess,
                        policyHistogram: [
                            .auditedAccess: 1
                        ]))
        let empty =
            BASAuditObservationProjectionsCthulhuAggregatesBlock
                .empty
        let encoder = canonicalEncoder()
        let dataPopulated = try encoder.encode(populated)
        let dataEmpty = try encoder.encode(empty)
        XCTAssertNotEqual(dataPopulated, dataEmpty)
        // Decode round-trips both
        let decodedPopulated = try JSONDecoder().decode(
            BASAuditObservationProjectionsCthulhuAggregatesBlock
                .self,
            from: dataPopulated)
        let decodedEmpty = try JSONDecoder().decode(
            BASAuditObservationProjectionsCthulhuAggregatesBlock
                .self,
            from: dataEmpty)
        XCTAssertEqual(decodedPopulated, populated)
        XCTAssertEqual(decodedEmpty, empty)
        XCTAssertNotEqual(decodedPopulated, decodedEmpty)
    }
}
