import Foundation
import BASRuntimeCore
import BASLeaseLife

// MARK: - M66 lifecycle façade
//
// M66 binds the L1 Lease & Life primitives (lung / thermal / breath
// scheduler) to real device signals and makes the wiring discoverable
// to hosts that use QinaoRuntime:
//
//   - `BASThermalTwin` reads `ProcessInfo.processInfo.thermalState`
//     (on Darwin; no-op elsewhere).
//   - `BASBreathScheduler` routes maintenance windows through
//     `QinaoBGMaintenanceBridge.system(...)`, which submits
//     `BGProcessingTaskRequest` via `BGTaskScheduler.shared` on iOS /
//     iPadOS / visionOS / tvOS / Mac Catalyst (no-op elsewhere).
//   - `BASLungStateAccumulator` folds cross-turn pressure back into
//     the thermal twin so the runtime's "session heat" shows up in
//     the guard level that downstream L1 observations read.
//
// Before M66, these three primitives existed as leaf components but
// had no caller on the Qinao main chain. `BASLeaseLifeCoordinator`
// (the plumbing that composes the three primitives correctly) was
// defined in `BASLeaseLife` but **no file in `QinaoRuntime` or
// `BASHostKit` imported it**; `QinaoBGMaintenanceBridge` existed as
// a ready-to-use `BASBreathScheduler.PlatformBridge` implementation
// but **never met a `BASBreathScheduler` instance**. The result was
// that hosts got the three-signature gate (permit / warrant /
// snapshot proof) but no live L1 — thermal guard levels were
// caller-invented constants, `BGTaskScheduler` was never called,
// and the L1 observation bundle's `.thermalReadingObserved` and
// `.maintenanceClassified` signals were carrying whatever the
// caller made up.
//
// `QinaoLifecycle` is the one-liner that closes that gap:
//
//     let lifecycle = QinaoLifecycle.makeSystem(
//         taskIdentifierPrefix: "myapp.breath")
//     // start-of-turn resample so thermal is fresh for the budget:
//     let reading = await lifecycle.resample()
//     let routedBudget = plannedBudget
//         .withLiveThermalGuardLevel(reading.thermal.guardLevel)
//     // end-of-turn record so pressure decays + scheduler reconciles:
//     await lifecycle.recordTurn(runMode: .engage, durationSeconds: 0.8)
//
// The helper `BASBudgetFrame.withLiveThermalGuardLevel(_:)` (M67,
// in `BASLeaseLife`) is the companion value transform that
// propagates the live reading into the main-chain budget.
//
// # Testability
//
// The actor keeps an injection seam so no test has to touch the real
// `BGTaskScheduler` or heat a device. `makeForTesting(...)` accepts:
//
//   - a `BASThermalTwin.Reader` closure (tests drive any thermal
//     trajectory)
//   - a `QinaoBGMaintenanceBridge.Submitter` (tests assert what the
//     platform was asked to schedule, and can simulate failure)
//   - a `QinaoBGMaintenanceBridge.Canceller` (tests observe
//     cancellation events)
//
// # Thread / actor model
//
// `QinaoLifecycle` is an `actor` — all state-touching methods are
// async. The `bridge` field is marked `nonisolated` because
// `QinaoBGMaintenanceBridge` is a `Sendable` value type and exposing
// it synchronously lets hosts forward the same bridge to other code
// paths (e.g. an out-of-band cancellation on app termination).

// MARK: - Public run-mode mirror
//
// `BASEBrainRunMode` lives on the substrate side and participates in
// the run-mode lattice (BR-001..BR-012 rely on it). Its raw name
// contains a forbidden brand token ("EBrain") that the public-surface
// redaction scanner (`scripts/check_sovereign_redaction.sh`) forbids
// from appearing in any Qinao module's public declaration fragment.
//
// `QinaoRunMode` is the thin Qinao-native mirror that `QinaoLifecycle`
// uses on its public surface. Its cases are a byte-for-byte 1:1 mirror
// of the substrate enum. The `init?(bridging:)` / `bridging` pair
// roundtrips losslessly. Hosts pass `QinaoRunMode`; the lifecycle
// actor translates to the substrate enum right before it calls into
// the coordinator. No BR-rule changes — we just replace the noun on
// the public surface.
public enum QinaoRunMode: String, Sendable, CaseIterable, Codable {
    case dormant
    case pulse
    case sentinel
    case engage
    case reflect
    case deepLoop
    case `guard` = "guard"
    case recovery
    case quarantine
    case lockdown

