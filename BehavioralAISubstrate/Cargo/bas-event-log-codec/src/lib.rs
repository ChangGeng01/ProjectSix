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

// chapter 七百四十四 第一刀 / M2391 — L3 Knowledge Graph
// storage codec port。 Adds knowledge_graph_codec module to
// this crate so the existing bas-event-log-codec staticlib
// (already wired to BASRustMemoryTrackerBinary) gains the
// L3 node/edge encode+decode primitives without a new crate。
pub mod knowledge_graph_codec;

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

// MARK: - chapter 七百二十四 第一刀 / M2291
//         Binary wire format (replaces JSON for highest-traffic
//         BASSQLiteEventLogStorage.append path)
//
// Wire layout (single entry):
//
//   [u8  schema_version]   (PAYLOAD_FORMAT_BINARY_V2 = 2)
//   [u8  kind_discriminant] (0..=6 matching EventKind order)
//   [u32 le entry_id_len][entry_id bytes]
//   [u32 le session_ref_len][session_ref bytes]
//   [u32 le turn_ref_len][turn_ref bytes]
//   [i64 le timestamp_ms]
//   [u8  payload_present (0/1)]
//     if present:
//       [u32 le payload_len][payload bytes]
//   [u8  provenance_present (0/1)]
//     if present:
//       [u32 le provenance_len][provenance bytes]
//
// Why little-endian:matches the substrate's Apple Silicon target
// (aarch64-le)。 If the substrate ever ships an architecture with
// a different endianness the schema-version field acts as the
// migration switch — bump to v3 and add a different layout。
//
// Why chunked encode entrypoint:`encode_batch_binary` returns one
// contiguous Vec<u8> framed with [u32 count][entry_1][entry_2]...
// Hosts append multiple events in a single SQLite write without
// re-encoding each one individually。

pub const PAYLOAD_FORMAT_JSON_V1:   u8 = 1;
pub const PAYLOAD_FORMAT_BINARY_V2: u8 = 2;

fn kind_to_u8(k: EventKind) -> u8 {
    match k {
        EventKind::InternalSignal     => 0,
        EventKind::HostInput          => 1,
        EventKind::SovereignVerdict   => 2,
        EventKind::PermitChange       => 3,
        EventKind::ObservationBundle  => 4,
        EventKind::ProvenanceMark     => 5,
        EventKind::ReplayMark         => 6,
    }
}

fn kind_from_u8(b: u8) -> Option<EventKind> {
    match b {
        0 => Some(EventKind::InternalSignal),
        1 => Some(EventKind::HostInput),
        2 => Some(EventKind::SovereignVerdict),
        3 => Some(EventKind::PermitChange),
        4 => Some(EventKind::ObservationBundle),
        5 => Some(EventKind::ProvenanceMark),
        6 => Some(EventKind::ReplayMark),
        _ => None,
    }
}

fn append_u32_le(buf: &mut Vec<u8>, v: u32) {
    buf.extend_from_slice(&v.to_le_bytes());
}

fn append_i64_le(buf: &mut Vec<u8>, v: i64) {
    buf.extend_from_slice(&v.to_le_bytes());
}

fn append_lenprefixed(buf: &mut Vec<u8>, s: &str) {
    let bytes = s.as_bytes();
    append_u32_le(buf, bytes.len() as u32);
    buf.extend_from_slice(bytes);
}

fn read_u32_le(buf: &[u8], pos: &mut usize) -> Option<u32> {
    if *pos + 4 > buf.len() { return None; }
    let v = u32::from_le_bytes([
        buf[*pos], buf[*pos+1], buf[*pos+2], buf[*pos+3]]);
    *pos += 4;
    Some(v)
}

fn read_i64_le(buf: &[u8], pos: &mut usize) -> Option<i64> {
    if *pos + 8 > buf.len() { return None; }
    let v = i64::from_le_bytes([
        buf[*pos],   buf[*pos+1], buf[*pos+2], buf[*pos+3],
        buf[*pos+4], buf[*pos+5], buf[*pos+6], buf[*pos+7]]);
    *pos += 8;
    Some(v)
}

