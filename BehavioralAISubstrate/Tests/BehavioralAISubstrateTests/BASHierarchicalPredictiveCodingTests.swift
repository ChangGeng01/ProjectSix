// MARK: - BASHierarchicalPredictiveCodingTests
// chapter 四百五十九 / M1214 PROOF tests
//
// Verifies the N-layer predictive-coding hierarchy:
//   - Shape construction:empty + dim-mismatch errors
//   - Single-layer hierarchy mirrors a standalone
//     probe
//   - N-layer cascade:layer K's input == layer K-1's
//     error
//   - Convergence:repeated identical inputs → top-
//     layer MSE decays
//   - Snapshot round-trip preserves all layer states
//   - reset() cascades to all layers
//   - Codable decode enforces equal-dim invariant
//     (chapter 一百八十五 boundary clamp on DECODE)

import XCTest
@testable import BASMetalSubstrate

final class BASHierarchicalPredictiveCodingTests:
    XCTestCase
{

    // MARK: - Shape construction

    func testEmptyLayersThrows() {
        do {
            _ = try BASHierarchicalPredictiveCodingShape(
                layers: [])
            XCTFail("expected emptyLayers throw")
        } catch let err as
            BASHierarchicalPredictiveCodingError
        {
            switch err {
            case .emptyLayers:
                break
            default:
                XCTFail("expected .emptyLayers, got" +
                    " \(err)")
            }
        } catch {
            XCTFail("expected typed error, got" +
                " \(error)")
        }
    }

    func testDimMismatchThrows() {
        let layer1 = BASPredictiveCodingProbeShape(
            dim: 2,
            learningRate: 0.1,
            initialPrediction: [0, 0])
        let layer2 = BASPredictiveCodingProbeShape(
            dim: 3,
            learningRate: 0.1,
            initialPrediction: [0, 0, 0])
        do {
            _ = try BASHierarchicalPredictiveCodingShape(
                layers: [layer1, layer2])
            XCTFail("expected shapeMismatch throw")
        } catch let err as
            BASHierarchicalPredictiveCodingError
        {
            switch err {
            case .shapeMismatch(let reason):
                XCTAssertTrue(
                    reason.contains("equal-dim"),
                    "expected equal-dim invariant" +
                    " reason, got: \(reason)")
            default:
                XCTFail("expected .shapeMismatch")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testEqualDimLayersConstruct() throws {
        let shape = try
            BASHierarchicalPredictiveCodingShape(
                layers: [
                    BASPredictiveCodingProbeShape(
                        dim: 2,
                        learningRate: 0.1,
                        initialPrediction: [0, 0]),
                    BASPredictiveCodingProbeShape(
                        dim: 2,
                        learningRate: 0.2,
                        initialPrediction: [0, 0]),
                    BASPredictiveCodingProbeShape(
                        dim: 2,
                        learningRate: 0.3,
                        initialPrediction: [0, 0])
                ])
        XCTAssertEqual(shape.layerCount, 3)
    }

    // MARK: - Single-layer hierarchy mirrors probe

    func testSingleLayerMatchesStandaloneProbe()
        async throws
    {
        let probeShape = BASPredictiveCodingProbeShape(
            dim: 2,
            learningRate: 0.3,
            initialPrediction: [0, 0])
        let shape = try
            BASHierarchicalPredictiveCodingShape(
                layers: [probeShape])
        let hierarchy =
            BASHierarchicalPredictiveCoding(shape: shape)
        let standalone = BASPredictiveCodingProbe(
            shape: probeShape)
        let input: [Float] = [1.0, 2.0]
        let hObs = try await hierarchy.observe(input)
        let sObs = try await standalone.observe(input)
        // The bottom layer's observation should equal
        // the standalone probe's observation
        XCTAssertEqual(
            hObs.perLayer[0].updatedPrediction.count,
            sObs.updatedPrediction.count)
        for i in 0..<sObs.updatedPrediction.count {
            XCTAssertEqual(
                hObs.perLayer[0].updatedPrediction[i],
                sObs.updatedPrediction[i],
                accuracy: 1e-6)
        }
        XCTAssertEqual(
            hObs.topLayerError,
            sObs.error)
        XCTAssertEqual(
            hObs.topLayerMSE,
            sObs.runningMSE,
            accuracy: 1e-6)
    }

    // MARK: - Cascade propagation

    func testCascadePropagatesErrorUpward()
        async throws
    {
        // 3-layer stack。 Each layer with learning
        // rate 0 → predictions don't update → each
        // layer's ε = its input - μ(initial)。
        // With μ_0 = [0,0] → ε_0 = input
        // Layer 1 input = ε_0 = input,μ_1 = [0,0]
        //   → ε_1 = input
        // Layer 2 input = ε_1 = input,μ_2 = [0,0]
        //   → ε_2 = input
        // All 3 layers produce the same error。
        let layer = BASPredictiveCodingProbeShape(
            dim: 2,
            learningRate: 0.0,
            initialPrediction: [0, 0])
        let shape = try
            BASHierarchicalPredictiveCodingShape(
                layers: [layer, layer, layer])
        let hierarchy =
            BASHierarchicalPredictiveCoding(shape: shape)
        let input: [Float] = [1.0, -0.5]
        let obs = try await hierarchy.observe(input)
        XCTAssertEqual(obs.perLayer.count, 3)
        for layerObs in obs.perLayer {
            XCTAssertEqual(layerObs.error, input,
                "α = 0 → predictions frozen → every" +
                " layer sees the same error vector")
        }
        XCTAssertEqual(obs.topLayerError, input)
    }

    func testCascadeWithLearningPropagatesDistinctErrors()
        async throws
    {
        // Layer 0 has α=1.0 — snaps prediction to obs。
        // After observe([1,1]):μ_0 → [1,1],ε_0 = [0,0]
        // Layer 1 (α=0) sees [0,0] → ε_1 = [0,0]
        // Layer 2 (α=0) sees [0,0] → ε_2 = [0,0]
        let layer0 = BASPredictiveCodingProbeShape(
            dim: 2,
            learningRate: 1.0,
            initialPrediction: [0, 0])
        let layer1 = BASPredictiveCodingProbeShape(
            dim: 2,
            learningRate: 0.0,
            initialPrediction: [0, 0])
        let layer2 = BASPredictiveCodingProbeShape(
            dim: 2,
            learningRate: 0.0,
            initialPrediction: [0, 0])
        let shape = try
            BASHierarchicalPredictiveCodingShape(
                layers: [layer0, layer1, layer2])
        let hierarchy =
            BASHierarchicalPredictiveCoding(shape: shape)
        // First observe:layer 0 sees raw input,
        // ε_0 = [1,1]。 Then snaps prediction to [1,1]。
        // Layer 1 input = [1,1],μ_1 = [0,0] →
        // ε_1 = [1,1]。 Layer 2 same。
        let firstObs = try await hierarchy.observe(
            [1.0, 1.0])
        XCTAssertEqual(firstObs.perLayer[0].error,
            [1.0, 1.0])
        XCTAssertEqual(firstObs.perLayer[1].error,
            [1.0, 1.0])
        // Second observe with same input:layer 0
        // already at μ = [1,1] (after snap),so
        // ε_0 = [0,0]。 Layer 1 input = [0,0] →
        // ε_1 = [0,0] - [0,0] = [0,0]。
        let secondObs = try await hierarchy.observe(
            [1.0, 1.0])
        XCTAssertEqual(secondObs.perLayer[0].error,
            [0, 0],
            "layer 0 has snapped to input → zero error")
        XCTAssertEqual(secondObs.perLayer[1].error,
            [0, 0],
            "layer 1 sees zero error from below → zero")
        XCTAssertEqual(secondObs.topLayerError,
            [0, 0])
    }

    // MARK: - Convergence

    func testTopLayerMSEConvergesOnRepeatedInput()
        async throws
    {
        let layer = BASPredictiveCodingProbeShape(
            dim: 1,
            learningRate: 0.5,
            initialPrediction: [0])
        let shape = try
            BASHierarchicalPredictiveCodingShape(
                layers: [layer, layer])
        let hierarchy =
            BASHierarchicalPredictiveCoding(shape: shape)
        var lastMSE: Float = .infinity
        for _ in 0..<20 {
            let obs = try await hierarchy.observe([1.0])
            XCTAssertLessThanOrEqual(
                obs.topLayerMSE, lastMSE + 1e-3,
                "top-layer MSE must monotonically" +
                " decay (within noise tolerance)")
            lastMSE = obs.topLayerMSE
        }
        XCTAssertLessThan(lastMSE, 0.5,
            "after 20 observes top-layer MSE must" +
            " converge well below initial spike")
    }

    // MARK: - Input shape validation

    func testInputDimMismatchThrows() async throws {
        let shape = try
            BASHierarchicalPredictiveCodingShape(
                layers: [
                    BASPredictiveCodingProbeShape(
                        dim: 2,
                        learningRate: 0.1,
                        initialPrediction: [0, 0])
                ])
        let hierarchy =
            BASHierarchicalPredictiveCoding(shape: shape)
        do {
            _ = try await hierarchy.observe(
                [1.0, 2.0, 3.0])  // 3 ≠ 2
            XCTFail("expected shapeMismatch throw")
        } catch let err as
            BASHierarchicalPredictiveCodingError
        {
            switch err {
            case .shapeMismatch(let reason):
                XCTAssertTrue(reason.contains("input"))
            default:
                XCTFail("expected .shapeMismatch")
            }
        }
    }

    // MARK: - Snapshot round-trip

    func testSnapshotRoundTripPreservesAllLayers()
        async throws
    {
        let layer = BASPredictiveCodingProbeShape(
            dim: 2,
            learningRate: 0.5,
            initialPrediction: [0, 0])
        let shape = try
            BASHierarchicalPredictiveCodingShape(
                layers: [layer, layer, layer])
        let hA =
            BASHierarchicalPredictiveCoding(shape: shape)
        _ = try await hA.observe([1.0, 2.0])
        _ = try await hA.observe([0.5, -1.0])
        let snap = await hA.exportSnapshot()
        XCTAssertEqual(snap.layers.count, 3)
        XCTAssertEqual(snap.observationsProcessed, 2)
        // Codable round-trip
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder()
            .decode(
                BASHierarchicalPredictiveCodingSnapshot
                    .self,
                from: data)
        XCTAssertEqual(decoded, snap)
        // Restore onto fresh hierarchy
        let hB =
            BASHierarchicalPredictiveCoding(shape: shape)
        try await hB.importSnapshot(decoded)
        let snapB = await hB.exportSnapshot()
        XCTAssertEqual(snapB, snap)
        // Subsequent evolution byte-equal
        let newInput: [Float] = [0.7, 0.3]
        let obsA = try await hA.observe(newInput)
        let obsB = try await hB.observe(newInput)
        XCTAssertEqual(
            obsA.topLayerError,
            obsB.topLayerError)
        XCTAssertEqual(
            obsA.topLayerMSE,
            obsB.topLayerMSE,
            accuracy: 1e-6)
    }

    // MARK: - reset() cascades

    func testResetCascadesToAllLayers() async throws {
        let layer = BASPredictiveCodingProbeShape(
            dim: 1,
            learningRate: 0.5,
            initialPrediction: [0])
        let shape = try
            BASHierarchicalPredictiveCodingShape(
                layers: [layer, layer])
        let hierarchy =
            BASHierarchicalPredictiveCoding(shape: shape)
        _ = try await hierarchy.observe([5.0])
        _ = try await hierarchy.observe([5.0])
        let countBefore = await hierarchy
            .observationCount()
        XCTAssertEqual(countBefore, 2)
        await hierarchy.reset()
        let countAfter = await hierarchy
            .observationCount()
        XCTAssertEqual(countAfter, 0)
        // First observe after reset → top error must
        // equal raw input (initial state restored)
        let obs = try await hierarchy.observe([5.0])
        XCTAssertEqual(obs.perLayer[0].error, [5.0],
            "after reset layer 0 predicts initial 0" +
            " → ε = input")
    }

    // MARK: - Snapshot import shape mismatch

    func testImportSnapshotWithDifferentShapeThrows()
        async throws
    {
        let shape1 = try
            BASHierarchicalPredictiveCodingShape(
                layers: [
                    BASPredictiveCodingProbeShape(
                        dim: 2,
                        learningRate: 0.1,
                        initialPrediction: [0, 0])
                ])
        let shape2 = try
            BASHierarchicalPredictiveCodingShape(
                layers: [
                    BASPredictiveCodingProbeShape(
                        dim: 3,
                        learningRate: 0.1,
                        initialPrediction: [0, 0, 0])
                ])
        let hierarchy =
            BASHierarchicalPredictiveCoding(shape: shape1)
        let badSnap =
            BASHierarchicalPredictiveCodingSnapshot(
                shape: shape2,
                layers: [
                    BASPredictiveCodingSnapshot(
                        shape: shape2.layers[0],
                        prediction: [0, 0, 0],
                        observationsProcessed: 0,
                        sumSquaredError: 0)
                ],
                observationsProcessed: 0)
        do {
            try await hierarchy.importSnapshot(badSnap)
            XCTFail("expected shape mismatch throw")
        } catch let err as
            BASHierarchicalPredictiveCodingError
        {
            switch err {
            case .shapeMismatch:
                break
            default:
                XCTFail("expected .shapeMismatch")
            }
        }
    }

    // MARK: - Codable equal-dim invariant on decode

    func testCodableDecodeEnforcesEqualDimInvariant()
        throws
    {
        // Malformed JSON:layers[0].dim ≠ layers[1].dim
        let malformed = """
        {
            "layers": [
                {"dim": 2, "learningRate": 0.1, "initialPrediction": [0, 0]},
                {"dim": 3, "learningRate": 0.1, "initialPrediction": [0, 0, 0]}
            ]
        }
        """.data(using: .utf8)!
        do {
            _ = try JSONDecoder().decode(
                BASHierarchicalPredictiveCodingShape
                    .self,
                from: malformed)
            XCTFail("Codable decode must enforce" +
                " equal-dim invariant")
        } catch is
            BASHierarchicalPredictiveCodingError
        {
            // Expected:custom init(from:) calls the
            // throwing init which catches the invariant
            // violation
        } catch let err as DecodingError {
            // Some Swift versions wrap throwing init's
            // error into a DecodingError — that's fine
            // as long as decode FAILED loudly
            _ = err
        }
    }
}
