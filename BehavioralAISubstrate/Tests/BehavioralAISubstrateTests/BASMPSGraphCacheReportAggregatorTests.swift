// MARK: - BASMPSGraphCacheReportAggregatorTests
// chapter 五百四 / M1393 — cache report aggregator tests

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

/// Test-only stub kernel — identity for probe → bundle
/// → aggregator multi-stage wire-in proof。
private actor IdentityKernelForAggregator:
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

final class BASMPSGraphCacheReportAggregatorTests:
    XCTestCase
{

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

    private func bundleWith(
        items: [BASMPSGraphKernelBuildLatencyResultBody]
    ) -> BASKernelEvaluateLatencyProbeBundle {
        return BASKernelEvaluateLatencyProbeBundle(
            bundleID: "agg-test",
            schemaVersion: "1.0.0",
            items: items,
            metadata: [:],
            recordedAt: Date(
                timeIntervalSince1970: 0))
    }

    // MARK: - 1) Empty bundle → zero report

    func testEmptyBundleProducesZeroReport() {
        let bundle = bundleWith(items: [])
        let report =
            BASMPSGraphCacheReportAggregator.report(
                from: bundle)
        XCTAssertTrue(report.success)
        XCTAssertEqual(report.body.hitCount, 0)
        XCTAssertEqual(report.body.missCount, 0)
        XCTAssertEqual(report.body.totalBuildNanos, 0)
        XCTAssertEqual(
            report.body.totalDispatchNanos, 0)
        XCTAssertEqual(
            report.body.totalCacheHitSavedNanos, 0)
        XCTAssertEqual(report.body.totalLookups, 0)
        XCTAssertEqual(report.body.hitRatio, 0.0)
    }

    // MARK: - 2) Mixed hit/miss → typed aggregate

    func testMixedHitMissProducesAggregate() {
        let bundle = bundleWith(items: [
            sampleBody(
                buildNanos: 1000,
                dispatchNanos: 200,
                wasCacheHit: false),
            sampleBody(
                buildNanos: 0,
                dispatchNanos: 100,
                cacheHitSavedNanos: 800,
                wasCacheHit: true),
            sampleBody(
                buildNanos: 1500,
                dispatchNanos: 300,
                wasCacheHit: false),
        ])
        let report =
            BASMPSGraphCacheReportAggregator.report(
                from: bundle)
        XCTAssertTrue(report.success)
        XCTAssertEqual(report.body.hitCount, 1)
        XCTAssertEqual(report.body.missCount, 2)
        XCTAssertEqual(report.body.totalLookups, 3)
        XCTAssertEqual(
            report.body.totalBuildNanos, 2500)
        XCTAssertEqual(
            report.body.totalDispatchNanos, 600)
        XCTAssertEqual(
            report.body.totalCacheHitSavedNanos, 800)
        XCTAssertEqual(report.body.hitRatio,
                       1.0 / 3.0, accuracy: 0.001)
    }

    // MARK: - 3) Caller can mark report failed

    func testCallerCanMarkReportFailed() {
        let bundle = bundleWith(items: [sampleBody()])
        let report =
            BASMPSGraphCacheReportAggregator.report(
                from: bundle,
                success: false,
                diagnostics: ["partial-failure"])
        XCTAssertFalse(report.success)
        XCTAssertEqual(report.diagnostics,
                       ["partial-failure"])
    }

    // MARK: - 4) zeroReport constant is shaped correctly

    func testZeroReportConstantIsZero() {
        let zero =
            BASMPSGraphCacheReportAggregator.zeroReport
        XCTAssertTrue(zero.success)
        XCTAssertEqual(zero.body.hitCount, 0)
        XCTAssertEqual(zero.body.missCount, 0)
        XCTAssertEqual(zero.body.totalLookups, 0)
        XCTAssertEqual(zero.body.hitRatio, 0.0)
    }

    // MARK: - 5) zeroReport is stable across calls
    //             (deterministic constant)

    func testZeroReportIsStableAcrossCalls() {
        let z1 =
            BASMPSGraphCacheReportAggregator.zeroReport
        let z2 =
            BASMPSGraphCacheReportAggregator.zeroReport
        XCTAssertEqual(z1, z2,
            "zeroReport MUST be a stable constant" +
            " (deterministic across multiple reads)")
    }

    // MARK: - 6) MULTI-STAGE WIRE-IN PROOF:
    //             probe → bundle → aggregator → result

    func testProbeToBundleToAggregatorPipeline()
        async throws
    {
        let probe = BASKernelEvaluateLatencyProbe(
            inner: IdentityKernelForAggregator())
        let descriptor = BASTensorDescriptor(
            shape: [4],
            strides: [1],
            dataType: .float32,
            backingKind: .cpuBytes,
            rankTag: "pipeline-test")
        let payload = Data(count: descriptor.byteCount)
        let inputs = BASKernelInputs(
            descriptors: [descriptor],
            payloads: [payload])
        // 5 probe runs feed the pipeline
        var bodies:
            [BASMPSGraphKernelBuildLatencyResultBody] = []
        for _ in 0..<5 {
            let r = try await probe.evaluateAndObserve(
                inputs: inputs)
            bodies.append(r.latency.body)
        }
        // M1386 bundle holds the bodies
        let bundle = BASKernelEvaluateLatencyProbeBundle(
            bundleID: "pipeline-proof",
            schemaVersion: "1.0.0",
            items: bodies,
            metadata: ["src": "probe-pipeline"],
            recordedAt: Date(
                timeIntervalSince1970: 0))
        // M1393 aggregator converts bundle → M1374 result
        let report =
            BASMPSGraphCacheReportAggregator.report(
                from: bundle)
        XCTAssertTrue(report.success)
        XCTAssertEqual(report.body.totalLookups, 5)
        XCTAssertEqual(report.body.hitCount, 0)
        XCTAssertEqual(report.body.missCount, 5)
        XCTAssertGreaterThan(
            report.body.totalBuildNanos, 0,
            "5 probe runs MUST aggregate non-zero" +
            " buildNanos through the full pipeline")
    }

    // MARK: - 7) Report Codable round-trip preserves
    //             aggregator output

    func testReportCodableRoundTripPreservesAggregator()
        throws
    {
        let bundle = bundleWith(items: [
            sampleBody(
                buildNanos: 1000,
                dispatchNanos: 500,
                wasCacheHit: false),
        ])
        let original =
            BASMPSGraphCacheReportAggregator.report(
                from: bundle)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMPSGraphCacheReportResult.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }
}
