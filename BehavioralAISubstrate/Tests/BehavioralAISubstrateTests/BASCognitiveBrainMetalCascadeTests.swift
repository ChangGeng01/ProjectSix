// MARK: - BASCognitiveBrainMetalCascadeTests
// 主线 继续 开发: brain.summary now computes a Metal-
// derived deterministic signal IN the cascade when the
// Metal pilot is wired。 Pins:
//   - Same input → identical signature (determinism)
//   - Different inputs → different signatures
//   - Nil signature when Metal not wired
//   - Cache-hit path layers fresh Metal signature

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASCognitiveBrainMetalCascadeTests: XCTestCase {

    // MARK: - Nil without loader

    func testNoMetalLoaderProducesNilSignal() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let summary = await brain.summary("test input")
        XCTAssertNil(summary.metalDerivedSignal,
            "No Metal loader → nil signal")
    }

    // MARK: - Real signature with loader

    func testMetalLoaderProducesNonNilSignal() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let summary = await brain.summary("test input")
        XCTAssertNotNil(summary.metalDerivedSignal,
            "Metal loader wired → signature populated" +
            " from GPU dispatch")
        let signal = summary.metalDerivedSignal!
        XCTAssertGreaterThanOrEqual(signal, 0,
            "2D norm is non-negative")
    }

    // MARK: - Determinism — same input → same signature

    func testSameInputProducesSameSignature() async throws {
        let brainA = try await BASCognitiveBrain
            .makeWithAllPilots()
        let brainB = try await BASCognitiveBrain
            .makeWithAllPilots()
        let s1 = await brainA.summary("identical input")
        // Clear B's cache to force re-dispatch (the cache
        // would otherwise short-circuit before Metal
        // dispatch even runs)
        await brainB.clearVolatilePilotStorage()
        // Use a brain-B that hasn't seen the input yet
        let s2 = await brainB.summary("identical input")
        XCTAssertNotNil(s1.metalDerivedSignal)
        XCTAssertNotNil(s2.metalDerivedSignal)
        // Float32 GPU dispatch should be bit-stable for
        // identical inputs across two instances on the
        // same hardware (chapter 392 replay-determinism)。
        // Use a tight tolerance — anything > 1e-5 would
        // suggest non-determinism。
        XCTAssertEqual(s1.metalDerivedSignal!,
            s2.metalDerivedSignal!, accuracy: 1e-5,
            "Same input → identical signature across" +
            " brain instances")
    }

    // MARK: - Sensitivity — different inputs → different signatures

    func testDifferentInputsProduceDifferentSignatures()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let s1 = await brain.summary("alpha")
        let s2 = await brain.summary("beta")
        let s3 = await brain.summary("gamma")
        XCTAssertNotNil(s1.metalDerivedSignal)
        XCTAssertNotNil(s2.metalDerivedSignal)
        XCTAssertNotNil(s3.metalDerivedSignal)
        XCTAssertNotEqual(s1.metalDerivedSignal,
            s2.metalDerivedSignal,
            "alpha vs beta → different signatures")
        XCTAssertNotEqual(s2.metalDerivedSignal,
            s3.metalDerivedSignal)
        XCTAssertNotEqual(s1.metalDerivedSignal,
            s3.metalDerivedSignal)
    }

    // MARK: - Cache hit still computes fresh Metal signature

    func testCacheHitLayersFreshMetalSignature()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let first = await brain.summary("cached input")
        let second = await brain.summary("cached input")
        // Same input → same Metal signature even on cache hit
        XCTAssertEqual(first.metalDerivedSignal!,
            second.metalDerivedSignal!, accuracy: 1e-5,
            "Cache hit still produces (deterministically" +
            " identical) Metal signature")
        // But repetitionCount differs (per-call field)
        XCTAssertNotEqual(first.repetitionCount,
            second.repetitionCount)
    }

    // MARK: - Codable round-trip with new field

    func testSummaryCodableRoundTripWithMetalSignal()
        throws
    {
        let original = BASCognitiveBrainSummary(
            input: "x", taskType: .chat,
            confidence: 0.5, ambiguityScore: 0.5,
            safetyVerdict: .safe,
            manipulationHints: [], latencyNanos: 1,
            metalDerivedSignal: 0.7234567)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASCognitiveBrainSummary.self, from: data)
        XCTAssertEqual(decoded.metalDerivedSignal!,
            0.7234567, accuracy: 1e-6)
        XCTAssertEqual(decoded, original)
    }

    func testSummaryBackwardCompatNilMetalSignal() {
        let s = BASCognitiveBrainSummary(
            input: "x", taskType: .chat,
            confidence: 0.5, ambiguityScore: 0.5,
            safetyVerdict: .safe,
            manipulationHints: [], latencyNanos: 1)
        XCTAssertNil(s.metalDerivedSignal,
            "Legacy initializer defaults to nil")
    }
}
