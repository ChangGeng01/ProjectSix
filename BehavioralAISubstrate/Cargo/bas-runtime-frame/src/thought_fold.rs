// SPDX:internal
//
// thought_fold.rs — chapter 七百三 第四刀 / M2174
//
// Typed thought-fold surface。 Mirrors Swift's BASThoughtFold —
// the per-turn aggregator that the sovereign commit signs +
// the host-side reducer consumes。

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ThoughtFold {
    pub fold_id: String,
    pub session_id: String,
    pub turn_id: String,
    pub checksum: String,
    pub rollback_anchor_ref: Option<String>,
    pub snapshot_ref: Option<String>,
    pub thought_frame_ref: String,
    pub budget_frame_ref: String,
    pub created_at_ms: i64,
}

impl ThoughtFold {
    pub fn new(
        fold_id: impl Into<String>,
        session_id: impl Into<String>,
        turn_id: impl Into<String>,
        thought_frame_ref: impl Into<String>,
        budget_frame_ref: impl Into<String>,
        checksum: impl Into<String>,
        created_at_ms: i64,
    ) -> Self {
        Self {
            fold_id: fold_id.into(),
            session_id: session_id.into(),
            turn_id: turn_id.into(),
            checksum: checksum.into(),
            rollback_anchor_ref: None,
            snapshot_ref: None,
            thought_frame_ref: thought_frame_ref.into(),
            budget_frame_ref: budget_frame_ref.into(),
            created_at_ms,
        }
    }

    pub fn with_rollback_anchor(
        mut self, anchor: impl Into<String>,
    ) -> Self {
        self.rollback_anchor_ref = Some(anchor.into());
        self
    }

    pub fn with_snapshot(
        mut self, snap: impl Into<String>,
    ) -> Self {
        self.snapshot_ref = Some(snap.into());
        self
    }

    pub fn encode(&self) -> Result<String, String> {
        serde_json::to_string(self).map_err(|e| e.to_string())
    }

    pub fn decode(s: &str) -> Result<Self, String> {
        serde_json::from_str(s).map_err(|e| e.to_string())
    }
}

// MARK: - L3 thought-fold observation derivation
//         (chapter 七百四十六 第一刀 / M2401)

/// Derived observation reference。 Deterministic projection
/// from (fold_id, observation_kind, timestamp_ms) — used by
/// the L3 thought-fold observation pipeline to produce
/// stable IDs that replay byte-identical across runs。
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ObservationDerivation {
    pub observation_id: String,
    /// Canonical bytes that the audit chain seals over。
    /// Used by replay verification to confirm the observation
    /// stays byte-stable。
    pub canonical_payload: Vec<u8>,
}

/// Pure derivation:given a fold + observation kind +
/// timestamp,produce a deterministic observation_id and
/// canonical bytes。
///
/// observation_id format:
///   "obs-{session_id}-{turn_id}-{kind}-{timestamp_ms}"
///
/// canonical_payload:
///   u32_be(fold_id_len) || fold_id_utf8
///   u32_be(kind_len)    || kind_utf8
///   i64_be(timestamp_ms)
///
/// This is the chapter 七百四十一 canonical-bytes pattern
/// reused for L3 observations。 Replay determinism preserved
/// by construction (no randomness,no clock dependency)。
pub fn derive_observation(
    fold: &ThoughtFold,
    observation_kind_raw: &str,
    timestamp_ms: i64,
) -> ObservationDerivation {
    let observation_id = format!(
        "obs-{}-{}-{}-{}",
        fold.session_id,
        fold.turn_id,
        observation_kind_raw,
        timestamp_ms);
    let mut buf: Vec<u8> = Vec::with_capacity(
        4 + fold.fold_id.len()
        + 4 + observation_kind_raw.len()
        + 8);
    let fid_bytes = fold.fold_id.as_bytes();
    buf.extend_from_slice(
        &(fid_bytes.len() as u32).to_be_bytes());
    buf.extend_from_slice(fid_bytes);
    let kind_bytes = observation_kind_raw.as_bytes();
    buf.extend_from_slice(
        &(kind_bytes.len() as u32).to_be_bytes());
    buf.extend_from_slice(kind_bytes);
    buf.extend_from_slice(&timestamp_ms.to_be_bytes());
    ObservationDerivation {
        observation_id,
        canonical_payload: buf,
    }
}

#[cfg(test)]
mod observation_tests {
    use super::*;

    fn sample() -> ThoughtFold {
        ThoughtFold::new(
            "fold-001", "sess-A", "turn-7",
            "tf-x", "bf-y", "chk-z", 100)
    }

    #[test]
    fn observation_id_format() {
        let f = sample();
        let d = derive_observation(&f, "intent", 1000);
        assert_eq!(
            d.observation_id,
            "obs-sess-A-turn-7-intent-1000");
    }

    #[test]
    fn observation_canonical_has_expected_length() {
        let f = sample();
        let d = derive_observation(&f, "intent", 1000);
        // 4 + 8 (fold_id "fold-001") + 4 + 6 ("intent") + 8
        assert_eq!(d.canonical_payload.len(),
            4 + 8 + 4 + 6 + 8);
    }

    #[test]
    fn observation_determinism() {
        let f = sample();
        let a = derive_observation(&f, "intent", 1000);
        let b = derive_observation(&f, "intent", 1000);
        assert_eq!(a, b);
    }

    #[test]
    fn distinct_kinds_distinct_canonical() {
        let f = sample();
        let a = derive_observation(&f, "intent", 1000);
        let b = derive_observation(&f, "veto", 1000);
        assert_ne!(a.canonical_payload, b.canonical_payload);
        assert_ne!(a.observation_id, b.observation_id);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> ThoughtFold {
        ThoughtFold::new(
            "fold-001", "session-A", "turn-1",
            "thought-frame-x", "budget-frame-y",
            "checksum-abcdef", 1_700_000)
            .with_rollback_anchor("anchor-001")
            .with_snapshot("snap-007")
    }

    #[test]
    fn builder_pattern_works() {
        let f = sample();
        assert_eq!(f.fold_id, "fold-001");
        assert_eq!(f.rollback_anchor_ref,
            Some("anchor-001".to_string()));
        assert_eq!(f.snapshot_ref,
            Some("snap-007".to_string()));
    }

    #[test]
    fn round_trip_json() {
        let f = sample();
        let j = f.encode().unwrap();
        let back = ThoughtFold::decode(&j).unwrap();
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
    fn optional_fields_none_round_trip() {
        let mut f = sample();
        f.rollback_anchor_ref = None;
        f.snapshot_ref = None;
        let j = f.encode().unwrap();
        let back = ThoughtFold::decode(&j).unwrap();
        assert_eq!(back.rollback_anchor_ref, None);
        assert_eq!(back.snapshot_ref, None);
    }

    #[test]
    fn checksum_field_distinguishes_folds() {
        let mut f1 = sample();
        let mut f2 = sample();
        f1.checksum = "AAAA".to_string();
        f2.checksum = "BBBB".to_string();
        assert_ne!(f1, f2);
    }
}
