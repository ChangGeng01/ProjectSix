// MARK: - bas-lease-life — L1 lung-state + breath-scheduler pure-fn port
// chapter 七百六十二 第一刀 / M2461 — DEEPER LAYER-MIGRATION ARC
//
// Pure-Rust port of L1 budget/scheduling pure-fn surface:
//
//   - LungStateAccumulator pressure decay + per-mode load weights
//   - BreathScheduler validate() — guard-level × maintenance-class
//     allowance matrix
//
// The full Swift actors (mutable accumulator + scheduled-breaths
// HashMap) STAY SWIFT — chapter 392 replay-determinism + actor
// isolation are easier to reason about on the Swift side。 Rust
// owns only the pure compute that drives the actors。
//
// Discipline pins
// ---------------
//
//  1. Enum discriminants mirror Swift case order (so wire formats
//     can use u8 codes interchangeably between sides)
//  2. f64 throughout for the exponential decay + load math
//     (chapter 392 replay tolerance is ε = 1e-4,well within
//     IEEE 754 reproducibility for this size)
//  3. validate() returns typed errors mirroring Swift's
//     ScheduleError exactly
//  4. Pressure clamped to [0, 1] (same Snapshot init invariant
//     as Swift line 53)

#![allow(clippy::missing_safety_doc)]

// MARK: - RunMode enum (mirrors BASEBrainRunMode)

/// L1 run modes。 Discriminants pinned via #[repr(u8)] for wire-
/// format interchange with Swift。 Order mirrors the Swift enum
/// case declaration order (chapter 一百八十五 anti-magic-number
/// — discriminants are explicit constants,not derived)。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum RunMode {
    Dormant    = 0,
    Pulse      = 1,
    Sentinel   = 2,
    Engage     = 3,
    Reflect    = 4,
    DeepLoop   = 5,
    Guard      = 6,
    Recovery   = 7,
    Quarantine = 8,
    Lockdown   = 9,
}

impl RunMode {
    /// Convert u8 wire byte to RunMode。 Returns None for out-of-
    /// range values (10..255) for defensive parsing。
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::Dormant),
            1 => Some(Self::Pulse),
            2 => Some(Self::Sentinel),
            3 => Some(Self::Engage),
            4 => Some(Self::Reflect),
            5 => Some(Self::DeepLoop),
            6 => Some(Self::Guard),
            7 => Some(Self::Recovery),
            8 => Some(Self::Quarantine),
            9 => Some(Self::Lockdown),
            _ => None,
        }
    }

    /// All 10 discriminants in canonical Swift enum case order。
    pub const ALL: [RunMode; 10] = [
        RunMode::Dormant, RunMode::Pulse, RunMode::Sentinel,
        RunMode::Engage,  RunMode::Reflect, RunMode::DeepLoop,
        RunMode::Guard,   RunMode::Recovery, RunMode::Quarantine,
        RunMode::Lockdown,
    ];

    /// Per-second load contribution。 Mirrors Swift line 133-148
    /// `BASLungStateAccumulator.load(for:)` exactly。
    pub fn load_per_second(self) -> f64 {
        match self {
            RunMode::Dormant | RunMode::Pulse | RunMode::Sentinel => 0.01,
            RunMode::Engage => 0.05,
            RunMode::Reflect => 0.06,
            RunMode::DeepLoop => 0.15,
            RunMode::Guard => 0.12,
            RunMode::Recovery | RunMode::Quarantine | RunMode::Lockdown => 0.0,
        }
    }
}

// MARK: - ThermalGuardLevel enum (mirrors BASThermalGuardLevel)

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum ThermalGuardLevel {
    Nominal   = 0,
    Watch     = 1,
    Throttle  = 2,
    Emergency = 3,
}

impl ThermalGuardLevel {
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::Nominal),
            1 => Some(Self::Watch),
            2 => Some(Self::Throttle),
            3 => Some(Self::Emergency),
            _ => None,
        }
    }
    pub const ALL: [ThermalGuardLevel; 4] = [
        ThermalGuardLevel::Nominal,
        ThermalGuardLevel::Watch,
        ThermalGuardLevel::Throttle,
        ThermalGuardLevel::Emergency,
    ];
}

