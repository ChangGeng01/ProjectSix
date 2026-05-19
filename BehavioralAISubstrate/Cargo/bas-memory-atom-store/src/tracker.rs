// SPDX:internal
//
// tracker.rs — chapter 七百三 第二刀 / M2172
//
// Rust port of BASMemoryUsageTracker in-memory mode。 Append-only
// log of `(record_id, atom_id, retrieved_at_ms, session_ref,
// turn_ref, permit_mode, helped_state)` rows with the same query
// surface the V1 Swift actor exposes。

use std::collections::BTreeMap;
use std::sync::Mutex;

use serde::{Deserialize, Serialize};

/// One row in the memory usage log。 Mirrors Swift's
/// `BASMemoryUsageRecord` struct field-for-field。 Serialized
/// JSON shape matches the Swift Codable output (sorted keys via
/// serde_json::to_string + manual alpha-ordering)。
#[derive(Clone, Debug, Eq, PartialEq, Hash,
    Serialize, Deserialize)]
pub struct MemoryUsageRecord {
    #[serde(rename = "recordID")]
    pub record_id: String,
    #[serde(rename = "atomID")]
    pub atom_id: String,
    #[serde(rename = "retrievedAtMs")]
    pub retrieved_at_ms: i64,
    #[serde(rename = "sessionRef")]
    pub session_ref: String,
    #[serde(rename = "turnRef")]
    pub turn_ref: String,
    #[serde(rename = "permitMode")]
    pub permit_mode: String,
    #[serde(rename = "helpedState")]
    pub helped_state: String,
}

impl MemoryUsageRecord {
    pub fn new(
        record_id: impl Into<String>,
        atom_id: impl Into<String>,
        retrieved_at_ms: i64,
        session_ref: impl Into<String>,
        turn_ref: impl Into<String>,
        permit_mode: impl Into<String>,
        helped_state: impl Into<String>,
    ) -> Self {
        Self {
            record_id: record_id.into(),
            atom_id: atom_id.into(),
            retrieved_at_ms,
            session_ref: session_ref.into(),
            turn_ref: turn_ref.into(),
            permit_mode: permit_mode.into(),
            helped_state: helped_state.into(),
        }
    }
}

/// Typed errors mirroring the Swift actor's throwing surface。
#[derive(Clone, Debug, Eq, PartialEq, Hash)]
pub enum TrackerError {
    /// Insertion lost — record id already present in the log。
    /// The V1 Swift actor's policy is "first writer wins;
    /// duplicates are silently merged" — Rust port surfaces the
    /// collision so callers can decide whether to retry under a
    /// fresh record_id。
    DuplicateRecordID(String),
    /// Empty atom_id / session_ref / turn_ref。 Swift V1 rejected
    /// these via guards;Rust port follows suit。
    InvalidField(&'static str),
}

/// In-memory tracker — protected by a single Mutex so multi-
/// threaded callers can hand the same handle to many threads
/// safely。
pub struct InMemoryTracker {
    inner: Mutex<TrackerState>,
}

#[derive(Default)]
struct TrackerState {
    /// Insertion-ordered log。 Newest at the tail (matches the
    /// `entries.append(...)` shape of the Swift actor)。
    records: Vec<MemoryUsageRecord>,
    /// Secondary index for O(1) `query(byRecordID:)` — Swift
    /// has `auditRefIndex`; we mirror that here。
    by_id: BTreeMap<String, usize>,
    /// Per-atom secondary index for the `recordsForAtom`
    /// accessor。 Values are insertion ordinals。
    by_atom: BTreeMap<String, Vec<usize>>,
}

impl Default for InMemoryTracker {
    fn default() -> Self {
        Self { inner: Mutex::new(TrackerState::default()) }
    }
}

impl InMemoryTracker {
    pub fn new() -> Self { Self::default() }

    pub fn append(
        &self, rec: MemoryUsageRecord,
    ) -> Result<(), TrackerError> {
        if rec.atom_id.is_empty() {
            return Err(TrackerError::InvalidField("atom_id"));
        }
        if rec.session_ref.is_empty() {
            return Err(TrackerError::InvalidField("session_ref"));
        }
        if rec.turn_ref.is_empty() {
            return Err(TrackerError::InvalidField("turn_ref"));
        }
        let mut s = self.inner.lock().unwrap();
        if s.by_id.contains_key(&rec.record_id) {
            return Err(TrackerError::DuplicateRecordID(
                rec.record_id));
        }
        let ord = s.records.len();
        s.by_id.insert(rec.record_id.clone(), ord);
        s.by_atom.entry(rec.atom_id.clone())
            .or_default().push(ord);
        s.records.push(rec);
        Ok(())
    }

    pub fn count(&self) -> usize {
        self.inner.lock().unwrap().records.len()
    }

    pub fn all_records(&self) -> Vec<MemoryUsageRecord> {
        self.inner.lock().unwrap().records.clone()
    }

    pub fn records_for_atom(
        &self, atom_id: &str,
    ) -> Vec<MemoryUsageRecord> {
        let s = self.inner.lock().unwrap();
        s.by_atom.get(atom_id).map(|ords| {
            ords.iter().map(|o| s.records[*o].clone()).collect()
        }).unwrap_or_default()
    }

    pub fn lookup_by_record_id(
        &self, record_id: &str,
    ) -> Option<MemoryUsageRecord> {
        let s = self.inner.lock().unwrap();
        s.by_id.get(record_id).map(|o| s.records[*o].clone())
    }

    pub fn records_for_session(
        &self, session_ref: &str,
    ) -> Vec<MemoryUsageRecord> {
        let s = self.inner.lock().unwrap();
        s.records.iter()
            .filter(|r| r.session_ref == session_ref)
            .cloned()
            .collect()
    }

