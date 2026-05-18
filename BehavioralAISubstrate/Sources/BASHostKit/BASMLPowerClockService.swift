// MARK: - BASMLPowerClockService
// REAL Layer-8 power-clock service deriving cognitive
// budget from device state + risk hint。 Ninth active
// ML-touched layer in the cognitive cascade。
//
// The power-clock service answers "given the device's
// current battery / thermal / foreground state and the
// turn's risk profile,how much cognitive work should
// we spend on this turn?"。 The placeholder returned a
// nominal budget regardless of inputs。
//
// This service derives the budget from BASDeviceState
// signals + an optional risk hint:
//   - Low battery → tighter loops + lower candidate cap
//   - High thermal → conservative routing (scout CPU
//     over core GPU)
//   - Background foreground → throttle aggressively
//   - High risk → invest MORE budget (more loops to
//     converge,more candidates to compare)
//
// **Honest scope**:
//   - This is a typed rule-based derivation,not a
//     learned budget policy。 Weights / thresholds are
//     hand-chosen for safety-first defaults。 Future
//     commits can train a budget policy from
//     (device_state, risk, latency_outcome) tuples。
//   - routeDevice() picks a single route from the
//     budget。 No fall-back chain — hosts implement
//     route-failure handling separately。

import Foundation
import BASRuntimeCore
import BASPolicy
import BASMemory

