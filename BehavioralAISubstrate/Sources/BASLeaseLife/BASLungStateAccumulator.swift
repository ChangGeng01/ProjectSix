import Foundation
import BASRuntimeCore

/// L1 "lung state" accumulator — the cross-turn memory of how hard
/// the runtime has been breathing. Each turn adds pressure; time
/// since the last turn decays it.
///
/// ## Why this exists
///
/// A single turn's thermal reading is always the instantaneous OS
/// signal. But the product promises "会醒会停" — the runtime must
/// treat a device that has been reflecting for 20 straight minutes
/// differently from a device that just booted. The OS thermal state
/// is lagging; we need a runtime-level integral.
///
/// `BASLungStateAccumulator` is that integral. It's a very small
/// piece — by design — so it can be tested deterministically and
/// reused across every milestone that needs "session heat".
///
/// ## Model
///
/// Pressure is bounded to `[0, 1]`. Each turn contributes a load
/// proportional to its run mode and duration; idle time between
/// turns decays pressure back toward zero using an exponential curve:
///
///     p_next = p_prev * exp(-idleSeconds / timeConstantSeconds)
///             + load(runMode, durationSeconds)
///
/// The load weights are intentionally asymmetric:
/// - `dormant` / `pulse` / `sentinel` are near-zero loads (~0.01 per
///   second of runtime) — the background heartbeat
/// - `engage` / `reflect` are mid loads (~0.05) — normal work
/// - `deepLoop` / `guard` are high loads (~0.15) — deep reasoning
/// - `recovery` / `quarantine` / `lockdown` are extraction modes,
///   near-zero load (system is winding down)
///
/// Time constant defaults to 180 s — pressure decays ~37% each
/// 3-minute idle window. Configurable by the caller.
public actor BASLungStateAccumulator {
    public struct Snapshot: Sendable, Equatable {
        public let pressure: Double
        public let turnCount: Int
        public let lastTurnAt: Date?
        public let lastDecayAt: Date?

        public init(
            pressure: Double,
            turnCount: Int,
            lastTurnAt: Date?,
            lastDecayAt: Date?
        ) {
            self.pressure = min(1, max(0, pressure))
            self.turnCount = max(0, turnCount)
            self.lastTurnAt = lastTurnAt
            self.lastDecayAt = lastDecayAt
        }
    }

    private let clock: @Sendable () -> Date
    private let timeConstantSeconds: Double

    private var pressure: Double = 0
    private var turnCount: Int = 0
    private var lastTurnAt: Date?
    private var lastDecayAt: Date?

    public init(
        timeConstantSeconds: Double = 180,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.timeConstantSeconds = max(1, timeConstantSeconds)
        self.clock = clock
    }

    // MARK: - Accumulation

    /// Record the completion of a single turn. `durationSeconds` is
    /// elapsed real time during the turn; `runMode` decides the load
    /// factor.
    @discardableResult
    public func record(
        runMode: BASEBrainRunMode,
        durationSeconds: Double
    ) -> Snapshot {
        let now = clock()
        decay(to: now)
        let contribution = Self.load(for: runMode) * max(0, durationSeconds)
        pressure = min(1, pressure + contribution)
        turnCount += 1
        lastTurnAt = now
        return snapshot()
    }

    /// Explicitly age the pressure forward to the given time without
    /// adding a turn. Useful when the scheduler is idle but we still
    /// want an accurate reading for the thermal twin.
    @discardableResult
    public func settle(to date: Date? = nil) -> Snapshot {
        let now = date ?? clock()
        decay(to: now)
        return snapshot()
    }

    public func snapshot() -> Snapshot {
        Snapshot(
            pressure: pressure,
            turnCount: turnCount,
            lastTurnAt: lastTurnAt,
            lastDecayAt: lastDecayAt)
    }

    public func reset() {
        pressure = 0
        turnCount = 0
        lastTurnAt = nil
        lastDecayAt = nil
    }

    // MARK: - Decay

    private func decay(to now: Date) {
        defer { lastDecayAt = now }
        guard let anchor = lastDecayAt ?? lastTurnAt else { return }
        let idle = max(0, now.timeIntervalSince(anchor))
        guard idle > 0 else { return }
        let factor = exp(-idle / timeConstantSeconds)
        pressure = min(1, max(0, pressure * factor))
    }

    // MARK: - Load weights (pure)

    /// Per-second load contribution by run mode.
    public static func load(for runMode: BASEBrainRunMode) -> Double {
        switch runMode {
        case .dormant, .pulse, .sentinel:
            return 0.01
        case .engage:
            return 0.05
        case .reflect:
            return 0.06
        case .deepLoop:
            return 0.15
        case .guard:
            return 0.12
        case .recovery, .quarantine, .lockdown:
            return 0.0
        }
    }
}
