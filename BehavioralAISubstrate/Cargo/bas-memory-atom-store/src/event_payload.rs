// SPDX:internal
//
// event_payload.rs — chapter 七百三 第二刀 / M2172
//
// Rust port of BASMemoryAtomEventPayload (Sources/BASMemory/
// BASMemoryAtomEventPayload.swift)。 Typed Codable payload that
// rides the BASEventLog as the canonical source-of-truth for
// memory-atom mutations。

use serde::{Deserialize, Serialize};

/// Typed enum naming canonical memory-atom mutation operations。
/// Raw values pinned for wire stability — bumping requires audit
/// migration (chapter 八十七 raw-value stability)。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum MemoryAtomEventOp {
    /// Atom admitted into the store。 Payload carries the full
    /// initial atom snapshot。
    Admitted,
    /// Atom's `tier` field changed。
    TierChanged,
    /// Atom's `governanceStatus` field changed。
    GovernanceChanged,
    /// Atom removed from the store。
    Removed,
}

/// Memory atom kind — mirror of Swift's BASMemoryKind。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MemoryKind {
    Semantic,
    Episodic,
    Procedural,
    Reflective,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MemoryScope {
    User,
    Session,
    Global,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MemorySensitivity {
    Low,
    Medium,
    High,
    Secret,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MemoryTier {
    Hot,
    Warm,
    Cold,
    Frozen,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum MemoryGovernanceStatus {
    Pending,
    Admitted,
    Deferred,
    Promoted,
    Removed,
    Quarantined,
}

/// Typed Codable payload encoded inside BASEventLogEntry
/// .payloadJson when the event represents a memory-atom mutation。
/// Only fields relevant to the operation are populated。
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct MemoryAtomEventPayload {
    pub op: MemoryAtomEventOp,
    #[serde(rename = "atomID")]
    pub atom_id: String,

    // .admitted full snapshot (nil otherwise)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub kind: Option<MemoryKind>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub scope: Option<MemoryScope>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sensitivity: Option<MemorySensitivity>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tier: Option<MemoryTier>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub confidence: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none",
        rename = "sourceType")]
    pub source_type: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none",
        rename = "lastConfirmedAtMs")]
    pub last_confirmed_at_ms: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none",
        rename = "governanceStatus")]
    pub governance_status: Option<MemoryGovernanceStatus>,
    #[serde(skip_serializing_if = "Option::is_none",
        rename = "provenanceSummary")]
    pub provenance_summary: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none",
        rename = "contentDigest")]
    pub content_digest: Option<String>,
}

impl MemoryAtomEventPayload {
    /// .admitted full-snapshot constructor。
    pub fn admitted(
        atom_id: impl Into<String>,
        kind: MemoryKind,
        scope: MemoryScope,
        sensitivity: MemorySensitivity,
        tier: MemoryTier,
        confidence: f64,
        source_type: impl Into<String>,
        last_confirmed_at_ms: Option<i64>,
        governance_status: MemoryGovernanceStatus,
        provenance_summary: impl Into<String>,
        content_digest: impl Into<String>,
    ) -> Self {
        Self {
            op: MemoryAtomEventOp::Admitted,
            atom_id: atom_id.into(),
            kind: Some(kind),
            scope: Some(scope),
            sensitivity: Some(sensitivity),
            tier: Some(tier),
            // Clamp confidence to [0, 1] per Swift policy。
            confidence: Some(confidence.clamp(0.0, 1.0)),
            source_type: Some(source_type.into()),
            last_confirmed_at_ms,
            governance_status: Some(governance_status),
            provenance_summary: Some(
                provenance_summary.into()),
            content_digest: Some(content_digest.into()),
        }
    }

    pub fn tier_changed(
        atom_id: impl Into<String>, new_tier: MemoryTier,
    ) -> Self {
        Self {
            op: MemoryAtomEventOp::TierChanged,
            atom_id: atom_id.into(),
            tier: Some(new_tier),
            kind: None, scope: None, sensitivity: None,
            confidence: None, source_type: None,
            last_confirmed_at_ms: None,
            governance_status: None,
            provenance_summary: None,
            content_digest: None,
        }
    }

    pub fn governance_changed(
        atom_id: impl Into<String>,
        new_status: MemoryGovernanceStatus,
    ) -> Self {
        Self {
            op: MemoryAtomEventOp::GovernanceChanged,
            atom_id: atom_id.into(),
            governance_status: Some(new_status),
            kind: None, scope: None, sensitivity: None,
            tier: None, confidence: None,
            source_type: None,
            last_confirmed_at_ms: None,
            provenance_summary: None,
            content_digest: None,
        }
    }

    pub fn removed(atom_id: impl Into<String>) -> Self {
        Self {
            op: MemoryAtomEventOp::Removed,
            atom_id: atom_id.into(),
            kind: None, scope: None, sensitivity: None,
            tier: None, confidence: None,
            source_type: None,
            last_confirmed_at_ms: None,
            governance_status: None,
            provenance_summary: None,
            content_digest: None,
        }
    }

