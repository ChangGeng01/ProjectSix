// MARK: - BASMPSGraphExecutableCacheTests
// chapter 四百八十 / M1297
//
// PROOF tests for the MPSGraph cache observation layer
// + 3rd real BASBundle<Item> typealias migration。

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMPSGraphExecutableCacheTests: XCTestCase {

    // MARK: - Cache key

    func testCacheKeyEqualityRespectsAllDimensions() {
        let k1 = BASMPSGraphCacheKey(
            operation: .matMul,
            dataType: .float32,
            inputShapes: [[2, 3], [3, 4]])
        let k2 = BASMPSGraphCacheKey(
            operation: .matMul,
            dataType: .float32,
            inputShapes: [[2, 3], [3, 4]])
        XCTAssertEqual(k1, k2)
        // Different op
        let k3 = BASMPSGraphCacheKey(
            operation: .softmax,
            dataType: .float32,
            inputShapes: [[2, 3], [3, 4]])
        XCTAssertNotEqual(k1, k3)
        // Different shape
        let k4 = BASMPSGraphCacheKey(
            operation: .matMul,
            dataType: .float32,
            inputShapes: [[3, 3], [3, 4]])
        XCTAssertNotEqual(k1, k4)
    }

    func testCacheKeyIsCodable() throws {
        let key = BASMPSGraphCacheKey(
            operation: .conv2D,
            dataType: .float32,
            inputShapes: [[1, 2, 2, 1], [1, 1, 1, 1]])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(key)
        let decoded = try JSONDecoder().decode(
            BASMPSGraphCacheKey.self, from: data)
        XCTAssertEqual(decoded, key,
            "Codable round-trip (chapter 三百九二)")
    }

    // MARK: - Cache actor recording

    func testCacheRecordsHitsAndMisses() async {
        let cache = BASMPSGraphExecutableCache()
        let key = BASMPSGraphCacheKey(
            operation: .matMul,
            dataType: .float32,
            inputShapes: [[2, 2], [2, 2]])
        await cache.recordMiss(key: key)
        await cache.recordHit(key: key)
        await cache.recordHit(key: key)
        let hits = await cache.hitCount
        let misses = await cache.missCount
        let total = await cache.totalLookups
        let ratio = await cache.hitRatio
        XCTAssertEqual(hits, 2)
        XCTAssertEqual(misses, 1)
        XCTAssertEqual(total, 3)
        XCTAssertEqual(ratio, 2.0 / 3.0, accuracy: 0.001)
    }

    func testCacheBundleSnapshotPreservesOrdering() async {
        let cache = BASMPSGraphExecutableCache()
        let key1 = BASMPSGraphCacheKey(
            operation: .matMul, dataType: .float32,
            inputShapes: [[2, 2]])
        let key2 = BASMPSGraphCacheKey(
            operation: .softmax, dataType: .float32,
            inputShapes: [[1, 3]])
        await cache.recordMiss(key: key1)
        await cache.recordHit(key: key1)
        await cache.recordMiss(key: key2)
        let bundle = await cache.bundle()
        XCTAssertEqual(bundle.items.count, 3)
        XCTAssertEqual(bundle.items[0].wasHit, false)
        XCTAssertEqual(bundle.items[0].sequenceIndex, 0)
        XCTAssertEqual(bundle.items[1].wasHit, true)
        XCTAssertEqual(bundle.items[1].sequenceIndex, 1)
        XCTAssertEqual(bundle.items[2].wasHit, false)
        XCTAssertEqual(bundle.items[2].sequenceIndex, 2)
        XCTAssertEqual(bundle.items[2].key, key2)
    }

    // MARK: - BASBundle accessors

    func testBundleHitRatioAccessor() {
        let bundle = BASMPSGraphCacheObservationBundle(
            items: [
                BASMPSGraphCacheHitObservationItem(
                    key: BASMPSGraphCacheKey(
                        operation: .matMul,
                        dataType: .float32,
                        inputShapes: [[2, 2]]),
                    wasHit: true, sequenceIndex: 0),
                BASMPSGraphCacheHitObservationItem(
                    key: BASMPSGraphCacheKey(
                        operation: .matMul,
                        dataType: .float32,
                        inputShapes: [[2, 2]]),
                    wasHit: true, sequenceIndex: 1),
                BASMPSGraphCacheHitObservationItem(
                    key: BASMPSGraphCacheKey(
                        operation: .matMul,
                        dataType: .float32,
                        inputShapes: [[3, 3]]),
                    wasHit: false, sequenceIndex: 2)
            ])
        XCTAssertEqual(bundle.hitCount, 2)
        XCTAssertEqual(bundle.missCount, 1)
        XCTAssertEqual(
            bundle.hitRatio, 2.0 / 3.0, accuracy: 0.001)
    }

    func testEmptyBundleReturnsZeroRatio() {
        let bundle = BASMPSGraphCacheObservationBundle(
            items: [])
        XCTAssertEqual(bundle.hitRatio, 0,
            "empty bundle must return 0, not NaN")
    }

    // MARK: - Reset

    func testCacheResetClearsObservations() async {
        let cache = BASMPSGraphExecutableCache()
        let key = BASMPSGraphCacheKey(
            operation: .matMul, dataType: .float32,
            inputShapes: [[2, 2]])
        await cache.recordHit(key: key)
        await cache.recordMiss(key: key)
        var total = await cache.totalLookups
        XCTAssertEqual(total, 2)
        await cache.reset()
        total = await cache.totalLookups
        XCTAssertEqual(total, 0,
            "reset must clear observations")
        // After reset, sequence indices restart at 0
        await cache.recordHit(key: key)
        let bundle = await cache.bundle()
        XCTAssertEqual(bundle.items[0].sequenceIndex, 0)
    }

    // MARK: - Third BASBundle adoption

    func testThirdRealBASBundleAdoption() {
        // M1281 BASKernelDispatchOutcomeBundle = 1st
        // M1286 BASMPSGraphKernelCoverageBundle = 2nd
        // M1297 BASMPSGraphCacheObservationBundle = 3rd
        let bundle: BASMPSGraphCacheObservationBundle =
            BASBundle(items: [])
        XCTAssertTrue(bundle.isEmpty,
            "3rd real BASBundle<Item> typealias works")
    }
}
