// SPDX:internal
//
// risk_plane.rs — chapter 七百三十九 第一刀 / M2366
//
// LAYER-MIGRATION ARC — L11 Wind Gate state-machine port to
// Rust。 Pairs with chapter 七百三十八's net-new SQL persistence
// layer (006_risk_observations.sql + 007_permit_escalation
// _ledger.sql + 008_permit_escalation_steps.sql)。
//
// Per user directive 2026-05-20:
//
//   「Swift 仍然应该保留为 façade / Apple glue / public API。
//    真正应该移植的是每层里的 热路径、状态机、持久化、审计、
//    数学计算。」
//
// AND the strengthening directive:
//
//   「如果 完全 移植后 整体 会 更好 那就 移植 进行 对比
//    最极致 最优雅 依旧 不删除 只 comment」
//
// ## What this module ports
//
// 1. BrainRiskLevel enum (mirror of Swift BASBrainRiskLevel,
//    4 cases:low / medium / high / extreme)
// 2. ActionPermitMode enum (mirror of Swift BASActionPermitMode,
//    9 cases:answer / mirror / compare / delay / draftOnly /
//    localOnly / block / replace / escalate)
// 3. RiskBand enum (the 4-bucket categorical from 006 schema)
// 4. risk_band_to_permit_mode — the L11 classifier。 Given a
//    risk_band + risk_climate (from existing risk.rs) + the
//    current_mode,produces the next mode the gate should
//    advance to。 Deterministic match cascade。
// 5. effective_threshold — the threshold delta application
//    (mirrors BASRiskCalibrationGate.effective<Tier>Threshold)
// 6. monotonic_version_compare — the bundle replacement
//    validator (mirrors BASRiskCalibrationGate.replace's
//    monotonic check)
//
// All functions are PURE (no shared mutable state)。 Byte-
// equality verifiable against Swift at the C ABI boundary
// (chapter 七百三十九 第三刀 byte-equality test)。
//
// ## Honest scope
//
// The full 5-stage permit escalation chain (chapter 四百四
// BASPermitEscalationLedger:abyssal → assertionCeiling →
// kunlun → cthulhuAssertionCeiling → cthulhuEscalation) is
// NOT ported in this knife。 Each stage has substrate-specific
// decision logic (M384 / M385 / M406 / M449 / M450) that lives
// in separate Swift modules。 Chapter 七百三十九 ports the
// CORE classifier (risk_band → next mode) only;the escalation
// chain stays Swift。
//
// ## ADR-014 OPT-IN preserved
//
// At this knife,Rust functions exist but no Swift caller wires
// them up yet。 Chapter 七百三十九 第二刀 adds the C ABI exports
// + Swift bridge + `useRoutedRiskPlane: Bool = false` flag。
// V1 Swift in-line classifier stays the live path until
// 5-axis comparison decides default flip。

use crate::enums::RiskClimate;
use serde::{Deserialize, Serialize};
use std::os::raw::c_char;

// MARK: - BrainRiskLevel (mirrors BASBrainRiskLevel)

/// Per-intent risk level bucketing。 Mirrors Swift
/// BASBrainRiskLevel raw values verbatim。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum BrainRiskLevel {
    Low,
    Medium,
    High,
    Extreme,
}

impl BrainRiskLevel {
    /// chapter 一百八十五 anti-magic-number rank。 Mirrors
    /// Swift BASBrainRiskLevel.rank private accessor verbatim。
    pub fn rank(self) -> i32 {
        match self {
            BrainRiskLevel::Low => 0,
            BrainRiskLevel::Medium => 1,
            BrainRiskLevel::High => 2,
            BrainRiskLevel::Extreme => 3,
        }
    }
}

// MARK: - RiskBand (mirrors 006_risk_observations.sql CHECK)

/// Categorical risk-band bucket from chapter 七百三十八
/// 006_risk_observations.sql。 4 buckets pinned in the SQL
/// CHECK constraint verbatim。 NOT the same axis as
/// BrainRiskLevel — risk_band is per-OBSERVATION,risk_level
/// is per-INTENT (aggregate)。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum RiskBand {
    Low,
    Medium,
    High,
    Critical,
}

impl RiskBand {
    /// Rank-style ordering for monotonic escalation decisions。
    pub fn rank(self) -> i32 {
        match self {
            RiskBand::Low => 0,
            RiskBand::Medium => 1,
            RiskBand::High => 2,
            RiskBand::Critical => 3,
        }
    }
}

