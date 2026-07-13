// MARK: - BASMetalGPUProbe
// ADR-038 §10 — the discriminating experiment for "Metal firmware vs MLX bug".
//
// PURPOSE
// The decode wedge (ADR-038) leaves the device GPU "poisoned" until a full reboot. The layer-pin
// (ADR-038 §10) proved the UNRECOVERABILITY is an MLX problem but could NOT determine whether the
// FAULT is owned by Apple's Metal/AGX driver/firmware OR by an MLX-induced GPU bug (premature buffer
// recycling / completion-handler lock-inversion in the vendored MLX device.cpp). The one experiment
// that discriminates them was never run: submit a TRIVIAL, MLX-FREE Metal command buffer on a
// contaminated GPU and see whether it completes.
//
//   • bare Metal command buffer COMPLETES on the poisoned device  ⇒ the GPU device itself is fine;
//     the contamination is MLX-process/queue-state-specific  ⇒ MLX-CAUSED ⇒ a real PREVENTION fix
//     could live in the vendored MLX (reopens "完全解决").
//   • bare Metal command buffer TIMES OUT / errors               ⇒ the whole GPU client is wedged
//     below MLX ⇒ leaning Apple driver/firmware ⇒ the external watchdog + reboot-on-poison ceiling
//     (ADR-038 §8/§9) stands.
//
// DESIGN — this probe uses ZERO MLX. It builds its own MTLDevice + MTLCommandQueue + a trivial inline
// compute kernel, and waits for completion via `addCompletedHandler` + a TIMED `DispatchSemaphore`
// (NOT `waitUntilCompleted`, which has no timeout and is the exact MLX trap — eval.cpp:92). So the
// probe is robust to a wedged GPU: it reports `timedOut` and returns, never permanently losing its
// thread. That property is what lets it run as a concurrent heartbeat ALONGSIDE a wedging MLX run.
//
// This file is byte-determinism-irrelevant (a diagnostic, never on the governance/replay spine) and
// ships behind opt-in env flags in the DeviceTestApp (BAS_METAL_PROBE_ONLY / BAS_METAL_PROBE_CONCURRENT).

import Foundation
#if canImport(Metal)
import Metal
#endif

// MARK: Outcome / Summary types

public struct BASMetalGPUProbeOutcome: Sendable, Equatable {
    public enum Status: String, Sendable, Equatable, Codable {
        /// The command buffer reached `.completed` within the timeout — the GPU is usable.
        case completed
        /// The command buffer never completed within the timeout — the GPU is (or became) wedged.
        case timedOut
        /// The command buffer reported `.error` (a GPU fault surfaced as an error, not a hang).
        case errored
        /// Could not even build device/queue/pipeline (Metal unavailable, or setup itself hung/failed).
        case setupFailed
    }

    public let status: Status
    public let elapsedMs: Double
    /// MTLCommandBuffer.status raw value at observation time (e.g. "completed", "committed", "error"),
    /// plus any error string — the raw forensic detail.
    public let detail: String

    public init(status: Status, elapsedMs: Double, detail: String) {
        self.status = status
        self.elapsedMs = elapsedMs
        self.detail = detail
    }
}

public struct BASMetalGPUProbeSummary: Sendable, Equatable {
    public let iterations: Int
    public let completed: Int
    public let timedOut: Int
    public let errored: Int
    public let setupFailed: Bool
    public let outcomes: [BASMetalGPUProbeOutcome]

    public init(outcomes: [BASMetalGPUProbeOutcome], setupFailed: Bool) {
        self.outcomes = outcomes
        self.setupFailed = setupFailed
        self.iterations = outcomes.count
        self.completed = outcomes.filter { $0.status == .completed }.count
        self.timedOut = outcomes.filter { $0.status == .timedOut }.count
        self.errored = outcomes.filter { $0.status == .errored }.count
    }

    /// True iff EVERY probe iteration completed — i.e. a healthy, usable GPU.
    public var allCompleted: Bool {
        !setupFailed && !outcomes.isEmpty && completed == outcomes.count
    }

    /// True iff at least one iteration hung/errored — i.e. the GPU is (or became) wedged.
    public var anyWedged: Bool {
        timedOut > 0 || errored > 0
    }

    /// A single grep-able discriminating verdict line for the endurance log (📊 ch1025 channel).
    /// `context` is e.g. "probe-only" (fresh-process control) or "concurrent" (alongside MLX).
    public func verdictLine(context: String) -> String {
        let status: String
        let reading: String
        if setupFailed {
            status = "SETUP_FAILED"
            reading = "could-not-create-device/queue/pipeline (Metal unavailable OR GPU wedged at setup)"
        } else if allCompleted {
            status = "ALL_COMPLETED"
            reading = "bare-Metal-WORKS → if device was poisoned, contamination is MLX-state-specific → MLX-CAUSED"
        } else if anyWedged {
            status = "WEDGED"
            reading = "bare-Metal-also-hangs → GPU client wedged below MLX → leaning Apple-driver/firmware"
        } else {
            status = "INCONCLUSIVE"
            reading = "no iterations ran"
        }
        let medianMs = Self.median(outcomes.map { $0.elapsedMs })
        return String(
            format: "📊 ch1025 metal-probe context=%@ verdict=%@ iters=%d completed=%d timed_out=%d errored=%d median_ms=%.2f reading=%@",
            context, status, iterations, completed, timedOut, errored, medianMs, reading)
    }

