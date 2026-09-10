// MARK: - SampleHostBenchThermalGate
//
// chapter 二百四十一 / M823 — extracted from SampleHostBenchSafetyKit.swift
// (chapter 一百九十二 / M716-M725 10h-readiness pack split into
// 9 single-responsibility files for navigability + isolated test surface).
//
// This file owns the M717 component invariant.

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - M717 thermal/battery gate

/// Decision returned by `SampleHostBenchThermalGate.shouldPause`.
/// `.run` → continue iter. `.pause(reason:)` → skip iter, sleep,
/// re-check next loop pass. Doctrine: gate NEVER terminates the
/// bench task; it just gates each iter so a 10h run can ride out
/// thermal swings without losing accumulated counters.
enum SampleHostBenchThermalDecision: Equatable, Sendable {
    case run
    case pause(reason: String)
}

/// Stateless thermal/battery gate — single-call decision.
/// M717 chapter 一百九十二. Doctrine pin: defaults are CONSERVATIVE:
/// pause on `.critical` thermal AND battery < 5% (not charging).
/// Non-conservative (e.g. permit `.serious`) would risk
/// throttling the model on iPhone 17e mid-bench.
enum SampleHostBenchThermalGate {
    /// Battery cutoff percentage (0.0 .. 1.0). Below this → pause.
    /// 0.05 = 5%. Charging state overrides — if charging, battery
    /// pause never fires (you can run on the wall).
    static let batteryPauseFloor: Double = 0.05

    /// Decision based on current device state.
    /// `nowThermalRaw` ∈ {nominal, fair, serious, critical, unknown}
    /// `batteryLevel`: -1 unknown, else 0..1.
    /// `lowPowerMode`: ProcessInfo.isLowPowerModeEnabled.
    /// `batteryStateRaw`: "charging" / "full" / "unplugged" / "unknown".
    /// `pauseOnSerious`: M740 chapter 一百九十七 — chapter 一百
    /// 九十六 iPhone smoke showed 91% of 12-min substrate-only run
    /// at `.serious` thermal. For 10h on iPhone, operator can
    /// opt to pause on `.serious` in addition to `.critical`
    /// (default false to preserve chapter-192 doctrine baseline).
    static func decide(
        thermalRaw: String,
        batteryLevel: Double,
        lowPowerMode: Bool,
        batteryStateRaw: String,
        pauseOnSerious: Bool = false
    ) -> SampleHostBenchThermalDecision {
        // Critical thermal — always pause
        if thermalRaw == "critical" {
            return .pause(reason: "thermal-critical")
        }
        // M740 — operator-opt-in serious-thermal pause for 10h
        // on hot devices (iPhone smoke showed iPhone 17e hits
        // serious in ~110s of substrate-only at 18 iter/sec).
        if pauseOnSerious && thermalRaw == "serious" {
            return .pause(reason: "thermal-serious-flex-opt-in")
        }
        // Charging → battery floor never trips
        let charging = batteryStateRaw == "charging"
            || batteryStateRaw == "full"
        if !charging
            && batteryLevel >= 0
            && batteryLevel < batteryPauseFloor
        {
            return .pause(reason: "battery-below-\(Int(batteryPauseFloor * 100))pct")
        }
        // Low power + serious thermal — defensive pause
        if lowPowerMode && thermalRaw == "serious" {
            return .pause(reason: "low-power-serious-thermal")
        }
        return .run
    }

    /// Read current device thermal/battery from ProcessInfo + UIDevice.
    /// Returns the raw 4-tuple suitable for `decide(...)`.
    /// macOS / non-UIKit hosts return `batteryLevel = -1`.
    /// `@MainActor` because UIDevice.current properties are
    /// MainActor-isolated on iOS.
    @MainActor
    static func currentDeviceState() -> (
        thermal: String,
        battery: Double,
        lowPower: Bool,
        batteryState: String
    ) {
        let thermalRaw: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalRaw = "nominal"
        case .fair: thermalRaw = "fair"
        case .serious: thermalRaw = "serious"
        case .critical: thermalRaw = "critical"
        @unknown default: thermalRaw = "unknown"
        }
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        let battery: Double = level >= 0 ? Double(level) : -1.0
        let batteryStateRaw: String
        switch UIDevice.current.batteryState {
        case .charging: batteryStateRaw = "charging"
        case .full: batteryStateRaw = "full"
        case .unplugged: batteryStateRaw = "unplugged"
        case .unknown: batteryStateRaw = "unknown"
        @unknown default: batteryStateRaw = "unknown"
        }
        #else
        let battery: Double = -1.0
        let batteryStateRaw: String = "unknown"
        #endif
        return (thermalRaw, battery, lowPower, batteryStateRaw)
    }
}
