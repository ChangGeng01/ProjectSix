import Foundation
import BASRuntimeCore

/// L1 breath scheduler — the "when is it safe to run background
/// maintenance" decision.
///
/// ## Why this exists
///
/// `BASBreathSchedulerFrame.backgroundMaintenanceWindowMs` used to be
/// a field nobody read. The plan calls it out explicitly as an M4
/// deliverable: "Based on `backgroundMaintenanceWindowMs` really
/// schedule (iOS BGTaskScheduler integration)."
///
/// BGTaskScheduler is an iOS-only framework. To keep `BASLeaseLife`
/// portable (it's a leaf module that every other library may depend
/// on), the scheduler is protocol-based here. Platform-specific
/// bindings live in `BASAppleAdapters`. The in-memory default
/// implementation in this file is what tests exercise.
///
/// ## Contract
///
/// The scheduler accepts "breath requests" (a maintenance class + a
/// desired delay + an identifier) and either *accepts* them — meaning
/// "we've asked the OS to wake us in that window" — or *rejects*
/// them — meaning "guard level + lung pressure rule out maintenance
/// right now". Accepted requests can be cancelled or fired for test.
///
/// The actor composes with `BASThermalTwin` and
/// `BASLungStateAccumulator` to answer:
///
/// - Under `.emergency` guard level → no maintenance is scheduled at
///   all. Existing scheduled breaths are cancelled.
/// - Under `.throttle` guard level → only `.light` class is allowed.
///   `.standard` and `.deferred` are pushed out further or rejected.
/// - Under `.watch` / `.nominal` → anything goes, caller's call.
public actor BASBreathScheduler {
    public enum ScheduleError:
        Error, Equatable, Sendable, Codable
    {
        case thermalEmergencyRejectsAll
        case classRejectedAtGuard(
            guardLevel: BASThermalGuardLevel,
            `class`: BASMaintenanceClass)
        case unknownRequest(id: String)
        case duplicateRequest(id: String)
    }

    public struct Request: Codable, Sendable, Equatable {
        public let id: String
        public let maintenanceClass: BASMaintenanceClass
        public let earliestFireAt: Date
        public let reasonCodes: [String]

        public init(
            id: String,
            maintenanceClass: BASMaintenanceClass,
            earliestFireAt: Date,
            reasonCodes: [String] = []
        ) {
            self.id = id
            self.maintenanceClass = maintenanceClass
            self.earliestFireAt = earliestFireAt
            self.reasonCodes = reasonCodes
        }
    }

    public struct ScheduledBreath: Codable, Sendable, Equatable {
        public let request: Request
        public let scheduledAt: Date
        public let guardLevelAtSchedule: BASThermalGuardLevel
    }

    /// Platform bridge. Tests use the default no-op; the Apple
    /// adapter layer wires this to `BGTaskScheduler`.
    public protocol PlatformBridge: Sendable {
        /// Ask the platform to wake us for this request.
        /// Implementations return `true` when the OS accepted the
        /// registration. Failures should be logged by the
        /// implementation; the scheduler still records the breath
        /// either way so tests can fire it deterministically.
        func register(_ request: Request) async -> Bool
        func cancel(id: String) async
    }

    public struct NoOpBridge: PlatformBridge {
        public init() {}
        public func register(_: Request) async -> Bool { true }
        public func cancel(id _: String) async {}
    }

    private let bridge: any PlatformBridge
    private let clock: @Sendable () -> Date
    private var scheduled: [String: ScheduledBreath] = [:]

    public init(
        bridge: any PlatformBridge = NoOpBridge(),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.bridge = bridge
        self.clock = clock
    }

    // MARK: - Scheduling

    @discardableResult
    public func schedule(
        _ request: Request,
        guardLevel: BASThermalGuardLevel
    ) async throws -> ScheduledBreath {
        if scheduled[request.id] != nil {
            throw ScheduleError.duplicateRequest(id: request.id)
        }
        try Self.validate(class: request.maintenanceClass, at: guardLevel)
        _ = await bridge.register(request)
        let breath = ScheduledBreath(
            request: request,
            scheduledAt: clock(),
            guardLevelAtSchedule: guardLevel)
        scheduled[request.id] = breath
        return breath
    }

    public func cancel(id: String) async throws {
        guard scheduled[id] != nil else {
            throw ScheduleError.unknownRequest(id: id)
        }
        await bridge.cancel(id: id)
        scheduled[id] = nil
    }

    /// Cancel every scheduled breath. Called when the thermal twin
    /// escalates to `.emergency` — at that point every maintenance
    /// wakeup is a liability.
    public func cancelAll() async {
        // audit M-p / x-concurrency MED-7: was `for id in scheduled.keys { await cancel } ; removeAll`.
        // This is an actor, so a concurrent `schedule()` completing during the `await bridge.cancel`
        // below adds its id to `scheduled` (+ a LIVE platform registration) AFTER the key snapshot;
        // the trailing `removeAll()` then wipes that id from the dict WITHOUT cancelling its platform
        // registration → a GHOST maintenance wakeup survives a thermal-emergency cancelAll. Drain to
        // empty, cancelling then removing each id individually, so no id is ever dropped un-cancelled
        // (a re-check after each await catches any concurrently-registered breath).
        while let id = scheduled.keys.first {
            await bridge.cancel(id: id)
            scheduled[id] = nil
        }
    }

    public func scheduledBreaths() -> [ScheduledBreath] {
        scheduled.values.sorted { $0.request.earliestFireAt < $1.request.earliestFireAt }
    }

    public func count() -> Int { scheduled.count }

    // MARK: - Thermal coupling

    /// Called by the thermal twin subscriber when guard level
    /// changes. Under `.emergency` cancels all; under `.throttle`
    /// cancels classes that are no longer permitted (standard /
    /// deferred).
    public func reconcile(
        with guardLevel: BASThermalGuardLevel
    ) async {
        switch guardLevel {
        case .emergency:
            await cancelAll()
        case .throttle:
            let toDrop = scheduled.values.filter {
                $0.request.maintenanceClass != .light
                    && $0.request.maintenanceClass != .none
            }
            for breath in toDrop {
                await bridge.cancel(id: breath.request.id)
                scheduled[breath.request.id] = nil
            }
        case .watch, .nominal:
            break
        }
    }

    // MARK: - Validation (pure)

    public static func validate(
        `class` c: BASMaintenanceClass,
        at guardLevel: BASThermalGuardLevel
    ) throws {
        switch guardLevel {
        case .emergency:
            throw ScheduleError.thermalEmergencyRejectsAll
        case .throttle:
            if c != .light && c != .none {
                throw ScheduleError.classRejectedAtGuard(
                    guardLevel: guardLevel, class: c)
            }
        case .watch, .nominal:
            break
        }
    }
}