fn read_lenprefixed_string(
    buf: &[u8], pos: &mut usize,
) -> Option<String> {
    let len = read_u32_le(buf, pos)? as usize;
    if *pos + len > buf.len() { return None; }
    let s = core::str::from_utf8(
        &buf[*pos..*pos + len]).ok()?.to_string();
    *pos += len;
    Some(s)
}

/// Encode `entry` to a compact binary buffer。 Deterministic —
/// same entry produces same bytes (replay-determinism preserved
/// across JSON-v1 → binary-v2 migration)。
pub fn encode_binary(entry: &EventLogEntry) -> Vec<u8> {
    let mut out: Vec<u8> = Vec::with_capacity(64);
    out.push(PAYLOAD_FORMAT_BINARY_V2);
    out.push(kind_to_u8(entry.kind));
    append_lenprefixed(&mut out, &entry.entry_id);
    append_lenprefixed(&mut out, &entry.session_ref);
    append_lenprefixed(&mut out, &entry.turn_ref);
    append_i64_le(&mut out, entry.timestamp_ms);
    if let Some(ref payload) = entry.payload_json {
        out.push(1);
        append_lenprefixed(&mut out, payload);
    } else {
        out.push(0);
    }
    if let Some(ref prov) = entry.provenance_summary {
        out.push(1);
        append_lenprefixed(&mut out, prov);
    } else {
        out.push(0);
    }
    out
}

/// Decode a binary entry。 First byte must be
/// `PAYLOAD_FORMAT_BINARY_V2`。
pub fn decode_binary(buf: &[u8]) -> Result<EventLogEntry, String> {
    if buf.is_empty() {
        return Err("empty buffer".to_string());
    }
    if buf[0] != PAYLOAD_FORMAT_BINARY_V2 {
        return Err(format!(
            "expected schema version {}, got {}",
            PAYLOAD_FORMAT_BINARY_V2, buf[0]));
    }
    let mut pos = 1usize;
    if pos >= buf.len() {
        return Err("missing kind byte".to_string());
    }
    let kind = kind_from_u8(buf[pos])
        .ok_or_else(|| format!(
            "unknown kind byte {}", buf[pos]))?;
    pos += 1;
    let entry_id = read_lenprefixed_string(buf, &mut pos)
        .ok_or_else(|| "entry_id read failed".to_string())?;
    let session_ref = read_lenprefixed_string(buf, &mut pos)
        .ok_or_else(|| "session_ref read failed".to_string())?;
    let turn_ref = read_lenprefixed_string(buf, &mut pos)
        .ok_or_else(|| "turn_ref read failed".to_string())?;
    let timestamp_ms = read_i64_le(buf, &mut pos)
        .ok_or_else(|| "timestamp read failed".to_string())?;
    if pos >= buf.len() {
        return Err("missing payload_present flag".to_string());
    }
    let payload_json = match buf[pos] {
        0 => { pos += 1; None }
        1 => {
            pos += 1;
            Some(read_lenprefixed_string(buf, &mut pos)
                .ok_or_else(|| "payload read failed".to_string())?)
        }
        b => return Err(format!(
            "invalid payload flag {}", b)),
    };
    if pos >= buf.len() {
        return Err("missing provenance_present flag".to_string());
    }
    let provenance_summary = match buf[pos] {
        0 => { pos += 1; None }
        1 => {
            pos += 1;
            Some(read_lenprefixed_string(buf, &mut pos)
                .ok_or_else(|| "provenance read failed".to_string())?)
        }
        b => return Err(format!(
            "invalid provenance flag {}", b)),
    };
    Ok(EventLogEntry {
        entry_id, kind, session_ref, turn_ref, timestamp_ms,
        payload_json, provenance_summary,
    })
}