    private static func median(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted()
        let mid = s.count / 2
        return s.count % 2 == 0 ? (s[mid - 1] + s[mid]) / 2 : s[mid]
    }
}

// MARK: In-flight budget

/// audit devicetestapp MED-8 — a thread-safe bound on outstanding GPU command buffers.
/// A Metal command queue blocks the makeCommandBuffer that would exceed its in-flight
/// quota (default 64). On a GPU wedge the probe's timed-out-but-uncompleted buffers
/// accumulate (each `.timedOut` leaves its buffer committed/in-flight), and ~21 min in
/// the 65th makeCommandBuffer BLOCKS — the heartbeat freezes and adjudication goes blind
/// exactly when it matters. This caps outstanding BELOW the quota so the probe emits a
/// bounded `.timedOut` forever instead of ever reaching the blocking allocation.
/// Pure + Mac-testable (no Metal); the wiring into runOnce is the device-verified part.
public final class BASMetalProbeInFlightBudget: @unchecked Sendable {
    private let lock = NSLock()
    private let cap: Int
    private var outstanding = 0

    public init(cap: Int) { self.cap = max(1, cap) }

    /// Reserve a slot. `false` ⇒ at capacity — the caller must NOT issue the command
    /// buffer (return a bounded `.timedOut` instead of blocking).
    public func tryAcquire() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard outstanding < cap else { return false }
        outstanding += 1
        return true
    }

    /// Release a slot — called from the command buffer's completion handler.
    public func release() {
        lock.lock(); defer { lock.unlock() }
        if outstanding > 0 { outstanding -= 1 }
    }

    /// Current outstanding count (diagnostics/tests).
    public var inFlight: Int {
        lock.lock(); defer { lock.unlock() }
        return outstanding
    }
}

// MARK: Probe

public enum BASMetalGPUProbe {

    /// Outstanding-command-buffer cap, safely below Metal's default 64-buffer queue quota
    /// so the probe never reaches the blocking makeCommandBuffer on a wedged queue.
    static let inFlightCap = 60

    /// Inline MSL: a trivial element-wise increment — representative GPU COMPUTE work (like MLX's
    /// decode kernels), not a blit, so a compute-path GPU wedge is exercised. Deliberately tiny.
    private static let kernelSource = """
    #include <metal_stdlib>
    using namespace metal;
    kernel void bas_probe_increment(device float *data [[buffer(0)]],
                                    uint i [[thread_position_in_grid]]) {
        data[i] = data[i] + 1.0f;
    }
    """

    private static let elementCount = 1024
    public static let defaultTimeoutSec: Double = 8.0

    #if canImport(Metal)

    /// Build the (device, queue, pipeline, buffer) once; the suite reuses them across iterations.
    fileprivate struct Rig {
        let device: MTLDevice
        let queue: MTLCommandQueue
        let pipeline: MTLComputePipelineState
        let buffer: MTLBuffer
        /// audit devicetestapp MED-8 — one budget per queue, shared across probeOnce calls.
        let budget: BASMetalProbeInFlightBudget
    }

    fileprivate static func makeRig() -> Rig? {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let buffer = device.makeBuffer(length: elementCount * MemoryLayout<Float>.stride,
                                             options: .storageModeShared)
        else { return nil }
        do {
            let library = try device.makeLibrary(source: kernelSource, options: nil)
            guard let fn = library.makeFunction(name: "bas_probe_increment") else { return nil }
            let pipeline = try device.makeComputePipelineState(function: fn)
            return Rig(device: device, queue: queue, pipeline: pipeline, buffer: buffer,
                       budget: BASMetalProbeInFlightBudget(cap: inFlightCap))
        } catch {
            return nil
        }
    }

