// SPDX:internal
//
// decision.rs — chapter 七百三 第四刀 / M2174
//
// Decision table — given (permit_mode, scope, risk_climate,
// host_observed_thermal_pressure, sovereign_verdict),return the
// canonical decision。 Mirrors Swift's BASPolicyDecisionRecord
// flow + the verdict-engine decision tree。

use serde::{Deserialize, Serialize};

use crate::enums::*;

/// Inputs to the decision table。 Pure value-type;the decision
/// is a pure function of these inputs。
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DecisionInput {
    pub permit_mode: PermitMode,
    pub scope: Scope,
    pub risk_climate: RiskClimate,
    /// Thermal pressure 0..1。
    pub thermal_pressure: f64,
    pub sovereign_verdict: Verdict,
}

/// Decision output。 In addition to the verdict the table emits
/// guidance for the runtime (whether to throttle, log loudly,
/// or refuse entirely)。
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DecisionOutput {
    pub verdict: Verdict,
    pub throttle: bool,
    pub log_loudly: bool,
}

/// Compute the decision。 Pure function — deterministic and
/// side-effect free。 Order of checks (highest to lowest
/// precedence):
///
///   1. Sovereign FailClosed always wins。
///   2. Crisis climate forces at least Defer。
///   3. Thermal pressure > 0.9 forces at least Throttle。
///   4. Quarantine permit forces Refuse。
///   5. Else: pass through sovereign_verdict。
pub fn decide(input: &DecisionInput) -> DecisionOutput {
    if matches!(input.sovereign_verdict, Verdict::FailClosed) {
        return DecisionOutput {
            verdict: Verdict::FailClosed,
            throttle: true,
            log_loudly: true,
        };
    }
    if matches!(input.risk_climate, RiskClimate::Crisis) {
        return DecisionOutput {
            verdict: Verdict::Defer,
            throttle: true,
            log_loudly: true,
        };
    }
    let mut verdict = input.sovereign_verdict;
    let mut throttle = false;
    let mut log_loudly = false;
    if input.thermal_pressure > 0.9 {
        throttle = true;
    }
    if matches!(input.permit_mode, PermitMode::Quarantine) {
        verdict = Verdict::Refuse;
        log_loudly = true;
    }
    if matches!(input.risk_climate, RiskClimate::Elevated) {
        if matches!(verdict, Verdict::Allow) {
            verdict = Verdict::AllowWithGuard;
        }
    }
    DecisionOutput { verdict, throttle, log_loudly }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn base_input() -> DecisionInput {
        DecisionInput {
            permit_mode: PermitMode::Default,
            scope: Scope::User,
            risk_climate: RiskClimate::Calm,
            thermal_pressure: 0.5,
            sovereign_verdict: Verdict::Allow,
        }
    }

    #[test]
    fn passthrough_in_calm_state() {
        let inp = base_input();
        let out = decide(&inp);
        assert_eq!(out.verdict, Verdict::Allow);
        assert!(!out.throttle);
        assert!(!out.log_loudly);
    }

    #[test]
    fn fail_closed_always_wins() {
        let mut inp = base_input();
        inp.sovereign_verdict = Verdict::FailClosed;
        let out = decide(&inp);
        assert_eq!(out.verdict, Verdict::FailClosed);
        assert!(out.throttle);
        assert!(out.log_loudly);
    }

    #[test]
    fn crisis_forces_defer() {
        let mut inp = base_input();
        inp.risk_climate = RiskClimate::Crisis;
        let out = decide(&inp);
        assert_eq!(out.verdict, Verdict::Defer);
        assert!(out.throttle);
    }

    #[test]
    fn elevated_upgrades_allow_to_allow_with_guard() {
        let mut inp = base_input();
        inp.risk_climate = RiskClimate::Elevated;
        let out = decide(&inp);
        assert_eq!(out.verdict, Verdict::AllowWithGuard);
    }

    #[test]
    fn high_thermal_pressure_throttles() {
        let mut inp = base_input();
        inp.thermal_pressure = 0.95;
        let out = decide(&inp);
        assert_eq!(out.verdict, Verdict::Allow);
        assert!(out.throttle);
    }

    #[test]
    fn quarantine_permit_refuses() {
        let mut inp = base_input();
        inp.permit_mode = PermitMode::Quarantine;
        let out = decide(&inp);
        assert_eq!(out.verdict, Verdict::Refuse);
        assert!(out.log_loudly);
    }

    #[test]
    fn determinism() {
        let inp = base_input();
        let o1 = decide(&inp);
        let o2 = decide(&inp);
        let o3 = decide(&inp);
        assert_eq!(o1, o2);
        assert_eq!(o2, o3);
    }

    #[test]
    fn decision_round_trip_json() {
        let inp = base_input();
        let j_in = serde_json::to_string(&inp).unwrap();
        let inp_back: DecisionInput =
            serde_json::from_str(&j_in).unwrap();
        assert_eq!(inp, inp_back);
        let out = decide(&inp);
        let j_out = serde_json::to_string(&out).unwrap();
        let out_back: DecisionOutput =
            serde_json::from_str(&j_out).unwrap();
        assert_eq!(out, out_back);
    }
}