    /// Bridge a substrate run mode into the Qinao mirror. Trivial
    /// since raw values are identical; kept explicit so that if the
    /// substrate ever adds a case ahead of the mirror the compiler
    /// points at this one spot. `internal` because substrate types
    /// must not appear in any Qinao public declaration fragment —
    /// hosts construct `QinaoRunMode` directly via its cases.
    internal init(bridging runMode: BASEBrainRunMode) {
        switch runMode {
        case .dormant:     self = .dormant
        case .pulse:       self = .pulse
        case .sentinel:    self = .sentinel
        case .engage:      self = .engage
        case .reflect:     self = .reflect
        case .deepLoop:    self = .deepLoop
        case .guard:       self = .guard
        case .recovery:    self = .recovery
        case .quarantine:  self = .quarantine
        case .lockdown:    self = .lockdown
        }
    }

    /// Translate the Qinao mirror back to the substrate enum for
    /// calls into `BASLeaseLifeCoordinator` / `BASBreathScheduler`.
    internal var bridging: BASEBrainRunMode {
        switch self {
        case .dormant:     return .dormant
        case .pulse:       return .pulse
        case .sentinel:    return .sentinel
        case .engage:      return .engage
        case .reflect:     return .reflect
        case .deepLoop:    return .deepLoop
        case .guard:       return .guard
        case .recovery:    return .recovery
        case .quarantine:  return .quarantine
        case .lockdown:    return .lockdown
        }
    }
}

