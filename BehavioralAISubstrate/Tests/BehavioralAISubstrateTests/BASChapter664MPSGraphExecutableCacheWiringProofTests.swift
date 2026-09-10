// MARK: - BASChapter664MPSGraphExecutableCacheWiringProofTests
// chapter 六百六十四 / M2034 — PROOF tests for the M2033
//                              BASMPSGraphExecutableCache
//                              storage-slot wiring (Phase
//                              J 第一刀:MPSGraphExecutable
//                              storage slot added to the
//                              cache actor)
//
// Verifies the new storage-slot accessors behave correctly:
//   - empty cache returns nil
//   - stored executable can be retrieved by key
//   - executableCount reflects storage state
//   - reset() drops cached executables
//   - recordHit/recordMiss continue to function (no
//     regression on M1297 observation surface)

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore
@preconcurrency import MetalPerformanceShadersGraph

final class BASChapter664MPSGraphExecutableCacheWiringProofTests:
    XCTestCase
{

    // MARK: - Storage-slot semantics

    func testEmptyCacheReturnsNil() async {
        let cache = BASMPSGraphExecutableCache()
        let key = BASMPSGraphCacheKey(
            operation: .rmsNorm,
            dataType: .float32,
            inputShapes: [[2, 4], [4]])
        let result = await cache.cachedExecutable(
            forKey: key)
        XCTAssertNil(result,
            "Empty cache must return nil for any key")
    }

    func testExecutableCountStartsAtZero() async {
        let cache = BASMPSGraphExecutableCache()
        let count = await cache.executableCount
        XCTAssertEqual(count, 0,
            "Fresh cache must have 0 stored executables")
    }

    func testStoreAndRetrieveExecutable() async throws {
        // Build a trivial MPSGraphExecutable so we have
        // a real instance to store + retrieve
        let graph = MPSGraph()
        let input = graph.placeholder(
            shape: [2, 2] as [NSNumber],
            dataType: .float32,
            name: "x")
        let output = graph.identity(
            with: input, name: "y")
        let inputShapeDesc = MPSGraphShapedType(
            shape: input.shape, dataType: input.dataType)
        let executable = graph.compile(
            with: nil,
            feeds: [input: inputShapeDesc],
            targetTensors: [output],
            targetOperations: nil,
            compilationDescriptor: nil)

        let cache = BASMPSGraphExecutableCache()
        let key = BASMPSGraphCacheKey(
            operation: .rmsNorm,
            dataType: .float32,
            inputShapes: [[2, 2]])
        await cache.storeExecutable(executable, forKey: key)

        let retrieved = await cache.cachedExecutable(
            forKey: key)
        XCTAssertNotNil(retrieved,
            "Stored executable must be retrievable by key")
        XCTAssertTrue(retrieved === executable,
            "Retrieved must be the same instance stored")

        let count = await cache.executableCount
        XCTAssertEqual(count, 1,
            "executableCount must reflect storage state")
    }

    func testResetDropsExecutables() async throws {
        let graph = MPSGraph()
        let input = graph.placeholder(
            shape: [1] as [NSNumber],
            dataType: .float32,
            name: "x")
        let output = graph.identity(
            with: input, name: "y")
        let inputShapeDesc = MPSGraphShapedType(
            shape: input.shape, dataType: input.dataType)
        let executable = graph.compile(
            with: nil,
            feeds: [input: inputShapeDesc],
            targetTensors: [output],
            targetOperations: nil,
            compilationDescriptor: nil)

        let cache = BASMPSGraphExecutableCache()
        let key = BASMPSGraphCacheKey(
            operation: .softmax,
            dataType: .float32,
            inputShapes: [[1]])
        await cache.storeExecutable(executable, forKey: key)

        let beforeReset = await cache.executableCount
        XCTAssertEqual(beforeReset, 1)

        await cache.reset()

        let afterReset = await cache.executableCount
        XCTAssertEqual(afterReset, 0,
            "reset() must drop cached executables")
        let retrievedAfterReset =
            await cache.cachedExecutable(forKey: key)
        XCTAssertNil(retrievedAfterReset,
            "Post-reset lookup must return nil")
    }

    // MARK: - Distinct keys stay distinct

    func testDistinctKeysProduceDistinctSlots() async throws {
        let graph = MPSGraph()
        let input = graph.placeholder(
            shape: [1] as [NSNumber],
            dataType: .float32,
            name: "x")
        let output = graph.identity(
            with: input, name: "y")
        let inputShapeDesc = MPSGraphShapedType(
            shape: input.shape, dataType: input.dataType)
        let exe1 = graph.compile(
            with: nil,
            feeds: [input: inputShapeDesc],
            targetTensors: [output],
            targetOperations: nil,
            compilationDescriptor: nil)
        let exe2 = graph.compile(
            with: nil,
            feeds: [input: inputShapeDesc],
            targetTensors: [output],
            targetOperations: nil,
            compilationDescriptor: nil)

        let cache = BASMPSGraphExecutableCache()
        let key1 = BASMPSGraphCacheKey(
            operation: .softmax,
            dataType: .float32,
            inputShapes: [[1]])
        let key2 = BASMPSGraphCacheKey(
            operation: .layerNorm,
            dataType: .float32,
            inputShapes: [[1]])

        await cache.storeExecutable(exe1, forKey: key1)
        await cache.storeExecutable(exe2, forKey: key2)

        let count = await cache.executableCount
        XCTAssertEqual(count, 2)

        let r1 = await cache.cachedExecutable(forKey: key1)
        let r2 = await cache.cachedExecutable(forKey: key2)
        XCTAssertTrue(r1 === exe1)
        XCTAssertTrue(r2 === exe2)
    }

    // MARK: - M1297 observation surface regression guard

    func testRecordHitMissStillWorksAlongsideStorage() async {
        let cache = BASMPSGraphExecutableCache()
        let key = BASMPSGraphCacheKey(
            operation: .attention,
            dataType: .float32,
            inputShapes: [[2, 4], [2, 4], [2, 4]])

        await cache.recordMiss(key: key)
        await cache.recordHit(key: key)
        await cache.recordHit(key: key)

        let hits = await cache.hitCount
        let misses = await cache.missCount
        let totalLookups = await cache.totalLookups
        let ratio = await cache.hitRatio

        XCTAssertEqual(hits, 2)
        XCTAssertEqual(misses, 1)
        XCTAssertEqual(totalLookups, 3)
        XCTAssertEqual(ratio, 2.0 / 3.0, accuracy: 1e-6)
    }

    func testResetClearsBothObservationsAndStorage() async throws {
        let graph = MPSGraph()
        let input = graph.placeholder(
            shape: [1] as [NSNumber],
            dataType: .float32,
            name: "x")
        let output = graph.identity(
            with: input, name: "y")
        let inputShapeDesc = MPSGraphShapedType(
            shape: input.shape, dataType: input.dataType)
        let executable = graph.compile(
            with: nil,
            feeds: [input: inputShapeDesc],
            targetTensors: [output],
            targetOperations: nil,
            compilationDescriptor: nil)

        let cache = BASMPSGraphExecutableCache()
        let key = BASMPSGraphCacheKey(
            operation: .rmsNorm,
            dataType: .float32,
            inputShapes: [[1]])

        await cache.recordMiss(key: key)
        await cache.storeExecutable(executable, forKey: key)
        await cache.recordHit(key: key)

        let preResetExec = await cache.executableCount
        let preResetLookups = await cache.totalLookups
        XCTAssertEqual(preResetExec, 1)
        XCTAssertEqual(preResetLookups, 2)

        await cache.reset()

        let postResetExec = await cache.executableCount
        let postResetLookups = await cache.totalLookups
        XCTAssertEqual(postResetExec, 0)
        XCTAssertEqual(postResetLookups, 0)
    }
}
