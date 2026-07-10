import Foundation
import BASRuntimeCore
import BASLeaseLife

/// P3 契合 — the ThermalTwin → BASDeviceState bridge. `foldedDeviceState` folds the twin's INSTANTANEOUS
/// `thermalLevel` into the device state a host hands the runtime, so gates read the twin's thermal level
/// instead of raw ProcessInfo. App targets never import BASLeaseLife.
///
/// deep-audit LOW (honesty correction — was a comment-lie + loaded-but-never-fired): the ACCUMULATED-
/// PRESSURE HYSTERESIS is DORMANT for this feed. `BASThermalTwin.sample()` only READS `accumulatedPressure`;
/// nothing calls `updateAccumulatedPressure` on THIS feed's private twin (the sole production pressure
/// source, `BASLeaseLifeCoordinator`, drives its OWN twin), so the returned `pressure` is always the
/// un-fed reading (0 at rest) — NOT the "hysteresis-bearing signal" the old comment claimed. The feed
/// also currently has no in-tree consumer of `foldedDeviceState`. Making the hysteresis real is
/// feature-completion: a host must (a) call `foldedDeviceState` per turn AND (b) feed the twin a pressure
/// source each turn; until both are wired, `pressure` is a pass-through, not an accumulated signal.
public final class BASThermalTwinFeed: @unchecked Sendable {
    private let twin = BASThermalTwin()

    public init() {}

    /// Sample the twin and fold the INSTANTANEOUS `thermalLevel` into `base`. Returns the folded state +
    /// telemetry fields (guard level raw value + accumulated pressure [0,1]). NOTE: `pressure` reflects
    /// the twin's un-fed accumulator (see the type doc) — it is NOT an active hysteresis signal here.
    public func foldedDeviceState(
        base: BASDeviceState
    ) async -> (state: BASDeviceState, guardLevel: String, pressure: Double) {
        let reading = await twin.sample()
        var state = base
        state.thermalLevel = reading.thermalLevel
        return (state, "\(reading.guardLevel)", reading.accumulatedPressure)
    }
}
