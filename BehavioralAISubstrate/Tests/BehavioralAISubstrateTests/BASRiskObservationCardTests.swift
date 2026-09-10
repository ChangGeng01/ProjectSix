// MARK: - BASRiskObservationCardTests
// chapter 五百七 / M1407 — 2nd Tier C primitive tests

import XCTest
@testable import BASRuntimeCore

private enum SampleRiskKind:
    String, Equatable, Hashable, Codable, Sendable,
    CaseIterable
{
    case dataLoss
    case integrityBreach
    case latencySpike
}

private struct SampleRiskBody:
    Equatable, Hashable, Codable, Sendable
{
    let detail: String
    let affectedRefs: [String]
}

final class BASRiskObservationCardTests: XCTestCase {

    private func sampleCard(
        severity: Double = 0.5,
        confidence: Double = 0.8,
        kind: SampleRiskKind = .dataLoss
    ) -> BASRiskObservationCard<SampleRiskKind,
                                SampleRiskBody>
    {
        return BASRiskObservationCard(
            riskID: "RISK-1",
            schemaVersion: "1.0.0",
            kind: kind,
            body: SampleRiskBody(
                detail: "test",
                affectedRefs: ["x"]),
            severityScore: severity,
            confidenceFloor: confidence,
            reasonCodes: ["test-reason"],
            observedAtMs: 0)
    }

    // MARK: - 1) Construction holds all fields

    func testConstructionHoldsAllFields() {
        let card = sampleCard()
        XCTAssertEqual(card.riskID, "RISK-1")
        XCTAssertEqual(card.schemaVersion, "1.0.0")
        XCTAssertEqual(card.kind, .dataLoss)
        XCTAssertEqual(card.severityScore, 0.5)
        XCTAssertEqual(card.confidenceFloor, 0.8)
        XCTAssertEqual(card.reasonCodes,
                       ["test-reason"])
    }

    // MARK: - 2) Severity clamped to [0, 1]

    func testSeverityClampedAboveOne() {
        let card = sampleCard(severity: 5.0)
        XCTAssertEqual(card.severityScore, 1.0,
            "severity > 1.0 MUST clamp to 1.0 per" +
            " L11 risk-plane invariant")
    }

    func testSeverityClampedBelowZero() {
        let card = sampleCard(severity: -0.5)
        XCTAssertEqual(card.severityScore, 0.0,
            "severity < 0 MUST clamp to 0")
    }

    // MARK: - 3) Confidence clamped to [0, 1]

    func testConfidenceClampedAboveOne() {
        let card = sampleCard(confidence: 1.5)
        XCTAssertEqual(card.confidenceFloor, 1.0)
    }

    func testConfidenceClampedBelowZero() {
        let card = sampleCard(confidence: -1.0)
        XCTAssertEqual(card.confidenceFloor, 0.0)
    }

    // MARK: - 4) requiresAction respects threshold

    func testRequiresActionAboveThreshold() {
        let card = sampleCard(severity: 0.8)
        XCTAssertTrue(card.requiresAction())
    }

    func testNoActionRequiredBelowThreshold() {
        let card = sampleCard(severity: 0.5)
        XCTAssertFalse(card.requiresAction())
    }

    func testRequiresActionExactlyAtThreshold() {
        let card = sampleCard(severity: 0.7)
        XCTAssertTrue(card.requiresAction(),
            "severity == 0.7 (threshold) MUST require" +
            " action (>= comparison)")
    }

    func testRequiresActionCustomThreshold() {
        let card = sampleCard(severity: 0.5)
        XCTAssertTrue(card.requiresAction(
            actionRequiredThreshold: 0.4))
        XCTAssertFalse(card.requiresAction(
            actionRequiredThreshold: 0.6))
    }

    // MARK: - 5) isTrustworthy respects min trust

    func testIsTrustworthyAboveMinTrust() {
        let card = sampleCard(confidence: 0.6)
        XCTAssertTrue(card.isTrustworthy())
    }

    func testIsTrustworthyBelowMinTrust() {
        let card = sampleCard(confidence: 0.3)
        XCTAssertFalse(card.isTrustworthy())
    }

    // MARK: - 6) effectiveWeightedRisk = severity × confidence

    func testEffectiveWeightedRisk() {
        let card = sampleCard(
            severity: 0.8,
            confidence: 0.5)
        XCTAssertEqual(card.effectiveWeightedRisk,
                       0.4, accuracy: 0.001)
    }

    func testEffectiveWeightedRiskStaysInRange() {
        let card = sampleCard(
            severity: 1.0,
            confidence: 1.0)
        XCTAssertEqual(card.effectiveWeightedRisk, 1.0)

        let zero = sampleCard(
            severity: 0.0,
            confidence: 1.0)
        XCTAssertEqual(zero.effectiveWeightedRisk, 0.0)
    }

    // MARK: - 7) Codable round-trip

    func testCodableRoundTrip() throws {
        let original = sampleCard(
            severity: 0.75,
            confidence: 0.85,
            kind: .integrityBreach)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRiskObservationCard<SampleRiskKind,
                                   SampleRiskBody>.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 8) Hashable

    func testHashable() {
        let c1 = sampleCard()
        let c2 = sampleCard()
        XCTAssertEqual(c1.hashValue, c2.hashValue)
        var seen = Set<BASRiskObservationCard<
            SampleRiskKind, SampleRiskBody>>()
        seen.insert(c1)
        seen.insert(c2)
        XCTAssertEqual(seen.count, 1)
    }

    // MARK: - 9) Sendable across actor boundary

    func testSendable() async {
        let card = sampleCard()
        let captured = card
        let task = Task {
            captured.effectiveWeightedRisk
        }
        let result = await task.value
        XCTAssertEqual(result, 0.4, accuracy: 0.001)
    }
}
