// MARK: - BASBrainDerivedSignalVectorTests
// 主线 全面 开发: brain.derivedSignalVector(forInput:)
// exposes the underlying 8-element Metal-derived
// signature vector,not just its L2 norm。 Lets hosts
// combine with brain.cosineSimilarity to build input-
// similarity search using only existing pilots — no
// new opt-in injection needed。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASBrainDerivedSignalVectorTests:
    XCTestCase
{
    // MARK: - Returns 8-element vector

    func testReturnsEightChannelVector() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let v = await brain.derivedSignalVector(
            forInput: "test input")
        XCTAssertNotNil(v)
        XCTAssertEqual(v!.count, 8,
            "SSMScan with D=8 → 8-element output")
    }

    func testNilWithoutMetalLoader() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let v = await brain.derivedSignalVector(
            forInput: "test")
        XCTAssertNil(v)
    }

    // MARK: - Determinism

    func testSameInputProducesSameVector() async throws {
        let brain1 = try await BASCognitiveBrain
            .makeWithAllPilots()
        let brain2 = try await BASCognitiveBrain
            .makeWithAllPilots()
        await brain2.clearVolatilePilotStorage()
        let v1 = await brain1.derivedSignalVector(
            forInput: "deterministic input")!
        let v2 = await brain2.derivedSignalVector(
            forInput: "deterministic input")!
        XCTAssertEqual(v1.count, v2.count)
        for i in 0..<v1.count {
            XCTAssertEqual(v1[i], v2[i], accuracy: 1e-5,
                "Element \(i) drifts across instances")
        }
    }

    func testDifferentInputsProduceDifferentVectors()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let va = await brain.derivedSignalVector(
            forInput: "alpha")!
        let vb = await brain.derivedSignalVector(
            forInput: "beta")!
        XCTAssertEqual(va.count, 8)
        XCTAssertEqual(vb.count, 8)
        // Statistically the 8-channel SHA256-derived
        // vectors should differ at every component。
        // A tolerance check tightens to "at least
        // ONE element differs by > 1e-4"。
        var anyDiffers = false
        for i in 0..<8 {
            if abs(va[i] - vb[i]) > 1e-4 {
                anyDiffers = true
                break
            }
        }
        XCTAssertTrue(anyDiffers,
            "At least one channel must differ across" +
            " distinct inputs")
    }

    // MARK: - Consistency with metalDerivedSignal

    func testVectorL2NormEqualsScalarSignal()
        async throws
    {
        // The brain.summary scalar `metalDerivedSignal`
        // is the L2 norm of the same 8-vector exposed
        // here。 Compute both,assert L2(vector) ==
        // scalar within float32 tolerance。
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let input = "consistency check input"
        let v = await brain.derivedSignalVector(
            forInput: input)!
        let summary = await brain.summary(input)
        let scalar = summary.metalDerivedSignal!
        var sumSq: Float = 0
        for x in v { sumSq += x * x }
        let computedNorm = sqrtf(sumSq)
        XCTAssertEqual(computedNorm, scalar,
            accuracy: 1e-4,
            "brain.summary.metalDerivedSignal ==" +
            " L2 norm of brain.derivedSignalVector")
    }

    // MARK: - Composes with brain.cosineSimilarity

    func testVectorSelfCosineEqualsOne() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let v = await brain.derivedSignalVector(
            forInput: "same self")!
        let r = try await brain.cosineSimilarity(v, v)
        XCTAssertEqual(r.similarity, 1.0,
            accuracy: 1e-4,
            "Vector cosine with itself = 1")
    }

    func testCrossPilotSimilarityRoundTrip() async throws {
        // End-to-end:two distinct inputs → two
        // signature vectors → cosineSimilarity gives a
        // real number in [-1, 1] that DIFFERS from
        // self-similarity (1.0)。
        //
        // Demonstrates the "build input-similarity
        // search using existing pilots" use case from
        // the doc comment。
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let va = await brain.derivedSignalVector(
            forInput: "input alpha")!
        let vb = await brain.derivedSignalVector(
            forInput: "input beta")!
        let crossSim = try await brain.cosineSimilarity(
            va, vb)
        XCTAssertGreaterThanOrEqual(
            crossSim.similarity, -1.0)
        XCTAssertLessThanOrEqual(
            crossSim.similarity, 1.0,
            "Cosine similarity is in [-1, 1]")
        XCTAssertNotEqual(crossSim.similarity, 1.0,
            "Distinct inputs should NOT have" +
            " similarity 1 (would only happen if" +
            " SHA256 produced identical 8-channel" +
            " vectors,statistically impossible)")
    }
}
