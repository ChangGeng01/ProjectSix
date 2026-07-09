// MARK: - BASDecodeLivenessMonitor — U3 decode 活性看门狗 (2026-06-12)
//
// Closes the observability gap the boundary-verdict adjudication
// confirmed (Docs/BOUNDARY_OVERHEAD_AND_HALT_VERDICT.md §D3):the MLX
// wedge (synchronous, uncancellable Metal eval — ADR-038 §9-§10.2)
// CANNOT be recovered in-process,and a per-turn timeout was tried
// and REMOVED on device evidence (ch1066:teardown deadlock + races
// a jetsam kill it cannot win)。 What CAN be built is DETECTION + a
// graceful surface:the host learns "this decode has stalled with
// the MLX-wedge signature",presents the QinaoSilentStub,persists
// state,and prompts a relaunch — while the external watchdog
// strategy (Mac-side kill+relaunch for unattended runs) gets a
// machine-parsable verdict line。
//
// ## HARD RULE: detection only — NEVER cancellation
//
// This monitor NEVER attempts to cancel, kill, or unwedge anything
// (ch1066 proved every such attempt deadlocks or loses the race)。
// It observes progress marks and reports。
//
// ## Shape: actor with injected monotonic clock (deterministic tests)
//
// The host marks `beginTurn` before the decode call,`progress()`
// per token/chunk (streaming hosts;non-streaming hosts simply have
// no marks between begin and end — the threshold then bounds the
// WHOLE decode),`endTurn` after。 A periodic `check()` (host-driven
// or via `startChecking`) compares now − lastProgress against
// `stallThresholdSec`;one verdict per stall episode (re-armed by the
// next progress mark)。 An optional injected `gpuProbe` closure (e.g.
// BASMetalGPUProbe one-shot) runs AT detection time:`gpuHealthy ==
// true` while decode is stalled is precisely the measured wedge
// signature (GPU fine, MLX process-local — 2026-06-09 control)。

import Foundation

/// One stall detection。 `gpuProbeHealthy == true` + a stalled decode
/// = the ADR-038 wedge signature (MLX-process-local;kill+relaunch
/// recovers;device GPU is NOT poisoned)。
public struct BASDecodeStallVerdict: Sendable, Equatable {
    public let turnID: String
    /// Seconds since the last progress mark (begin/progress)。
    public let secondsSinceProgress: Double
    /// Result of the injected GPU sibling probe at detection time;
    /// nil = no probe injected。
    public let gpuProbeHealthy: Bool?
    /// audit devicetestapp MED-1 — the strong "mlx-process-local-wedge" claim requires
    /// BOTH a healthy GPU AND the stall PERSISTING past the wedge-confirmation horizon
    /// (≫ the base stall threshold). A single base-threshold crossing on a slow-but-
    /// healthy non-streaming decode is only a `stall` (observability), NEVER a wedge —
    /// so an external Mac watchdog no longer false-kills a healthy long decode.
    public let isWedgeConfirmed: Bool

    public init(turnID: String, secondsSinceProgress: Double,
                gpuProbeHealthy: Bool?, isWedgeConfirmed: Bool = false) {
        self.turnID = turnID
        self.secondsSinceProgress = secondsSinceProgress
        self.gpuProbeHealthy = gpuProbeHealthy
        self.isWedgeConfirmed = isWedgeConfirmed
    }

    /// Machine-parsable one-liner for syslog (external watchdogs)。
    public var verdictLine: String {
        let gpu = gpuProbeHealthy.map { $0 ? "healthy" : "unhealthy" }
            ?? "unprobed"
        // audit devicetestapp MED-1: the wedge signature (which an external watchdog
        // acts on with a kill+relaunch) is stamped ONLY on a confirmed wedge, not on a
        // first-crossing healthy-GPU stall.
        let signature = isWedgeConfirmed
            ? "mlx-process-local-wedge" : "stall"
        return "🛑 decode-stall turn=\(turnID) "
            + "stalled_s=\(String(format: "%.1f", secondsSinceProgress)) "
            + "gpu_probe=\(gpu) signature=\(signature)"
    }
}

