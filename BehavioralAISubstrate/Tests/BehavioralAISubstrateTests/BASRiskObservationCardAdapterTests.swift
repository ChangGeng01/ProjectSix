// MARK: - BASRiskObservationCardAdapterTests
// chapter 五百九 / M1413 — Tier C adapter tests

import XCTest
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASRiskObservationCardAdapterTests:
    XCTestCase
{

    private func sampleObservation(
        kind: BASRiskSignalKind = .hazardReading,
        intentID: String = "intent-a",
        salience: Double = 0.7,
        confidence: Double = 0.9,
        content: String = "sample-content",
        observedAt: Date = Date(
            timeIntervalSince1970: 1_700_000_000)
    ) -> BASRiskObservation {
        return BASRiskObservation(
            kind: kind,
            intentID: intentID,
            salience: salience,
            confidence: confidence,
            content: content,
            observedAt: observedAt)
    }

    // MARK: - 1) Single observation → card preserves
    //             core fields

    func testSingleObservationToCardPreservesCoreFields() {
        let obs = sampleObservation()
        let card = BASRiskObservationCardAdapter
            .card(from: obs)
        XCTAssertEqual(card.kind, .hazardReading)
        XCTAssertEqual(card.body.intentID, "intent-a")
        XCTAssertEqual(card.body.content,
                       "sample-content")
        XCTAssertEqual(card.severityScore, 0.7)
        XCTAssertEqual(card.confidenceFloor, 0.9)
    }

    // MARK: - 2) riskID composes intentID + observedAtMs

    func testRiskIDComposesStableIdentifier() {
        let obs = sampleObservation(
            intentID: "intent-x",
            observedAt: Date(
                timeIntervalSince1970: 1_700_000_000))
        let card = BASRiskObservationCardAdapter
            .card(from: obs)
        XCTAssertEqual(card.riskID,
                       "intent-x@1700000000000",
            "riskID composes intentID + observed-millis" +
            " for stable per-observation identification")
    }

    // MARK: - 3) observedAtMs derives from Date

    func testObservedAtMsDerivesFromDate() {
        let obs = sampleObservation(
            observedAt: Date(
                timeIntervalSince1970: 1_700_000_000))
        let card = BASRiskObservationCardAdapter
            .card(from: obs)
        XCTAssertEqual(card.observedAtMs,
                       1_700_000_000_000)
    }

    // MARK: - 4) Adapter respects severity clamping
    //             (re-uses primitive's invariant)

    func testAdapterRespectsClamping() {
        let obs = sampleObservation(
            salience: 1.5,  // out of range
            confidence: -0.2)
        let card = BASRiskObservationCardAdapter
            .card(from: obs)
        XCTAssertEqual(card.severityScore, 1.0,
            "salience > 1 clamps via primitive invariant")
        XCTAssertEqual(card.confidenceFloor, 0.0,
            "confidence < 0 clamps via primitive" +
            " invariant")
    }

    // MARK: - 5) Bundle → N cards preserves order

    func testBundleToCardsPreservesOrder() {
        let bundle = BASRiskObservationBundle(
            turnID: "T",
            sessionID: "S",
            observations: [
                sampleObservation(intentID: "i1"),
                sampleObservation(intentID: "i2"),
                sampleObservation(intentID: "i3"),
            ],
            emittedAt: Date(
                timeIntervalSince1970: 1_700_000_000))
        let cards = BASRiskObservationCardAdapter
            .cards(from: bundle)
        XCTAssertEqual(cards.count, 3)
        XCTAssertEqual(cards[0].body.intentID, "i1")
        XCTAssertEqual(cards[1].body.intentID, "i2")
        XCTAssertEqual(cards[2].body.intentID, "i3")
    }

    // MARK: - 6) Empty bundle → empty cards array

    func testEmptyBundleProducesEmptyCards() {
        let bundle = BASRiskObservationBundle(
            turnID: "T",
            sessionID: "S",
            observations: [],
            emittedAt: Date(
                timeIntervalSince1970: 0))
        let cards = BASRiskObservationCardAdapter
            .cards(from: bundle)
        XCTAssertTrue(cards.isEmpty)
    }

    // MARK: - 7) Determinism — same observation → same card

    func testDeterminism() {
        let obs = sampleObservation()
        let c1 = BASRiskObservationCardAdapter
            .card(from: obs)
        let c2 = BASRiskObservationCardAdapter
            .card(from: obs)
        XCTAssertEqual(c1, c2)
    }

    // MARK: - 8) Adapter preserves existing observation
    //             (read-only)

    func testAdapterPreservesOriginalObservation() {
        let obs = sampleObservation()
        let originalContent = obs.content
        _ = BASRiskObservationCardAdapter
            .card(from: obs)
        XCTAssertEqual(obs.content, originalContent,
            "adapter is read-only — does NOT mutate" +
            " original BASRiskObservation")
    }

    // MARK: - 9) Card retains primitive-derived queries

    func testCardRetainsDerivedQueries() {
        let highSev = sampleObservation(
            salience: 0.8, confidence: 0.7)
        let card = BASRiskObservationCardAdapter
            .card(from: highSev)
        XCTAssertTrue(card.requiresAction())
        XCTAssertTrue(card.isTrustworthy())
        XCTAssertEqual(card.effectiveWeightedRisk,
                       0.56, accuracy: 0.001)
    }

    // MARK: - 10) Codable round-trip on adapted card

    func testCardCodableRoundTripPreservesAdaptation()
        throws
    {
        let obs = sampleObservation()
        let original = BASRiskObservationCardAdapter
            .card(from: obs)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRiskObservationCard<
                BASRiskSignalKind,
                BASRiskObservationCardBody>.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }
}