/// Real power-clock service deriving cognitive budget
/// from device + risk signals。 Replaces BASPlaceholder
/// PowerClockService in cognitive brains that want
/// device-aware budgeting。
public struct BASMLPowerClockService:
    BASPowerClockServicing, Sendable
{

    /// Named budget bounds — the staircase across run
    /// modes from dormant → engage → deepLoop。 Each
    /// step uses the named constants below。
    public enum BudgetTiers {
        /// Critical-low-battery / locked-down state。
        public static let lockdownMaxLoops: Int = 1
        public static let lockdownMaxCandidates: Int = 1
        public static let lockdownMaxDecodeTokens:
            Int = 60
        public static let lockdownRetrievalDepth: Int
            = 1

        /// Throttled state (warm thermal, low battery,
        /// background)。
        public static let throttleMaxLoops: Int = 2
        public static let throttleMaxCandidates: Int = 2
        public static let throttleMaxDecodeTokens:
            Int = 120
        public static let throttleRetrievalDepth: Int
            = 2

        /// Nominal engage state (default)。
        public static let engageMaxLoops: Int = 3
        public static let engageMaxCandidates: Int = 3
        public static let engageMaxDecodeTokens: Int
            = 240
        public static let engageRetrievalDepth: Int = 3

        /// Deep-loop state (high risk turn,plenty of
        /// device headroom)。
        public static let deepMaxLoops: Int = 5
        public static let deepMaxCandidates: Int = 5
        public static let deepMaxDecodeTokens: Int
            = 360
        public static let deepRetrievalDepth: Int = 4
    }

    /// Named thresholds for the device-state checks。
    public enum Thresholds {
        /// Battery level below which we enter lockdown
        /// state — preserve battery,minimum cognitive
        /// budget。
        public static let criticalBattery: Double = 0.10

        /// Battery level below which we throttle (still
        /// usable but conservative)。
        public static let lowBattery: Double = 0.20

        /// Memory free MB below which we throttle to
        /// prevent OOM。
        public static let lowMemoryMB: Int = 256

        /// CPU load above which we throttle to avoid
        /// contention。
        public static let highCPULoad: Double = 0.85
    }

    public init() {}

    public func planBudget(
        deviceState: BASDeviceState,
        taskPing: String,
        riskHint: BASBrainRiskLevel?
    ) -> BASBudgetFrame {
        let tier = Self.tier(
            deviceState: deviceState,
            riskHint: riskHint)
        let (maxLoops, maxCandidates, maxDecodeTokens,
            retrievalDepth) = Self.bounds(for: tier)
        let runMode = Self.runMode(for: tier)
        let precisionProfile = Self.precisionProfile(
            for: tier)
        let deviceRoute = Self.deviceRoute(
            deviceState: deviceState,
            tier: tier)
        let thermalGuardLevel = Self.thermalGuardLevel(
            for: deviceState.thermalLevel)
        return BASBudgetFrame(
            runMode: runMode,
            maxLoops: maxLoops,
            maxCandidates: maxCandidates,
            maxDecodeTokens: maxDecodeTokens,
            retrievalDepth: retrievalDepth,
            precisionProfile: precisionProfile,
            deviceRoute: deviceRoute,
            thermalGuardLevel: thermalGuardLevel,
            maintenanceAllowed: scheduleMaintenance(
                deviceState: deviceState,
                budget: BASBudgetFrame(
                    runMode: runMode,
                    maxLoops: maxLoops,
                    maxCandidates: maxCandidates,
                    maxDecodeTokens: maxDecodeTokens,
                    retrievalDepth: retrievalDepth,
                    precisionProfile: precisionProfile,
                    deviceRoute: deviceRoute,
                    thermalGuardLevel: thermalGuardLevel,
                    maintenanceAllowed: false)))
    }

    public func routeDevice(
        deviceState: BASDeviceState,
        budget: BASBudgetFrame
    ) -> BASDeviceRoute {
        return Self.deviceRoute(
            deviceState: deviceState,
            tier: Self.tier(
                deviceState: deviceState,
                riskHint: nil))
    }

    public func scheduleMaintenance(
        deviceState: BASDeviceState,
        budget: BASBudgetFrame
    ) -> Bool {
        // Maintenance is allowed when:
        //   - battery >= 50% (charging / well-charged)
        //   - thermal level is nominal
        //   - foreground state is background (user
        //     not actively using the device)
        return deviceState.batteryLevel >= 0.5
            && deviceState.thermalLevel == .nominal
            && deviceState.foregroundState == .background
    }

    // MARK: - Tier derivation

    /// Cognitive budget tier — ordered from most
    /// conservative (lockdown) to most permissive
    /// (deepLoop)。
    public enum Tier: String, CaseIterable {
        case lockdown
        case throttle
        case engage
        case deepLoop
    }

    /// Determine the budget tier from device state +
    /// risk hint。 Most-conservative tier wins on any
    /// signal。
    public static func tier(
        deviceState: BASDeviceState,
        riskHint: BASBrainRiskLevel?
    ) -> Tier {
        // 1. Critical signals → lockdown
        if deviceState.batteryLevel
            < Thresholds.criticalBattery
            || deviceState.thermalLevel == .critical
        {
            return .lockdown
        }
        // 2. Throttle signals
        if deviceState.batteryLevel
            < Thresholds.lowBattery
            || deviceState.thermalLevel == .hot
            || deviceState.memoryFreeMB
                < Thresholds.lowMemoryMB
            || deviceState.cpuLoad
                > Thresholds.highCPULoad
            || deviceState.foregroundState == .background
        {
            return .throttle
        }
        // 3. High-risk + healthy device → invest more
        if let risk = riskHint,
           risk == .high || risk == .extreme
        {
            return .deepLoop
        }
        // 4. Default
        return .engage
    }

    /// Map tier to (maxLoops, maxCandidates,
    /// maxDecodeTokens, retrievalDepth)。
    public static func bounds(
        for tier: Tier
    ) -> (Int, Int, Int, Int) {
        switch tier {
        case .lockdown:
            return (
                BudgetTiers.lockdownMaxLoops,
                BudgetTiers.lockdownMaxCandidates,
                BudgetTiers.lockdownMaxDecodeTokens,
                BudgetTiers.lockdownRetrievalDepth)
        case .throttle:
            return (
                BudgetTiers.throttleMaxLoops,
                BudgetTiers.throttleMaxCandidates,
                BudgetTiers.throttleMaxDecodeTokens,
                BudgetTiers.throttleRetrievalDepth)
        case .engage:
            return (
                BudgetTiers.engageMaxLoops,
                BudgetTiers.engageMaxCandidates,
                BudgetTiers.engageMaxDecodeTokens,
                BudgetTiers.engageRetrievalDepth)
        case .deepLoop:
            return (
                BudgetTiers.deepMaxLoops,
                BudgetTiers.deepMaxCandidates,
                BudgetTiers.deepMaxDecodeTokens,
                BudgetTiers.deepRetrievalDepth)
        }
    }

    /// Run mode for each tier。
    public static func runMode(
        for tier: Tier
    ) -> BASEBrainRunMode {
        switch tier {
        case .lockdown: return .lockdown
        case .throttle: return .guard
        case .engage: return .engage
        case .deepLoop: return .deepLoop
        }
    }

    /// Precision profile for each tier。
    public static func precisionProfile(
        for tier: Tier
    ) -> BASRuntimePrecisionProfile {
        switch tier {
        case .lockdown: return .minimal
        case .throttle: return .balanced
        case .engage: return .protected
        case .deepLoop: return .full
        }
    }

    /// Device route from state + tier。 Thermal pressure
    /// pushes us to lighter compute paths。
    public static func deviceRoute(
        deviceState: BASDeviceState,
        tier: Tier
    ) -> BASDeviceRoute {
        switch tier {
        case .lockdown, .throttle:
            return .scoutCPU
        case .engage, .deepLoop:
            if deviceState.thermalLevel == .warm {
                return .scoutGPU
            }
            return deviceState.npuAvailable
                ? .coreNPU
                : .hybridLocal
        }
    }

    /// Thermal guard level — direct echo of device
    /// thermal level for downstream cascade visibility。
    public static func thermalGuardLevel(
        for level: BASThermalLevel
    ) -> BASThermalGuardLevel {
        switch level {
        case .nominal: return .nominal
        case .warm: return .watch
        case .hot: return .throttle
        case .critical: return .emergency
        }
    }
}
