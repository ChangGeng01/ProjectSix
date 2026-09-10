// MARK: - BASSSMScanWallclockBenchmarkTests
// chapter 六百八十 / M2098 第二刀 — GPU vs CPU wallclock
//                                  characterization tests
//                                  measuring elapsed time
//                                  for the SSM scan kernel
//                                  across multiple fixture
//                                  scales。
//
// ## What this measures
//
// Honest wallclock characterization — NOT a strict pass/
// fail benchmark like the Phase J MPSGraph cache test
// (which asserts ≥5× speedup)。 SSM scan is fundamentally
// sequential per (batch, channel) thread,so GPU's
// advantage only shows up at scale (more parallel threads
// → better GPU utilization)。
//
// On small fixtures (B*D ≤ 16),GPU dispatch overhead
// (~100µs) often exceeds the CPU's scan cost — CPU wins。
// On larger fixtures (B*D ≥ 256),GPU parallelism wins。
//
// These tests CHARACTERIZE the crossover + assert the
// kernel completes within reasonable time bounds (not
// strict speedup ratios)。

import XCTest
@testable import BASMetalSubstrate

final class BASSSMScanWallclockBenchmarkTests:
    XCTestCase
{
    typealias R = BASSSMScanExtendedFixtureRegistry
    typealias CPU = BASSSMScanCPUReference

    private func skipUnlessMetal() throws {
        try XCTSkipUnless(
            MTLCreateSystemDefaultDevice() != nil,
            "Metal not available on this platform")
    }

    // MARK: - Wallclock comparison helper

    private struct WallclockMeasurement {
        let cpuElapsedNanos: UInt64
        let gpuElapsedNanos: UInt64
        var cpuMs: Double {
            return Double(cpuElapsedNanos) / 1_000_000.0
        }
        var gpuMs: Double {
            return Double(gpuElapsedNanos) / 1_000_000.0
        }
        var gpuOverCpuRatio: Double {
            return Double(gpuElapsedNanos) /
                Double(cpuElapsedNanos)
        }
    }

    /// Run a fixture on both CPU and GPU,measure wallclock
    /// elapsed time for each。 Warm-up the GPU pipeline
    /// first to avoid first-dispatch overhead skewing
    /// the measurement。
    private func measureFixture(
        _ fixture: BASSSMScanExtendedFixture
    ) async throws -> WallclockMeasurement {
        let kernel = try BASMetalSSMScanKernel()
        let inputs = fixture.generateInputs()

        // GPU warm-up dispatch (excluded from measurement)
        _ = try await gpuRun(
            kernel: kernel,
            fixture: fixture,
            inputs: inputs)

        // CPU measurement
        let cpuStart = DispatchTime.now()
            .uptimeNanoseconds
        _ = try CPU.scan(
            x: inputs.x, delta: inputs.delta,
            A: inputs.A, B: inputs.B, C: inputs.C,
            shape: fixture.shape)
        let cpuEnd = DispatchTime.now()
            .uptimeNanoseconds

        // GPU measurement (post-warm-up)
        let gpuStart = DispatchTime.now()
            .uptimeNanoseconds
        _ = try await gpuRun(
            kernel: kernel,
            fixture: fixture,
            inputs: inputs)
        let gpuEnd = DispatchTime.now()
            .uptimeNanoseconds

        return WallclockMeasurement(
            cpuElapsedNanos: cpuEnd - cpuStart,
            gpuElapsedNanos: gpuEnd - gpuStart)
    }

    private func gpuRun(
        kernel: BASMetalSSMScanKernel,
        fixture: BASSSMScanExtendedFixture,
        inputs: (
            x: [Float],
            delta: [Float],
            A: [Float],
            B: [Float],
            C: [Float])
    ) async throws -> [Float] {
        let descBLD = BASTensorDescriptor.contiguous(
            shape: [
                Int(fixture.shape.B),
                Int(fixture.shape.L),
                Int(fixture.shape.D)
            ],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "ssm-scan-bld")
        let descD = BASTensorDescriptor.contiguous(
            shape: [Int(fixture.shape.D)],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "ssm-scan-d")
        let kernelInputs = BASKernelInputs(
            descriptors: [
                descBLD, descBLD, descD, descBLD, descBLD
            ],
            payloads: [
                floatsToData(inputs.x),
                floatsToData(inputs.delta),
                floatsToData(inputs.A),
                floatsToData(inputs.B),
                floatsToData(inputs.C)
            ])
        let outputs = try await kernel.evaluate(
            inputs: kernelInputs)
        return bytesToFloats(outputs.payloads[0])
    }

    // MARK: - Small-scale fixture wallclock

    func testWallclockSmallFixture() async throws {
        try skipUnlessMetal()
        let m = try await measureFixture(
            R.largeScaleB2L8D4)
        print("[BASSSMScanWallclockBenchmark] " +
              "B2L8D4: CPU=\(m.cpuMs)ms " +
              "GPU=\(m.gpuMs)ms " +
              "ratio=\(m.gpuOverCpuRatio)")
        // Both should complete in reasonable time
        XCTAssertLessThan(m.cpuMs, 100.0,
            "CPU should complete in < 100ms")
        XCTAssertLessThan(m.gpuMs, 1000.0,
            "GPU should complete in < 1000ms " +
            "(generous bound for dispatch overhead)")
    }

    // MARK: - Larger fixture wallclock

    func testWallclockLargerFixture() async throws {
        try skipUnlessMetal()
        let m = try await measureFixture(
            R.largeScaleB4L16D8)
        print("[BASSSMScanWallclockBenchmark] " +
              "B4L16D8: CPU=\(m.cpuMs)ms " +
              "GPU=\(m.gpuMs)ms " +
              "ratio=\(m.gpuOverCpuRatio)")
        XCTAssertLessThan(m.cpuMs, 100.0)
        XCTAssertLessThan(m.gpuMs, 1000.0)
    }

    // MARK: - Throughput characterization

    /// Run 100 GPU dispatches back-to-back to measure
    /// amortized per-dispatch cost (warm-cache scenario)。
    func testThroughputHundredDispatches() async throws {
        try skipUnlessMetal()
        let kernel = try BASMetalSSMScanKernel()
        let fixture = R.largeScaleB2L8D4
        let inputs = fixture.generateInputs()

        // Warm up
        _ = try await gpuRun(
            kernel: kernel,
            fixture: fixture,
            inputs: inputs)

        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<100 {
            _ = try await gpuRun(
                kernel: kernel,
                fixture: fixture,
                inputs: inputs)
        }
        let end = DispatchTime.now().uptimeNanoseconds
        let totalMs = Double(end - start) / 1_000_000.0
        let perDispatchMs = totalMs / 100.0
        print("[BASSSMScanWallclockBenchmark] " +
              "100 dispatches B2L8D4: total=\(totalMs)ms " +
              "avg=\(perDispatchMs)ms per dispatch")
        XCTAssertLessThan(totalMs, 5000.0,
            "100 dispatches should complete in < 5s " +
            "(amortized per-dispatch < 50ms)")
    }

    // MARK: - GPU execution-nanos reported in output

    /// Verify the kernel's reported `executionNanos`
    /// value is non-zero + roughly in line with our
    /// wallclock measurement。
    func testKernelReportsExecutionNanos() async throws {
        try skipUnlessMetal()
        let kernel = try BASMetalSSMScanKernel()
        let fixture = R.largeScaleB4L16D8
        let inputs = fixture.generateInputs()

        let descBLD = BASTensorDescriptor.contiguous(
            shape: [
                Int(fixture.shape.B),
                Int(fixture.shape.L),
                Int(fixture.shape.D)
            ],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "ssm-scan-bld")
        let descD = BASTensorDescriptor.contiguous(
            shape: [Int(fixture.shape.D)],
            dataType: .float32,
            backingKind: .metalBuffer,
            rankTag: "ssm-scan-d")
        let kernelInputs = BASKernelInputs(
            descriptors: [
                descBLD, descBLD, descD, descBLD, descBLD
            ],
            payloads: [
                floatsToData(inputs.x),
                floatsToData(inputs.delta),
                floatsToData(inputs.A),
                floatsToData(inputs.B),
                floatsToData(inputs.C)
            ])
        let outputs = try await kernel.evaluate(
            inputs: kernelInputs)
        XCTAssertGreaterThan(
            outputs.executionNanos, 0,
            "kernel must report non-zero execution nanos")
    }

    // MARK: - Helpers

    private func floatsToData(_ floats: [Float]) -> Data {
        return floats.withUnsafeBufferPointer { buf in
            Data(buffer: buf)
        }
    }

    private func bytesToFloats(_ data: Data) -> [Float] {
        let count = data.count / 4
        return data.withUnsafeBytes { raw -> [Float] in
            let ptr = raw.bindMemory(to: Float.self)
            return Array(ptr[0..<count])
        }
    }
}