/// Encode a batch of entries as `[u32 le count][entry_1]...
/// [entry_n]`。 Each entry's own schema-version byte still leads
/// its slice so per-entry decode works on the slice。
pub fn encode_batch_binary(
    entries: &[EventLogEntry],
) -> Vec<u8> {
    let mut out: Vec<u8> = Vec::with_capacity(
        4 + entries.len() * 64);
    append_u32_le(&mut out, entries.len() as u32);
    for e in entries {
        let encoded = encode_binary(e);
        append_u32_le(&mut out, encoded.len() as u32);
        out.extend_from_slice(&encoded);
    }
    out
}

// MARK: - chapter 七百二十四 第二刀 / M2292
//         C ABI for binary encode (decode happens Swift-side
//         since the format is trivial to walk)
//
// Two-phase like the BPE / importance scorer FFIs:
//   - First call with out_capacity=0 returns required size
//   - Second call with sized buffer fills

/// Encode one event log entry into binary wire format。
///
/// Returns:
///   ≥ 0 = number of OUTPUT BYTES needed (whether or not the
///         out_buf was filled — caller realloc + retry if
///         needed > out_capacity)
///   -1  = null pointer (only flagged when the corresponding
///         length is non-zero,or out_buf null with non-zero
///         capacity)
///   -2  = invalid UTF-8 in any of the string fields
///
/// # Safety
/// Caller must provide readable buffers of declared lengths and
/// a writable `out_buf` of at least `out_capacity` bytes (or
/// null when out_capacity == 0)。
#[no_mangle]
pub unsafe extern "C" fn bas_event_log_encode_binary(
    kind: u8,
    entry_id: *const u8,
    entry_id_len: usize,
    session_ref: *const u8,
    session_ref_len: usize,
    turn_ref: *const u8,
    turn_ref_len: usize,
    timestamp_ms: i64,
    payload_present: u8,
    payload: *const u8,
    payload_len: usize,
    provenance_present: u8,
    provenance: *const u8,
    provenance_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
) -> i64 {
    if out_capacity > 0 && out_buf.is_null() {
        return -1;
    }
    let kind = match kind_from_u8(kind) {
        Some(k) => k,
        None => return -2,
    };

    fn read_str(
        buf: *const u8, len: usize,
    ) -> Result<String, ()> {
        if len == 0 {
            return Ok(String::new());
        }
        if buf.is_null() {
            return Err(());
        }
        let slice = unsafe {
            core::slice::from_raw_parts(buf, len)
        };
        core::str::from_utf8(slice)
            .map(|s| s.to_string())
            .map_err(|_| ())
    }

    let entry_id_s = match read_str(entry_id, entry_id_len) {
        Ok(s) => s,
        Err(_) => return -2,
    };
    let session_ref_s = match read_str(
        session_ref, session_ref_len)
    {
        Ok(s) => s,
        Err(_) => return -2,
    };
    let turn_ref_s = match read_str(turn_ref, turn_ref_len) {
        Ok(s) => s,
        Err(_) => return -2,
    };
    let payload_json = if payload_present != 0 {
        match read_str(payload, payload_len) {
            Ok(s) => Some(s),
            Err(_) => return -2,
        }
    } else {
        None
    };
    let provenance_summary = if provenance_present != 0 {
        match read_str(provenance, provenance_len) {
            Ok(s) => Some(s),
            Err(_) => return -2,
        }
    } else {
        None
    };

    let entry = EventLogEntry {
        entry_id: entry_id_s,
        kind,
        session_ref: session_ref_s,
        turn_ref: turn_ref_s,
        timestamp_ms,
        payload_json,
        provenance_summary,
    };
    let bytes = encode_binary(&entry);
    let needed = bytes.len();
    if out_capacity > 0 && needed > 0 {
        let copy_n = core::cmp::min(needed, out_capacity);
        let dst = unsafe {
            core::slice::from_raw_parts_mut(out_buf, copy_n)
        };
        dst.copy_from_slice(&bytes[..copy_n]);
    }
    needed as i64
}

