// MARK: - BASSleepConsolidationDriver — 全面进化 T3.1 Phase B
//
// The DRIVER that connects the L1 power-clock's per-turn maintenance
// verdict to the (Phase A) `BASMemorySleepConsolidationPass`。 Two
// paths,exactly as adjudicated by the premise scout:
//
//   PRIMARY (this type): the FOREGROUND after-turn entry point。 The
//   budget frame already carries the L1 decision
//   (`maintenanceAllowed` + `maintenanceClass`) and the turn result
//   already sizes the window (`evolutionSchedulerMaintenanceWindowMs`
//   — zeroed under quarantine/lockdown breath modes)。 The host calls
//   `runIfPermitted(after:now:)` OFF the synchronous turn path,
//   strictly after result composition — the driver only READS the
//   completed result,so it cannot perturb turn bytes。
//
//   SECONDARY (AppleBGTaskSchedulerBridge.registerLaunchHandler):
//   OS-fired background windows feeding the same pass —
//   OPPORTUNISTIC, NOT LOAD-BEARING (BGTask scheduling is at the
//   OS's discretion;the foreground path is the dependable one)。
//
// ## Gating (three nested guards, all must pass)
//
//   1. `BASMemorySleepConsolidationPass.sleepConsolidationEnabled`
//      (static, default-off) — while false this driver returns nil
//      WITHOUT constructing the pass actor (byte-equal + zero cost,
//      ADR-014)。
//   2. `result.budgetFrame.maintenanceAllowed` &&
//      `maintenanceClass != .none` — the L1 verdict。
//   3. window > 0 — quarantine/lockdown zero the window even when
//      a class was granted (EBrainTurnResult+EvolutionPrecisionHotCold)。
//
// ## Dry-run-first discipline (亏的不要, second key)
//
// `dryRun` defaults TRUE here:a host that flips the static flag
// still gets verdict-only passes until it ALSO opts into writes。
// Promotion of either default is a manual reviewed commit。

import Foundation
import BASMemory
import BASRustCoreBridge

/// Foreground after-turn driver for the sleep/consolidation pass。
/// Hold one per host;construct with the host's live memory wiring。
public struct BASSleepConsolidationDriver: Sendable {

    /// Canonical BGTask identifier for the SECONDARY (OS-fired)
    /// path。 Hosts list it under `BGTaskSchedulerPermittedIdentifiers`
    /// in Info.plist and register a launch handler at app launch
    /// (`AppleBGTaskSchedulerBridge.registerConsolidationLaunchHandler`)。
    public static let backgroundTaskIdentifier =
        "bas.sleep.consolidation"

    private let tracker: BASRustMemoryUsageTrackerActor
    private let applier: BASMemoryClosedLoopApplier
    private let store: any BASMemoryAtomStore
    /// Snapshot provider:enumerate the governed store's
    /// (atomID → tier) map at pass time。 Host-owned (the driver
    /// never guesses at corpus shape)。
    private let atomTiersProvider:
        @Sendable () async -> [String: BASMemoryTier]
    private let storeAtomID: @Sendable (String) -> String?
    private let halfLife: TimeInterval
    private let retainFraction: Double
    private let dryRun: Bool
    private let clock: @Sendable () -> Date

    public init(
        tracker: BASRustMemoryUsageTrackerActor,
        applier: BASMemoryClosedLoopApplier,
        store: any BASMemoryAtomStore,
        atomTiersProvider:
            @escaping @Sendable () async -> [String: BASMemoryTier],
        storeAtomID: @escaping @Sendable (String) -> String? = { $0 },
        halfLife: TimeInterval =
            BASMemorySleepConsolidationPass.defaultHalfLife,
        retainFraction: Double =
            BASMemorySleepConsolidationPass.defaultRetainFraction,
        dryRun: Bool = true,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.tracker = tracker
        self.applier = applier
        self.store = store
        self.atomTiersProvider = atomTiersProvider
        self.storeAtomID = storeAtomID
        self.halfLife = halfLife
        self.retainFraction = retainFraction
        self.dryRun = dryRun
        self.clock = clock
    }

    /// The PRIMARY entry point。 nil ⇒ one of the three guards said
    /// no (flag off / L1 denied / window zeroed) — and when the flag
    /// is off,nil is returned WITHOUT constructing the pass actor。
    /// Non-nil ⇒ the pass ran (possibly partially — the checkpoint
    /// reports honestly) within the turn's own maintenance window。
    public func runIfPermitted(
        after result: BASEBrainTurnResult,
        now: Date? = nil
    ) async -> BASConsolidationCheckpoint? {
        guard BASMemorySleepConsolidationPass
            .sleepConsolidationEnabled else { return nil }
        guard result.budgetFrame.maintenanceAllowed,
              result.budgetFrame.maintenanceClass != .none
        else { return nil }
        let windowMs = result.evolutionSchedulerMaintenanceWindowMs()
        guard windowMs > 0 else { return nil }

        let pass = BASMemorySleepConsolidationPass(
            tracker: tracker,
            applier: applier,
            store: store,
            storeAtomID: storeAtomID,
            clock: clock)
        let atomTiers = await atomTiersProvider()
        return await pass.run(BASSleepConsolidationRequest(
            atomTiers: atomTiers,
            now: now ?? clock(),
            halfLife: halfLife,
            retainFraction: retainFraction,
            maintenanceClass: result.budgetFrame.maintenanceClass,
            windowMs: windowMs,
            dryRun: dryRun,
            deviceStateSummary:
                "thermal.\(result.deviceState.thermalLevel.rawValue)"
                + " battery.\(result.deviceState.batteryLevel)"))
    }
}
