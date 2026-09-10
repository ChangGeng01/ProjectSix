// MARK: - BASKernelEvaluateLatencyProbeBundleTests
// chapter 五百二 / M1386 — typed probe bundle aggregator tests

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

/// Test-only stub kernel that emits inputs verbatim
/// (identity)。 Used to verify probe → bundle wire-in
/// without real Metal hardware。
private actor IdentityKernelForProbeBundle:
    BASMetalKernel
{
    nonisolated let key: BASKernelKey =
        BASKernelKey(
            operation: .matMul,
            dataType: .float32,
            backingKind: .cpuBytes)

    func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        return BASKernelOutputs(
            descriptors: inputs.descriptors,
            payloads: inputs.payloads,
            executionNanos: 0)
    }
}

final class BASKernelEvaluateLatencyProbeBundleTests:
    XCTestCase
{

    // MARK: - Helpers

    private func sampleBody(
        operation: BASNeuralOp = .matMul,
        buildNanos: UInt64 = 100,
        dispatchNanos: UInt64 = 50,
        cacheHitSavedNanos: UInt64 = 0,
        wasCacheHit: Bool = false
    ) -> BASMPSGraphKernelBuildLatencyResultBody {
        return BASMPSGraphKernelBuildLatencyResultBody(
            operation: operation,
            dataType: .float32,
            inputShapes: [[4, 4]],
            buildNanos: buildNanos,
            dispatchNanos: dispatchNanos,
            cacheHitSavedNanos: cacheHitSavedNanos,
            wasCacheHit: wasCacheHit)
    }

    private func sampleBundle(
        items: [BASMPSGraphKernelBuildLatencyResultBody]
    ) -> BASKernelEvaluateLatencyProbeBundle {
        return BASKernelEvaluateLatencyProbeBundle(
            bundleID: "probe-bundle-1",
            schemaVersion: "1.0.0",
            items: items,
            metadata: [:],
            recordedAt: Date(
                timeIntervalSince1970: 0))
    }

    // MARK: - 1) Empty bundle has zero aggregates

    func testEmptyBundleAggregatesAreZero() {
        let bundle = sampleBundle(items: [])
        XCTAssertEqual(bundle.totalBuildNanos, 0)
        XCTAssertEqual(bundle.totalDispatchNanos, 0)
        XCTAssertEqual(bundle.totalCacheHitSavedNanos, 0)
        XCTAssertEqual(bundle.cacheHitCount, 0)
        XCTAssertEqual(bundle.cacheMissCount, 0)
        XCTAssertEqual(bundle.cacheHitRatio, 0.0)
        XCTAssertTrue(bundle.perOperationCounts.isEmpty)
    }

    // MARK: - 2) Single-item aggregates

    func testSingleItemAggregates() {
        let bundle = sampleBundle(items: [
            sampleBody(
                buildNanos: 500,
                dispatchNanos: 100,
                cacheHitSavedNanos: 400,
                wasCacheHit: true)
        ])
        XCTAssertEqual(bundle.totalBuildNanos, 500)
        XCTAssertEqual(bundle.totalDispatchNanos, 100)
        XCTAssertEqual(
            bundle.totalCacheHitSavedNanos, 400)
        XCTAssertEqual(bundle.cacheHitCount, 1)
        XCTAssertEqual(bundle.cacheMissCount, 0)
        XCTAssertEqual(bundle.cacheHitRatio, 1.0)
    }

    // MARK: - 3) Mixed hit/miss aggregates

    func testMixedHitMissAggregates() {
        let bundle = sampleBundle(items: [
            sampleBody(
                buildNanos: 1000,
                dispatchNanos: 200,
                wasCacheHit: false),
            sampleBody(
                buildNanos: 0,
                dispatchNanos: 100,
                cacheHitSavedNanos: 1000,
                wasCacheHit: true),
            sampleBody(
                buildNanos: 1500,
                dispatchNanos: 250,
                wasCacheHit: false),
        ])
        XCTAssertEqual(bundle.totalBuildNanos, 2500)
        XCTAssertEqual(bundle.totalDispatchNanos, 550)
        XCTAssertEqual(
            bundle.totalCacheHitSavedNanos, 1000)
        XCTAssertEqual(bundle.cacheHitCount, 1)
        XCTAssertEqual(bundle.cacheMissCount, 2)
        XCTAssertEqual(
            bundle.cacheHitRatio,
            1.0 / 3.0, accuracy: 0.001)
    }

    // MARK: - 4) Miss does NOT contribute saved nanos

    func testMissDoesNotContributeSavedNanos() {
        let bundle = sampleBundle(items: [
            sampleBody(
                cacheHitSavedNanos: 999_999,
                wasCacheHit: false)
        ])
        XCTAssertEqual(
            bundle.totalCacheHitSavedNanos, 0,
            "INVARIANT: cache-hit-saved-nanos for a" +
            " miss is 0,not the populated body field," +
            " per M1369 effectiveCacheSavingsNanos" +
            " honest-accounting semantic")
    }

    // MARK: - 5) Per-operation counts partition correctly

    func testPerOperationCountsPartition() {
        let bundle = sampleBundle(items: [
            sampleBody(operation: .matMul),
            sampleBody(operation: .matMul),
            sampleBody(operation: .rmsNorm),
            sampleBody(operation: .attention),
            sampleBody(operation: .attention),
            sampleBody(operation: .attention),
        ])
        let counts = bundle.perOperationCounts
        XCTAssertEqual(counts[.matMul], 2)
        XCTAssertEqual(counts[.rmsNorm], 1)
        XCTAssertEqual(counts[.attention], 3)
        // Other ops not present
        XCTAssertNil(counts[.softmax])
        XCTAssertEqual(counts.values.reduce(0, +),
                       bundle.items.count)
    }

    // MARK: - 6) Wire-in proof:probe result body → bundle item

    func testProbeResultBodyFlowsDirectlyIntoBundle()
        async throws
    {
        let probe = BASKernelEvaluateLatencyProbe(
            inner: IdentityKernelForProbeBundle())
        let descriptor = BASTensorDescriptor(
            shape: [4],
            strides: [1],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: "probe-bundle-test")
        let payload = Data(count: descriptor.byteCount)
        let inputs = BASKernelInputs(
            descriptors: [descriptor],
            payloads: [payload])
        // Capture 3 probe runs to demonstrate aggregation
        var items:
            [BASMPSGraphKernelBuildLatencyResultBody] = []
        for _ in 0..<3 {
            let result = try await probe
                .evaluateAndObserve(inputs: inputs)
            items.append(result.latency.body)
        }
        // Bundle directly consumes the probe-produced
        // bodies — this is the wire-in proof
        let bundle = BASKernelEvaluateLatencyProbeBundle(
            bundleID: "probe-flow-test",
            schemaVersion: "1.0.0",
            items: items,
            metadata: ["src": "probe"],
            recordedAt: Date(
                timeIntervalSince1970: 0))
        XCTAssertEqual(bundle.items.count, 3)
        XCTAssertEqual(bundle.cacheMissCount, 3,
            "probe always reports wasCacheHit=false" +
            " (M1371 semantic)")
        XCTAssertGreaterThan(
            bundle.totalBuildNanos, 0,
            "3 probe runs MUST aggregate non-zero" +
            " buildNanos (each probe records wall-" +
            "clock latency)")
    }

    // MARK: - 7) Codable round-trip

    func testBundleCodableRoundTrip() throws {
        let original = sampleBundle(items: [
            sampleBody(
                operation: .matMul,
                buildNanos: 100,
                dispatchNanos: 50),
            sampleBody(
                operation: .softmax,
                buildNanos: 200,
                dispatchNanos: 75,
                cacheHitSavedNanos: 150,
                wasCacheHit: true)
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASKernelEvaluateLatencyProbeBundle.self,
            from: data)
        XCTAssertEqual(decoded.bundleID,
                       original.bundleID)
        XCTAssertEqual(decoded.items.count,
                       original.items.count)
        XCTAssertEqual(decoded.totalBuildNanos,
                       original.totalBuildNanos)
        XCTAssertEqual(decoded.cacheHitRatio,
                       original.cacheHitRatio,
                       accuracy: 0.001)
    }
}
