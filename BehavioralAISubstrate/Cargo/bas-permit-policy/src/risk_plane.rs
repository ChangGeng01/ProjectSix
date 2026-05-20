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
