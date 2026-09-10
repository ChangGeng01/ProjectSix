// SPDX:internal
//
// frame.rs — chapter 七百三 第四刀 / M2174
//
// L14 sovereign-frame aggregator。 Binds together everything one
// turn touches in the sovereign domain。 Codable so it can ride
// the event log as a single payload。

use serde::{Deserialize, Serialize};

/// The per-turn sovereign frame。 Mirrors Swift's
/// BASSovereignFrame field-for-field。
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SovereignFrame {
    pub session_id: String,
    pub turn_id: String,
    pub device_ref: String,
    pub host_ref: String,
    pub continuity_ref: String,
    pub fold_ref: String,
    pub risk_ref: String,
    pub permit_ref: String,
    pub pending_action_digests: Vec<String>,
    pub jurisdiction_ref: String,
    pub time_lock_ref: String,
    pub contamination_refs: Vec<String>,
    pub policy_hash: String,
    pub recorded_at_ms: i64,
}

impl SovereignFrame {
    /// Build a frame with empty list fields。 Useful for the
    /// happy-path turn that has no pending actions / no
    /// contamination。
    pub fn empty(
        session_id: impl Into<String>,
        turn_id: impl Into<String>,
        recorded_at_ms: i64,
    ) -> Self {
        Self {
            session_id: session_id.into(),
            turn_id: turn_id.into(),
            device_ref: String::new(),
            host_ref: String::new(),
            continuity_ref: String::new(),
            fold_ref: String::new(),
            risk_ref: String::new(),
            permit_ref: String::new(),
            pending_action_digests: Vec::new(),
            jurisdiction_ref: String::new(),
            time_lock_ref: String::new(),
            contamination_refs: Vec::new(),
            policy_hash: String::new(),
            recorded_at_ms,
        }
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

    fn sample() -> SovereignFrame {
        SovereignFrame {
            session_id: "session-A".into(),
            turn_id: "turn-1".into(),
            device_ref: "device-ipad".into(),
            host_ref: "host-app-1.0".into(),
            continuity_ref: "cont-001".into(),
            fold_ref: "fold-002".into(),
            risk_ref: "risk-calm".into(),
            permit_ref: "permit-default".into(),
            pending_action_digests:
                vec!["dig-001".into()],
            jurisdiction_ref: "jur-default".into(),
            time_lock_ref: "tl-default".into(),
            contamination_refs: Vec::new(),
            policy_hash: "abcdef".into(),
            recorded_at_ms: 1_700_000_000_000,
        }
    }

    #[test]
    fn empty_constructor() {
        let f = SovereignFrame::empty(
            "session-A", "turn-1", 0);
        assert!(f.device_ref.is_empty());
        assert!(f.pending_action_digests.is_empty());
        assert_eq!(f.session_id, "session-A");
    }

    #[test]
    fn round_trip_json() {
        let f = sample();
        let j = f.encode().unwrap();
        let back = SovereignFrame::decode(&j).unwrap();
        assert_eq!(f, back);
    }

    #[test]
    fn determinism() {
        let f = sample();
        let j1 = f.encode().unwrap();
        let j2 = f.encode().unwrap();
        assert_eq!(j1, j2);
    }

    #[test]
    fn list_fields_preserved() {
        let f = sample();
        let j = f.encode().unwrap();
        let back = SovereignFrame::decode(&j).unwrap();
        assert_eq!(back.pending_action_digests.len(), 1);
        assert_eq!(back.pending_action_digests[0], "dig-001");
    }
}
