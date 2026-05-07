// MARK: - BASChengluMemoryAspirationalAdapterTests — chapter 三百三六 / M823
//
// Tests for the Swift-side aspirational adapter that closes
// the in-repo portion of the chapter 一百七十七 P1 vision
// (`ChengluMemory.mlpackage` 5-head training)。
//
// Doctrine pins verified:
//   - 5 aspirational output key constants typed-pinned
//   - allOutputKeys count == 5
//   - outputCount == 5
//   - Closure-based factory works (testable today, no real
//     model needed)
//   - Layer ID propagation through factory

import XCTest
@testable import BASAppleAdapters
@testable import BASRuntimeCore

final class BASChengluMemoryAspirationalAdapterTests: XCTestCase
{
    // MARK: - Output key constants pinning

    func testOutputKeysPinned() {
        XCTAssertEqual(
            BASChengluMemoryAspirationalAdapter.embeddingKey,
            "embedding")
        XCTAssertEqual(
            BASChengluMemoryAspirationalAdapter.memoryTypeKey,
            "memory_type")
        XCTAssertEqual(
            BASChengluMemoryAspirationalAdapter.memoryDecayKey,
            "memory_decay")
        XCTAssertEqual(
            BASChengluMemoryAspirationalAdapter
                .retrievalRerankKey,
            "retrieval_rerank")
        XCTAssertEqual(
            BASChengluMemoryAspirationalAdapter
                .conflictScoreKey,
            "conflict_score")
    }

    func testAllOutputKeysHas5Entries() {
        XCTAssertEqual(
            BASChengluMemoryAspirationalAdapter.allOutputKeys
                .count,
            5)
    }

    func testOutputCountIs5() {
        XCTAssertEqual(
            BASChengluMemoryAspirationalAdapter.outputCount, 5)
    }

    func testAllOutputKeysAreUnique() {
        let keys = BASChengluMemoryAspirationalAdapter
            .allOutputKeys
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    // MARK: - Closure-based factory

    func testMakeWithClosureReturnsHeadAtCorrectLayer() {
        let head = BASChengluMemoryAspirationalAdapter
            .make(
                headID: "test-memory-head",
                layerIDPin: .l8,
                outputKey: BASChengluMemoryAspirationalAdapter
                    .memoryTypeKey,
                inferenceClosure: { _ in
                    BASCoreMLPredictionFrame(
                        scores: ["memory_type": 0.85],
                        modelDescription: "stub",
                        inferenceLatencyMs: 0.5)
                })
        XCTAssertEqual(head.layerIDPin, .l8)
        XCTAssertEqual(head.headID, "test-memory-head")
    }

    func testFactoryClosureReachesInferenceTransformer()
        async throws
    {
        let head = BASChengluMemoryAspirationalAdapter
            .make(
                headID: "memory-test",
                layerIDPin: .l8,
                outputKey: BASChengluMemoryAspirationalAdapter
                    .memoryDecayKey,
                inferenceClosure: { _ in
                    BASCoreMLPredictionFrame(
                        scores: ["memory_decay": 0.42],
                        inferenceLatencyMs: 0.3)
                })
        let ref = try BASChengluFeatureRefBuilder.build(
            from: bASChengluDefaultSignature)
        let input = BASLayerInferenceInput(
            layerID: .l8,
            featureRef: ref,
            confidenceFloor: .high)
        let output = try await head.infer(input: input)
        XCTAssertEqual(output.layerID, .l8)
        XCTAssertEqual(
            output.scores["memory_decay"] ?? 0, 0.42,
            accuracy: 0.001)
        // Aspirational adapter emits typed reason codes
        XCTAssertTrue(output.reasonCodes.contains(
            "coreml-head:chenglu-memory-aspirational"))
        XCTAssertTrue(output.reasonCodes.contains(
            "coreml-output-key:memory_decay"))
    }

    // MARK: - Doctrine note pinning

    /// Pin the doctrine: this adapter's `make(model:)` exists
    /// for forward-compat but no shipped model is bound to
    /// these output keys today。If a future contributor adds
    /// a model with `embedding` / `memory_type` / etc. outputs,
    /// this adapter is ready。
    func testAspirationalKeysFollowChapter177Vision() {
        // Pin the 5 keys mirror chapter 一百七十七 P1 vision
        let expected = [
            "embedding",
            "memory_type",
            "memory_decay",
            "retrieval_rerank",
            "conflict_score"
        ]
        XCTAssertEqual(
            Set(BASChengluMemoryAspirationalAdapter
                .allOutputKeys),
            Set(expected),
            "Output keys must match chapter 一百七十七 P1 " +
            "vision verbatim")
    }
}
