// ADR-039 Phase 1 — per-kernel execution observability: the accumulator logic + the recordSink mechanism
// (a record is emitted on every instrumented dispatch, whether it ran on GPU or threw → caller falls back).

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASMetalKernelExecutionTests: XCTestCase {

    // MARK: - Accumulator (pure)

    func testAccumulatorRecordDrainAggregate() {
        let acc = BASMetalKernelExecutionAccumulator()
        acc.record(rec("a", gpu: true, ms: 1.0))
        acc.record(rec("b", gpu: true, ms: 3.0))
        acc.record(rec("c", gpu: false, ms: 9.0, error: "boom"))
        let batch = acc.drain()
        XCTAssertEqual(batch.count, 3)
        XCTAssertTrue(acc.drain().isEmpty, "drain clears")
        let agg = BASMetalKernelExecutionAccumulator.aggregate(batch)
        XCTAssertEqual(agg.gpuRuns, 2)
        XCTAssertEqual(agg.cpuFallbacks, 1)
        XCTAssertEqual(agg.errors, 1)
        XCTAssertTrue(agg.anythingRanOnGPU)
        XCTAssertGreaterThanOrEqual(agg.p99DurationMs, agg.p50DurationMs)
    }

    func testCpuFallbackIsDerivedFromGpuFlag() {
        XCTAssertTrue(rec("x", gpu: false, ms: 1, error: "e").cpuFallback)
        XCTAssertFalse(rec("y", gpu: true, ms: 1).cpuFallback)
    }

    // MARK: - recordSink mechanism (a real dispatch through BASCognitiveMetalKernels)

    func testRecordSinkEmitsOnInstrumentedDispatch() async {
        let acc = BASMetalKernelExecutionAccumulator()
        let mk = BASCognitiveMetalKernels(
            metalLibraryLoader: BASMetalKernelLibraryLoader(),
            recordSink: { acc.record($0) })
        // Runs on Mac Metal if available; if the GPU path throws (env), the instrument helper still emits a
        // record (didRunOnGPU=false + error). Either way the MECHANISM fired exactly once.
        _ = try? await mk.cosineSimilarity([1, 0, 1], [1, 0, 1])
        let recs = acc.drain()
        XCTAssertEqual(recs.count, 1, "one instrumented dispatch ⇒ exactly one record")
        XCTAssertEqual(recs.first?.kernelSymbol, "cosine")
        XCTAssertGreaterThanOrEqual(recs.first?.durationMs ?? -1, 0)
    }

    func testNilRecordSinkEmitsNothing() async {
        // recordSink nil ⇒ the instrument helper calls the body directly (byte-equal-off, zero overhead).
        let mk = BASCognitiveMetalKernels(metalLibraryLoader: BASMetalKernelLibraryLoader())
        _ = try? await mk.cosineSimilarity([1, 0, 1], [1, 0, 1])
        // No sink, no accumulator → nothing to assert beyond "did not crash"; the nil path is exercised.
    }

    private func rec(_ sym: String, gpu: Bool, ms: Double, error: String? = nil) -> BASMetalKernelExecutionRecord {
        BASMetalKernelExecutionRecord(
            kernelSymbol: sym, didRunOnGPU: gpu, durationMs: ms, error: error,
            dispatchStartMonoNs: 0, dispatchEndMonoNs: UInt64(ms * 1_000_000))
    }
}
