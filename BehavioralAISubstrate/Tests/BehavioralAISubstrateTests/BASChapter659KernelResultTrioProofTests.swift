// MARK: - BASChapter659KernelResultTrioProofTests
// chapter 六百五十九 / M2014 — PROOF tests

import XCTest
@testable import BASMetalSubstrate

final class BASChapter659KernelResultTrioProofTests: XCTestCase {

    func testBASKernelEvaluateLatencyProbeResultConformsToCodable() {
        // #18: real round-trip
        let latency = BASMPSGraphKernelBuildLatencyResult(
            success: true,
            body: BASMPSGraphKernelBuildLatencyResultBody(
                operation: .matMul,
                dataType: .float16,
                inputShapes: [],
                buildNanos: 0,
                dispatchNanos: 0,
                cacheHitSavedNanos: 0,
                wasCacheHit: false))
        assertCodableRoundTrips(
            BASKernelEvaluateLatencyProbeResult(
                outputs: BASKernelOutputs(
                    descriptors: [],
                    payloads: [],
                    executionNanos: 0),
                latency: latency))
    }

    func testBASKernelDispatchResultConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASKernelDispatchResult(
                routedKey: BASKernelKey(
                    operation: .matMul,
                    dataType: .float16,
                    backingKind: .mlxArray),
                outputs: BASKernelOutputs(
                    descriptors: [],
                    payloads: [],
                    executionNanos: 0)))
    }

    func testBASBCMMetaPlasticityUpdateConformsToCodable() {
        // #18: real round-trip
        assertCodableRoundTrips(
            BASBCMMetaPlasticityUpdate(
                pre: [],
                post: [],
                priorThreshold: 0,
                updatedThreshold: 0,
                weightDelta: [],
                updatedWeightSnapshot: [],
                updateIndex: 0))
    }
}
