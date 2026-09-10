// ADR-039 Phase 1 — per-Metal-kernel execution observability (point 4: record whether each kernel REALLY
// executed on the GPU, its duration, and GPU fallback). Pure telemetry — feeds NO value/verdict/hash, so
// it is byte-equal-off (the recordSink defaults nil). This is the foundation that makes Phases 2–4's live
// Metal *measurable* before it is trusted, and it is where a hang shows up (a record with a start stamp
// but no end, or no record at all — see the heartbeat).

import Foundation

/// One Metal dispatch attempt: did it complete on the GPU, how long, and (on failure) why.
public struct BASMetalKernelExecutionRecord: Sendable, Equatable, Codable {
    public let kernelSymbol: String
    /// `true` = the dispatch completed on the GPU; `false` = it threw (the CALLER then falls back to CPU).
    public let didRunOnGPU: Bool
    public let durationMs: Double
    public let error: String?
    public let dispatchStartMonoNs: UInt64
    public let dispatchEndMonoNs: UInt64

    public init(
        kernelSymbol: String,
        didRunOnGPU: Bool,
        durationMs: Double,
        error: String?,
        dispatchStartMonoNs: UInt64,
        dispatchEndMonoNs: UInt64
    ) {
        self.kernelSymbol = kernelSymbol
        self.didRunOnGPU = didRunOnGPU
        self.durationMs = durationMs
        self.error = error
        self.dispatchStartMonoNs = dispatchStartMonoNs
        self.dispatchEndMonoNs = dispatchEndMonoNs
    }

    /// A failed GPU attempt = the caller falls back to CPU.
    public var cpuFallback: Bool { !didRunOnGPU }
}

/// Per-turn aggregate for the endurance log's `📊 metal-kernels` line.
public struct BASMetalKernelExecutionAggregate: Sendable, Equatable, Codable {
    public let gpuRuns: Int
    public let cpuFallbacks: Int
    public let errors: Int
    public let p50DurationMs: Double
    public let p99DurationMs: Double

    public var anythingRanOnGPU: Bool { gpuRuns > 0 }
}

/// Collects execution records, drained per turn. Lock-guarded (not an actor) so the sync `recordSink`
/// closure can append without an await — the host wires `recordSink = { acc.record($0) }` and drains once
/// per turn off the value path.
public final class BASMetalKernelExecutionAccumulator: @unchecked Sendable {

    private let lock = NSLock()
    private var records: [BASMetalKernelExecutionRecord] = []

    public init() {}

    public func record(_ r: BASMetalKernelExecutionRecord) {
        lock.lock(); defer { lock.unlock() }
        records.append(r)
    }

    /// Return + clear the accumulated records (call once per turn).
    @discardableResult
    public func drain() -> [BASMetalKernelExecutionRecord] {
        lock.lock(); defer { lock.unlock() }
        let out = records
        records = []
        return out
    }

    /// Aggregate a drained batch (pure; safe to call on the result of `drain()`).
    public static func aggregate(_ batch: [BASMetalKernelExecutionRecord]) -> BASMetalKernelExecutionAggregate {
        let gpu = batch.filter { $0.didRunOnGPU }
        let durations = batch.map(\.durationMs).sorted()
        func pct(_ p: Double) -> Double {
            guard !durations.isEmpty else { return 0 }
            let idx = min(durations.count - 1, max(0, Int((p * Double(durations.count - 1)).rounded())))
            return durations[idx]
        }
        return BASMetalKernelExecutionAggregate(
            gpuRuns: gpu.count,
            cpuFallbacks: batch.count - gpu.count,
            errors: batch.filter { $0.error != nil }.count,
            p50DurationMs: pct(0.50),
            p99DurationMs: pct(0.99))
    }
}