/// Qinao lifecycle façade binding `BASLeaseLifeCoordinator` +
/// `QinaoBGMaintenanceBridge` into one wire-able unit. See the file
/// header for rationale and usage patterns.
public actor QinaoLifecycle {

    // MARK: - Type aliases (for readable call sites)

    public typealias PlatformReader = BASThermalTwin.Reader
    public typealias Submitter = QinaoBGMaintenanceBridge.Submitter
    public typealias Canceller = QinaoBGMaintenanceBridge.Canceller

    // MARK: - Stored state

    /// Prefix every scheduled breath identifier carries when it is
    /// handed to the OS. Hosts must register this prefix (plus the
    /// individual IDs they schedule) under
    /// `BGTaskSchedulerPermittedIdentifiers` in Info.plist if they
    /// want the real OS wakeups to fire on iOS.
    public nonisolated let taskIdentifierPrefix: String

    /// The bridge the internal scheduler uses. Exposed `nonisolated`
    /// so hosts can forward it to app-termination handlers without an
    /// actor hop.
    public nonisolated let bridge: QinaoBGMaintenanceBridge

    private let coordinator: BASLeaseLifeCoordinator

    // MARK: - Private init

    private init(
        taskIdentifierPrefix: String,
        bridge: QinaoBGMaintenanceBridge,
        coordinator: BASLeaseLifeCoordinator
    ) {
        self.taskIdentifierPrefix = taskIdentifierPrefix
        self.bridge = bridge
        self.coordinator = coordinator
    }

    // MARK: - Factories

    /// Default production wiring. Reads real
    /// `ProcessInfo.processInfo.thermalState` on Darwin (returns
    /// `.nominal` elsewhere) and submits real
    /// `BGProcessingTaskRequest` via `BGTaskScheduler.shared` on
    /// iOS / iPadOS / visionOS / tvOS / Mac Catalyst. On watchOS and
    /// other platforms the submitter returns `false` — the internal
    /// scheduler still tracks the breath locally so in-process fires
    /// work, but the OS is never asked to wake the app.
    ///
    /// - Parameters:
    ///   - taskIdentifierPrefix: Host must register this prefix (plus
    ///     individual IDs) under `BGTaskSchedulerPermittedIdentifiers`
    ///     in Info.plist, and call `BGTaskScheduler.shared.register(...)`
    ///     at launch for each expected identifier. Default
    ///     `"qinao.breath"`.
    ///   - timeConstantSeconds: Pressure decay half-life passed to
    ///     `BASLungStateAccumulator`. Default 180 s (~37% decay per
    ///     3-minute idle window).
    ///   - requiresNetworkConnectivity: Forwarded to
    ///     `BGProcessingTaskRequest`. Default `false`.
    ///   - requiresExternalPower: Forwarded to
    ///     `BGProcessingTaskRequest`. Default `false`.
    ///   - clock: Injection seam for time. Default `{ Date() }`.
    public static func makeSystem(
        taskIdentifierPrefix: String = "qinao.breath",
        timeConstantSeconds: Double = 180,
        requiresNetworkConnectivity: Bool = false,
        requiresExternalPower: Bool = false,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) -> QinaoLifecycle {
        let bridge = QinaoBGMaintenanceBridge.system(
            taskIdentifierPrefix: taskIdentifierPrefix,
            requiresNetworkConnectivity: requiresNetworkConnectivity,
            requiresExternalPower: requiresExternalPower)
        let scheduler = BASBreathScheduler(
            bridge: bridge, clock: clock)
        let thermal = BASThermalTwin(
            reader: BASThermalTwin.defaultReader, clock: clock)
        let lung = BASLungStateAccumulator(
            timeConstantSeconds: timeConstantSeconds, clock: clock)
        let coordinator = BASLeaseLifeCoordinator(
            lung: lung, thermal: thermal, scheduler: scheduler)
        return QinaoLifecycle(
            taskIdentifierPrefix: taskIdentifierPrefix,
            bridge: bridge,
            coordinator: coordinator)
    }

    /// Test-friendly wiring. Every platform signal is injected so
    /// tests run deterministically without real `BGTaskScheduler` or
    /// real thermal readings.
    ///
    /// - Parameters:
    ///   - thermalReader: Returns an `OSThermalState` per call.
    ///     Tests use a mutable recorder to drive trajectories.
    ///   - submitter: Invoked whenever a breath is registered. Must
    ///     return `true` to simulate the OS accepting the request,
    ///     `false` otherwise.
    ///   - canceller: Invoked when a scheduled breath is cancelled
    ///     (either explicitly or via thermal reconciliation).
    public static func makeForTesting(
        taskIdentifierPrefix: String = "qinao.breath",
        timeConstantSeconds: Double = 180,
        thermalReader: @escaping PlatformReader,
        submitter: @escaping Submitter,
        canceller: @escaping Canceller,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) -> QinaoLifecycle {
        let bridge = QinaoBGMaintenanceBridge(
            taskIdentifierPrefix: taskIdentifierPrefix,
            submitter: submitter,
            canceller: canceller)
        let scheduler = BASBreathScheduler(
            bridge: bridge, clock: clock)
        let thermal = BASThermalTwin(reader: thermalReader, clock: clock)
        let lung = BASLungStateAccumulator(
            timeConstantSeconds: timeConstantSeconds, clock: clock)
        let coordinator = BASLeaseLifeCoordinator(
            lung: lung, thermal: thermal, scheduler: scheduler)
        return QinaoLifecycle(
            taskIdentifierPrefix: taskIdentifierPrefix,
            bridge: bridge,
            coordinator: coordinator)
    }

    // MARK: - Turn lifecycle

    /// Record a completed turn. Updates the lung accumulator, folds
    /// the new pressure into the thermal twin, and reconciles the
    /// breath scheduler against the resulting guard level.
    /// Returns the structured outcome — lung snapshot, thermal
    /// reading, and IDs of any breaths cancelled during reconcile.
    ///
    /// The public surface takes the Qinao-native `QinaoRunMode`
    /// mirror. The actor translates to the substrate enum before
    /// calling into the coordinator so downstream BR-rule evaluation
    /// still sees the original lattice.
    @discardableResult
    public func recordTurn(
        runMode: QinaoRunMode,
        durationSeconds: Double
    ) async -> BASLeaseLifeCoordinator.TurnRecorded {
        await coordinator.recordTurn(
            runMode: runMode.bridging,
            durationSeconds: durationSeconds)
    }

    /// Resample thermal + lung without recording a turn. Use this at
    /// the start of a turn (before building the budget frame) or on
    /// idle heartbeats to decay accumulated pressure and pick up the
    /// latest OS thermal state.
    @discardableResult
    public func resample() async -> BASLeaseLifeCoordinator.TurnRecorded {
        await coordinator.resample()
    }

    /// Live thermal reading. Cheap — returns the cached reading from
    /// the last `recordTurn` / `resample`. If the actor has not yet
    /// sampled, forces a fresh sample.
    public func currentReading() async -> BASThermalTwin.Reading {
        let thermal = await coordinator.thermalActor()
        if let cached = await thermal.currentReading() {
            return cached
        }
        return await thermal.sample()
    }

    /// Live guard level. Convenience around `currentReading`.
    public func currentGuardLevel() async -> BASThermalGuardLevel {
        await currentReading().guardLevel
    }

    // MARK: - M104 per-tier thermal snapshot (T3)

    /// Project the live scalar `BASThermalTwin.Reading` into a
    /// three-tier `BASComputeTierThermalSnapshot` suitable for
    /// `BASComputeRouter.route(snapshot:)`.
    ///
    /// The scalar twin carries a single `BASThermalLevel` (today's
    /// substrate only knows one thermal domain via
    /// `ProcessInfo.thermalState`). The projection maps that level
    /// to a normalized headroom uniformly across CPU / GPU / NPU:
    ///
    /// | BASThermalLevel | Headroom |
    /// |-----------------|----------|
    /// | .nominal        | 1.0      |
    /// | .warm           | 0.7      |
    /// | .hot            | 0.3      |
    /// | .critical       | 0.0      |
    ///
    /// All three tiers receive the SAME headroom under this naïve
    /// projection — the scalar twin cannot distinguish per-tier
    /// pressure, so the router's preferred-order tie-breaker
    /// (NPU > GPU > CPU by default) carries the decision.
    ///
    /// Future platform adapters (IOKit CPU pressure / Metal
    /// performance query / ANE pressure) will replace this
    /// projection with real per-tier signals. Until then the
    /// router at least has a non-stub snapshot to act on, which
    /// is strictly better than refusing to route.
    ///
    /// - Parameter observedAt: timestamp for the per-tier readings
    ///   and the snapshot wrapper. Defaults to `Date()`.
    /// - Returns: three-tier snapshot populated from the live
    ///   scalar reading.
    public func computeTierThermalSnapshot(
        observedAt: Date = Date()
    ) async -> BASComputeTierThermalSnapshot {
        let reading = await currentReading()
        let headroom = Self.headroom(for: reading.thermalLevel)
        let tiers: [BASComputeTier] = [.cpu, .gpu, .npu]
        let readings = tiers.map { tier in
            BASComputeTierThermalReading(
                tier: tier,
                level: reading.thermalLevel,
                headroom: headroom,
                observedAt: observedAt)
        }
        return BASComputeTierThermalSnapshot(
            readings: readings,
            snapshotAt: observedAt)
    }

    /// Pure mapping from scalar level to normalized headroom.
    /// Extracted as `static` so tests can exercise the mapping
    /// without driving a full lifecycle fixture.
    internal static func headroom(
        for level: BASThermalLevel
    ) -> Double {
        switch level {
        case .nominal: return 1.0
        case .warm: return 0.7
        case .hot: return 0.3
        case .critical: return 0.0
        }
    }

    // MARK: - Budget-frame routing (M69)

    /// Stamp the lifecycle's live thermal guard level onto a planned
    /// `BASBudgetFrame` and return the routed copy.
    ///
    /// This is the M69 seam that closes the main-chain wiring from
    /// lifecycle → per-turn budget. Before M69, hosts had to spell
    /// out the two-step "read the twin, then call
    /// `withLiveThermalGuardLevel`" dance themselves; with M69 the
    /// one-liner becomes:
    ///
    ///     let routed = await lifecycle
    ///         .applyLiveThermalGuardLevel(to: plannedBudget)
    ///
    /// Mirror of `BASBudgetFrame.withLiveThermalGuardLevel(from:)`
    /// (M67), but keyed on `QinaoLifecycle` instead of
    /// `BASLeaseLifeCoordinator` so hosts never have to touch the
    /// substrate-private coordinator. Internally uses
    /// `currentReading()` — warm-cache-preferred, force-sample when
    /// the lifecycle has not yet observed a turn.
    ///
    /// Pure value-transform semantics: every other field of the
    /// frame — schema version, run mode, caps, precision profile,
    /// device route, lease metadata, maintenance class, allowed
    /// heads, policy identifiers — is preserved byte-for-byte.
    ///
    /// - Parameter planned: The budget frame the caller has already
    ///   built for the upcoming turn.
    /// - Returns: A new frame identical to `planned` except that its
    ///   `thermalGuardLevel` is the lifecycle's live value.
    public func applyLiveThermalGuardLevel(
        to planned: BASBudgetFrame
    ) async -> BASBudgetFrame {
        let reading = await currentReading()
        return planned.withLiveThermalGuardLevel(reading.guardLevel)
    }

    // MARK: - Breath scheduling (forwarding)

    /// Schedule a maintenance breath. Routes through the thermal-
    /// gated `BASBreathScheduler` — under `.emergency` all breaths
    /// are rejected, under `.throttle` only `.light` is allowed.
    /// Accepted breaths are handed to the platform bridge (real
    /// `BGTaskScheduler` via `makeSystem`, or the injected submitter
    /// via `makeForTesting`).
    @discardableResult
    public func scheduleBreath(
        _ request: BASBreathScheduler.Request
    ) async throws -> BASBreathScheduler.ScheduledBreath {
        try await coordinator.scheduleBreath(request)
    }

    // MARK: - Actor accessors (for interop / inspection)

    public func thermalActor() async -> BASThermalTwin {
        await coordinator.thermalActor()
    }
    public func schedulerActor() async -> BASBreathScheduler {
        await coordinator.schedulerActor()
    }
    public func lungActor() async -> BASLungStateAccumulator {
        await coordinator.lungActor()
    }
}
