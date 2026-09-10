// MARK: - BASChapter780StrongFlipTests
// chapter 七百八十 / M2551-M2555
//
// Verifies the 2 STRONG-FLIP decisions from chapter 七百七十九:
// production-default Rust routes for L6 presence fusion (7.51×)
// and L4 world-prior aggregation (5.12×)。
//
// Each test asserts:
//   1. Default route produces the same answer as the V1 inline
//      Swift fallback (byte-equality where applicable, IEEE 754
//      ε = 1e-9 for floating-point)
//   2. Default route works on Apple platforms (Rust path active)
//   3. Edge cases (empty input, invalid bytes) handled identically

import XCTest
@testable import BASOrchestration

final class BASChapter780StrongFlipTests: XCTestCase {

    // MARK: - presence-eye routed fusion

    func testPresenceFuseEmptyYieldsZero() {
        XCTAssertEqual(
            BASRoutedPresenceFusion.fuse(observations: []),
            0.0)
    }

    func testPresenceFuseDefaultMatchesSwiftInline() {
        let observations = [
            BASChannelObservationInput(channelByte: 0, salience: 0.5, confidence: 0.8),
            BASChannelObservationInput(channelByte: 1, salience: 0.6, confidence: 0.7),
            BASChannelObservationInput(channelByte: 2, salience: 0.7, confidence: 0.9),
            BASChannelObservationInput(channelByte: 3, salience: 0.4, confidence: 0.6),
            BASChannelObservationInput(channelByte: 4, salience: 0.5, confidence: 0.5),
        ]
        let viaDefault = BASRoutedPresenceFusion.fuse(
            observations: observations)
        let viaSwift = BASRoutedPresenceFusion.fuseViaSwiftInline(
            observations: observations)
        XCTAssertEqual(viaDefault, viaSwift, accuracy: 1e-9,
            "Default route must match Swift inline fallback")
    }

    func testPresenceFuseManipulationDominates() {
        // Strong manipulation signal, weak environment → result
        // biased toward manipulation per weight 2.0 vs 0.5。
        let observations = [
            BASChannelObservationInput(channelByte: 2, salience: 0.9, confidence: 1.0),
            BASChannelObservationInput(channelByte: 3, salience: 0.1, confidence: 1.0),
        ]
        let r = BASRoutedPresenceFusion.fuse(observations: observations)
        // (0.9 * 2.0 + 0.1 * 0.5) / (2.0 + 0.5) = 1.85 / 2.5 = 0.74
        XCTAssertEqual(r, 0.74, accuracy: 1e-9)
    }

    func testPresenceFuseDuplicateObservationsAveraged() {
        // 2 observations of the same channel → averaged before
        // weighting (mirrors Rust crate semantics)。
        let observations = [
            BASChannelObservationInput(channelByte: 0, salience: 0.8, confidence: 1.0),
            BASChannelObservationInput(channelByte: 0, salience: 0.4, confidence: 1.0),
        ]
        let r = BASRoutedPresenceFusion.fuse(observations: observations)
        // mean(0.8, 0.4) * weight(1.0) / total_weight(1.0) = 0.6
        XCTAssertEqual(r, 0.6, accuracy: 1e-9)
    }

    func testPresenceFuseInvalidChannelByteSkipped() {
        // Channel byte > 4 → defensively skipped (both paths)
        let observations = [
            BASChannelObservationInput(channelByte: 0, salience: 0.5, confidence: 1.0),
            BASChannelObservationInput(channelByte: 99, salience: 1.0, confidence: 1.0),
        ]
        let r = BASRoutedPresenceFusion.fuse(observations: observations)
        // Only task channel counts → score 0.5, weight 1.0 → 0.5
        XCTAssertEqual(r, 0.5, accuracy: 1e-9)
    }

    // MARK: - world-prior routed propagate_evidence

    func testWorldPriorEvidenceEmptyYieldsAnecdotal() {
        XCTAssertEqual(
            BASRoutedWorldPriorAggregation.propagateEvidence(
                levels: []),
            0) // Anecdotal
    }

    func testWorldPriorEvidenceWeakestWins() {
        // [Mechanistic=3, Anecdotal=0, PeerReviewed=2] → min is 0
        XCTAssertEqual(
            BASRoutedWorldPriorAggregation.propagateEvidence(
                levels: [3, 0, 2]),
            0)
    }

    func testWorldPriorEvidenceDefaultMatchesSwiftInline() {
        for levels in [[UInt8](),
                       [0],
                       [3, 3, 3],
                       [3, 2, 1, 0, 2, 3, 1, 2, 3, 0]] {
            let viaDefault = BASRoutedWorldPriorAggregation
                .propagateEvidence(levels: levels)
            let viaSwift = BASRoutedWorldPriorAggregation
                .propagateEvidenceViaSwiftInline(levels: levels)
            XCTAssertEqual(viaDefault, viaSwift,
                "Default ≡ Swift inline for levels=\(levels)")
        }
    }

    func testWorldPriorEvidenceInvalidByteYieldsMinus1() {
        XCTAssertEqual(
            BASRoutedWorldPriorAggregation.propagateEvidence(
                levels: [0, 99, 2]),
            -1)
    }

    // MARK: - world-prior routed aggregate_latency

    func testWorldPriorAggregateLatencyEmptyYieldsZero() {
        XCTAssertEqual(
            BASRoutedWorldPriorAggregation.aggregateLatency(
                latencies: []),
            0)
    }

    func testWorldPriorAggregateLatencyMean() {
        XCTAssertEqual(
            BASRoutedWorldPriorAggregation.aggregateLatency(
                latencies: [100, 200, 300]),
            200)
    }

    func testWorldPriorAggregateLatencyDefaultMatchesSwiftInline() {
        for latencies in [[Int64](),
                          [100],
                          [100, 200, 300],
                          [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]] {
            let viaDefault = BASRoutedWorldPriorAggregation
                .aggregateLatency(latencies: latencies)
            let viaSwift = BASRoutedWorldPriorAggregation
                .aggregateLatencyViaSwiftInline(latencies: latencies)
            XCTAssertEqual(viaDefault, viaSwift,
                "Default ≡ Swift inline for latencies=\(latencies)")
        }
    }

    // MARK: - world-prior routed worst_reversibility

    func testWorldPriorReversibilityEmptyYieldsEasy() {
        XCTAssertEqual(
            BASRoutedWorldPriorAggregation.worstReversibility(
                values: []),
            3) // Easy
    }

    func testWorldPriorReversibilityIrreversibleDominates() {
        // [Easy=3, Irreversible=0, Medium=2] → min is 0
        XCTAssertEqual(
            BASRoutedWorldPriorAggregation.worstReversibility(
                values: [3, 0, 2]),
            0)
    }

    func testWorldPriorReversibilityDefaultMatchesSwiftInline() {
        for values in [[UInt8](),
                       [0],
                       [3, 3, 3],
                       [3, 0, 2, 1, 3]] {
            let viaDefault = BASRoutedWorldPriorAggregation
                .worstReversibility(values: values)
            let viaSwift = BASRoutedWorldPriorAggregation
                .worstReversibilityViaSwiftInline(values: values)
            XCTAssertEqual(viaDefault, viaSwift,
                "Default ≡ Swift inline for values=\(values)")
        }
    }

    func testWorldPriorReversibilityInvalidByte() {
        XCTAssertEqual(
            BASRoutedWorldPriorAggregation.worstReversibility(
                values: [3, 99]),
            -1)
    }
}
