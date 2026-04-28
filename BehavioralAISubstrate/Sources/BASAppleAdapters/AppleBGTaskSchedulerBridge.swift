import Foundation
import BASLeaseLife
import BASRuntimeCore
// `BGTaskScheduler` is `API_UNAVAILABLE(macos)` — the type
// itself is not available on native macOS even though the
// `BackgroundTasks` module imports. Gate the actual API calls
// on the platforms that support `BGTaskScheduler.shared`:
// iOS / iPadOS / tvOS / visionOS / Mac Catalyst (which builds
// as iOS).
#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
import BackgroundTasks
#endif

/// M16 / L1 — `BGTaskScheduler`-backed `PlatformBridge` for
/// `BASBreathScheduler`.
///
/// ## Why this exists
///
/// `BASBreathSchedulerFrame.backgroundMaintenanceWindowMs` was
/// emitted every turn but nothing actually schedules a real OS
/// wake-up. The plan calls this out as M16 / M4: "Based on
/// `backgroundMaintenanceWindowMs` really schedule (iOS
/// `BGTaskScheduler` integration)."
///
/// ## Mapping
///
/// `BASBreathScheduler.Request` →
/// `BGProcessingTaskRequest`:
///
/// - `request.id` → `BGProcessingTaskRequest.identifier`. The
///   host app must register this identifier in `Info.plist`
///   under `BGTaskSchedulerPermittedIdentifiers` for the OS
///   to accept the submission. If not registered, `submit`
///   throws and the bridge returns `false` (the substrate's
///   contract — caller can choose to retry or downgrade).
/// - `request.earliestFireAt` → `earliestBeginDate`. The OS
///   schedules the task no earlier than this date; actual fire
///   time depends on system conditions.
/// - `request.maintenanceClass` shapes the resource flags:
///   - `.light` → no power / network requirements (fastest scheduling)
///   - `.standard` → no special requirements
///   - `.deferred` → `requiresExternalPower = true` (only fires
///     while plugged in; for heavy maintenance like KV cache
///     compaction or audit-ledger SQLite vacuum)
///   - `.none` → register call is a no-op, returns `true`
///     (caller didn't actually want a wakeup)
///
/// ## Platform availability
///
/// `BackgroundTasks` is importable on iOS 13+, iPadOS 13+,
/// macOS 13+ (with caveats), tvOS 13+, visionOS 1+. **Not
/// watchOS.** When the framework isn't importable, the bridge
/// compiles as a no-op — `register` returns `false`,
/// `cancel` is empty. Hosts on those platforms can still wire
/// the bridge in; the `BASBreathScheduler` actor will record
/// the request locally for in-process bookkeeping but won't
/// receive an OS callback.
///
/// ## Thread safety
///
/// The bridge holds no mutable state. `BGTaskScheduler.shared`
/// is documented as thread-safe for `submit` and `cancel`
/// calls. The class is `final` with no stored properties, so
/// declaring it `Sendable` is honest.
public final class AppleBGTaskSchedulerBridge:
    BASBreathScheduler.PlatformBridge, Sendable
{
    public init() {}

    public func register(
        _ request: BASBreathScheduler.Request
    ) async -> Bool {
        // None-class requests are a no-op — caller didn't ask
        // the OS for anything.
        if request.maintenanceClass == .none {
            return true
        }
        #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
        return Self.submitProcessingRequest(request)
        #else
        // Native macOS / watchOS / non-Apple — no
        // BGTaskScheduler. `BASBreathScheduler` still records
        // the request locally so foreground-fire logic works.
        return false
        #endif
    }

    public func cancel(id: String) async {
        #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
        Self.cancelProcessingRequest(id: id)
        #endif
    }

    // MARK: - Platform calls

    #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
    private static func submitProcessingRequest(
        _ request: BASBreathScheduler.Request
    ) -> Bool {
        // iOS 13+, iPadOS 13+, tvOS 13+, visionOS 1+, Mac
        // Catalyst 13+. Gate with `#available` for the rare
        // case a host backports below the framework minimum.
        guard #available(
            iOS 13.0, tvOS 13.0, visionOS 1.0,
            macCatalyst 13.0, *)
        else { return false }

        let bg = BGProcessingTaskRequest(
            identifier: request.id)
        bg.earliestBeginDate = request.earliestFireAt
        bg.requiresNetworkConnectivity = false
        // Only `.deferred` (heavy work) requires charging.
        // `.light` and `.standard` run on battery so they
        // can fire during normal background time.
        bg.requiresExternalPower =
            request.maintenanceClass == .deferred
        do {
            try BGTaskScheduler.shared.submit(bg)
            return true
        } catch {
            // Common throws:
            //   * .unavailable — device unsupported
            //   * .tooManyPendingTaskRequests — 10+ pending
            //   * .notPermitted — identifier not in
            //     `BGTaskSchedulerPermittedIdentifiers`
            // None recoverable from the bridge side.
            // `BASBreathScheduler` keeps its own record so
            // foreground-fire logic still works.
            return false
        }
    }

    private static func cancelProcessingRequest(id: String) {
        guard #available(
            iOS 13.0, tvOS 13.0, visionOS 1.0,
            macCatalyst 13.0, *)
        else { return }
        BGTaskScheduler.shared.cancel(
            taskRequestWithIdentifier: id)
    }
    #endif
}