// MARK: - MaintenanceClass enum (mirrors BASMaintenanceClass)

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum MaintenanceClass {
    /// No maintenance scheduled — sentinel for empty。
    None     = 0,
    /// Light background work (e.g。 metrics flush)。
    Light    = 1,
    /// Standard maintenance (e.g。 cache eviction)。
    Standard = 2,
    /// Deferred maintenance (e.g。 model recompaction)。
    Deferred = 3,
}

impl MaintenanceClass {
    pub const fn from_u8(b: u8) -> Option<Self> {
        match b {
            0 => Some(Self::None),
            1 => Some(Self::Light),
            2 => Some(Self::Standard),
            3 => Some(Self::Deferred),
            _ => None,
        }
    }
    pub const ALL: [MaintenanceClass; 4] = [
        MaintenanceClass::None,
        MaintenanceClass::Light,
        MaintenanceClass::Standard,
        MaintenanceClass::Deferred,
    ];
}

// MARK: - ScheduleError (mirrors BASBreathScheduler.ScheduleError)

/// Validation errors returned by `breath_validate`。 Wire encoding
/// (C ABI) uses i32 codes 1..3 (0 = OK)。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(i32)]
pub enum ScheduleError {
    /// Thermal guard level is Emergency — ALL maintenance rejected
    /// regardless of class。 Mirrors Swift case
    /// `thermalEmergencyRejectsAll`。
    ThermalEmergencyRejectsAll = 1,
    /// At Throttle level,only `.light` and `.none` classes allowed。
    /// Mirrors Swift case `classRejectedAtGuard`。
    ClassRejectedAtGuard = 2,
}

// MARK: - LungStateAccumulator pure-fn surface (knife 一 / M2461)

/// Default time constant in seconds (180s → ~37% pressure decay
/// per 3-minute idle window)。 Mirrors Swift line 38 default。
pub const DEFAULT_TIME_CONSTANT_SECONDS: f64 = 180.0;

/// Compute the new pressure value after `idle_seconds` of decay
/// from `prev_pressure` with the given `time_constant_seconds`。
///
/// Formula:`p_next = clamp01(p_prev * exp(-idle / tau))`
/// Mirrors Swift line 121-128 `decay(to:)` method body。
///
/// Pure function:no I/O,no shared state,deterministic per
/// (prev_pressure,idle_seconds,time_constant_seconds)。
///
/// Special cases:
///   - `idle_seconds < 0` → treat as 0 (no decay)
///   - `time_constant_seconds < 1` → use 1.0 (mirrors Swift
///     line 71 max(1, timeConstantSeconds) defensive clamp)
///   - Any NaN input → return 0.0 (defensive,not Swift behavior
///     but Swift can't produce NaN from `Date.timeIntervalSince`
///     in practice)
pub fn lung_state_decay(
    prev_pressure: f64,
    idle_seconds: f64,
    time_constant_seconds: f64,
) -> f64 {
    if prev_pressure.is_nan() || idle_seconds.is_nan()
        || time_constant_seconds.is_nan() {
        return 0.0;
    }
    let idle = if idle_seconds > 0.0 { idle_seconds } else { 0.0 };
    let tau = if time_constant_seconds < 1.0 { 1.0 } else { time_constant_seconds };
    let factor = (-idle / tau).exp();
    let raw = prev_pressure * factor;
    // Clamp to [0, 1] per Swift Snapshot.init line 52。
    if raw < 0.0 { 0.0 }
    else if raw > 1.0 { 1.0 }
    else { raw }
}

/// Compute the pressure contribution from a single turn。
/// Mirrors Swift line 87:
///   `contribution = load(runMode) * max(0, durationSeconds)`
///
/// Pure function:no I/O,no shared state。
pub fn lung_state_turn_contribution(
    run_mode: RunMode,
    duration_seconds: f64,
) -> f64 {
    if duration_seconds.is_nan() {
        return 0.0;
    }
    let dur = if duration_seconds > 0.0 { duration_seconds } else { 0.0 };
    run_mode.load_per_second() * dur
}