/// Observation-only decode liveness monitor。 Detection, never
/// cancellation (ch1066 / ADR-038)。
public actor BASDecodeLivenessMonitor {

    /// Monotonic now in nanoseconds — injected for deterministic
    /// tests;defaults to `DispatchTime.now()`。
    public typealias Clock = @Sendable () -> UInt64

    private let stallThresholdSec: Double
    /// audit devicetestapp MED-1 — the persistence horizon a stall must exceed (with a
    /// healthy GPU) before it is escalated to the strong `mlx-process-local-wedge` claim.
    private let wedgeConfirmSec: Double
    private let clock: Clock
    /// Optional GPU sibling probe run at detection time (host wires
    /// e.g. BASMetalGPUProbe;kept as a closure so this module gains
    /// no Metal dependency)。
    private let gpuProbe: (@Sendable () -> Bool)?
    /// Verdict sink — host presents the stub / logs the line。
    private let onStall: @Sendable (BASDecodeStallVerdict) -> Void

    private var currentTurnID: String?
    private var lastProgressNs: UInt64 = 0
    /// One base-stall verdict per episode;re-armed by the next progress。
    private var stallReported = false
    /// One escalated wedge verdict per episode (audit devicetestapp MED-1)。
    private var wedgeReported = false
    private var checkTask: Task<Void, Never>?

    public init(
        stallThresholdSec: Double = 30,
        wedgeConfirmSec: Double = 120,
        gpuProbe: (@Sendable () -> Bool)? = nil,
        clock: @escaping Clock = { DispatchTime.now().uptimeNanoseconds },
        onStall: @escaping @Sendable (BASDecodeStallVerdict) -> Void
    ) {
        // Boundary clamp: a non-positive threshold is a host bug;
        // 1s floor keeps the monitor honest rather than hyperactive。
        self.stallThresholdSec = max(1, stallThresholdSec)
        // The wedge horizon can never be below the base stall threshold.
        self.wedgeConfirmSec = max(self.stallThresholdSec, wedgeConfirmSec)
        self.gpuProbe = gpuProbe
        self.clock = clock
        self.onStall = onStall
    }

    // MARK: Progress marks (host-called)

    /// Mark the start of a decode turn (call just before
    /// `adapter.draft(...)` / the stream loop)。
    public func beginTurn(id: String) {
        currentTurnID = id
        lastProgressNs = clock()
        stallReported = false
        wedgeReported = false
    }

    /// Mark token/chunk progress (streaming hosts;optional for
    /// non-streaming — then the threshold bounds the whole decode)。
    public func progress() {
        guard currentTurnID != nil else { return }
        lastProgressNs = clock()
        stallReported = false
        wedgeReported = false
    }

    /// Mark turn completion (call after the decode returns/throws)。
    public func endTurn() {
        currentTurnID = nil
        stallReported = false
        wedgeReported = false
    }

    // MARK: Detection

    /// Evaluate liveness now。 Returns the verdict when a NEW stall
    /// episode is detected (also delivered to `onStall`);nil when
    /// idle, progressing, or already reported this episode。
    @discardableResult
    public func check() -> BASDecodeStallVerdict? {
        guard let turnID = currentTurnID else { return nil }
        let elapsedNs = clock() &- lastProgressNs
        let elapsedSec = Double(elapsedNs) / 1_000_000_000

        // audit devicetestapp MED-1 — escalate to the WEDGE signature only once the
        // stall has PERSISTED past the confirmation horizon with a healthy GPU. This is
        // the only path that stamps "mlx-process-local-wedge" (which the external
        // watchdog kills on). One escalated verdict per episode.
        if elapsedSec >= wedgeConfirmSec && !wedgeReported {
            wedgeReported = true
            stallReported = true            // the wedge subsumes the base stall
            let healthy = gpuProbe?()
            let verdict = BASDecodeStallVerdict(
                turnID: turnID,
                secondsSinceProgress: elapsedSec,
                gpuProbeHealthy: healthy,
                isWedgeConfirmed: healthy == true)   // healthy GPU + persistence = a real wedge
            onStall(verdict)
            return verdict
        }

        // Base stall (observability only — NOT a wedge, no external kill). One per episode.
        if elapsedSec >= stallThresholdSec && !stallReported {
            stallReported = true
            let verdict = BASDecodeStallVerdict(
                turnID: turnID,
                secondsSinceProgress: elapsedSec,
                gpuProbeHealthy: gpuProbe?(),
                isWedgeConfirmed: false)
            onStall(verdict)
            return verdict
        }
        return nil
    }

    // MARK: Self-driving checker (host convenience)

    /// Start a periodic background `check()` every `intervalSec`。
    /// Idempotent (restart replaces the prior task)。 The task only
    /// reads state and reports — it can never block or touch the
    /// decode (detection-only hard rule)。
    public func startChecking(intervalSec: Double = 5) {
        let interval = max(0.1, intervalSec)
        checkTask?.cancel()
        checkTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(interval * 1_000_000_000))
                guard let self else { return }
                await self.check()
            }
        }
    }

    public func stopChecking() {
        checkTask?.cancel()
        checkTask = nil
    }
}
