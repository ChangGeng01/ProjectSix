// SPDX:internal
//
// bas-event-log-codec — chapter 七百三 第四刀 / M2174
//
// Rust port of BASEventLogEntry encode/decode + replay-byte-
// stability harness。 The substrate's event log is the canonical
// source-of-truth for atom mutations,permits,sovereign verdicts,
// runtime observations。 Replay determinism (chapter 392) demands
// byte-stable encoding so a reducer rebuilt from the log
// reconstructs identical state。

#![forbid(unsafe_op_in_unsafe_fn)]

use serde::{Deserialize, Serialize};

pub const ABI_VERSION: i32 = 1;

#[no_mangle]
pub extern "C" fn bas_event_log_abi_version() -> i32 {
    ABI_VERSION
}

/// Typed kind discriminator matching Swift's BASEventLogEntryKind。
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum EventKind {
    InternalSignal,
    HostInput,
    SovereignVerdict,
    PermitChange,
    ObservationBundle,
    ProvenanceMark,
    ReplayMark,
}

/// One row in the event log。 Mirrors Swift's BASEventLogEntry
/// field-for-field。
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct EventLogEntry {
    pub entry_id: String,
    pub kind: EventKind,
    pub session_ref: String,
    pub turn_ref: String,
    pub timestamp_ms: i64,
    /// Optional JSON payload — typed by caller via the `kind`
    /// discriminator。 Codec preserves the JSON string verbatim
    /// so byte-equality across encode/decode round trips holds。
    pub payload_json: Option<String>,
    pub provenance_summary: Option<String>,
}

impl EventLogEntry {
    pub fn new(
        entry_id: impl Into<String>,
        kind: EventKind,
        session_ref: impl Into<String>,
        turn_ref: impl Into<String>,
        timestamp_ms: i64,
    ) -> Self {
        Self {
            entry_id: entry_id.into(),
            kind,
            session_ref: session_ref.into(),
            turn_ref: turn_ref.into(),
            timestamp_ms,
            payload_json: None,
            provenance_summary: None,
        }
    }

    pub fn with_payload(mut self, p: String) -> Self {
        self.payload_json = Some(p);
        self
    }

    pub fn with_provenance(
        mut self, s: impl Into<String>
    ) -> Self {
        self.provenance_summary = Some(s.into());
        self
    }
}

/// Encode entry as canonical JSON。 Same encoding twice produces
/// the same bytes (replay-determinism)。
pub fn encode(entry: &EventLogEntry) -> Result<String, String> {
    serde_json::to_string(entry).map_err(|e| e.to_string())
}

/// Decode a JSON string into an entry。
pub fn decode(s: &str) -> Result<EventLogEntry, String> {
    serde_json::from_str(s).map_err(|e| e.to_string())
}

/// Encode many entries as a JSON array — used for snapshot
/// export / replay buffer materialization。
pub fn encode_batch(
    entries: &[EventLogEntry],
) -> Result<String, String> {
    serde_json::to_string(entries).map_err(|e| e.to_string())
}

/// Decode many entries from a JSON array。
pub fn decode_batch(
    s: &str,
) -> Result<Vec<EventLogEntry>, String> {
    serde_json::from_str(s).map_err(|e| e.to_string())
}

/// Filter entries by kind。 Pure helper — no shared state。
pub fn filter_by_kind(
    entries: &[EventLogEntry], kind: EventKind,
) -> Vec<EventLogEntry> {
    entries.iter()
        .filter(|e| e.kind == kind)
        .cloned()
        .collect()
}

/// Filter entries by (session_ref, turn_ref) pair。
pub fn filter_by_turn(
    entries: &[EventLogEntry],
    session_ref: &str, turn_ref: &str,
) -> Vec<EventLogEntry> {
    entries.iter()
        .filter(|e| e.session_ref == session_ref
            && e.turn_ref == turn_ref)
        .cloned()
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> EventLogEntry {
        EventLogEntry::new(
            "entry-001",
            EventKind::SovereignVerdict,
            "session-A", "turn-1", 1_700_000_000_000)
            .with_payload(r#"{"verdict":"allow"}"#.to_string())
            .with_provenance("test-source")
    }

    #[test]
    fn encode_decode_round_trip() {
        let e = sample();
        let json = encode(&e).unwrap();
        let back = decode(&json).unwrap();
        assert_eq!(e, back);
    }

    #[test]
    fn encoding_is_deterministic() {
        let e = sample();
        let j1 = encode(&e).unwrap();
        let j2 = encode(&e).unwrap();
        let j3 = encode(&e).unwrap();
        assert_eq!(j1, j2);
        assert_eq!(j2, j3);
    }

    #[test]
    fn batch_round_trip() {
        let entries = vec![
            sample(),
            EventLogEntry::new(
                "entry-002",
                EventKind::HostInput,
                "session-A", "turn-1", 1_700_000_001_000),
        ];
        let json = encode_batch(&entries).unwrap();
        let back = decode_batch(&json).unwrap();
        assert_eq!(entries, back);
    }

    #[test]
    fn filter_by_kind_works() {
        let entries = vec![
            sample(),
            EventLogEntry::new(
                "entry-002", EventKind::HostInput,
                "session-A", "turn-1", 1),
            EventLogEntry::new(
                "entry-003", EventKind::SovereignVerdict,
                "session-A", "turn-2", 2),
        ];
        let sov = filter_by_kind(
            &entries, EventKind::SovereignVerdict);
        assert_eq!(sov.len(), 2);
        let host = filter_by_kind(
            &entries, EventKind::HostInput);
        assert_eq!(host.len(), 1);
    }

    #[test]
    fn filter_by_turn_works() {
        let entries = vec![
            EventLogEntry::new(
                "a", EventKind::HostInput, "s1", "t1", 1),
            EventLogEntry::new(
                "b", EventKind::HostInput, "s1", "t2", 2),
            EventLogEntry::new(
                "c", EventKind::HostInput, "s2", "t1", 3),
        ];
        let t1 = filter_by_turn(&entries, "s1", "t1");
        assert_eq!(t1.len(), 1);
        assert_eq!(t1[0].entry_id, "a");
    }

    #[test]
    fn kind_raw_value_pinned() {
        let cases = [
            (EventKind::InternalSignal, "\"internal-signal\""),
            (EventKind::HostInput, "\"host-input\""),
            (EventKind::SovereignVerdict, "\"sovereign-verdict\""),
            (EventKind::PermitChange, "\"permit-change\""),
            (EventKind::ObservationBundle,
                "\"observation-bundle\""),
            (EventKind::ProvenanceMark, "\"provenance-mark\""),
            (EventKind::ReplayMark, "\"replay-mark\""),
        ];
        for (v, expected) in cases {
            assert_eq!(
                serde_json::to_string(&v).unwrap(), expected);
        }
    }

    #[test]
    fn optional_payload_round_trip_some_and_none() {
        let mut e = sample();
        let j1 = encode(&e).unwrap();
        let back1 = decode(&j1).unwrap();
        assert_eq!(back1.payload_json,
            Some(r#"{"verdict":"allow"}"#.to_string()));
        e.payload_json = None;
        let j2 = encode(&e).unwrap();
        let back2 = decode(&j2).unwrap();
        assert_eq!(back2.payload_json, None);
    }
}
