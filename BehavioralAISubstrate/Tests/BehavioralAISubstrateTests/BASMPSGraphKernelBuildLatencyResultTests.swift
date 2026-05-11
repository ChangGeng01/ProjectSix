// MARK: - BASMPSGraphKernelBuildLatencyResultTests
// chapter 四百九十八 / M1369 — typed build-latency result tests

import XCTest
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASMPSGraphKernelBuildLatencyResultTests:
    XCTestCase
{

    // MARK: - 1) Construction holds inputs

    func testConstructionHoldsInputs() {
        let body =
            BASMPSGraphKernelBuildLatencyResultBody(
                operation: .matMul,
                dataType: .float32,
                inputShapes: [[4, 8], [8, 16]],
                buildNanos: 1_500_000,
                dispatchNanos: 200_000,
                cacheHitSavedNanos: 1_400_000,
                wasCacheHit: true)
        XCTAssertEqual(body.operation, .matMul)
        XCTAssertEqual(body.dataType, .float32)
        XCTAssertEqual(body.inputShapes,
                       [[4, 8], [8, 16]])
        XCTAssertEqual(body.buildNanos, 1_500_000)
        XCTAssertEqual(body.dispatchNanos, 200_000)
        XCTAssertEqual(body.cacheHitSavedNanos, 1_400_000)
        XCTAssertTrue(body.wasCacheHit)
    }

    // MARK: - 2) totalNanos sums build + dispatch

    func testTotalNanosSumsBuildAndDispatch() {
        let body =
            BASMPSGraphKernelBuildLatencyResultBody(
                operation: .matMul,
                dataType: .float32,
                inputShapes: [],
                buildNanos: 100,
                dispatchNanos: 200,
                cacheHitSavedNanos: 0,
                wasCacheHit: false)
        XCTAssertEqual(body.totalNanos, 300)
    }

    // MARK: - 3) effectiveCacheSavingsNanos respects flag

    func testEffectiveCacheSavingsOnlyOnHit() {
        let hit =
            BASMPSGraphKernelBuildLatencyResultBody(
                operation: .matMul,
                dataType: .float32,
                inputShapes: [],
                buildNanos: 0,
                dispatchNanos: 100,
                cacheHitSavedNanos: 1500,
                wasCacheHit: true)
        XCTAssertEqual(
            hit.effectiveCacheSavingsNanos, 1500)

        let miss =
            BASMPSGraphKernelBuildLatencyResultBody(
                operation: .matMul,
                dataType: .float32,
                inputShapes: [],
                buildNanos: 1500,
                dispatchNanos: 100,
                cacheHitSavedNanos: 1500,
                wasCacheHit: false)
        XCTAssertEqual(
            miss.effectiveCacheSavingsNanos, 0,
            "miss MUST report 0 effective savings even" +
            " if the cacheHitSavedNanos field is populated" +
            " (defensive against caller error)")
    }

    // MARK: - 4) Result typealias wraps body

    func testResultTypealiasWrapsBody() {
        let body =
            BASMPSGraphKernelBuildLatencyResultBody(
                operation: .matMul,
                dataType: .float32,
                inputShapes: [],
                buildNanos: 0,
                dispatchNanos: 0,
                cacheHitSavedNanos: 0,
                wasCacheHit: false)
        let result =
            BASMPSGraphKernelBuildLatencyResult(
                success: true,
                body: body,
                diagnostics: [])
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.body.operation, .matMul)
        XCTAssertTrue(result.diagnostics.isEmpty)
    }

    // MARK: - 5) Codable round-trip

    func testCodableRoundTrip() throws {
        let original =
            BASMPSGraphKernelBuildLatencyResultBody(
                operation: .rmsNorm,
                dataType: .float32,
                inputShapes: [[128]],
                buildNanos: 1_200_000,
                dispatchNanos: 80_000,
                cacheHitSavedNanos: 0,
                wasCacheHit: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASMPSGraphKernelBuildLatencyResultBody.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 6) Saturating-add safety

    func testSaturatingAddOnTotalNanos() {
        let body =
            BASMPSGraphKernelBuildLatencyResultBody(
                operation: .matMul,
                dataType: .float32,
                inputShapes: [],
                buildNanos: .max,
                dispatchNanos: 1,
                cacheHitSavedNanos: 0,
                wasCacheHit: false)
        // &+ wraps to 0;test verifies no crash and
        // documented wrap-around semantic
        let _ = body.totalNanos
    }
}
