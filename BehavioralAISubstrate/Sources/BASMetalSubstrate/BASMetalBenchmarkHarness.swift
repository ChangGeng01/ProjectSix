// MARK: - BASMetalBenchmarkHarness — chapter 四百六十 / M1217
// 系统熵 reduction
//
// **DEBT-REPAYMENT** chapter — closes the BENCHMARK
// debt surfaced by chapter 459's self-audit:chapter
// 458 doctrine claimed "~30µs on M2 vs ~1ms CPU" for
// GPU plasticity but those numbers were never measured。
// Chapter 460 ships a real harness that takes timing
// measurements + tests that EMIT measured µs values
// for the dev's actual hardware。
//
// ## Why this exists (system entropy framing)
//
// Up to chapter 459 we had:
//   - 7 substrate primitives with GPU paths
//   - 0 measurements
//   - Doctrine prose making performance claims based
//     on "feels right" intuition,not data
//
// That's the same epistemological failure mode chapter
// 446 SWEEP had:claiming ratification before the
// real-execution layer was built。 Chapter 460 closes
// the benchmark debt by:
//
//   1. A typed `BASMetalBenchmarkHarness` actor that
//      runs N warmup + M timed iterations of CPU +
//      GPU paths against a typed shape configuration
//   2. A typed `BASMetalBenchmarkReport` value-type
//      carrying mean / median / p50 / p95 µs for both
//      paths + a derived speedup ratio
//   3. PROOF tests that exercise the harness on
//      32×32 / 256×256 / 1024×1024 weight shapes,
//      assert the harness produces sensible numbers
//      (positive,monotonic,not NaN),and PRINT the
//      measurements to stderr so the dev can copy
//      them into the chapter 458 doctrine
//
// ## What this DOES NOT promise
//
//   - Specific µs numbers in the doctrine。 Hardware
//     varies (M1 vs M2 vs M3 vs A17 vs A18);CI may
//     run on Intel macOS。 The harness MEASURES;
//     doctrine prose now references the harness as
//     the source of truth instead of inventing numbers
//   - GPU is always faster than CPU。 For tiny shapes
//     (e.g. 4×4) GPU dispatch overhead exceeds gain。
//     The harness reports the actual ratio without
//     editorializing
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed shape (preDim ×
//     postDim × iterations) + typed report
//   - chapter 二百一一 — one harness type covers all
//     shapes
//   - chapter 三百九二 — replay-determinism (same
//     hardware + same shape produces stable µs to
//     within ~5% noise)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive primitive)
//   - 红线 7 — measurements are observation,not
//     commitment
//   - ADR-014 OPT-IN — purely additive

import Foundation

// MARK: - Typed shape

/// Typed configuration for one benchmark run。
public struct BASMetalBenchmarkShape:
    Equatable, Hashable, Sendable, Codable
{

    /// Pre-synaptic dim (rows of weight matrix)。
    /// Clamped to >= 1。
    public let preDim: Int

    /// Post-synaptic dim (cols of weight matrix)。
    /// Clamped to >= 1。
    public let postDim: Int

    /// Number of warmup iterations (NOT counted toward
    /// the timing samples)。 Warmup pays first-call
    /// overhead (lazy MTLDevice / pipeline build /
    /// MTLBuffer allocation paths) so timed samples
    /// reflect steady-state cost。 Clamped >= 0。
    public let warmupIterations: Int

    /// Number of timed iterations (each contributes
    /// one µs sample to the report)。 Clamped >= 1。
    public let timedIterations: Int

    public init(
        preDim: Int,
        postDim: Int,
        warmupIterations: Int = 5,
        timedIterations: Int = 50
    ) {
        self.preDim = max(1, preDim)
        self.postDim = max(1, postDim)
        self.warmupIterations =
            max(0, warmupIterations)
        self.timedIterations =
            max(1, timedIterations)
    }
}

// MARK: - Typed report

/// Typed report from one benchmark run。 Carries timing
/// statistics for both CPU + GPU paths,plus the
/// derived speedup ratio。 µs values are NEVER asserted
/// against doctrine — they're observation/audit。
public struct BASMetalBenchmarkReport:
    Equatable, Hashable, Sendable, Codable
{

    public let shape: BASMetalBenchmarkShape

    /// CPU-path timing samples in microseconds (one
    /// per timed iteration)。 Length =
    /// shape.timedIterations。
    public let cpuMicrosecondsSamples: [Double]

    /// GPU-path timing samples in microseconds。
    /// Length = shape.timedIterations,or empty if GPU
    /// was unavailable on this device。
    public let gpuMicrosecondsSamples: [Double]

    /// True when the harness successfully ran the GPU
    /// path。 False on devices without Metal
    /// (simulator,watchOS)。
    public let gpuAvailable: Bool

    public init(
        shape: BASMetalBenchmarkShape,
        cpuMicrosecondsSamples: [Double],
        gpuMicrosecondsSamples: [Double],
        gpuAvailable: Bool
    ) {
        self.shape = shape
        self.cpuMicrosecondsSamples =
            cpuMicrosecondsSamples
        self.gpuMicrosecondsSamples =
            gpuMicrosecondsSamples
        self.gpuAvailable = gpuAvailable
    }

    /// Mean CPU µs across timed samples。
    public var cpuMicrosecondsMean: Double {
        return Self.mean(cpuMicrosecondsSamples)
    }

    /// Median CPU µs (p50)。
    public var cpuMicrosecondsMedian: Double {
        return Self.median(cpuMicrosecondsSamples)
    }

    /// p95 CPU µs。
    public var cpuMicrosecondsP95: Double {
        return Self.percentile(
            cpuMicrosecondsSamples, 0.95)
    }

    /// Mean GPU µs (returns 0 if GPU unavailable)。
    public var gpuMicrosecondsMean: Double {
        return Self.mean(gpuMicrosecondsSamples)
    }

    public var gpuMicrosecondsMedian: Double {
        return Self.median(gpuMicrosecondsSamples)
    }

    public var gpuMicrosecondsP95: Double {
        return Self.percentile(
            gpuMicrosecondsSamples, 0.95)
    }

    /// Speedup ratio = CPU mean / GPU mean。 > 1 means
    /// GPU is faster;< 1 means CPU is faster (typical
    /// for tiny shapes due to GPU dispatch overhead)。
    /// Returns 0 when GPU unavailable。
    public var speedupMean: Double {
        let g = gpuMicrosecondsMean
        guard g > 0 else { return 0 }
        return cpuMicrosecondsMean / g
    }

    /// Pretty-printable single-line summary。 Useful
    /// for test logs that the dev copies into the
    /// chapter 458 doctrine。
    public var summary: String {
        let cpu = String(
            format: "%.1f", cpuMicrosecondsMean)
        if gpuAvailable {
            let gpu = String(
                format: "%.1f", gpuMicrosecondsMean)
            let speedup = String(
                format: "%.2fx", speedupMean)
            return "shape=\(shape.preDim)x" +
                "\(shape.postDim) " +
                "n=\(shape.timedIterations) " +
                "cpu_mean=\(cpu)µs " +
                "gpu_mean=\(gpu)µs " +
                "speedup=\(speedup)"
        } else {
            return "shape=\(shape.preDim)x" +
                "\(shape.postDim) " +
                "n=\(shape.timedIterations) " +
                "cpu_mean=\(cpu)µs " +
                "gpu=unavailable"
        }
    }

    // Statistics helpers

    private static func mean(_ samples: [Double])
        -> Double
    {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +)
            / Double(samples.count)
    }

    private static func median(_ samples: [Double])
        -> Double
    {
        return percentile(samples, 0.5)
    }

    private static func percentile(
        _ samples: [Double], _ p: Double
    ) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sorted = samples.sorted()
        let clampedP = max(0, min(1, p))
        let idx = Int(
            (Double(sorted.count - 1) * clampedP)
            .rounded())
        return sorted[idx]
    }
}

