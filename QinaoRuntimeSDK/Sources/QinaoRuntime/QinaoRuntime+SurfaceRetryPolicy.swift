import Foundation
import BASRuntimeCore
import QinaoSovereign

extension QinaoRuntime {

    /// M126 — Per-severity retry-window policy. Every
    /// delay-packet-producing audit severity has its own seconds
    /// value; hotter devices stretch the window via a thermal
    /// multiplier. All fields are `Int` seconds so the value
    /// round-trips cleanly to `BASSurfaceSubstitute
    /// .deferToLater(retryAfterSeconds: Int)`.
    public struct SurfaceRetryPolicy: Sendable, Equatable, Codable {
        public let throttleSeconds: Int
        public let shadowLockSeconds: Int
        public let toolCutSeconds: Int
        public let memoryFreezeSeconds: Int
        public let quarantineSeconds: Int

        /// M131 — every value is clamped to `max(0, …)` at init
        /// time. A negative retry window has no meaningful UI
        /// semantics; callers that pass a negative value silently
        /// get 0 (retry immediately).
        public init(
            throttleSeconds: Int = 30,
            shadowLockSeconds: Int = 60,
            toolCutSeconds: Int = 120,
            memoryFreezeSeconds: Int = 180,
            quarantineSeconds: Int = 300
        ) {
            self.throttleSeconds =
                Swift.max(0, throttleSeconds)
            self.shadowLockSeconds =
                Swift.max(0, shadowLockSeconds)
            self.toolCutSeconds = Swift.max(0, toolCutSeconds)
            self.memoryFreezeSeconds =
                Swift.max(0, memoryFreezeSeconds)
            self.quarantineSeconds =
                Swift.max(0, quarantineSeconds)
        }

        public static let `default` = SurfaceRetryPolicy()

        /// Base seconds for a given severity, or `nil` for
        /// severities that do not produce a delay packet
        /// (`.pass` / `.rollback` / `.deadStop`).
        public func baseSeconds(
            for severity:
                QinaoSovereignControlPlane.AuditSeverity
        ) -> Int? {
            switch severity {
            case .throttle:       return throttleSeconds
            case .shadowLock:     return shadowLockSeconds
            case .toolCut:        return toolCutSeconds
            case .memoryFreeze:   return memoryFreezeSeconds
            case .quarantine:     return quarantineSeconds
            case .pass, .rollback, .deadStop: return nil
            }
        }

        /// Thermal multiplier: nominal = 1.0, watch = 1.25,
        /// throttle = 1.5, emergency = 2.0. A hotter device
        /// waits longer to retry so it can cool off.
        public static func thermalMultiplier(
            for level: BASThermalGuardLevel?
        ) -> Double {
            guard let level = level else { return 1.0 }
            switch level {
            case .nominal:    return 1.0
            case .watch:      return 1.25
            case .throttle:   return 1.5
            case .emergency:  return 2.0
            }
        }

        /// Effective retry seconds = base × thermal-multiplier,
        /// rounded to the nearest non-negative `Int`.
        public func effectiveSeconds(
            for severity:
                QinaoSovereignControlPlane.AuditSeverity,
            thermalLevel: BASThermalGuardLevel?
        ) -> Int? {
            guard let base = baseSeconds(for: severity) else {
                return nil
            }
            let multiplier = Self.thermalMultiplier(
                for: thermalLevel)
            let raw = Int(
                (Double(base) * multiplier).rounded())
            return Swift.max(0, raw)
        }
    }
}