// MARK: - ActionPermitMode (mirrors BASActionPermitMode)

/// Action permit modes — the 9 cases that L11 may issue。
/// Raw values mirror Swift BASActionPermitMode verbatim
/// (with snake_case for the multi-word cases)。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
pub enum ActionPermitMode {
    #[serde(rename = "answer")]
    Answer,
    #[serde(rename = "mirror")]
    Mirror,
    #[serde(rename = "compare")]
    Compare,
    #[serde(rename = "delay")]
    Delay,
    #[serde(rename = "draft_only")]
    DraftOnly,
    #[serde(rename = "local_only")]
    LocalOnly,
    #[serde(rename = "block")]
    Block,
    #[serde(rename = "replace")]
    Replace,
    #[serde(rename = "escalate")]
    Escalate,
}

// MARK: - L11 classifier — risk_band × climate → next_mode

/// Pure classifier:given a per-observation risk_band + the
/// session's current climate (from chapter 七百三 risk.rs) +
/// the gate's current mode,produce the next mode the gate
/// should advance to。
///
/// This is the CORE L11 state-machine transition。 Deterministic
/// match cascade — no shared state,no randomness。 Byte-equality
/// verifiable against Swift implementation。
///
/// ## Decision rule
///
/// 1. Critical band + Crisis climate → Block (gate slams shut)
/// 2. Critical band + non-Crisis climate → Escalate (5-stage
///    chain takes over)
/// 3. High band + Crisis/Elevated climate → Replace (substitute
///    a safer candidate)
/// 4. High band + Watchful climate → Delay (defer until cooler)
/// 5. High band + Calm climate → DraftOnly (no live answer yet)
/// 6. Medium band + Elevated/Crisis climate → Compare (require
///    second comparison before answer)
/// 7. Medium band + Watchful climate → Mirror (echo with
///    softer tone)
/// 8. Medium band + Calm climate → keep current mode
/// 9. Low band → keep current mode (no L11 intervention needed)
///
/// "Keep current mode" lets the per-turn loop's default
/// decision stand without L11 override。
pub fn risk_band_to_next_mode(
    band: RiskBand,
    climate: RiskClimate,
    current: ActionPermitMode,
) -> ActionPermitMode {
    match (band, climate) {
        // Critical band: shut or escalate per climate
        (RiskBand::Critical, RiskClimate::Crisis) =>
            ActionPermitMode::Block,
        (RiskBand::Critical, _) =>
            ActionPermitMode::Escalate,
        // High band: substitute / defer / draft per climate
        (RiskBand::High, RiskClimate::Crisis)
        | (RiskBand::High, RiskClimate::Elevated) =>
            ActionPermitMode::Replace,
        (RiskBand::High, RiskClimate::Watchful) =>
            ActionPermitMode::Delay,
        (RiskBand::High, RiskClimate::Calm) =>
            ActionPermitMode::DraftOnly,
        // Medium band: comparison / mirror / pass per climate
        (RiskBand::Medium, RiskClimate::Crisis)
        | (RiskBand::Medium, RiskClimate::Elevated) =>
            ActionPermitMode::Compare,
        (RiskBand::Medium, RiskClimate::Watchful) =>
            ActionPermitMode::Mirror,
        (RiskBand::Medium, RiskClimate::Calm) => current,
        // Low band: no L11 intervention
        (RiskBand::Low, _) => current,
    }
}

// MARK: - Effective threshold (mirrors BASRiskCalibrationGate)

/// Apply a per-stratum threshold delta to a base threshold +
/// clamp the result to [0, 1]。 Mirrors Swift
/// BASRiskCalibrationGate.effective<Tier>Threshold verbatim。
///
/// NaN inputs → 0 (matches Swift clamp01)。 Defensive against
/// upstream calibration bundle corruption。
pub fn effective_threshold(base: f64, delta: f64) -> f64 {
    let sum = base + delta;
    if sum.is_nan() {
        return 0.0;
    }
    if sum < 0.0 {
        0.0
    } else if sum > 1.0 {
        1.0
    } else {
        sum
    }
}

// MARK: - Monotonic version comparator

/// Compare bundle versions for monotonic-replace validation。
/// Mirrors Swift BASRiskCalibrationGate.replace's monotonic
/// check (string compare with baseline as the implicit floor)。
///
/// Returns:
///   - Some(true)  if proposed > current (replace permitted)
///   - Some(false) if proposed <= current (replace rejected
///                 unless current is baseline)
///   - None        if either input is empty (validation
///                 fault upstream)
pub fn monotonic_version_compare(
    current: &str,
    proposed: &str,
) -> Option<bool> {
    if current.is_empty() || proposed.is_empty() {
        return None;
    }
    Some(proposed > current)
}