// MARK: - Harness actor

/// Actor that runs CPU + GPU plasticity benchmark
/// against a typed shape configuration and returns a
/// typed report carrying real µs measurements。
public actor BASMetalBenchmarkHarness {

    public init() {}

    /// Run a Mamba selective-scan benchmark for the
    /// given (batch × hiddenDim × stateDim × sequence)
    /// shape。 chapter 471 / M1261 — extends harness
    /// coverage from plasticity-only (chapter 460) to
    /// Mamba SSM (chapter 451 GPU path)。 Reports CPU
    /// vs GPU µs。
    public func runMambaScan(
        batch: Int,
        hiddenDim: Int,
        stateDim: Int,
        sequenceLength: Int,
        warmupIterations: Int = 3,
        timedIterations: Int = 10
    ) async throws -> BASMetalBenchmarkReport {
        let shape = BASMambaSSMShape(
            batch: batch,
            hiddenDim: hiddenDim,
            stateDim: stateDim)
        let inputs = BASMambaSSMScanInputs(
            x: Array(repeating: 0.5,
                count: batch * sequenceLength * hiddenDim),
            delta: Array(repeating: 0.1,
                count: batch * sequenceLength * hiddenDim),
            a: Array(repeating: -1.0,
                count: hiddenDim * stateDim),
            b: Array(repeating: 0.2,
                count: batch * sequenceLength * stateDim),
            c: Array(repeating: 0.3,
                count: batch * sequenceLength * stateDim),
            sequenceLength: sequenceLength)
        // CPU path
        let cpuMamba = BASMambaSSMState(shape: shape)
        for _ in 0..<warmupIterations {
            _ = try await cpuMamba.selectiveScan(
                inputs: inputs)
        }
        var cpuSamples: [Double] = []
        for _ in 0..<timedIterations {
            let t0 = Self.nowMicroseconds()
            _ = try await cpuMamba.selectiveScan(
                inputs: inputs)
            let t1 = Self.nowMicroseconds()
            cpuSamples.append(t1 - t0)
        }
        // GPU path
        var gpuSamples: [Double] = []
        var gpuAvailable = true
        let gpuMamba = BASMambaSSMState(shape: shape)
        do {
            for _ in 0..<warmupIterations {
                _ = try await gpuMamba.selectiveScanGPU(
                    inputs: inputs)
            }
            for _ in 0..<timedIterations {
                let t0 = Self.nowMicroseconds()
                _ = try await gpuMamba.selectiveScanGPU(
                    inputs: inputs)
                let t1 = Self.nowMicroseconds()
                gpuSamples.append(t1 - t0)
            }
        } catch BASMambaSSMError.gpuUnavailable {
            gpuAvailable = false
        }
        return BASMetalBenchmarkReport(
            shape: BASMetalBenchmarkShape(
                preDim: batch * hiddenDim,
                postDim: stateDim * sequenceLength,
                warmupIterations: warmupIterations,
                timedIterations: timedIterations),
            cpuMicrosecondsSamples: cpuSamples,
            gpuMicrosecondsSamples: gpuSamples,
            gpuAvailable: gpuAvailable)
    }

    /// Run one full benchmark for the given shape。
    /// The fold's plasticity rule is fixed to
    /// `.hebbian` (the simplest rule;all 4 rules share
    /// the same outer-product compute kernel so
    /// timing differences across rules are negligible)。
    public func runPlasticity(
        shape: BASMetalBenchmarkShape
    ) async throws -> BASMetalBenchmarkReport {
        let foldShape = BASPlasticityFoldShape(
            preDim: shape.preDim,
            postDim: shape.postDim,
            learningRate: 0.01,
            rule: .hebbian)
        let pre = Array(repeating: Float(0.5),
            count: shape.preDim)
        let post = Array(repeating: Float(0.5),
            count: shape.postDim)
        // CPU path
        let cpuFold = BASPlasticityFold(
            shape: foldShape)
        for _ in 0..<shape.warmupIterations {
            _ = try await cpuFold.apply(
                pre: pre, post: post)
        }
        var cpuSamples: [Double] = []
        cpuSamples.reserveCapacity(
            shape.timedIterations)
        for _ in 0..<shape.timedIterations {
            let t0 = Self.nowMicroseconds()
            _ = try await cpuFold.apply(
                pre: pre, post: post)
            let t1 = Self.nowMicroseconds()
            cpuSamples.append(t1 - t0)
        }
        // GPU path — gracefully skip if Metal
        // unavailable
        var gpuSamples: [Double] = []
        var gpuAvailable = true
        let gpuFold = BASPlasticityFold(
            shape: foldShape)
        do {
            for _ in 0..<shape.warmupIterations {
                _ = try await gpuFold.applyGPU(
                    pre: pre, post: post)
            }
            gpuSamples.reserveCapacity(
                shape.timedIterations)
            for _ in 0..<shape.timedIterations {
                let t0 = Self.nowMicroseconds()
                _ = try await gpuFold.applyGPU(
                    pre: pre, post: post)
                let t1 = Self.nowMicroseconds()
                gpuSamples.append(t1 - t0)
            }
        } catch BASPlasticityError.gpuUnavailable {
            gpuAvailable = false
        }
        return BASMetalBenchmarkReport(
            shape: shape,
            cpuMicrosecondsSamples: cpuSamples,
            gpuMicrosecondsSamples: gpuSamples,
            gpuAvailable: gpuAvailable)
    }

    // High-resolution MONOTONIC clock in µs。 Uses
    // `DispatchTime.now().uptimeNanoseconds` (backed by
    // mach_absolute_time) so a wall-clock adjustment (NTP
    // step, manual clock change) during a benchmark run
    // cannot produce a negative or skewed elapsed time。
    // Benchmark-only timing — not a parity path。
    fileprivate static func nowMicroseconds() -> Double {
        return Double(DispatchTime.now().uptimeNanoseconds)
            / 1_000.0
    }
}