/// Combined decay + turn-record step。 Mirrors Swift line 81-92
/// `record(runMode:durationSeconds:)`:
///   1. Decay prev_pressure by idle_seconds
///   2. Add turn contribution
///   3. Clamp to [0, 1]
///
/// Returns the new pressure value。
pub fn lung_state_record_turn(
    prev_pressure: f64,
    idle_seconds: f64,
    time_constant_seconds: f64,
    run_mode: RunMode,
    duration_seconds: f64,
) -> f64 {
    let decayed = lung_state_decay(prev_pressure, idle_seconds, time_constant_seconds);
    let contribution = lung_state_turn_contribution(run_mode, duration_seconds);
    let raw = decayed + contribution;
    if raw < 0.0 { 0.0 }
    else if raw > 1.0 { 1.0 }
    else { raw }
}

// MARK: - BreathScheduler validate() pure fn (preview for knife 二)

/// Validate whether a maintenance class is allowed at the given
/// thermal guard level。 Mirrors Swift `BASBreathScheduler
/// .validate(class:at:)` line 175-190。 Returns Ok(()) when
/// allowed,Err(ScheduleError) otherwise。
///
/// Allowance matrix:
///   - Nominal    : all classes allowed
///   - Watch      : all classes allowed
///   - Throttle   : only .None and .Light allowed
///   - Emergency  : nothing allowed (all rejected)
///
/// Pure function:no I/O,no shared state。
pub fn breath_validate(
    class: MaintenanceClass,
    guard_level: ThermalGuardLevel,
) -> Result<(), ScheduleError> {
    match guard_level {
        ThermalGuardLevel::Emergency => {
            Err(ScheduleError::ThermalEmergencyRejectsAll)
        }
        ThermalGuardLevel::Throttle => {
            match class {
                MaintenanceClass::Light | MaintenanceClass::None => Ok(()),
                _ => Err(ScheduleError::ClassRejectedAtGuard),
            }
        }
        ThermalGuardLevel::Watch | ThermalGuardLevel::Nominal => Ok(()),
    }
}

// MARK: - ABI version

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_lease_life_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - Tests (knife 一 / M2461 scaffold)

#[cfg(test)]
mod tests {
    use super::*;

    // MARK: ABI version

    #[test]
    fn test_abi_version_pinned_at_v1() {
        assert_eq!(bas_lease_life_abi_version(), 1);
    }

    // MARK: RunMode

    #[test]
    fn test_run_mode_cardinality() {
        assert_eq!(RunMode::ALL.len(), 10,
            "10 run modes mirroring BASEBrainRunMode");
    }

    #[test]
    fn test_run_mode_discriminants_pinned() {
        assert_eq!(RunMode::Dormant as u8, 0);
        assert_eq!(RunMode::Pulse as u8, 1);
        assert_eq!(RunMode::Sentinel as u8, 2);
        assert_eq!(RunMode::Engage as u8, 3);
        assert_eq!(RunMode::Reflect as u8, 4);
        assert_eq!(RunMode::DeepLoop as u8, 5);
        assert_eq!(RunMode::Guard as u8, 6);
        assert_eq!(RunMode::Recovery as u8, 7);
        assert_eq!(RunMode::Quarantine as u8, 8);
        assert_eq!(RunMode::Lockdown as u8, 9);
    }

    #[test]
    fn test_run_mode_from_u8_round_trip() {
        for &m in &RunMode::ALL {
            assert_eq!(RunMode::from_u8(m as u8), Some(m));
        }
        assert_eq!(RunMode::from_u8(10), None);
        assert_eq!(RunMode::from_u8(255), None);
    }

    #[test]
    fn test_run_mode_load_per_second_matches_swift() {
        // Pin each load value from Swift line 133-148。
        assert_eq!(RunMode::Dormant.load_per_second(), 0.01);
        assert_eq!(RunMode::Pulse.load_per_second(), 0.01);
        assert_eq!(RunMode::Sentinel.load_per_second(), 0.01);
        assert_eq!(RunMode::Engage.load_per_second(), 0.05);
        assert_eq!(RunMode::Reflect.load_per_second(), 0.06);
        assert_eq!(RunMode::DeepLoop.load_per_second(), 0.15);
        assert_eq!(RunMode::Guard.load_per_second(), 0.12);
        assert_eq!(RunMode::Recovery.load_per_second(), 0.0);
        assert_eq!(RunMode::Quarantine.load_per_second(), 0.0);
        assert_eq!(RunMode::Lockdown.load_per_second(), 0.0);
    }

