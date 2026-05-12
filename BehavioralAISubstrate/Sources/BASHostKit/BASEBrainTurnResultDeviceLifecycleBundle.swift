// MARK: - BASEBrainTurnResultDeviceLifecycleBundle
// chapter 五百三十一 / M1501 — typed device/lifecycle
//                              cluster packaging surface
//
// Aggregates the 6 device/lifecycle fields of
// `BASEBrainTurnResult` into one typed input surface。
// 8th cluster bundle in the BASEBrainTurnResult fold
// arc。
//
// ## Why this exists
//
// 6 of the remaining ~14 args on BASEBrainTurnResult
// form a device/runtime-lifecycle cluster:
//
//   1. deviceState (REQUIRED) — L0 host device state
//   2. budgetFrame (REQUIRED) — L0 routed budget
//   3. wakeIntent (REQUIRED) — L0 wake intent
//   4. vitalState (REQUIRED) — L0 vital state
//   5. runLease (optional) — L0 run lease
//   6. emergencyBrake (REQUIRED, default) — L11 brake
//
// All 6 describe the device/lifecycle envelope of a
// turn:what device,what budget,what wake intent,
// what lease,what vital state,what emergency brake。
// Packaging into a typed surface gives the L0 boundary
// a clear name。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 6
//     device/lifecycle fields via ONE typed surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable
//   - chapter 四百二十九:typed-surface count 76 → 77
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1500 → M1501

import Foundation
import BASOrchestration
import BASRuntimeCore

/// Typed-surface bundle packaging the 6 device/lifecycle
/// fields of `BASEBrainTurnResult`。 5 required + 1
/// optional (runLease)。
public struct BASEBrainTurnResultDeviceLifecycleBundle:
    Equatable, Sendable
{

    // MARK: - 6 device/lifecycle fields

    /// L0 host device state (required)。
    public let deviceState: BASDeviceState

    /// L0 routed budget frame (required)。
    public let budgetFrame: BASBudgetFrame

    /// L0 wake intent (required)。
    public let wakeIntent: BASWakeIntent

    /// L0 vital state (required)。
    public let vitalState: BASVitalState

    /// L0 run lease (optional)。
    public let runLease: BASRunLease?

    /// L11 emergency brake (required,defaults to
    /// brakeLevel: .none)。
    public let emergencyBrake: BASEmergencyBrake

    // MARK: - Construction

    public init(
        deviceState: BASDeviceState,
        budgetFrame: BASBudgetFrame,
        wakeIntent: BASWakeIntent,
        vitalState: BASVitalState,
        runLease: BASRunLease? = nil,
        emergencyBrake: BASEmergencyBrake
            = BASEmergencyBrake(
                brakeLevel: .none,
                reasonCodes: [])
    ) {
        self.deviceState = deviceState
        self.budgetFrame = budgetFrame
        self.wakeIntent = wakeIntent
        self.vitalState = vitalState
        self.runLease = runLease
        self.emergencyBrake = emergencyBrake
    }

    // MARK: - Coverage queries

    /// Count of populated fields (5-6)。 5 required +
    /// 1 optional (runLease) determines coverage。
    public var populatedFieldCount: Int {
        return 5 + (runLease == nil ? 0 : 1)
    }

    /// Field count invariant — 6 device/lifecycle fields。
    public static let deviceLifecycleFieldCount: Int = 6
}
