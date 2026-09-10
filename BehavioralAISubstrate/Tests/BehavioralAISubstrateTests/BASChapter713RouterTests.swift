// MARK: - BASChapter713RouterTests
// chapter 七百十三 第四刀 / M2239
//
// Verifies BASAutoRouteRanker.forgetCascadeFilter +
// provenanceFilter + the BASCognitiveBrain helpers:
//
//   1. forget-cascade routing lands on Rust + produces correct
//      (kept, removed) index partition
//   2. provenance gate matches the Swift
//      BASOrganTrainedWeightFilter.rejectionReason decision tree
//      on every rejection variant + the happy path
//   3. brain helper ≡ ranker call (dual-mode parity)

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASHostKit

final class BASChapter713RouterTests: XCTestCase {

    // MARK: - Forget cascade routing

    func testForgetCascadeRoutesToRust() {
        let records = ["a", "b", "c", "d"]
        let targets = ["b", "d"]
        let r = BASAutoRouteRanker.forgetCascadeFilter(
            recordIds: records, targetIds: targets)
        #if os(iOS) || os(macOS)
        XCTAssertEqual(r.choice, .rustForgetCascadeFilter)
        #endif
        XCTAssertEqual(r.value.kept, [0, 2])
        XCTAssertEqual(r.value.removed, [1, 3])
    }

    func testForgetCascadeEmptyTargetsKeepsEverything() {
        let records = ["a", "b", "c"]
        let r = BASAutoRouteRanker.forgetCascadeFilter(
            recordIds: records, targetIds: [])
        XCTAssertEqual(r.value.kept, [0, 1, 2])
        XCTAssertTrue(r.value.removed.isEmpty)
    }

    func testForgetCascadeEmptyRecordsReturnsEmpty() {
        let r = BASAutoRouteRanker.forgetCascadeFilter(
            recordIds: [], targetIds: ["a", "b"])
        XCTAssertTrue(r.value.kept.isEmpty)
        XCTAssertTrue(r.value.removed.isEmpty)
    }

    func testForgetCascadeFullRemoval() {
        let records = ["x", "y", "z"]
        let targets = ["z", "y", "x"]
        let r = BASAutoRouteRanker.forgetCascadeFilter(
            recordIds: records, targetIds: targets)
        XCTAssertTrue(r.value.kept.isEmpty)
        XCTAssertEqual(r.value.removed, [0, 1, 2])
    }

    func testForgetCascadePreservesInsertionOrder() {
        let records = ["a", "b", "c", "d", "e"]
        // Out-of-order in cascade — kept/removed should still
        // reflect RECORD order,not target order。
        let targets = ["d", "b"]
        let r = BASAutoRouteRanker.forgetCascadeFilter(
            recordIds: records, targetIds: targets)
        XCTAssertEqual(r.value.kept, [0, 2, 4])
        XCTAssertEqual(r.value.removed, [1, 3])
    }

    func testForgetCascadeUnicodeIds() {
        let records = ["普通-id", "中文-id", "ascii"]
        let targets = ["中文-id"]
        let r = BASAutoRouteRanker.forgetCascadeFilter(
            recordIds: records, targetIds: targets)
        XCTAssertEqual(r.value.kept, [0, 2])
        XCTAssertEqual(r.value.removed, [1])
    }

    // MARK: - Provenance gate routing

    private static let goodHash =
        "ba7816bf8f01cfea414140de5dae2223"
        + "b00361a396177a9cb410ff61f20015ad"

    func testProvenancePermittedForProductionTier() {
        let r = BASAutoRouteRanker.provenanceFilter(
            trainingCorpusHashHex: Self.goodHash,
            trainedWeightsHashHex: Self.goodHash,
            tier: .domainExpertReviewed,
            hasAttestationSignatureRef: true,
            hasAttestationIssuedAt: true)
        #if os(iOS) || os(macOS)
        XCTAssertEqual(r.choice, .rustProvenanceFilter)
        #endif
        XCTAssertEqual(r.value, .permitted)
        XCTAssertTrue(r.value.isPermitted)
    }

    func testProvenanceMalformedLengthTrainingCorpus() {
        let r = BASAutoRouteRanker.provenanceFilter(
            trainingCorpusHashHex: "short",
            trainedWeightsHashHex: Self.goodHash,
            tier: .domainExpertReviewed,
            hasAttestationSignatureRef: true,
            hasAttestationIssuedAt: true)
        XCTAssertEqual(r.value,
            .malformedHashLengthTrainingCorpus)
    }

    func testProvenanceMalformedLengthTrainedWeights() {
        let r = BASAutoRouteRanker.provenanceFilter(
            trainingCorpusHashHex: Self.goodHash,
            trainedWeightsHashHex: "way-too-short",
            tier: .domainExpertReviewed,
            hasAttestationSignatureRef: true,
            hasAttestationIssuedAt: true)
        XCTAssertEqual(r.value,
            .malformedHashLengthTrainedWeights)
    }

