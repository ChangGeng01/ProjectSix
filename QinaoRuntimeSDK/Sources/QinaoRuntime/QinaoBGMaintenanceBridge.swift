import Foundation
import BASLeaseLife
// BGTaskScheduler is available on iOS 13+, tvOS 13+, visionOS 1+,
// and Mac Catalyst 13.1+. It is explicitly unavailable on macOS and
// watchOS. The guard below mirrors Apple's own availability
// annotation so the symbol is only referenced where it exists.
#if canImport(BackgroundTasks) && (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst))
import BackgroundTasks
#endif

/// Qinao bridge between `BASBreathScheduler.PlatformBridge` and
/// Apple's `BGTaskScheduler`.
///
/// ## Why this lives here
///
/// `BASLeaseLife` is a leaf module — it cannot import
/// `BackgroundTasks` without dragging Apple-framework coupling into
/// every consumer of the substrate. The scheduler instead defines a
/// `PlatformBridge` protocol and accepts a no-op default. Qinao
/// (which already imports Apple frameworks in places) is the right
/// home for the real BGTaskScheduler plumbing.
///
/// ## Behaviour
///
/// - On iOS 18+ and macOS 14+ (where `BackgroundTasks` is available):
///   `register(_:)` submits a `BGProcessingTaskRequest` with
///   `earliestBeginDate = request.earliestFireAt`. The identifier is
///   `"\(prefix).\(request.id)"` so hosts can predict it.
/// - On watchOS and any platform without `BackgroundTasks`:
///   `register(_:)` returns `false`; `cancel(id:)` is a no-op. The
///   scheduler records the breath either way so tests can fire it
///   deterministically.
///
/// ## Testable seam
///
/// The real `BGTaskScheduler` is hard to exercise in unit tests — it
/// requires a registered identifier and the `BGTaskSchedulerPermittedIdentifiers`
/// Info.plist entry. The bridge therefore takes injectable
/// `Submitter` / `Canceller` closures; `system(...)` wires the Apple
/// defaults, `testing(...)` accepts fakes. Hosts that just want the
/// default behaviour use `QinaoBGMaintenanceBridge.system()`.
public struct QinaoBGMaintenanceBridge: BASBreathScheduler.PlatformBridge {

    /// Closure that asks the platform to wake us for a request.
    /// Return `true` when the platform accepted the registration.
    public typealias Submitter = @Sendable (
        _ identifier: String,
        _ earliestFireAt: Date
    ) async -> Bool

    /// Closure that cancels a previously submitted request.
    public typealias Canceller = @Sendable (
        _ identifier: String
    ) async -> Void

    public let taskIdentifierPrefix: String
    private let submitter: Submitter
    private let canceller: Canceller

    public init(
        taskIdentifierPrefix: String = "qinao.breath",
        submitter: @escaping Submitter,
        canceller: @escaping Canceller
    ) {
        self.taskIdentifierPrefix = taskIdentifierPrefix
        self.submitter = submitter
        self.canceller = canceller
    }

    // MARK: - PlatformBridge

    public func register(
        _ request: BASBreathScheduler.Request
    ) async -> Bool {
        let identifier = Self.identifier(
            prefix: taskIdentifierPrefix, id: request.id)
        return await submitter(identifier, request.earliestFireAt)
    }

    public func cancel(id: String) async {
        let identifier = Self.identifier(
            prefix: taskIdentifierPrefix, id: id)
        await canceller(identifier)
    }

    // MARK: - Identifier formatting (pure, testable)

    public static func identifier(
        prefix: String,
        id: String
    ) -> String {
        "\(prefix).\(id)"
    }

    // MARK: - Factories

    /// Default production bridge. Submits `BGProcessingTaskRequest`
    /// on iOS/macOS via `BGTaskScheduler.shared`. On watchOS or any
    /// platform without `BackgroundTasks`, the submitter returns
    /// `false` so the scheduler still tracks the breath but does not
    /// claim an OS wakeup was scheduled.
    ///
    /// - Parameters:
    ///   - taskIdentifierPrefix: Host must register this prefix (plus
    ///     individual IDs) in its Info.plist under
    ///     `BGTaskSchedulerPermittedIdentifiers`, and register a
    ///     handler via `BGTaskScheduler.shared.register(...)`.
    ///   - requiresNetworkConnectivity: Forwarded to
    ///     `BGProcessingTaskRequest`.
    ///   - requiresExternalPower: Forwarded to
    ///     `BGProcessingTaskRequest`.
    public static func system(
        taskIdentifierPrefix: String = "qinao.breath",
        requiresNetworkConnectivity: Bool = false,
        requiresExternalPower: Bool = false
    ) -> QinaoBGMaintenanceBridge {
        #if canImport(BackgroundTasks) && (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst))
        let submitter: Submitter = { identifier, earliestFireAt in
            let req = BGProcessingTaskRequest(identifier: identifier)
            req.earliestBeginDate = earliestFireAt
            req.requiresNetworkConnectivity = requiresNetworkConnectivity
            req.requiresExternalPower = requiresExternalPower
            do {
                try BGTaskScheduler.shared.submit(req)
                return true
            } catch {
                return false
            }
        }
        let canceller: Canceller = { identifier in
            BGTaskScheduler.shared.cancel(
                taskRequestWithIdentifier: identifier)
        }
        #else
        // watchOS / platforms without BackgroundTasks. The scheduler
        // still records the breath so tests can fire it; the OS just
        // will not wake us.
        let submitter: Submitter = { _, _ in false }
        let canceller: Canceller = { _ in }
        #endif
        return QinaoBGMaintenanceBridge(
            taskIdentifierPrefix: taskIdentifierPrefix,
            submitter: submitter,
            canceller: canceller)
    }
}