    // MARK: ThermalGuardLevel

    #[test]
    fn test_thermal_guard_level_cardinality() {
        assert_eq!(ThermalGuardLevel::ALL.len(), 4);
    }

    #[test]
    fn test_thermal_guard_level_discriminants_pinned() {
        assert_eq!(ThermalGuardLevel::Nominal as u8, 0);
        assert_eq!(ThermalGuardLevel::Watch as u8, 1);
        assert_eq!(ThermalGuardLevel::Throttle as u8, 2);
        assert_eq!(ThermalGuardLevel::Emergency as u8, 3);
    }

    #[test]
    fn test_thermal_guard_level_from_u8_round_trip() {
        for &g in &ThermalGuardLevel::ALL {
            assert_eq!(ThermalGuardLevel::from_u8(g as u8), Some(g));
        }
        assert_eq!(ThermalGuardLevel::from_u8(4), None);
    }

    // MARK: MaintenanceClass

    #[test]
    fn test_maintenance_class_cardinality() {
        assert_eq!(MaintenanceClass::ALL.len(), 4);
    }

    #[test]
    fn test_maintenance_class_discriminants_pinned() {
        assert_eq!(MaintenanceClass::None as u8, 0);
        assert_eq!(MaintenanceClass::Light as u8, 1);
        assert_eq!(MaintenanceClass::Standard as u8, 2);
        assert_eq!(MaintenanceClass::Deferred as u8, 3);
    }

    #[test]
    fn test_maintenance_class_from_u8_round_trip() {
        for &c in &MaintenanceClass::ALL {
            assert_eq!(MaintenanceClass::from_u8(c as u8), Some(c));
        }
        assert_eq!(MaintenanceClass::from_u8(4), None);
    }

    // MARK: ScheduleError

    #[test]
    fn test_schedule_error_discriminants() {
        assert_eq!(ScheduleError::ThermalEmergencyRejectsAll as i32, 1);
        assert_eq!(ScheduleError::ClassRejectedAtGuard as i32, 2);
    }

    // MARK: lung_state_decay pure fn

    #[test]
    fn test_lung_state_decay_zero_idle_is_no_op() {
        let result = lung_state_decay(0.5, 0.0, 180.0);
        assert_eq!(result, 0.5);
    }

    #[test]
    fn test_lung_state_decay_one_time_constant_yields_inverse_e() {
        // At idle = tau, factor = exp(-1) ≈ 0.367879。
        let result = lung_state_decay(1.0, 180.0, 180.0);
        // ε = 1e-6 (chapter 392 replay tolerance is 1e-4)
        assert!((result - (-1.0_f64).exp()).abs() < 1e-6);
    }

    #[test]
    fn test_lung_state_decay_negative_idle_is_zero() {
        // Swift defensive max(0, idle) → no decay。
        let result = lung_state_decay(0.5, -10.0, 180.0);
        assert_eq!(result, 0.5);
    }

    #[test]
    fn test_lung_state_decay_clamps_to_zero_bottom() {
        // Tiny prev × big factor still → 0+ epsilon then clamp。
        let result = lung_state_decay(0.0, 100.0, 180.0);
        assert_eq!(result, 0.0);
    }

    #[test]
    fn test_lung_state_decay_clamps_to_one_top() {
        // Defensive:if a caller supplies prev > 1,clamp to 1 after decay。
        let result = lung_state_decay(1.5, 0.0, 180.0);
        // After decay (factor=1) result = 1.5,clamped to 1.0。
        assert_eq!(result, 1.0);
    }

    #[test]
    fn test_lung_state_decay_nan_inputs_yield_zero() {
        assert_eq!(lung_state_decay(f64::NAN, 1.0, 180.0), 0.0);
        assert_eq!(lung_state_decay(0.5, f64::NAN, 180.0), 0.0);
        assert_eq!(lung_state_decay(0.5, 1.0, f64::NAN), 0.0);
    }

    #[test]
    fn test_lung_state_decay_tiny_time_constant_clamped_to_one() {
        // Swift line 71 max(1, timeConstantSeconds)。 Test that
        // sub-1 tau is clamped to 1.0 before exp。
        let result = lung_state_decay(1.0, 1.0, 0.1);
        // tau = 1.0,idle = 1.0 → factor = exp(-1) ≈ 0.368
        assert!((result - (-1.0_f64).exp()).abs() < 1e-6);
    }

