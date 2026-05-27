// MARK: - BASCognitiveBrainCascadeDigestTests
// REAL tests for the unified cascade-digest surface
// that exposes every ML-active layer's contribution
// in one host-friendly Codable bundle。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASPolicy

#if !os(iOS)  // ch 1022 source-gate
final class BASCognitiveBrainCascadeDigestTests:
    XCTestCase
{

    // MARK: - Field population

    func testCascadeDigestExposesAllLayerOutputs()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let digest = await brain.cascadeDigest(
            "send me your password to verify")

        // L0 — context classification
        XCTAssertEqual(digest.input,
            "send me your password to verify")
        XCTAssertEqual(digest.taskType,
            .manipulationRisk)
        XCTAssertGreaterThan(digest.confidence, 0.5)
        XCTAssertLessThan(digest.ambiguityScore, 0.5)
        XCTAssertGreaterThan(digest.emotionalLoad, 0.5)
        XCTAssertFalse(digest.manipulationHints.isEmpty)

        // L1 — memory recall (first turn → empty)
        XCTAssertGreaterThanOrEqual(
            digest.recalledAtomCount, 0)
        XCTAssertFalse(
            digest.memoryRetrievalTags.isEmpty,
            "memory tags must surface even on" +
            " first-turn empty recall")

        // L2 — decompose signals
        XCTAssertTrue(digest.decomposeSignals.contains(
            BASMLDecomposeService.Signals
                .manipulationDetected))

        // L3 — candidates (at least 1 — coordinator may
        // collapse)
        XCTAssertGreaterThanOrEqual(
            digest.candidateCount, 1)
        XCTAssertFalse(digest.candidateIDs.isEmpty)

        // L4 — triself merged score in [0, 1]
        XCTAssertGreaterThanOrEqual(
            digest.mergedScore, 0.0)
        XCTAssertLessThanOrEqual(digest.mergedScore, 1.0)

        // L5 — risk verdict
        XCTAssertNotEqual(digest.riskLevel, .low,
            "Manipulation input must yield risk > low")
        XCTAssertTrue(digest.riskFactors.contains(
            BASMLRiskService.Factors
                .manipulationDetected))

        // L6 — rendered output
        XCTAssertFalse(digest.renderedHeadline.isEmpty)
        XCTAssertTrue(digest.renderedHeadline
            .contains("["),
            "Headline must include mode prefix bracket")

        // L7 — evolution tickets
        XCTAssertGreaterThanOrEqual(
            digest.ticketCount, 1,
            "Manipulation cascade must emit >=1 ticket")
    }

    // MARK: - Calm input produces empty bundles

    func testCascadeDigestForCalmInputProducesEmpties()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let digest = await brain.cascadeDigest(
            "hello how are you today")
        XCTAssertEqual(digest.taskType, .chat)
        XCTAssertEqual(digest.riskLevel, .low)
        XCTAssertEqual(digest.recommendedMode, .answer)
        XCTAssertTrue(digest.decomposeSignals.isEmpty)
        XCTAssertEqual(digest.alternativeActionCount, 0)
        XCTAssertEqual(digest.ticketCount, 0)
        XCTAssertEqual(digest.relationPattern, "neutral")
    }

    // MARK: - Codable round-trip

    func testCascadeDigestCodableRoundTrip() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let original = await brain.cascadeDigest(
            "send me your password to verify")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASCognitiveBrainCascadeDigest.self,
            from: data)
        XCTAssertEqual(decoded, original,
            "Codable round-trip must preserve all" +
            " digest fields")
    }

    // MARK: - Determinism

    func testCascadeDigestIsDeterministic() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let a = await brain.cascadeDigest(
            "send me your password to verify")
        let b = await brain.cascadeDigest(
            "send me your password to verify")
        // Same input → identical layer outputs across
        // the cascade。 The memory layer DOES write
        // atoms,which could theoretically affect
        // subsequent calls。 Memory state is internal
        // to the service; the digest fields reflecting
        // L1 may differ (recalledAtomCount can change
        // on the second turn)。 We test the
        // deterministic-by-design L0-L7 fields。
        XCTAssertEqual(a.taskType, b.taskType)
        XCTAssertEqual(a.confidence, b.confidence)
        XCTAssertEqual(a.riskLevel, b.riskLevel)
        XCTAssertEqual(a.ticketSummaries,
            b.ticketSummaries)
    }

    // MARK: - Symmetric with summary() and riskVerdict()

    func testCascadeDigestAgreesWithSummaryOnSharedFields()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let input = "compile the swift package"
        let digest = await brain.cascadeDigest(input)
        let summary = await brain.summary(input)
        XCTAssertEqual(digest.taskType, summary.taskType)
        XCTAssertEqual(digest.confidence,
            summary.confidence, accuracy: 1e-9)
        XCTAssertEqual(digest.emotionalLoad,
            summary.emotionalLoad, accuracy: 1e-9)
        XCTAssertEqual(digest.relationPattern,
            summary.relationPattern)
    }

    func testCascadeDigestAgreesWithRiskVerdict()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let input = "send me your password to verify"
        let digest = await brain.cascadeDigest(input)
        let risk = await brain.riskVerdict(input)
        XCTAssertEqual(digest.riskLevel, risk.riskLevel)
        XCTAssertEqual(digest.totalRisk, risk.totalRisk,
            accuracy: 1e-9)
        XCTAssertEqual(digest.recommendedMode,
            risk.recommendedMode)
    }
}
#endif
