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
        return await Self.submitProcessingRequest(request)
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

    // MARK: - Launch-handler registration — 全面进化 T3.1 Phase B
    //
    // The SUBMIT side above asks the OS for a wake;this is the
    // missing RECEIVE side:what runs when the OS grants it。 Apple
    // requires registration BEFORE the app finishes launching and
    // the identifier to be listed under
    // `BGTaskSchedulerPermittedIdentifiers` in Info.plist —
    // otherwise submit throws `.notPermitted`。
    //
    // OPPORTUNISTIC, NOT LOAD-BEARING (T3.1 adjudication): the
    // foreground after-turn driver (`BASSleepConsolidationDriver`)
    // is the dependable consolidation path;OS-fired windows are a
    // bonus。 The handler MUST call `setTaskCompleted(success:)`
    // and honor expiration — the wrapper enforces both by running
    // the work in a cancellable Task wired to `expirationHandler`。

    /// Register a launch handler for `identifier`。 Returns false
    /// when the platform has no BGTaskScheduler,when called after
    /// launch, or when the identifier was already registered。
    /// `work` runs on an OS-granted background window;it is
    /// CANCELLED (Task cancellation) when the OS expires the
    /// window,and the task is always marked completed。
    public static func registerLaunchHandler(
        identifier: String,
        work: @escaping @Sendable () async -> Bool
    ) -> Bool {
        #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
        guard #available(
            iOS 13.0, tvOS 13.0, visionOS 1.0,
            macCatalyst 13.0, *)
        else { return false }
        return BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil
        ) { task in
            // BGTask is not Sendable but `setTaskCompleted` is
            // documented thread-safe;the box carries it across the
            // Task/expiration domains and guards against double
            // completion (expiration + late finish racing)。
            let box = CompletionBox(task)
            let job = Task {
                let success = await work()
                box.completeOnce(success: success)
            }
            task.expirationHandler = {
                job.cancel()
                box.completeOnce(success: false)
            }
        }
        #else
        // Native macOS / watchOS / non-Apple — no BGTaskScheduler;
        // the foreground driver is the only path (by design)。
        return false
        #endif
    }

    #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
    /// Carries the (non-Sendable) BGTask across concurrency domains
    /// + serializes completion。 `@unchecked` is honest:the only
    /// cross-domain call is `setTaskCompleted` (documented
    /// thread-safe) and the once-flag is lock-guarded。
    @available(iOS 13.0, tvOS 13.0, visionOS 1.0, macCatalyst 13.0, *)
    private final class CompletionBox: @unchecked Sendable {
        private let task: BGTask
        private let lock = NSLock()
        private var completed = false
        init(_ task: BGTask) { self.task = task }
        func completeOnce(success: Bool) {
            lock.lock()
            let first = !completed
            completed = true
            lock.unlock()
            if first { task.setTaskCompleted(success: success) }
        }
    }
    #endif

    // MARK: - Continued processing — iOS 27 P3/P4 (IOS27_PERF_ADOPTION_PLAN)
    //
    // `BGContinuedProcessingTask` (ios 26.0;iOS-only — the header
    // marks macos/tvos/visionos/macCatalyst UNAVAILABLE) converts
    // "user just finished a heavy session" into a GUARANTEED-start
    // background window with user-visible progress UI — the third
    // driver path for T3.1 consolidation,after the foreground
    // after-turn hook (dependable) and opportunistic BGProcessingTask
    // windows (OS may never grant)。 P4: `.gpu` resources additionally
    // permit background Metal — REQUIRES the
    // com.apple.developer.background-tasks.continued-processing.gpu
    // entitlement and stays ADR-039-quarantined (background GPU
    // products are reasoning-side only,never spine)。
    //
    // Identifier contract (header doc): registration uses WILDCARD
    // form `<bundleID>.<context>.*`;each submission a concrete
    // `<bundleID>.<context>.<unique>`。 Info.plist must list the
    // wildcard under BGTaskSchedulerPermittedIdentifiers。

    /// Pure identifier derivation (testable cross-platform)。 nil
    /// when no bundle ID is available (the OS would reject anyway)。
    public static func continuedTaskIdentifiers(
        bundleID: String?,
        context: String,
        unique: String
    ) -> (wildcard: String, concrete: String)? {
        guard let bundleID, !bundleID.isEmpty,
              !context.isEmpty, !unique.isEmpty,
              !context.contains("*"), !unique.contains("*")
        else { return nil }
        return ("\(bundleID).\(context).*",
                "\(bundleID).\(context).\(unique)")
    }

    /// Register the launch handler for a continued-processing
    /// WILDCARD identifier。 `work` receives a progress-reporter
    /// closure (the task is force-expired by the OS if it appears
    /// stalled — report honestly per unit of real work) and runs
    /// cancellably;completion is guarded exactly like
    /// `registerLaunchHandler`。 Returns false off-iOS / below 26。
    public static func registerContinuedLaunchHandler(
        wildcardIdentifier: String,
        work: @escaping @Sendable (
            _ report: @escaping @Sendable (
                _ completed: Int64, _ total: Int64) -> Void
        ) async -> Bool
    ) -> Bool {
        #if os(iOS)
        guard #available(iOS 26.0, *) else { return false }
        return BGTaskScheduler.shared.register(
            forTaskWithIdentifier: wildcardIdentifier,
            using: nil
        ) { task in
            guard let continued = task as? BGContinuedProcessingTask
            else {
                task.setTaskCompleted(success: false)
                return
            }
            let box = CompletionBox(continued)
            let progress = continued.progress
            let report: @Sendable (Int64, Int64) -> Void = {
                completed, total in
                progress.totalUnitCount = max(1, total)
                progress.completedUnitCount =
                    min(max(0, completed), max(1, total))
            }
            let job = Task {
                let success = await work(report)
                box.completeOnce(success: success)
            }
            continued.expirationHandler = {
                job.cancel()
                box.completeOnce(success: false)
            }
        }
        #else
        return false
        #endif
    }

    /// Submit one continued-processing request (guaranteed start or
    /// honest failure per `strategy`)。 GPU windows additionally
    /// require the continued-processing.gpu entitlement AND device
    /// support — `supportedResources` is consulted first so an
    /// unsupported request degrades to a CPU window instead of a
    /// rejected submission。 Returns false on any rejection。
    public static func submitContinuedProcessing(
        concreteIdentifier: String,
        title: String,
        subtitle: String,
        preferGPU: Bool = false,
        queueWhenBusy: Bool = true
    ) async -> Bool {
        #if os(iOS)
        guard #available(iOS 26.0, *) else { return false }
        let request = BGContinuedProcessingTaskRequest(
            identifier: concreteIdentifier,
            title: title,
            subtitle: subtitle)
        request.strategy = queueWhenBusy ? .queue : .fail
        if preferGPU,
           BGTaskScheduler.supportedResources.contains(.gpu) {
            request.requiredResources = .gpu
        }
        do {
            if #available(iOS 27.0, *) {
                try await BGTaskScheduler.shared
                    .submitTaskRequest(request)
            } else {
                try BGTaskScheduler.shared.submit(request)
            }
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: - Platform calls

    #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
    private static func submitProcessingRequest(
        _ request: BASBreathScheduler.Request
    ) async -> Bool {
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
            // iOS 27 A4 (IOS27_PERF_ADOPTION_PLAN) — the async
            // submit removes a synchronous cross-process roundtrip
            // from the (already-async) register flow and surfaces
            // submission errors the deprecated sync API dropped。
            // Older OSes keep the sync call;behavior (Bool) is
            // identical on both forks。
            if #available(iOS 27.0, tvOS 27.0, *) {
                try await BGTaskScheduler.shared.submitTaskRequest(bg)
            } else {
                try BGTaskScheduler.shared.submit(bg)
            }
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
