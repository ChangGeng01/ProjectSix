// SPDX:internal
//
// decay.rs — chapter 七百三 第三刀 / M2173
//
// Score-decay policies ported from Swift's BASMemory decay
// scheduling + CognitionCore retrieval scoring。 Three canonical
// shapes:
//
//   - Exponential decay:  score × exp(-λ × age_ms / 1000)
//   - Linear decay:       score × max(0, 1 - age_ms / horizon_ms)
//   - Step decay:         score × (1.0 if age_ms < threshold_ms
//                                  else floor_factor)

use serde::{Deserialize, Serialize};

/// Typed decay policy enum mirroring Swift's
/// `BASMemoryDecayPolicy` raw-stable string enum。
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "kebab-case")]
pub enum DecayPolicy {
    /// `score × exp(-rate × age_seconds)`。 `rate` is per-second。
    Exponential { rate: f64 },
    /// `score × max(0, 1 - age_ms / horizon_ms)`。
    Linear { horizon_ms: i64 },
    /// `score × (1 if age_ms < threshold_ms else floor_factor)`。
    Step { threshold_ms: i64, floor_factor: f64 },
    /// `score` unchanged regardless of age。
    None,
}

/// Apply the decay policy to a raw score given the entry's age
/// (now_ms - last_observed_ms)。 Negative ages clamp to 0。
pub fn apply_decay(
    raw_score: f64, age_ms: i64, policy: DecayPolicy,
) -> f64 {
    let age_ms = age_ms.max(0);
    match policy {
        DecayPolicy::None => raw_score,
        DecayPolicy::Exponential { rate } => {
            let age_s = age_ms as f64 / 1000.0;
            raw_score * (-rate * age_s).exp()
        }
        DecayPolicy::Linear { horizon_ms } => {
            if horizon_ms <= 0 {
                return 0.0;
            }
            let factor = 1.0
                - (age_ms as f64 / horizon_ms as f64);
            raw_score * factor.max(0.0)
        }
        DecayPolicy::Step { threshold_ms, floor_factor } => {
            if age_ms < threshold_ms {
                raw_score
            } else {
                raw_score * floor_factor
            }
        }
    }
}

/// Compute decay for many entries at once。 Common in batch
/// retrieval where 100s of candidates are scored together。
pub fn apply_decay_batch(
    raw_scores: &[f64], ages_ms: &[i64], policy: DecayPolicy,
) -> Vec<f64> {
    if raw_scores.len() != ages_ms.len() {
        return Vec::new();
    }
    raw_scores.iter().zip(ages_ms.iter())
        .map(|(s, a)| apply_decay(*s, *a, policy))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx_eq(a: f64, b: f64, tol: f64) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn none_policy_passthrough() {
        let s = apply_decay(0.5, 1_000_000, DecayPolicy::None);
        assert_eq!(s, 0.5);
    }

    #[test]
    fn exponential_at_zero_age() {
        let s = apply_decay(
            1.0, 0, DecayPolicy::Exponential { rate: 0.1 });
        assert!(approx_eq(s, 1.0, 1e-9));
    }

    #[test]
    fn exponential_after_one_second() {
        // rate=ln(2): half-life is 1s
        let rate = std::f64::consts::LN_2;
        let s = apply_decay(
            1.0, 1000, DecayPolicy::Exponential { rate });
        assert!(approx_eq(s, 0.5, 1e-6));
    }

    #[test]
    fn linear_full_score_at_zero_age() {
        let s = apply_decay(
            1.0, 0,
            DecayPolicy::Linear { horizon_ms: 1000 });
        assert!(approx_eq(s, 1.0, 1e-9));
    }

    #[test]
    fn linear_zero_at_horizon() {
        let s = apply_decay(
            1.0, 1000,
            DecayPolicy::Linear { horizon_ms: 1000 });
        assert!(approx_eq(s, 0.0, 1e-9));
    }

    #[test]
    fn linear_half_at_half_horizon() {
        let s = apply_decay(
            1.0, 500,
            DecayPolicy::Linear { horizon_ms: 1000 });
        assert!(approx_eq(s, 0.5, 1e-9));
    }

    #[test]
    fn linear_clamps_negative() {
        let s = apply_decay(
            1.0, 2000,
            DecayPolicy::Linear { horizon_ms: 1000 });
        assert_eq!(s, 0.0);
    }

    #[test]
    fn step_below_threshold() {
        let s = apply_decay(
            1.0, 500,
            DecayPolicy::Step {
                threshold_ms: 1000, floor_factor: 0.1 });
        assert_eq!(s, 1.0);
    }

    #[test]
    fn step_above_threshold() {
        let s = apply_decay(
            1.0, 1500,
            DecayPolicy::Step {
                threshold_ms: 1000, floor_factor: 0.1 });
        assert!(approx_eq(s, 0.1, 1e-9));
    }

    #[test]
    fn negative_age_clamps_to_zero() {
        let s = apply_decay(
            1.0, -500,
            DecayPolicy::Linear { horizon_ms: 1000 });
        assert_eq!(s, 1.0);
    }

    #[test]
    fn batch_handles_mismatched_lengths() {
        let scores = [1.0, 2.0];
        let ages = [0_i64];
        let out = apply_decay_batch(
            &scores, &ages, DecayPolicy::None);
        assert!(out.is_empty());
    }

    #[test]
    fn batch_per_entry_decay() {
        let scores = [1.0, 0.5];
        let ages = [0_i64, 500];
        let out = apply_decay_batch(
            &scores, &ages,
            DecayPolicy::Linear { horizon_ms: 1000 });
        assert_eq!(out.len(), 2);
        assert!(approx_eq(out[0], 1.0, 1e-9));
        assert!(approx_eq(out[1], 0.25, 1e-9));
    }
}
