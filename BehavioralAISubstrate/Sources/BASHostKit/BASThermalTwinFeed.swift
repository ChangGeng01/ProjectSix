import Foundation
import BASRuntimeCore
import BASLeaseLife

/// P3 契合 — the ThermalTwin → BASDeviceState bridge (closing the recon's "module island": the twin's
/// guard-level + ACCUMULATED-PRESSURE reading existed with zero production consumers while every gate
/// read raw ProcessInfo). A host holds ONE feed; each turn it samples the twin and folds the reading
/// into the device state it hands the runtime — so effort headroom / deliberation floors see the
/// hysteresis-bearing signal instead of an instantaneous one. App targets never import BASLeaseLife.
public final class BASThermalTwinFeed: @unchecked Sendable {
    private let twin = BASThermalTwin()

    public init() {}

    /// Sample the twin and fold `thermalLevel` into `base`. Returns the folded state + the reading's
    /// richer fields for telemetry (guard level raw value + accumulated pressure [0,1]).
    public func foldedDeviceState(
        base: BASDeviceState
    ) async -> (state: BASDeviceState, guardLevel: String, pressure: Double) {
        let reading = await twin.sample()
        var state = base
        state.thermalLevel = reading.thermalLevel
        return (state, "\(reading.guardLevel)", reading.accumulatedPressure)
    }
}