    /// Submit ONE trivial compute command buffer and wait — timeout-bounded so a wedged GPU yields
    /// `.timedOut` instead of hanging this thread forever.
    fileprivate static func runOnce(_ rig: Rig, timeoutSec: Double) -> BASMetalGPUProbeOutcome {
        let start = DispatchTime.now()
        // audit devicetestapp MED-8: reserve an in-flight slot BEFORE the (potentially
        // blocking) makeCommandBuffer. At capacity ⇒ a wedge has accumulated the queue's
        // whole quota of uncompleted buffers; emit a bounded .timedOut rather than block.
        guard rig.budget.tryAcquire() else {
            return BASMetalGPUProbeOutcome(
                status: .timedOut, elapsedMs: 0,
                detail: "in-flight command-buffer budget exhausted (cap \(inFlightCap)) — "
                    + "refusing to block makeCommandBuffer on a wedged queue")
        }
        guard let cb = rig.queue.makeCommandBuffer(),
              let enc = cb.makeComputeCommandEncoder()
        else {
            rig.budget.release()   // never issued the buffer → free the reserved slot
            return BASMetalGPUProbeOutcome(status: .setupFailed, elapsedMs: 0,
                                           detail: "makeCommandBuffer/Encoder returned nil")
        }
        enc.setComputePipelineState(rig.pipeline)
        enc.setBuffer(rig.buffer, offset: 0, index: 0)
        let threads = MTLSize(width: elementCount, height: 1, depth: 1)
        let tgroup = MTLSize(
            width: min(rig.pipeline.maxTotalThreadsPerThreadgroup, elementCount),
            height: 1, depth: 1)
        enc.dispatchThreads(threads, threadsPerThreadgroup: tgroup)
        enc.endEncoding()

        let sem = DispatchSemaphore(value: 0)
        // deep-audit P2-24 (2026-07-13): capture only the Sendable pieces (`budget` is
        // @unchecked Sendable — see the thread-safety rationale on Budget), not the whole
        // non-Sendable `rig`. Behaviour-identical; silences the Sendable-capture warning that
        // surfaced in every BASMetalSubstrate build (and would be a Swift-6-mode error).
        let budget = rig.budget
        // Release the in-flight slot when the buffer completes (even on error). A buffer
        // that never completes (a true wedge) holds its slot forever — which is the point:
        // outstanding saturates the cap and subsequent probes short-circuit to .timedOut.
        cb.addCompletedHandler { _ in budget.release(); sem.signal() }
        cb.commit()

        let waitResult = sem.wait(timeout: .now() + timeoutSec)
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0

        if waitResult == .timedOut {
            return BASMetalGPUProbeOutcome(
                status: .timedOut, elapsedMs: elapsedMs,
                detail: "no completion within \(timeoutSec)s; status=\(statusString(cb.status))")
        }
        if cb.status == .error {
            let err = cb.error.map { String(describing: $0) } ?? "unknown"
            return BASMetalGPUProbeOutcome(status: .errored, elapsedMs: elapsedMs,
                                           detail: "status=error error=\(err)")
        }
        return BASMetalGPUProbeOutcome(status: .completed, elapsedMs: elapsedMs,
                                       detail: "status=\(statusString(cb.status))")
    }

    private static func statusString(_ s: MTLCommandBufferStatus) -> String {
        switch s {
        case .notEnqueued: return "notEnqueued"
        case .enqueued: return "enqueued"
        case .committed: return "committed"
        case .scheduled: return "scheduled"
        case .completed: return "completed"
        case .error: return "error"
        @unknown default: return "unknown(\(s.rawValue))"
        }
    }

    /// Run `iterations` trivial command buffers on a fresh rig. Returns a summary with a discriminating
    /// verdict. Safe to call on a wedged GPU (each iteration is timeout-bounded).
    public static func runSuite(iterations: Int = 5,
                                timeoutSec: Double = defaultTimeoutSec) -> BASMetalGPUProbeSummary {
        guard let rig = makeRig() else {
            return BASMetalGPUProbeSummary(outcomes: [], setupFailed: true)
        }
        var outcomes: [BASMetalGPUProbeOutcome] = []
        outcomes.reserveCapacity(max(1, iterations))
        for _ in 0..<max(1, iterations) {
            outcomes.append(runOnce(rig, timeoutSec: timeoutSec))
        }
        return BASMetalGPUProbeSummary(outcomes: outcomes, setupFailed: false)
    }

    #else

    /// Metal-less platforms (Linux CI): setup cannot succeed; surface it honestly.
    public static func runSuite(iterations: Int = 5,
                                timeoutSec: Double = defaultTimeoutSec) -> BASMetalGPUProbeSummary {
        return BASMetalGPUProbeSummary(outcomes: [], setupFailed: true)
    }

    #endif
}

#if canImport(Metal)
/// A LONG-LIVED probe session: builds one device/queue/pipeline up front, then services repeated
/// `probeOnce()` calls on that same sibling queue. Used by the concurrent heartbeat (ADR-038 §10) to
/// answer, in a SINGLE run: does a long-lived non-MLX Metal queue keep completing command buffers
/// AFTER the MLX decode wedges (→ GPU device fine, MLX-state-local wedge) or stop at the same moment
/// (→ whole GPU client wedged). MTLDevice/Queue/Pipeline are thread-safe for this use.
public final class BASMetalGPUProbeSession: @unchecked Sendable {
    private let rig: BASMetalGPUProbe.Rig
    private init(rig: BASMetalGPUProbe.Rig) { self.rig = rig }

    /// Returns nil iff the GPU rig could not be built (no Metal device, or setup itself wedged).
    public static func make() -> BASMetalGPUProbeSession? {
        guard let rig = BASMetalGPUProbe.makeRig() else { return nil }
        return BASMetalGPUProbeSession(rig: rig)
    }

    public func probeOnce(timeoutSec: Double = BASMetalGPUProbe.defaultTimeoutSec) -> BASMetalGPUProbeOutcome {
        BASMetalGPUProbe.runOnce(rig, timeoutSec: timeoutSec)
    }
}
#endif