// MARK: - C ABI exports (chapter 七百三十九 第二刀)
//
// Stable C ABI surface for Swift to call into via the
// BASRustMemoryTracker XCFramework。 Wire encoding pinned
// here is the SINGLE SOURCE OF TRUTH for the Swift
// bridge's integer constants。
//
// ## Wire encoding
//
// RiskBand   : 0=Low, 1=Medium, 2=High, 3=Critical
// RiskClimate: 0=Calm, 1=Watchful, 2=Elevated, 3=Crisis
// ActionPermitMode:
//   0=Answer  1=Mirror   2=Compare 3=Delay
//   4=DraftOnly 5=LocalOnly 6=Block 7=Replace 8=Escalate
//
// ## Fault encoding
//
// Functions returning `i32` return -1 on bad input (out-
// of-range encoding) so the Swift bridge can fall back
// to the V1 path without crashing。

fn band_from_i32(v: i32) -> Option<RiskBand> {
    match v {
        0 => Some(RiskBand::Low),
        1 => Some(RiskBand::Medium),
        2 => Some(RiskBand::High),
        3 => Some(RiskBand::Critical),
        _ => None,
    }
}

fn climate_from_i32(v: i32) -> Option<RiskClimate> {
    match v {
        0 => Some(RiskClimate::Calm),
        1 => Some(RiskClimate::Watchful),
        2 => Some(RiskClimate::Elevated),
        3 => Some(RiskClimate::Crisis),
        _ => None,
    }
}

fn mode_from_i32(v: i32) -> Option<ActionPermitMode> {
    match v {
        0 => Some(ActionPermitMode::Answer),
        1 => Some(ActionPermitMode::Mirror),
        2 => Some(ActionPermitMode::Compare),
        3 => Some(ActionPermitMode::Delay),
        4 => Some(ActionPermitMode::DraftOnly),
        5 => Some(ActionPermitMode::LocalOnly),
        6 => Some(ActionPermitMode::Block),
        7 => Some(ActionPermitMode::Replace),
        8 => Some(ActionPermitMode::Escalate),
        _ => None,
    }
}

fn mode_to_i32(m: ActionPermitMode) -> i32 {
    match m {
        ActionPermitMode::Answer => 0,
        ActionPermitMode::Mirror => 1,
        ActionPermitMode::Compare => 2,
        ActionPermitMode::Delay => 3,
        ActionPermitMode::DraftOnly => 4,
        ActionPermitMode::LocalOnly => 5,
        ActionPermitMode::Block => 6,
        ActionPermitMode::Replace => 7,
        ActionPermitMode::Escalate => 8,
    }
}

/// L11 risk-plane classifier C ABI。
///
/// Parameters:
///   band:    RiskBand encoding (0-3)
///   climate: RiskClimate encoding (0-3)
///   current: ActionPermitMode encoding (0-8)
///
/// Returns: next ActionPermitMode encoding (0-8),or -1
/// if any input is out of range。 Swift bridge falls back
/// to V1 on -1。
#[no_mangle]
pub extern "C" fn bas_permit_policy_risk_band_to_next_mode(
    band: i32,
    climate: i32,
    current: i32,
) -> i32 {
    let b = match band_from_i32(band) {
        Some(b) => b, None => return -1,
    };
    let c = match climate_from_i32(climate) {
        Some(c) => c, None => return -1,
    };
    let m = match mode_from_i32(current) {
        Some(m) => m, None => return -1,
    };
    mode_to_i32(risk_band_to_next_mode(b, c, m))
}

/// Effective threshold C ABI。 Same shape as
/// effective_threshold;NaN guarded;clamped [0,1]。
#[no_mangle]
pub extern "C" fn bas_permit_policy_effective_threshold(
    base: f64,
    delta: f64,
) -> f64 {
    effective_threshold(base, delta)
}

