import Foundation
import BASRuntimeCore

extension QinaoRuntime {

    /// M162 — Per-thermal-level work-volume compressor for
    /// `BASBudgetFrame`. Generalizes the `SurfaceRetryPolicy`
    /// thermal-multiplier idea ("stretch retry windows when hot")
    /// into "shrink work volume when hot". The four numeric budget
    /// fields that drive turn cost (`maxLoops`, `maxCandidates`,
    /// `maxDecodeTokens`, `retrievalDepth`) get scaled by a
    /// per-level multiplier.
    ///
    /// Defaults: 1.0 / 0.75 / 0.5 / 0.25 for `.nominal` / `.watch`
    /// / `.throttle` / `.emergency`. M165 — `compress` is a
    /// one-way valve: multipliers > 1.0 are clamped to 1.0 so the
    /// adapter never exceeds the host's planned budget. Hosts that
    /// want pre-M162 behavior pass `.identity` to
    /// `prepareBudgetForTurn(_:thermalAdapter:)`.
    public struct BudgetThermalAdapter:
        Sendable, Equatable, Codable
    {
        public let nominalMultiplier: Double
        public let watchMultiplier: Double
        public let throttleMultiplier: Double
        public let emergencyMultiplier: Double

        /// Each multiplier is clamped to `[0, ∞)` at init time;
        /// `compress` further clamps the effective multiplier to
        /// `[0, 1]` so the adapter is a one-way valve regardless
        /// of how callers configure it.
        public init(
            nominal: Double = 1.0,
            watch: Double = 0.75,
            throttle: Double = 0.5,
            emergency: Double = 0.25
        ) {
            self.nominalMultiplier = Swift.max(0, nominal)
            self.watchMultiplier = Swift.max(0, watch)
            self.throttleMultiplier = Swift.max(0, throttle)
            self.emergencyMultiplier = Swift.max(0, emergency)
        }

        public static let `default` = BudgetThermalAdapter()

        /// Pre-M162 behavior: 1.0 at every level. Useful when the
        /// host runs its own compression elsewhere.
        public static let identity = BudgetThermalAdapter(
            nominal: 1.0,
            watch: 1.0,
            throttle: 1.0,
            emergency: 1.0)

        public func multiplier(
            for level: BASThermalGuardLevel
        ) -> Double {
            switch level {
            case .nominal:    return nominalMultiplier
            case .watch:      return watchMultiplier
            case .throttle:   return throttleMultiplier
            case .emergency:  return emergencyMultiplier
            }
        }

        public func compress(
            _ frame: BASBudgetFrame
        ) -> BASBudgetFrame {
            compress(frame, level: frame.thermalGuardLevel)
        }

        /// M165 — explicit-level overload avoids the "thermal seen
        /// twice" split-brain risk by letting the caller pass the
        /// authoritative level instead of having the adapter
        /// re-read `frame.thermalGuardLevel`.
        public func compress(
            _ frame: BASBudgetFrame,
            level: BASThermalGuardLevel
        ) -> BASBudgetFrame {
            let m = multiplier(for: level)
            // M165 — one-way valve. Even if a caller configures
            // multipliers > 1.0, we clamp to 1.0 so the adapter
            // never exceeds the host's planned budget.
            let capped = Swift.min(1.0, m)
            if capped >= 1.0 { return frame }
            func scale(_ x: Int) -> Int {
                Int((Double(x) * capped).rounded())
            }
            return BASBudgetFrame(
                schemaVersion: frame.schemaVersion,
                runMode: frame.runMode,
                maxLoops: scale(frame.maxLoops),
                maxCandidates: scale(frame.maxCandidates),
                maxDecodeTokens: scale(frame.maxDecodeTokens),
                retrievalDepth: scale(frame.retrievalDepth),
                precisionProfile: frame.precisionProfile,
                deviceRoute: frame.deviceRoute,
                thermalGuardLevel: frame.thermalGuardLevel,
                maintenanceAllowed: frame.maintenanceAllowed,
                leaseID: frame.leaseID,
                leaseExpiresAt: frame.leaseExpiresAt,
                maintenanceClass: frame.maintenanceClass,
                wakeIntentID: frame.wakeIntentID,
                allowedHeads: frame.allowedHeads,
                policyBundleVersion: frame.policyBundleVersion,
                policyDecisionIDs: frame.policyDecisionIDs)
        }
    }
}