    /// Encode as JSON。 Returns an Err only on serde failure
    /// (extremely rare for valid Codable types)。
    pub fn encode_json(&self) -> Result<String, String> {
        serde_json::to_string(self).map_err(|e| e.to_string())
    }

    /// Decode from JSON。
    pub fn decode_json(s: &str) -> Result<Self, String> {
        serde_json::from_str(s).map_err(|e| e.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn admitted_sample() -> MemoryAtomEventPayload {
        MemoryAtomEventPayload::admitted(
            "atom-abc",
            MemoryKind::Semantic,
            MemoryScope::User,
            MemorySensitivity::Low,
            MemoryTier::Warm,
            0.75,
            "test-source",
            Some(1_700_000_000_000),
            MemoryGovernanceStatus::Admitted,
            "summary-text",
            "abcdef0123")
    }

    #[test]
    fn admitted_round_trip() {
        let p = admitted_sample();
        let json = p.encode_json().unwrap();
        let decoded =
            MemoryAtomEventPayload::decode_json(&json)
                .unwrap();
        assert_eq!(p, decoded);
    }

    #[test]
    fn tier_changed_round_trip() {
        let p = MemoryAtomEventPayload::tier_changed(
            "atom-x", MemoryTier::Cold);
        let json = p.encode_json().unwrap();
        let decoded =
            MemoryAtomEventPayload::decode_json(&json)
                .unwrap();
        assert_eq!(p, decoded);
        assert_eq!(decoded.op, MemoryAtomEventOp::TierChanged);
        assert_eq!(decoded.tier, Some(MemoryTier::Cold));
        // Other optional fields must round-trip as None
        assert!(decoded.kind.is_none());
        assert!(decoded.scope.is_none());
    }

    #[test]
    fn governance_changed_round_trip() {
        let p = MemoryAtomEventPayload::governance_changed(
            "atom-y", MemoryGovernanceStatus::Quarantined);
        let json = p.encode_json().unwrap();
        let decoded =
            MemoryAtomEventPayload::decode_json(&json)
                .unwrap();
        assert_eq!(p, decoded);
    }

    #[test]
    fn removed_round_trip() {
        let p = MemoryAtomEventPayload::removed("atom-z");
        let json = p.encode_json().unwrap();
        let decoded =
            MemoryAtomEventPayload::decode_json(&json)
                .unwrap();
        assert_eq!(p, decoded);
        // Removed carries only atom_id — every snapshot field
        // should be None。
        assert!(decoded.kind.is_none());
        assert!(decoded.tier.is_none());
        assert!(decoded.governance_status.is_none());
    }

    #[test]
    fn confidence_clamped_low() {
        let p = MemoryAtomEventPayload::admitted(
            "x", MemoryKind::Semantic, MemoryScope::User,
            MemorySensitivity::Low, MemoryTier::Warm,
            -0.5, "s", None,
            MemoryGovernanceStatus::Admitted, "", "");
        assert_eq!(p.confidence, Some(0.0));
    }

    #[test]
    fn confidence_clamped_high() {
        let p = MemoryAtomEventPayload::admitted(
            "x", MemoryKind::Semantic, MemoryScope::User,
            MemorySensitivity::Low, MemoryTier::Warm,
            5.0, "s", None,
            MemoryGovernanceStatus::Admitted, "", "");
        assert_eq!(p.confidence, Some(1.0));
    }

    #[test]
    fn confidence_passthrough_in_range() {
        let p = MemoryAtomEventPayload::admitted(
            "x", MemoryKind::Semantic, MemoryScope::User,
            MemorySensitivity::Low, MemoryTier::Warm,
            0.42, "s", None,
            MemoryGovernanceStatus::Admitted, "", "");
        assert_eq!(p.confidence, Some(0.42));
    }

    /// Determinism — encoding the same payload twice yields the
    /// same JSON bytes (chapter 三百九二 replay-determinism)。
    #[test]
    fn json_encoding_is_deterministic() {
        let p = admitted_sample();
        let j1 = p.encode_json().unwrap();
        let j2 = p.encode_json().unwrap();
        let j3 = p.encode_json().unwrap();
        assert_eq!(j1, j2);
        assert_eq!(j2, j3);
    }

    /// op enum raw values are pinned for wire stability。
    #[test]
    fn op_raw_values_pinned() {
        let cases = [
            (MemoryAtomEventOp::Admitted, "admitted"),
            (MemoryAtomEventOp::TierChanged, "tier-changed"),
            (MemoryAtomEventOp::GovernanceChanged,
                "governance-changed"),
            (MemoryAtomEventOp::Removed, "removed"),
        ];
        for (variant, expected) in cases {
            let json = serde_json::to_string(&variant).unwrap();
            // serde wraps enum variants in quotes for tagged
            // enums; strip the quotes for comparison。
            let stripped = json.trim_matches('"');
            assert_eq!(stripped, expected);
        }
    }
}