    func testProvenanceMalformedContentTrainingCorpus() {
        // 64 z's — passes length but fails content
        let badHash = String(repeating: "z", count: 64)
        let r = BASAutoRouteRanker.provenanceFilter(
            trainingCorpusHashHex: badHash,
            trainedWeightsHashHex: Self.goodHash,
            tier: .domainExpertReviewed,
            hasAttestationSignatureRef: true,
            hasAttestationIssuedAt: true)
        XCTAssertEqual(r.value,
            .malformedHashContentTrainingCorpus)
    }

    func testProvenanceMalformedContentTrainedWeights() {
        let badHash = "G" + String(
            repeating: "a", count: 63)
        let r = BASAutoRouteRanker.provenanceFilter(
            trainingCorpusHashHex: Self.goodHash,
            trainedWeightsHashHex: badHash,
            tier: .domainExpertReviewed,
            hasAttestationSignatureRef: true,
            hasAttestationIssuedAt: true)
        XCTAssertEqual(r.value,
            .malformedHashContentTrainedWeights)
    }

    func testProvenanceBelowProductionTierNoAttestation() {
        let r = BASAutoRouteRanker.provenanceFilter(
            trainingCorpusHashHex: Self.goodHash,
            trainedWeightsHashHex: Self.goodHash,
            tier: .peerReviewed,
            hasAttestationSignatureRef: false,
            hasAttestationIssuedAt: false)
        XCTAssertEqual(r.value, .belowProductionTier)
    }

    func testProvenanceNonProductionWithAttestationFlagged() {
        // Forged-uplift signal: non-prod tier carrying att。
        let r = BASAutoRouteRanker.provenanceFilter(
            trainingCorpusHashHex: Self.goodHash,
            trainedWeightsHashHex: Self.goodHash,
            tier: .aiAdvisory,
            hasAttestationSignatureRef: true,
            hasAttestationIssuedAt: false)
        XCTAssertEqual(r.value,
            .nonProductionTierCarriesAttestation)
    }

    func testProvenanceProductionTierMissingSigRef() {
        let r = BASAutoRouteRanker.provenanceFilter(
            trainingCorpusHashHex: Self.goodHash,
            trainedWeightsHashHex: Self.goodHash,
            tier: .domainExpertReviewed,
            hasAttestationSignatureRef: false,
            hasAttestationIssuedAt: true)
        XCTAssertEqual(r.value,
            .missingAttestationForProductionTier)
    }

    func testProvenanceProductionTierMissingIssuedAt() {
        let r = BASAutoRouteRanker.provenanceFilter(
            trainingCorpusHashHex: Self.goodHash,
            trainedWeightsHashHex: Self.goodHash,
            tier: .domainExpertReviewed,
            hasAttestationSignatureRef: true,
            hasAttestationIssuedAt: false)
        XCTAssertEqual(r.value,
            .missingAttestationForProductionTier)
    }

    func testProvenanceUppercaseHexAccepted() {
        let upperHash =
            "BA7816BF8F01CFEA414140DE5DAE2223"
            + "B00361A396177A9CB410FF61F20015AD"
        let r = BASAutoRouteRanker.provenanceFilter(
            trainingCorpusHashHex: upperHash,
            trainedWeightsHashHex: upperHash,
            tier: .domainExpertReviewed,
            hasAttestationSignatureRef: true,
            hasAttestationIssuedAt: true)
        XCTAssertEqual(r.value, .permitted)
    }

    // MARK: - Brain helpers

    func testBrainForgetCascadeMatchesRanker() {
        let records = ["a", "b", "c"]
        let targets = ["b"]
        let viaBrain = BASCognitiveBrain
            .forgetCascadeFilterAuto(
                recordIds: records, targetIds: targets)
        let viaRanker = BASAutoRouteRanker
            .forgetCascadeFilter(
                recordIds: records, targetIds: targets)
        XCTAssertEqual(viaBrain.choice, viaRanker.choice)
        XCTAssertEqual(viaBrain.value.kept,
            viaRanker.value.kept)
        XCTAssertEqual(viaBrain.value.removed,
            viaRanker.value.removed)
    }

    func testBrainProvenanceMatchesRanker() {
        let viaBrain = BASCognitiveBrain
            .provenanceFilterAuto(
                trainingCorpusHashHex: Self.goodHash,
                trainedWeightsHashHex: Self.goodHash,
                tier: .domainExpertReviewed,
                hasAttestationSignatureRef: true,
                hasAttestationIssuedAt: true)
        let viaRanker = BASAutoRouteRanker
            .provenanceFilter(
                trainingCorpusHashHex: Self.goodHash,
                trainedWeightsHashHex: Self.goodHash,
                tier: .domainExpertReviewed,
                hasAttestationSignatureRef: true,
                hasAttestationIssuedAt: true)
        XCTAssertEqual(viaBrain.choice, viaRanker.choice)
        XCTAssertEqual(viaBrain.value, viaRanker.value)
    }
}