/// Monotonic version comparator C ABI。
///
/// Pointer-based to permit borrowing Swift String bytes
/// without an extra copy。 Lengths in bytes (UTF-8)。
///
/// Returns:
///   1  if proposed > current
///   0  if proposed <= current
///   -1 if either string is empty or pointer is null
///
/// SAFETY: Caller must ensure `current_ptr` points to a
/// valid UTF-8 byte sequence of `current_len` bytes and
/// `proposed_ptr` likewise。 The Swift bridge enforces
/// this by passing `String.utf8` count and pointer。
#[no_mangle]
pub unsafe extern "C" fn
    bas_permit_policy_monotonic_version_compare(
        current_ptr: *const c_char,
        current_len: i32,
        proposed_ptr: *const c_char,
        proposed_len: i32,
) -> i32 {
    if current_ptr.is_null()
        || proposed_ptr.is_null()
        || current_len <= 0
        || proposed_len <= 0
    {
        return -1;
    }
    // SAFETY:caller pins ptr+len validity per the
    // function's safety contract above。
    let current_bytes = unsafe {
        std::slice::from_raw_parts(
            current_ptr as *const u8,
            current_len as usize)
    };
    let proposed_bytes = unsafe {
        std::slice::from_raw_parts(
            proposed_ptr as *const u8,
            proposed_len as usize)
    };
    let current_str = match std::str::from_utf8(current_bytes)
    {
        Ok(s) => s, Err(_) => return -1,
    };
    let proposed_str = match
        std::str::from_utf8(proposed_bytes)
    {
        Ok(s) => s, Err(_) => return -1,
    };
    match monotonic_version_compare(
        current_str, proposed_str)
    {
        Some(true) => 1,
        Some(false) => 0,
        None => -1,
    }
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    // MARK: - BrainRiskLevel rank

    #[test]
    fn brain_risk_level_ranks_are_monotonic() {
        assert_eq!(BrainRiskLevel::Low.rank(), 0);
        assert_eq!(BrainRiskLevel::Medium.rank(), 1);
        assert_eq!(BrainRiskLevel::High.rank(), 2);
        assert_eq!(BrainRiskLevel::Extreme.rank(), 3);
    }

    #[test]
    fn brain_risk_level_round_trip() {
        for lvl in [
            BrainRiskLevel::Low, BrainRiskLevel::Medium,
            BrainRiskLevel::High, BrainRiskLevel::Extreme,
        ] {
            let j = serde_json::to_string(&lvl).unwrap();
            let back: BrainRiskLevel =
                serde_json::from_str(&j).unwrap();
            assert_eq!(lvl, back);
        }
    }

    // MARK: - RiskBand

    #[test]
    fn risk_band_raw_values_pinned() {
        let cases = [
            (RiskBand::Low, "\"low\""),
            (RiskBand::Medium, "\"medium\""),
            (RiskBand::High, "\"high\""),
            (RiskBand::Critical, "\"critical\""),
        ];
        for (band, expected) in cases {
            let j = serde_json::to_string(&band).unwrap();
            assert_eq!(j, expected);
        }
    }

    // MARK: - ActionPermitMode raw values (must match
    //         BASActionPermitMode Swift raw values verbatim)

    #[test]
    fn action_permit_mode_raw_values_pinned() {
        let cases = [
            (ActionPermitMode::Answer, "\"answer\""),
            (ActionPermitMode::Mirror, "\"mirror\""),
            (ActionPermitMode::Compare, "\"compare\""),
            (ActionPermitMode::Delay, "\"delay\""),
            (ActionPermitMode::DraftOnly, "\"draft_only\""),
            (ActionPermitMode::LocalOnly, "\"local_only\""),
            (ActionPermitMode::Block, "\"block\""),
            (ActionPermitMode::Replace, "\"replace\""),
            (ActionPermitMode::Escalate, "\"escalate\""),
        ];
        for (mode, expected) in cases {
            let j = serde_json::to_string(&mode).unwrap();
            assert_eq!(j, expected);
        }
    }

    // MARK: - L11 classifier — match cascade

    #[test]
    fn critical_band_crisis_climate_blocks() {
        assert_eq!(
            risk_band_to_next_mode(
                RiskBand::Critical,
                RiskClimate::Crisis,
                ActionPermitMode::Answer),
            ActionPermitMode::Block);
    }

    #[test]
    fn critical_band_non_crisis_escalates() {
        for climate in [
            RiskClimate::Calm, RiskClimate::Watchful,
            RiskClimate::Elevated,
        ] {
            assert_eq!(
                risk_band_to_next_mode(
                    RiskBand::Critical,
                    climate,
                    ActionPermitMode::Answer),
                ActionPermitMode::Escalate,
                "Critical band non-crisis must escalate");
        }
    }

    #[test]
    fn high_band_warm_climates_replace() {
        for climate in [
            RiskClimate::Crisis, RiskClimate::Elevated,
        ] {
            assert_eq!(
                risk_band_to_next_mode(
                    RiskBand::High,
                    climate,
                    ActionPermitMode::Answer),
                ActionPermitMode::Replace);
        }
    }

    #[test]
    fn high_band_watchful_delays() {
        assert_eq!(
            risk_band_to_next_mode(
                RiskBand::High,
                RiskClimate::Watchful,
                ActionPermitMode::Answer),
            ActionPermitMode::Delay);
    }

    #[test]
    fn high_band_calm_drafts() {
        assert_eq!(
            risk_band_to_next_mode(
                RiskBand::High,
                RiskClimate::Calm,
                ActionPermitMode::Answer),
            ActionPermitMode::DraftOnly);
    }

    #[test]
    fn medium_band_warm_compares() {
        for climate in [
            RiskClimate::Crisis, RiskClimate::Elevated,
        ] {
            assert_eq!(
                risk_band_to_next_mode(
                    RiskBand::Medium,
                    climate,
                    ActionPermitMode::Answer),
                ActionPermitMode::Compare);
        }
    }

    #[test]
    fn medium_band_watchful_mirrors() {
        assert_eq!(
            risk_band_to_next_mode(
                RiskBand::Medium,
                RiskClimate::Watchful,
                ActionPermitMode::Answer),
            ActionPermitMode::Mirror);
    }

    #[test]
    fn medium_band_calm_keeps_current() {
        for current in [
            ActionPermitMode::Answer,
            ActionPermitMode::Mirror,
            ActionPermitMode::DraftOnly,
        ] {
            assert_eq!(
                risk_band_to_next_mode(
                    RiskBand::Medium,
                    RiskClimate::Calm,
                    current),
                current,
                "Medium + Calm must keep current = {:?}",
                current);
        }
    }

    #[test]
    fn low_band_keeps_current_in_any_climate() {
        for climate in [
            RiskClimate::Calm, RiskClimate::Watchful,
            RiskClimate::Elevated, RiskClimate::Crisis,
        ] {
            for current in [
                ActionPermitMode::Answer,
                ActionPermitMode::DraftOnly,
                ActionPermitMode::Escalate,
            ] {
                assert_eq!(
                    risk_band_to_next_mode(
                        RiskBand::Low, climate, current),
                    current,
                    "Low band must keep current ({:?}/{:?})",
                    climate, current);
            }
        }
    }

    // MARK: - Determinism

    #[test]
    fn classifier_is_deterministic_across_repeats() {
        // Same inputs → same outputs every call。
        for _ in 0..10 {
            assert_eq!(
                risk_band_to_next_mode(
                    RiskBand::High,
                    RiskClimate::Crisis,
                    ActionPermitMode::Answer),
                ActionPermitMode::Replace);
        }
    }

    // MARK: - Effective threshold

    #[test]
    fn effective_threshold_clamps_low() {
        // Negative sum clamped to 0
        assert_eq!(effective_threshold(0.1, -0.5), 0.0);
    }

    #[test]
    fn effective_threshold_clamps_high() {
        // Sum > 1 clamped to 1
        assert_eq!(effective_threshold(0.8, 0.5), 1.0);
    }

    #[test]
    fn effective_threshold_passes_through_in_range() {
        assert!(
            (effective_threshold(0.5, 0.1) - 0.6).abs()
                < 1e-9);
    }

    #[test]
    fn effective_threshold_nan_returns_zero() {
        assert_eq!(
            effective_threshold(f64::NAN, 0.5), 0.0);
        assert_eq!(
            effective_threshold(0.5, f64::NAN), 0.0);
    }

    // MARK: - Monotonic version compare

    #[test]
    fn monotonic_version_proposed_greater_passes() {
        assert_eq!(
            monotonic_version_compare("v1.0.0", "v2.0.0"),
            Some(true));
    }

    #[test]
    fn monotonic_version_proposed_equal_rejected() {
        assert_eq!(
            monotonic_version_compare("v1.0.0", "v1.0.0"),
            Some(false));
    }

    #[test]
    fn monotonic_version_proposed_lesser_rejected() {
        assert_eq!(
            monotonic_version_compare("v2.0.0", "v1.0.0"),
            Some(false));
    }

    #[test]
    fn monotonic_version_empty_inputs_fault() {
        assert_eq!(
            monotonic_version_compare("", "v1.0.0"), None);
        assert_eq!(
            monotonic_version_compare("v1.0.0", ""), None);
    }
}