pub fn decode_batch_binary(
    buf: &[u8],
) -> Result<Vec<EventLogEntry>, String> {
    let mut pos = 0usize;
    let count = read_u32_le(buf, &mut pos)
        .ok_or_else(|| "count read failed".to_string())?
        as usize;
    let mut out: Vec<EventLogEntry> =
        Vec::with_capacity(count);
    for _ in 0..count {
        let entry_len = read_u32_le(buf, &mut pos)
            .ok_or_else(|| "entry length read failed".to_string())?
            as usize;
        if pos + entry_len > buf.len() {
            return Err("entry buffer underrun".to_string());
        }
        let entry = decode_binary(&buf[pos..pos + entry_len])?;
        pos += entry_len;
        out.push(entry);
    }
    Ok(out)
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

    // MARK: - chapter 七百二十四 第一刀 binary wire format tests

    #[test]
    fn binary_round_trip_with_full_payload() {
        let e = sample();
        let bytes = encode_binary(&e);
        assert_eq!(bytes[0], PAYLOAD_FORMAT_BINARY_V2);
        let back = decode_binary(&bytes).unwrap();
        assert_eq!(e, back);
    }

    #[test]
    fn binary_round_trip_with_none_payload() {
        let mut e = sample();
        e.payload_json = None;
        e.provenance_summary = None;
        let bytes = encode_binary(&e);
        let back = decode_binary(&bytes).unwrap();
        assert_eq!(e, back);
    }

    #[test]
    fn binary_encoding_is_deterministic() {
        let e = sample();
        let b1 = encode_binary(&e);
        let b2 = encode_binary(&e);
        let b3 = encode_binary(&e);
        assert_eq!(b1, b2);
        assert_eq!(b2, b3);
    }

    #[test]
    fn binary_is_more_compact_than_json() {
        let e = sample();
        let json_size = encode(&e).unwrap().len();
        let bin_size = encode_binary(&e).len();
        assert!(
            bin_size < json_size,
            "binary ({}) should be smaller than JSON ({})",
            bin_size, json_size);
    }

    #[test]
    fn binary_rejects_wrong_schema_version() {
        let mut bytes = encode_binary(&sample());
        bytes[0] = PAYLOAD_FORMAT_JSON_V1;
        let err = decode_binary(&bytes);
        assert!(err.is_err());
    }

    #[test]
    fn binary_rejects_invalid_kind_byte() {
        let mut bytes = encode_binary(&sample());
        bytes[1] = 99;  // not a valid kind discriminator
        let err = decode_binary(&bytes);
        assert!(err.is_err());
    }

    #[test]
    fn binary_rejects_truncated_buffer() {
        let bytes = encode_binary(&sample());
        let truncated = &bytes[..bytes.len() - 4];
        let err = decode_binary(truncated);
        assert!(err.is_err());
    }

    #[test]
    fn binary_batch_round_trip() {
        let entries = vec![
            sample(),
            EventLogEntry::new(
                "entry-002",
                EventKind::HostInput,
                "session-A", "turn-1", 1_700_000_001_000),
            EventLogEntry::new(
                "entry-003",
                EventKind::ReplayMark,
                "session-B", "turn-99", 1_700_000_002_000)
                .with_payload(r#"{"mark":"end"}"#.to_string()),
        ];
        let bytes = encode_batch_binary(&entries);
        let back = decode_batch_binary(&bytes).unwrap();
        assert_eq!(entries, back);
    }

    #[test]
    fn binary_batch_empty_round_trip() {
        let entries: Vec<EventLogEntry> = vec![];
        let bytes = encode_batch_binary(&entries);
        let back = decode_batch_binary(&bytes).unwrap();
        assert_eq!(entries, back);
    }

    #[test]
    fn binary_all_kind_discriminants_round_trip() {
        let kinds = [
            EventKind::InternalSignal,
            EventKind::HostInput,
            EventKind::SovereignVerdict,
            EventKind::PermitChange,
            EventKind::ObservationBundle,
            EventKind::ProvenanceMark,
            EventKind::ReplayMark,
        ];
        for k in kinds {
            let e = EventLogEntry::new(
                "id", k, "s", "t", 0);
            let back = decode_binary(
                &encode_binary(&e)).unwrap();
            assert_eq!(e, back);
        }
    }
}
