// SPDX:internal
//
// risk.rs — chapter 七百三 第四刀 / M2174
//
// Risk climate evaluation。 Given recent observations,bucket the
// host into Calm / Watchful / Elevated / Crisis。 Mirrors the
// Swift BASRiskClimate hysteresis logic but with explicit
// thresholds + no shared mutable state。

use crate::enums::RiskClimate;

/// Snapshot of recent observations that drive climate evaluation。
#[derive(Clone, Debug, PartialEq)]
pub struct RiskObservation {
    /// Count of `.refuse` verdicts in the last 50 turns。
    pub recent_refuse_count: u32,
    /// Count of `.failClosed` verdicts in the last 50 turns。
    pub recent_fail_closed_count: u32,
    /// Thermal pressure observed at the most recent breath。
    pub thermal_pressure: f64,
    /// Whether the integrity sentinel flagged any artifact in
    /// the last 50 turns。
    pub integrity_violation_in_window: bool,
}

/// Evaluate the risk climate from the observation snapshot。
/// Hysteresis-friendly:thresholds are step-function-style so
/// the same observation always yields the same climate。
pub fn evaluate(o: &RiskObservation) -> RiskClimate {
    // Crisis dominates。 Two signals: fail-closed > 0 OR
    // integrity-violation。
    if o.recent_fail_closed_count > 0
        || o.integrity_violation_in_window
    {
        return RiskClimate::Crisis;
    }
    // Elevated: refuse count over threshold OR thermal > 0.85
    if o.recent_refuse_count >= 5 || o.thermal_pressure > 0.85
    {
        return RiskClimate::Elevated;
    }
    // Watchful: any refuse OR thermal > 0.7
    if o.recent_refuse_count > 0 || o.thermal_pressure > 0.7
    {
        return RiskClimate::Watchful;
    }
    RiskClimate::Calm
}

#[cfg(test)]
mod tests {
    use super::*;

    fn calm_obs() -> RiskObservation {
        RiskObservation {
            recent_refuse_count: 0,
            recent_fail_closed_count: 0,
            thermal_pressure: 0.3,
            integrity_violation_in_window: false,
        }
    }

    #[test]
    fn calm_baseline() {
        assert_eq!(evaluate(&calm_obs()), RiskClimate::Calm);
    }

    #[test]
    fn fail_closed_forces_crisis() {
        let mut o = calm_obs();
        o.recent_fail_closed_count = 1;
        assert_eq!(evaluate(&o), RiskClimate::Crisis);
    }

    #[test]
    fn integrity_violation_forces_crisis() {
        let mut o = calm_obs();
        o.integrity_violation_in_window = true;
        assert_eq!(evaluate(&o), RiskClimate::Crisis);
    }

    #[test]
    fn refuse_count_threshold_elevates() {
        let mut o = calm_obs();
        o.recent_refuse_count = 5;
        assert_eq!(evaluate(&o), RiskClimate::Elevated);
    }

    #[test]
    fn thermal_pressure_threshold_elevates() {
        let mut o = calm_obs();
        o.thermal_pressure = 0.86;
        assert_eq!(evaluate(&o), RiskClimate::Elevated);
    }

    #[test]
    fn single_refuse_warrants_watchful() {
        let mut o = calm_obs();
        o.recent_refuse_count = 1;
        assert_eq!(evaluate(&o), RiskClimate::Watchful);
    }

    #[test]
    fn mid_thermal_watchful() {
        let mut o = calm_obs();
        o.thermal_pressure = 0.75;
        assert_eq!(evaluate(&o), RiskClimate::Watchful);
    }

    #[test]
    fn determinism_across_calls() {
        let o = calm_obs();
        for _ in 0..10 {
            assert_eq!(evaluate(&o), RiskClimate::Calm);
        }
    }
}
