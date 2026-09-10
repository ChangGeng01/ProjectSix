// SPDX:internal
//
// observation.rs — chapter 七百三 第四刀 / M2174
//
// Per-turn observation reconciliation report。 Mirrors Swift's
// BASObservationReconciliationReport — the typed mirror of M44
// cross-layer coverage verdicts。

use serde::{Deserialize, Serialize};

/// One coverage signal — a layer reporting whether its
/// observations agreed with the sovereign verdict's expectations。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum CoverageSignal {
    Agreed,
    Disagreed,
    Insufficient,
    NotApplicable,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ObservationReconciliationReport {
    pub session_id: String,
    pub turn_id: String,
    pub recorded_at_ms: i64,
    pub layer_signals: Vec<(String, CoverageSignal)>,
    pub remarks: Option<String>,
}

impl ObservationReconciliationReport {
    pub fn new(
        session_id: impl Into<String>,
        turn_id: impl Into<String>,
        recorded_at_ms: i64,
    ) -> Self {
        Self {
            session_id: session_id.into(),
            turn_id: turn_id.into(),
            recorded_at_ms,
            layer_signals: Vec::new(),
            remarks: None,
        }
    }

    pub fn add_layer(
        &mut self, name: impl Into<String>,
        signal: CoverageSignal,
    ) {
        self.layer_signals.push((name.into(), signal));
    }

    pub fn disagreement_count(&self) -> usize {
        self.layer_signals.iter()
            .filter(|(_, s)| *s == CoverageSignal::Disagreed)
            .count()
    }

    pub fn all_layers_agree(&self) -> bool {
        !self.layer_signals.is_empty()
            && self.layer_signals.iter()
                .all(|(_, s)| *s == CoverageSignal::Agreed)
    }

    pub fn encode(&self) -> Result<String, String> {
        serde_json::to_string(self).map_err(|e| e.to_string())
    }

    pub fn decode(s: &str) -> Result<Self, String> {
        serde_json::from_str(s).map_err(|e| e.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_layers_and_count() {
        let mut r = ObservationReconciliationReport::new(
            "s", "t", 0);
        r.add_layer("L1", CoverageSignal::Agreed);
        r.add_layer("L3", CoverageSignal::Disagreed);
        r.add_layer("L5", CoverageSignal::Insufficient);
        assert_eq!(r.disagreement_count(), 1);
        assert!(!r.all_layers_agree());
    }

    #[test]
    fn all_layers_agree_path() {
        let mut r = ObservationReconciliationReport::new(
            "s", "t", 0);
        r.add_layer("L1", CoverageSignal::Agreed);
        r.add_layer("L3", CoverageSignal::Agreed);
        assert!(r.all_layers_agree());
        assert_eq!(r.disagreement_count(), 0);
    }

    #[test]
    fn empty_report_does_not_satisfy_all_agree() {
        let r = ObservationReconciliationReport::new(
            "s", "t", 0);
        assert!(!r.all_layers_agree());
    }

    #[test]
    fn round_trip_json() {
        let mut r = ObservationReconciliationReport::new(
            "session-A", "turn-1", 1_700_000);
        r.add_layer("L1", CoverageSignal::Agreed);
        r.add_layer("L14", CoverageSignal::NotApplicable);
        r.remarks = Some("looks fine".to_string());
        let j = r.encode().unwrap();
        let back =
            ObservationReconciliationReport::decode(&j).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn signal_raw_values_pinned() {
        let cases = [
            (CoverageSignal::Agreed, "\"agreed\""),
            (CoverageSignal::Disagreed, "\"disagreed\""),
            (CoverageSignal::Insufficient, "\"insufficient\""),
            (CoverageSignal::NotApplicable,
                "\"not-applicable\""),
        ];
        for (v, expected) in cases {
            assert_eq!(
                serde_json::to_string(&v).unwrap(), expected);
        }
    }
}