    // MARK: lung_state_turn_contribution

    #[test]
    fn test_turn_contribution_zero_duration() {
        assert_eq!(
            lung_state_turn_contribution(RunMode::DeepLoop, 0.0),
            0.0);
    }

    #[test]
    fn test_turn_contribution_negative_duration_is_zero() {
        assert_eq!(
            lung_state_turn_contribution(RunMode::DeepLoop, -5.0),
            0.0);
    }

    #[test]
    fn test_turn_contribution_deeploop_high_load() {
        // DeepLoop is 0.15/s × 2s = 0.30。
        let result = lung_state_turn_contribution(RunMode::DeepLoop, 2.0);
        assert!((result - 0.30).abs() < 1e-9);
    }

    #[test]
    fn test_turn_contribution_dormant_near_zero() {
        // Dormant is 0.01/s × 1s = 0.01。
        let result = lung_state_turn_contribution(RunMode::Dormant, 1.0);
        assert!((result - 0.01).abs() < 1e-9);
    }

    // MARK: lung_state_record_turn (combined decay + turn)

    #[test]
    fn test_record_turn_zero_idle_zero_prev() {
        // Empty accumulator,1 second deepLoop → 0.15。
        let result = lung_state_record_turn(
            0.0, 0.0, 180.0, RunMode::DeepLoop, 1.0);
        assert!((result - 0.15).abs() < 1e-9);
    }

    #[test]
    fn test_record_turn_decay_then_add() {
        // prev=0.5,idle=180s (1 tau) → decayed ≈ 0.1839
        // + 1s engage (0.05) → ≈ 0.2339
        let result = lung_state_record_turn(
            0.5, 180.0, 180.0, RunMode::Engage, 1.0);
        let expected = 0.5 * (-1.0_f64).exp() + 0.05;
        assert!((result - expected).abs() < 1e-6);
    }

    #[test]
    fn test_record_turn_clamps_to_one() {
        // prev=0.9 + 1s deepLoop (0.15) = 1.05 → clamped to 1.0。
        let result = lung_state_record_turn(
            0.9, 0.0, 180.0, RunMode::DeepLoop, 1.0);
        assert_eq!(result, 1.0);
    }

    // MARK: breath_validate

    #[test]
    fn test_breath_validate_nominal_allows_all_classes() {
        for &c in &MaintenanceClass::ALL {
            assert!(breath_validate(c, ThermalGuardLevel::Nominal).is_ok(),
                "Nominal must allow class {:?}", c);
        }
    }

    #[test]
    fn test_breath_validate_watch_allows_all_classes() {
        for &c in &MaintenanceClass::ALL {
            assert!(breath_validate(c, ThermalGuardLevel::Watch).is_ok());
        }
    }

    #[test]
    fn test_breath_validate_throttle_allows_only_light_and_none() {
        assert!(breath_validate(MaintenanceClass::None,
            ThermalGuardLevel::Throttle).is_ok());
        assert!(breath_validate(MaintenanceClass::Light,
            ThermalGuardLevel::Throttle).is_ok());
        assert_eq!(
            breath_validate(MaintenanceClass::Standard,
                ThermalGuardLevel::Throttle),
            Err(ScheduleError::ClassRejectedAtGuard));
        assert_eq!(
            breath_validate(MaintenanceClass::Deferred,
                ThermalGuardLevel::Throttle),
            Err(ScheduleError::ClassRejectedAtGuard));
    }

    #[test]
    fn test_breath_validate_emergency_rejects_all_classes() {
        for &c in &MaintenanceClass::ALL {
            assert_eq!(
                breath_validate(c, ThermalGuardLevel::Emergency),
                Err(ScheduleError::ThermalEmergencyRejectsAll),
                "Emergency must reject class {:?}", c);
        }
    }

    // MARK: Default time constant pin

    #[test]
    fn test_default_time_constant_pinned_at_180_seconds() {
        assert_eq!(DEFAULT_TIME_CONSTANT_SECONDS, 180.0,
            "180s default mirrors Swift line 38 default");
    }
}