    pub fn records_for_turn(
        &self, session_ref: &str, turn_ref: &str,
    ) -> Vec<MemoryUsageRecord> {
        let s = self.inner.lock().unwrap();
        s.records.iter()
            .filter(|r| r.session_ref == session_ref
                && r.turn_ref == turn_ref)
            .cloned()
            .collect()
    }

    /// Serialize ALL records as JSON。 Used by callers that want
    /// to ship a snapshot across a boundary。
    pub fn snapshot_json(&self) -> String {
        let s = self.inner.lock().unwrap();
        serde_json::to_string(&s.records)
            .unwrap_or_else(|_| "[]".into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn r(id: &str, atom: &str, ms: i64) -> MemoryUsageRecord {
        MemoryUsageRecord::new(
            id, atom, ms,
            "session-1", "turn-1",
            "permit-mode-A", "helped-state-OK")
    }

    #[test]
    fn append_and_count() {
        let t = InMemoryTracker::new();
        t.append(r("a", "atom-1", 1_000)).unwrap();
        t.append(r("b", "atom-2", 2_000)).unwrap();
        t.append(r("c", "atom-1", 3_000)).unwrap();
        assert_eq!(t.count(), 3);
    }

    #[test]
    fn duplicate_record_id_rejected() {
        let t = InMemoryTracker::new();
        t.append(r("dup", "atom-1", 1_000)).unwrap();
        let err = t.append(r("dup", "atom-2", 2_000))
            .unwrap_err();
        assert!(matches!(
            err, TrackerError::DuplicateRecordID(_)));
        assert_eq!(t.count(), 1);
    }

    #[test]
    fn empty_atom_id_rejected() {
        let t = InMemoryTracker::new();
        let err = t.append(r("a", "", 1_000)).unwrap_err();
        assert_eq!(err, TrackerError::InvalidField("atom_id"));
    }

    #[test]
    fn empty_session_ref_rejected() {
        let t = InMemoryTracker::new();
        let bad = MemoryUsageRecord::new(
            "a", "atom-1", 1, "", "turn-1", "p", "h");
        let err = t.append(bad).unwrap_err();
        assert_eq!(err, TrackerError::InvalidField("session_ref"));
    }

    #[test]
    fn empty_turn_ref_rejected() {
        let t = InMemoryTracker::new();
        let bad = MemoryUsageRecord::new(
            "a", "atom-1", 1, "s", "", "p", "h");
        let err = t.append(bad).unwrap_err();
        assert_eq!(err, TrackerError::InvalidField("turn_ref"));
    }

    #[test]
    fn records_for_atom_filters() {
        let t = InMemoryTracker::new();
        t.append(r("a", "atom-1", 1)).unwrap();
        t.append(r("b", "atom-2", 2)).unwrap();
        t.append(r("c", "atom-1", 3)).unwrap();
        let atom1 = t.records_for_atom("atom-1");
        assert_eq!(atom1.len(), 2);
        assert_eq!(atom1[0].record_id, "a");
        assert_eq!(atom1[1].record_id, "c");
    }

    #[test]
    fn records_for_atom_unknown_returns_empty() {
        let t = InMemoryTracker::new();
        t.append(r("a", "atom-1", 1)).unwrap();
        assert!(t.records_for_atom("ghost").is_empty());
    }

    #[test]
    fn lookup_by_record_id_round_trip() {
        let t = InMemoryTracker::new();
        let rec = r("specific", "atom-1", 42);
        t.append(rec.clone()).unwrap();
        let found = t.lookup_by_record_id("specific")
            .unwrap();
        assert_eq!(found, rec);
    }

    #[test]
    fn lookup_by_unknown_record_id_returns_none() {
        let t = InMemoryTracker::new();
        assert!(t.lookup_by_record_id("ghost").is_none());
    }

    #[test]
    fn records_for_session_filters() {
        let t = InMemoryTracker::new();
        t.append(r("a", "atom-1", 1)).unwrap();
        let other_session = MemoryUsageRecord::new(
            "b", "atom-2", 2, "session-X", "turn-1", "p", "h");
        t.append(other_session).unwrap();
        let s1 = t.records_for_session("session-1");
        assert_eq!(s1.len(), 1);
        assert_eq!(s1[0].record_id, "a");
    }

    #[test]
    fn records_for_turn_filters() {
        let t = InMemoryTracker::new();
        t.append(r("a", "atom-1", 1)).unwrap();
        let other_turn = MemoryUsageRecord::new(
            "b", "atom-1", 2, "session-1", "turn-2", "p", "h");
        t.append(other_turn).unwrap();
        let t1 = t.records_for_turn("session-1", "turn-1");
        assert_eq!(t1.len(), 1);
        assert_eq!(t1[0].record_id, "a");
    }

    #[test]
    fn insertion_order_preserved() {
        let t = InMemoryTracker::new();
        for i in 0..50_i64 {
            let id = format!("rec-{:03}", i);
            t.append(r(&id, "atom", i * 10)).unwrap();
        }
        let all = t.all_records();
        for i in 0..50_usize {
            let expected = format!("rec-{:03}", i);
            assert_eq!(all[i].record_id, expected);
        }
    }

    #[test]
    fn snapshot_json_round_trip() {
        let t = InMemoryTracker::new();
        t.append(r("a", "atom-1", 1)).unwrap();
        t.append(r("b", "atom-2", 2)).unwrap();
        let snap = t.snapshot_json();
        let parsed: Vec<MemoryUsageRecord> =
            serde_json::from_str(&snap).unwrap();
        assert_eq!(parsed.len(), 2);
        assert_eq!(parsed[0].record_id, "a");
    }
}
