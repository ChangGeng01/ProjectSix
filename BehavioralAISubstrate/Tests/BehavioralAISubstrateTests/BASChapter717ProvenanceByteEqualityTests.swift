// MARK: - BASChapter717ProvenanceByteEqualityTests
// chapter 七百十七 第三刀 / M2258
//
// SAFETY-CRITICAL test:proves that
// BASOrganTrainedWeightFilter.rejectionReason(for:) produces
// IDENTICAL output regardless of which decision-tree path is
// selected by `useRoutedFilter`。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASOrgan

final class BASChapter717ProvenanceByteEqualityTests:
    XCTestCase
{
    override func tearDown() {
        // Restore the CURRENT production default (true, flipped ON
        // at M2260 / da2d5a168) — not the pre-flip `false`,which
        // would leave the global in a non-production state for any
        // later test that reads it。
        BASOrganTrainedWeightFilter.useRoutedFilter = true
        super.tearDown()
    }

    private let goodHash =
        "ba7816bf8f01cfea414140de5dae2223" +
        "b00361a396177a9cb410ff61f20015ad"

    private func makeProvenance(
        trainingHash: String? = nil,
        weightsHash: String? = nil,
        tier: BASOrganTrainedWeightProvenance.Tier =
            .domainExpertReviewed,
        attestationRef: String? = "att-ref",
        attestationAt: Date? = Date(
            timeIntervalSince1970: 1_700_000_000)
    ) -> BASOrganTrainedWeightProvenance {
        return BASOrganTrainedWeightProvenance(
            adapterID: "adapter-1",
            baseModelID: "base-1",
            tier: tier,
            trainingCurriculumRef: "curriculum-1",
            trainingCorpusHashHex:
                trainingHash ?? goodHash,
            trainedWeightsHashHex:
                weightsHash ?? goodHash,
            expertAttestationSignatureRef: attestationRef,
            attestationIssuedAt: attestationAt)
    }

    private func bothPathDecisions(
        _ p: BASOrganTrainedWeightProvenance
    ) -> (
        legacy: BASOrganTrainedWeightFilter.Rejection?,
        routed: BASOrganTrainedWeightFilter.Rejection?
    ) {
        BASOrganTrainedWeightFilter.useRoutedFilter = false
        let legacy = BASOrganTrainedWeightFilter
            .rejectionReason(for: p)
        BASOrganTrainedWeightFilter.useRoutedFilter = true
        let routed = BASOrganTrainedWeightFilter
            .rejectionReason(for: p)
        return (legacy, routed)
    }

    // MARK: - Happy path

    func testPermittedBothPaths() {
        let p = makeProvenance()
        let (legacy, routed) = bothPathDecisions(p)
        XCTAssertNil(legacy)
        XCTAssertNil(routed)
    }

    // MARK: - Hash-length variants

    func testMalformedTrainingCorpusLength() {
        let p = makeProvenance(trainingHash: "short")
        let (legacy, routed) = bothPathDecisions(p)
        XCTAssertEqual(legacy, routed)
        if case .malformedHash(
            let field, let length) = legacy
        {
            XCTAssertEqual(field, "trainingCorpusHashHex")
            XCTAssertEqual(length, 5)
        } else { XCTFail("expected malformedHash") }
    }

    func testMalformedTrainedWeightsLength() {
        let p = makeProvenance(weightsHash: "tiny")
        let (legacy, routed) = bothPathDecisions(p)
        XCTAssertEqual(legacy, routed)
        if case .malformedHash(let field, _) = legacy {
            XCTAssertEqual(field, "trainedWeightsHashHex")
        } else { XCTFail("expected malformedHash") }
    }

    // MARK: - Hash-content variants

    func testMalformedTrainingCorpusContent() {
        let bad = String(repeating: "z", count: 64)
        let p = makeProvenance(trainingHash: bad)
        let (legacy, routed) = bothPathDecisions(p)
        XCTAssertEqual(legacy, routed)
        if case .malformedHashContent(
            let field, let firstBad) = legacy
        {
            XCTAssertEqual(field, "trainingCorpusHashHex")
            XCTAssertEqual(firstBad, "z")
        } else { XCTFail("expected malformedHashContent") }
    }

    func testMalformedTrainedWeightsContent() {
        let bad = "G" + String(
            repeating: "a", count: 63)
        let p = makeProvenance(weightsHash: bad)
        let (legacy, routed) = bothPathDecisions(p)
        XCTAssertEqual(legacy, routed)
        if case .malformedHashContent(
            let field, let firstBad) = legacy
        {
            XCTAssertEqual(field, "trainedWeightsHashHex")
            XCTAssertEqual(firstBad, "G")
        } else { XCTFail("expected malformedHashContent") }
    }

    // MARK: - Tier variants

    func testBelowProductionTierWithoutAttestation() {
        let p = makeProvenance(
            tier: .peerReviewed,
            attestationRef: nil,
            attestationAt: nil)
        let (legacy, routed) = bothPathDecisions(p)
        XCTAssertEqual(legacy, routed)
        if case .belowProductionTier(let t) = legacy {
            XCTAssertEqual(t, .peerReviewed)
        } else { XCTFail("expected belowProductionTier") }
    }

    func testNonProductionTierCarryingAttestation() {
        let p = makeProvenance(
            tier: .aiAdvisory,
            attestationRef: "att-ref",
            attestationAt: nil)
        let (legacy, routed) = bothPathDecisions(p)
        XCTAssertEqual(legacy, routed)
        XCTAssertEqual(
            legacy,
            .nonProductionTierCarriesAttestation)
    }

    func testProductionTierMissingSignatureRef() {
        let p = makeProvenance(attestationRef: nil)
        let (legacy, routed) = bothPathDecisions(p)
        XCTAssertEqual(legacy, routed)
        XCTAssertEqual(
            legacy,
            .missingAttestationForProductionTier)
    }

    func testProductionTierMissingIssuedAt() {
        let p = makeProvenance(attestationAt: nil)
        let (legacy, routed) = bothPathDecisions(p)
        XCTAssertEqual(legacy, routed)
        XCTAssertEqual(
            legacy,
            .missingAttestationForProductionTier)
    }

    // MARK: - Filter helpers parity

    func testIsPermittedForProductionMatches() {
        let good = makeProvenance()
        BASOrganTrainedWeightFilter.useRoutedFilter = false
        let legacyOk = BASOrganTrainedWeightFilter
            .isPermittedForProduction(good)
        BASOrganTrainedWeightFilter.useRoutedFilter = true
        let routedOk = BASOrganTrainedWeightFilter
            .isPermittedForProduction(good)
        XCTAssertEqual(legacyOk, routedOk)
        XCTAssertTrue(legacyOk)

        let bad = makeProvenance(tier: .illustrative)
        BASOrganTrainedWeightFilter.useRoutedFilter = false
        let legacyBad = BASOrganTrainedWeightFilter
            .isPermittedForProduction(bad)
        BASOrganTrainedWeightFilter.useRoutedFilter = true
        let routedBad = BASOrganTrainedWeightFilter
            .isPermittedForProduction(bad)
        XCTAssertEqual(legacyBad, routedBad)
        XCTAssertFalse(legacyBad)
    }
}
