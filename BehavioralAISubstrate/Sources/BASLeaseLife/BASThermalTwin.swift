import Foundation
import BASRuntimeCore
#if canImport(Darwin)
import Darwin
#endif

/// L1 thermal twin — the runtime's live reading of the device's
/// thermal state, mapped into the vocabulary the rest of L1 speaks
/// (`BASThermalLevel` for observation, `BASThermalGuardLevel` for
/// policy enforcement).
///
/// ## Why this exists
///
/// Before today, `BASBudgetFrame.thermalGuardLevel` was a value the
/// caller had to invent. Nothing in the codebase read
/// `ProcessInfo.thermalState`, turned it into a guard level, and
/// handed it to the budget builder. The field was decoration.
///
/// This actor closes the gap:
///
/// 1. Observes `ProcessInfo.processInfo.thermalState` (real device
///    signal, backed by SMC / IOKit on iOS/macOS/watchOS).
/// 2. Maps the OS-level 4-way enum
///    (`nominal / fair / serious / critical`) into the L1
///    `BASThermalLevel` enum (`nominal / warm / hot / critical`).
/// 3. Folds in an *accumulation* signal (cumulative heat from a
///    long-running session — supplied by `BASLungStateAccumulator`)
///    and produces a `BASThermalGuardLevel` for the budget frame.
/// 4. Publishes changes via async stream so the budget builder can
///    react mid-session without polling.
///
/// The actor is designed to be test-injectable: the platform reader
/// is a `@Sendable` closure, so tests can drive any arbitrary
/// thermal trajectory without actually heating a device.
///
/// ## Mapping rationale
///
/// | OS thermalState | BASThermalLevel | Rationale                     |
/// |-----------------|-----------------|-------------------------------|
/// | .nominal        | .nominal        | cool, no pressure             |
/// | .fair           | .warm           | load rising but not throttled |
/// | .serious        | .hot            | OS is already throttling CPU  |
/// | .critical       | .critical       | thermal emergency             |
///
/// Guard-level mapping is further gated by accumulated pressure —
/// a device reading "warm" after 20 minutes of deepLoop should be
/// treated as "throttle", not "watch". Concretely:
///
/// | Level    | Accumulated <0.3 | <0.7        | ≥0.7         |
/// |----------|------------------|-------------|--------------|
/// | nominal  | nominal          | nominal     | watch        |
/// | warm     | watch            | throttle    | throttle     |
/// | hot      | throttle         | throttle    | emergency    |
/// | critical | emergency        | emergency   | emergency    |
public actor BASThermalTwin {
    /// OS-level thermal reading. Mirrors `ProcessInfo.ThermalState`
    /// so the actor remains portable across platforms where that
    /// type is available and testable where it isn't.
    public enum OSThermalState: String, Codable, Sendable, Equatable, CaseIterable {
        case nominal
        case fair
        case serious
        case critical
    }

    public struct Reading: Codable, Sendable, Equatable {
        public let osState: OSThermalState
        public let thermalLevel: BASThermalLevel
        public let guardLevel: BASThermalGuardLevel
        public let accumulatedPressure: Double
        public let observedAt: Date

        public init(
            osState: OSThermalState,
            thermalLevel: BASThermalLevel,
            guardLevel: BASThermalGuardLevel,
            accumulatedPressure: Double,
            observedAt: Date
        ) {
            self.osState = osState
            self.thermalLevel = thermalLevel
            self.guardLevel = guardLevel
            self.accumulatedPressure =
                min(1, max(0, accumulatedPressure))
            self.observedAt = observedAt
        }
    }

    /// Platform reader — returns the current OS thermal state.
    /// Default wiring reads `ProcessInfo.processInfo.thermalState`
    /// on Darwin and returns `.nominal` elsewhere. Tests override it.
    public typealias Reader = @Sendable () -> OSThermalState

    private let reader: Reader
    private let clock: @Sendable () -> Date
    private var lastReading: Reading?
    private var accumulatedPressure: Double = 0
    private var observers: [UUID: AsyncStream<Reading>.Continuation] = [:]
    /// M216 — holder for the SYNCHRONOUS observer registration — see
    /// `startObservingSystemNotifications(notificationCenter:)`.
    ///
    /// Boxed because `NSObjectProtocol` is not Sendable and a nonisolated `deinit` cannot
    /// touch actor-isolated non-Sendable state. The box is only ever mutated from the actor
    /// or from `deinit` (which runs when no other reference survives), so the unchecked
    /// conformance is sound.
    private final class ObserverBox: @unchecked Sendable {
        var token: NSObjectProtocol?
        var center: NotificationCenter?
        func remove() {
            if let token { (center ?? .default).removeObserver(token) }
            token = nil
            center = nil
        }
    }
    private let observerBox = ObserverBox()

    public init(
        reader: @escaping Reader = BASThermalTwin.defaultReader,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.reader = reader
        self.clock = clock
    }

    // MARK: - Observation

    /// Read the current state and publish it to observers. Returns
    /// the reading so the caller can inspect synchronously.
    @discardableResult
    public func sample() -> Reading {
        let osState = reader()
        let level = Self.thermalLevel(for: osState)
        let guardLevel = Self.guardLevel(
            for: level, accumulated: accumulatedPressure)
        let reading = Reading(
            osState: osState,
            thermalLevel: level,
            guardLevel: guardLevel,
            accumulatedPressure: accumulatedPressure,
            observedAt: clock())
        lastReading = reading
        for (_, continuation) in observers {
            continuation.yield(reading)
        }
        return reading
    }

    /// Update the accumulated pressure signal fed by the lung-state
    /// accumulator. Re-samples immediately so the guard level
    /// reflects new pressure without a second call.
    @discardableResult
    public func updateAccumulatedPressure(_ value: Double) -> Reading {
        accumulatedPressure = min(1, max(0, value))
        return sample()
    }

    public func currentReading() -> Reading? { lastReading }

    /// Default freshness window for `readingFresherThan(_:)`. Thermal state moves on the order of
    /// seconds; `sample()` is cheap (a `ProcessInfo.thermalState` read), so a short TTL is safe.
    public static let defaultReadingMaxAge: TimeInterval = 2.0

    /// audit policy-obs-misc LOW-6 — return the cached reading ONLY if it is younger than `maxAge`;
    /// otherwise take a fresh `sample()`. Callers that preferred `currentReading()` unconditionally
    /// (and the twin's notification observation is opt-in) could act on an arbitrarily stale thermal
    /// state — e.g. a breath scheduled at `.nominal` guard while the device has since gone `.serious`.
    @discardableResult
    public func readingFresherThan(
        _ maxAge: TimeInterval = BASThermalTwin.defaultReadingMaxAge
    ) -> Reading {
        if let last = lastReading, clock().timeIntervalSince(last.observedAt) < maxAge {
            return last
        }
        return sample()
    }

    // MARK: - Subscription

    /// Subscribe to reading updates. The stream terminates when the
    /// twin deallocates or when the returned handle is cancelled.
    public func subscribe() -> AsyncStream<Reading> {
        AsyncStream { continuation in
            let id = UUID()
            observers[id] = continuation
            // If we already have a reading, replay it so new
            // subscribers don't have to wait for the next sample.
            if let lastReading { continuation.yield(lastReading) }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeObserver(id: id) }
            }
        }
    }

    private func removeObserver(id: UUID) {
        observers[id] = nil
    }

    public func observerCount() -> Int { observers.count }

    // MARK: - System notification integration (M216)

    /// Start auto-sampling on
    /// `ProcessInfo.thermalStateDidChangeNotification`. While
    /// active, every system thermal-state change triggers
    /// `sample()` and yields a fresh Reading to every active
    /// subscriber — without a manual `sample()` call.
    ///
    /// `notificationCenter` is injected (default
    /// `NotificationCenter.default`) so tests can post synthetic
    /// notifications onto a private center without mutating the
    /// process-wide one. Calling this method again replaces any
    /// prior task; calling `stopObservingSystemNotifications()`
    /// cancels it.
    ///
    /// Idempotent: calling twice cancels the first observer Task
    /// before starting the second.
    /// ATTACHES SYNCHRONOUSLY — the twin IS observing when this returns.
    ///
    /// The previous implementation spawned a `Task` that only subscribed once it happened to
    /// run (`notificationCenter.notifications(named:)` attaches on first iteration), so this
    /// method returned BEFORE observation began and any notification posted in that window
    /// was silently lost. The API name promises otherwise, and a host that starts observing
    /// and immediately sees a thermal change would miss it.
    ///
    /// That race was real and measured, not theoretical: BASThermalTwinNotificationTests
    /// normally completes in ~86ms but hung past a 2s timeout on roughly 1 run in 3, and the
    /// timeout was being reported as an "OS NotificationCenter flake — not a substrate
    /// regression". It was a substrate regression. `addObserver(forName:object:queue:using:)`
    /// registers before it returns, which removes the window entirely.
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public func startObservingSystemNotifications(
        notificationCenter: NotificationCenter = .default
    ) {
        stopObservingSystemNotifications()
        observerBox.center = notificationCenter
        observerBox.token = notificationCenter.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            // The block runs synchronously on the posting thread; hop back onto the actor to
            // sample. Delivery is what must be race-free — sampling may land after.
            Task { [weak self] in await self?.sample() }
        }
    }

    /// Cancel the notification observer task started by
    /// `startObservingSystemNotifications(...)`. No-op if not
    /// running.
    public func stopObservingSystemNotifications() {
        observerBox.remove()
    }

    /// `true` while a notification observer task is active.
    public func isObservingSystemNotifications() -> Bool {
        observerBox.token != nil
    }

    deinit {
        observerBox.remove()
    }

    // MARK: - Mapping (pure; safe to unit-test)

    public static func thermalLevel(
        for osState: OSThermalState
    ) -> BASThermalLevel {
        switch osState {
        case .nominal: .nominal
        case .fair: .warm
        case .serious: .hot
        case .critical: .critical
        }
    }

    /// Map a thermal level + accumulated pressure into a guard level.
    /// See the table in the type doc for the full matrix.
    public static func guardLevel(
        for thermal: BASThermalLevel,
        accumulated: Double
    ) -> BASThermalGuardLevel {
        let p = min(1, max(0, accumulated))
        switch thermal {
        case .nominal:
            return p >= 0.7 ? .watch : .nominal
        case .warm:
            return p < 0.3 ? .watch : .throttle
        case .hot:
            return p >= 0.7 ? .emergency : .throttle
        case .critical:
            return .emergency
        }
    }

    // MARK: - Default reader

    /// Read `ProcessInfo.processInfo.thermalState` where available.
    /// On platforms that don't expose it (Linux CI), reports
    /// `.nominal` so the actor remains testable everywhere.
    public static let defaultReader: Reader = {
        #if canImport(Darwin)
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
        #else
        return .nominal
        #endif
    }
}
