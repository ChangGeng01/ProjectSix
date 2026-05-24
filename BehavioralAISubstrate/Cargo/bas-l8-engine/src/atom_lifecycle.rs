// SPDX:internal
//
// atom_lifecycle.rs — chapter 八百九十七 / M3175
//
// L8 Rust unification MED-risk migration #2 per
// Docs/L8_RUST_UNIFICATION_RFC.md。 Ports schema 023 +
// `BASSQLiteAtomLifecycleStore` SQL queries to Rust + rusqlite。
// Append-only event log for L8 atom-lifecycle phase transitions
// (Created → Admitted → Linked → Archived → Tombstoned)。
//
// Phase + Action + Outcome are stored as TEXT in SQL (per
// existing schema 023 CHECK constraints) but as i32/u8 in the
// FFI surface (matches Swift's BASAtomLifecycleEvent struct
// shape that uses u8 / i32 codes)。 This module does the
// mapping。

use std::os::raw::{c_char, c_int};
use rusqlite::Connection;
use rusqlite::params;

use crate::L8Engine;

// MARK: - Phase / Action / Outcome ↔ TEXT mapping
//
// Matches bas-atom-lifecycle AtomPhase / AtomAction enums + the
// schema 023 CHECK constraints。

fn phase_byte_to_text(b: u8) -> Option<&'static str> {
    match b {
        0 => Some("created"),
        1 => Some("admitted"),
        2 => Some("linked"),
        3 => Some("archived"),
        4 => Some("tombstoned"),
        _ => None,
    }
}

fn action_byte_to_text(b: u8) -> Option<&'static str> {
    match b {
        0 => Some("admit"),
        1 => Some("link"),
        2 => Some("archive"),
        3 => Some("tombstone"),
        _ => None,
    }
}

fn outcome_int_to_text(i: i32) -> Option<&'static str> {
    match i {
        0 => Some("advanced"),
        1 => Some("rejected_illegal"),
        2 => Some("rejected_terminal"),
        _ => None,
    }
}

// MARK: - Embedded schema

const SCHEMA_023: &str = r#"
CREATE TABLE IF NOT EXISTS atom_lifecycle_events (
    event_id TEXT PRIMARY KEY NOT NULL,
    atom_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    from_phase TEXT NOT NULL CHECK (from_phase IN
        ('created', 'admitted', 'linked', 'archived', 'tombstoned')),
    to_phase TEXT NOT NULL CHECK (to_phase IN
        ('created', 'admitted', 'linked', 'archived', 'tombstoned')),
    action TEXT NOT NULL CHECK (action IN
        ('admit', 'link', 'archive', 'tombstone')),
    outcome TEXT NOT NULL CHECK (outcome IN
        ('advanced', 'rejected_illegal', 'rejected_terminal')),
    recorded_at_ms INTEGER NOT NULL,
    actor_ref TEXT
);
CREATE INDEX IF NOT EXISTS ale_atom_idx
  ON atom_lifecycle_events(atom_id, recorded_at_ms);
CREATE INDEX IF NOT EXISTS ale_session_idx
  ON atom_lifecycle_events(session_id);
CREATE INDEX IF NOT EXISTS ale_phase_idx
  ON atom_lifecycle_events(to_phase);
CREATE INDEX IF NOT EXISTS ale_recorded_at_idx
  ON atom_lifecycle_events(recorded_at_ms);
"#;

// MARK: - Pure-Rust ops

pub fn init_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_023)?;
    Ok(())
}

pub fn append_event(
    conn: &Connection,
    event_id: &str,
    atom_id: &str,
    session_id: &str,
    from_phase_byte: u8,
    to_phase_byte: u8,
    action_byte: u8,
    outcome: i32,
    recorded_at_ms: i64,
    actor_ref: Option<&str>,
) -> rusqlite::Result<()> {
    let from_phase = phase_byte_to_text(from_phase_byte)
        .ok_or_else(|| rusqlite::Error::InvalidParameterName(
            format!("invalid from_phase byte {}", from_phase_byte)))?;
    let to_phase = phase_byte_to_text(to_phase_byte)
        .ok_or_else(|| rusqlite::Error::InvalidParameterName(
            format!("invalid to_phase byte {}", to_phase_byte)))?;
    let action = action_byte_to_text(action_byte)
        .ok_or_else(|| rusqlite::Error::InvalidParameterName(
            format!("invalid action byte {}", action_byte)))?;
    let outcome_text = outcome_int_to_text(outcome)
        .ok_or_else(|| rusqlite::Error::InvalidParameterName(
            format!("invalid outcome {}", outcome)))?;
    conn.execute(
        "INSERT INTO atom_lifecycle_events (
            event_id, atom_id, session_id,
            from_phase, to_phase, action, outcome,
            recorded_at_ms, actor_ref
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        params![
            event_id, atom_id, session_id,
            from_phase, to_phase, action, outcome_text,
            recorded_at_ms, actor_ref,
        ],
    )?;
    Ok(())
}

pub fn count_events(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM atom_lifecycle_events",
        [], |row| row.get(0))
}

pub fn count_events_for_atom(
    conn: &Connection,
    atom_id: &str,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM atom_lifecycle_events
         WHERE atom_id = ?",
        params![atom_id], |row| row.get(0))
}

pub fn count_events_for_session(
    conn: &Connection,
    session_id: &str,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM atom_lifecycle_events
         WHERE session_id = ?",
        params![session_id], |row| row.get(0))
}

// MARK: - chapter 九百三十四 / M3375 — full-row events query
//
// Per USER-PASS finding (ch 933):the ch 897 Swift bridge labeled
// these methods「Full」 in L8_ROUTED_OVERVIEW.md but shipped with
// `return []` stubs。 This module now provides the full-row query
// surface that the bridge was promising。
//
// Output format:JSON array of `BASAtomLifecycleEvent`-shaped
// objects (Codable-compatible)。 TEXT columns mapped back to u8/i32
// codes to match the Swift struct exactly。
//
// FFI pattern:probe + fill (matches `bas_l8_engine_db_path` and
// the chapter 906/909 hot-path consolidation primitives)。

fn phase_text_to_byte(s: &str) -> u8 {
    match s {
        "created" => 0,
        "admitted" => 1,
        "linked" => 2,
        "archived" => 3,
        "tombstoned" => 4,
        _ => 255,
    }
}

fn action_text_to_byte(s: &str) -> u8 {
    match s {
        "admit" => 0,
        "link" => 1,
        "archive" => 2,
        "tombstone" => 3,
        _ => 255,
    }
}

fn outcome_text_to_int(s: &str) -> i32 {
    match s {
        "advanced" => 0,
        "rejected_illegal" => 1,
        "rejected_terminal" => 2,
        _ => -1,
    }
}

/// Serialize a single row as JSON object string。 Uses manual
/// construction (no serde dep) — schema is small + this avoids
/// pulling in additional crate weight for the bas-l8-engine
/// minimal-dep footprint。
fn row_to_json(
    event_id: &str,
    atom_id: &str,
    session_id: &str,
    from_phase: &str,
    to_phase: &str,
    action: &str,
    outcome: &str,
    recorded_at_ms: i64,
    actor_ref: Option<String>,
) -> String {
    // JSON-string-escape helper: escape ", \, and control chars
    // (newline, tab) — minimum-correct for the limited string
    // content this schema produces (UUIDs, enum-like values,
    // human-readable actor refs)。
    fn esc(s: &str) -> String {
        let mut out = String::with_capacity(s.len() + 2);
        for c in s.chars() {
            match c {
                '"' => out.push_str("\\\""),
                '\\' => out.push_str("\\\\"),
                '\n' => out.push_str("\\n"),
                '\t' => out.push_str("\\t"),
                '\r' => out.push_str("\\r"),
                c if (c as u32) < 0x20 => {
                    out.push_str(&format!(
                        "\\u{:04x}", c as u32));
                }
                c => out.push(c),
            }
        }
        out
    }
    let mut out = String::from("{");
    out.push_str(&format!("\"eventID\":\"{}\",", esc(event_id)));
    out.push_str(&format!("\"atomID\":\"{}\",", esc(atom_id)));
    out.push_str(&format!("\"sessionID\":\"{}\",",
        esc(session_id)));
    out.push_str(&format!("\"fromPhaseByte\":{},",
        phase_text_to_byte(from_phase)));
    out.push_str(&format!("\"toPhaseByte\":{},",
        phase_text_to_byte(to_phase)));
    out.push_str(&format!("\"actionByte\":{},",
        action_text_to_byte(action)));
    out.push_str(&format!("\"outcome\":{},",
        outcome_text_to_int(outcome)));
    out.push_str(&format!("\"recordedAtMs\":{}",
        recorded_at_ms));
    match actor_ref {
        Some(ar) => out.push_str(&format!(
            ",\"actorRef\":\"{}\"", esc(&ar))),
        None => out.push_str(",\"actorRef\":null"),
    }
    out.push('}');
    out
}

pub fn events_for_atom_json(
    conn: &Connection,
    atom_id: &str,
) -> rusqlite::Result<String> {
    let mut stmt = conn.prepare(
        "SELECT event_id, atom_id, session_id, from_phase, \
                to_phase, action, outcome, recorded_at_ms, \
                actor_ref \
         FROM atom_lifecycle_events \
         WHERE atom_id = ? \
         ORDER BY recorded_at_ms")?;
    let mut rows = stmt.query(params![atom_id])?;
    let mut out = String::from("[");
    let mut first = true;
    while let Some(row) = rows.next()? {
        if !first { out.push(','); }
        first = false;
        let json = row_to_json(
            &row.get::<_, String>(0)?,
            &row.get::<_, String>(1)?,
            &row.get::<_, String>(2)?,
            &row.get::<_, String>(3)?,
            &row.get::<_, String>(4)?,
            &row.get::<_, String>(5)?,
            &row.get::<_, String>(6)?,
            row.get::<_, i64>(7)?,
            row.get::<_, Option<String>>(8)?,
        );
        out.push_str(&json);
    }
    out.push(']');
    Ok(out)
}

pub fn events_for_session_json(
    conn: &Connection,
    session_id: &str,
) -> rusqlite::Result<String> {
    let mut stmt = conn.prepare(
        "SELECT event_id, atom_id, session_id, from_phase, \
                to_phase, action, outcome, recorded_at_ms, \
                actor_ref \
         FROM atom_lifecycle_events \
         WHERE session_id = ? \
         ORDER BY recorded_at_ms")?;
    let mut rows = stmt.query(params![session_id])?;
    let mut out = String::from("[");
    let mut first = true;
    while let Some(row) = rows.next()? {
        if !first { out.push(','); }
        first = false;
        let json = row_to_json(
            &row.get::<_, String>(0)?,
            &row.get::<_, String>(1)?,
            &row.get::<_, String>(2)?,
            &row.get::<_, String>(3)?,
            &row.get::<_, String>(4)?,
            &row.get::<_, String>(5)?,
            &row.get::<_, String>(6)?,
            row.get::<_, i64>(7)?,
            row.get::<_, Option<String>>(8)?,
        );
        out.push_str(&json);
    }
    out.push(']');
    Ok(out)
}

// MARK: - FFI surface

#[no_mangle]
pub unsafe extern "C" fn bas_l8_atom_lifecycle_init_schema(
    engine: *const L8Engine,
) -> c_int {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match init_schema(conn) {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_atom_lifecycle_append(
    engine: *const L8Engine,
    event_id_utf8: *const c_char, event_id_len: usize,
    atom_id_utf8: *const c_char, atom_id_len: usize,
    session_id_utf8: *const c_char, session_id_len: usize,
    from_phase_byte: u8,
    to_phase_byte: u8,
    action_byte: u8,
    outcome: i32,
    recorded_at_ms: i64,
    actor_ref_utf8: *const c_char, actor_ref_len: usize,
) -> c_int {
    if engine.is_null() { return -1; }
    let event_id = match crate::cstr_to_str(
        event_id_utf8, event_id_len) {
        Some(s) => s, None => return -3,
    };
    let atom_id = match crate::cstr_to_str(
        atom_id_utf8, atom_id_len) {
        Some(s) => s, None => return -3,
    };
    let session_id = match crate::cstr_to_str(
        session_id_utf8, session_id_len) {
        Some(s) => s, None => return -3,
    };
    let actor_ref = if actor_ref_len == 0 {
        None
    } else {
        match crate::cstr_to_str(
            actor_ref_utf8, actor_ref_len) {
            Some(s) => Some(s),
            None => return -3,
        }
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match append_event(
            conn, event_id, atom_id, session_id,
            from_phase_byte, to_phase_byte, action_byte,
            outcome, recorded_at_ms, actor_ref)
        {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_atom_lifecycle_count(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_events(conn).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_atom_lifecycle_count_for_atom(
    engine: *const L8Engine,
    atom_id_utf8: *const c_char, atom_id_len: usize,
) -> i64 {
    if engine.is_null() { return -1; }
    let atom_id = match crate::cstr_to_str(
        atom_id_utf8, atom_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_events_for_atom(conn, atom_id).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_atom_lifecycle_count_for_session(
    engine: *const L8Engine,
    session_id_utf8: *const c_char, session_id_len: usize,
) -> i64 {
    if engine.is_null() { return -1; }
    let session_id = match crate::cstr_to_str(
        session_id_utf8, session_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_events_for_session(conn, session_id).unwrap_or(-2)
    })
}

// chapter 九百三十四 / M3375 — full-row events JSON FFI
//
// USER-PASS finding (ch 933):the ch 897 bridge was labeled「Full」
// in L8_ROUTED_OVERVIEW.md but `events(forAtom:)` and
// `events(forSession:)` shipped `return []` stubs。 This FFI
// surface provides the underlying read path:probe + fill pattern。
//
// Returns:
//   -1 → null engine
//   -3 → null/invalid UTF-8 input
//   -2 → SQLite error
//   ≥0 → if out_buf is null and out_capacity is 0:bytes needed
//        for the JSON output (probe);else bytes written into
//        out_buf (fill,must be ≤ out_capacity)
//
// JSON output is a UTF-8-encoded JSON array of objects matching
// the `BASAtomLifecycleEvent` Codable struct exactly:
//   [{"eventID":"...","atomID":"...","sessionID":"...",
//     "fromPhaseByte":0..4,"toPhaseByte":0..4,"actionByte":0..3,
//     "outcome":0..2,"recordedAtMs":<i64>,
//     "actorRef":"..." | null}, ...]
//
// SAFETY: caller must pass valid UTF-8 pointer + length for
// the lookup key; out_buf must be writable for out_capacity
// bytes if non-null。

unsafe fn events_json_ffi(
    engine: *const L8Engine,
    key_utf8: *const c_char,
    key_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
    by_atom: bool,
) -> i32 {
    if engine.is_null() { return -1; }
    let key = match crate::cstr_to_str(key_utf8, key_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    let json_result = engine_ref.with_conn(|conn| {
        if by_atom {
            events_for_atom_json(conn, key)
        } else {
            events_for_session_json(conn, key)
        }
    });
    let json = match json_result {
        Ok(s) => s,
        Err(_) => return -2,
    };
    let bytes = json.as_bytes();
    let needed = bytes.len();
    // probe call:return required size
    if out_buf.is_null() || out_capacity == 0 {
        return needed as i32;
    }
    // fill call:write up to capacity
    if out_capacity < needed {
        return -3; // caller buffer too small
    }
    unsafe {
        std::ptr::copy_nonoverlapping(
            bytes.as_ptr(), out_buf, needed);
    }
    needed as i32
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_atom_lifecycle_events_for_atom(
    engine: *const L8Engine,
    atom_id_utf8: *const c_char, atom_id_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
) -> i32 {
    events_json_ffi(
        engine, atom_id_utf8, atom_id_len,
        out_buf, out_capacity, true)
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_atom_lifecycle_events_for_session(
    engine: *const L8Engine,
    session_id_utf8: *const c_char, session_id_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
) -> i32 {
    events_json_ffi(
        engine, session_id_utf8, session_id_len,
        out_buf, out_capacity, false)
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{bas_l8_engine_init, bas_l8_engine_close};

    fn make_engine() -> *mut L8Engine {
        unsafe { bas_l8_engine_init(std::ptr::null(), 0) }
    }

    #[test]
    fn init_idempotent() {
        let engine = make_engine();
        let rc1 = unsafe {
            bas_l8_atom_lifecycle_init_schema(engine) };
        assert_eq!(rc1, 0);
        let rc2 = unsafe {
            bas_l8_atom_lifecycle_init_schema(engine) };
        assert_eq!(rc2, 0);
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn append_and_count_round_trip() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_atom_lifecycle_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            append_event(
                conn, "evt-1", "atom-A", "sess-1",
                0, 1, 0, 0,  // created→admitted via admit,advanced
                1_700_000_000_000, Some("reducer")).unwrap();
            append_event(
                conn, "evt-2", "atom-A", "sess-1",
                1, 2, 1, 0,  // admitted→linked via link,advanced
                1_700_000_001_000, None).unwrap();
            assert_eq!(count_events(conn).unwrap(), 2);
            assert_eq!(
                count_events_for_atom(conn, "atom-A").unwrap(), 2);
            assert_eq!(
                count_events_for_atom(conn, "atom-B").unwrap(), 0);
            assert_eq!(
                count_events_for_session(conn, "sess-1").unwrap(), 2);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn invalid_phase_byte_rejected() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_atom_lifecycle_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let r = append_event(
                conn, "evt-X", "atom-X", "sess-X",
                99, 0, 0, 0,  // invalid from_phase
                0, None);
            assert!(r.is_err());
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn ffi_append_round_trip() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_atom_lifecycle_init_schema(engine) };
        let eid = "ffi-evt-1";
        let aid = "ffi-atom-1";
        let sid = "ffi-sess-1";
        let rc = unsafe {
            bas_l8_atom_lifecycle_append(
                engine,
                eid.as_ptr() as *const c_char, eid.len(),
                aid.as_ptr() as *const c_char, aid.len(),
                sid.as_ptr() as *const c_char, sid.len(),
                0, 1, 0, 0,
                1_700_000_000_000,
                std::ptr::null(), 0,
            )
        };
        assert_eq!(rc, 0);
        let count = unsafe {
            bas_l8_atom_lifecycle_count(engine) };
        assert_eq!(count, 1);
        unsafe { bas_l8_engine_close(engine); }
    }

    // chapter 九百三十四 / M3375 — round-trip test for the
    // ch 933 USER-PASS fix。 Verifies events_for_atom_json and
    // events_for_session_json reconstruct the appended events as
    // JSON,with TEXT columns mapped back to u8/i32 codes。
    #[test]
    fn events_for_atom_json_round_trip() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_atom_lifecycle_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            append_event(
                conn, "ev-1", "atom-RT", "sess-RT",
                0, 1, 0, 0,  // created→admitted via admit,advanced
                1_700_000_000_000, Some("reducer")).unwrap();
            append_event(
                conn, "ev-2", "atom-RT", "sess-RT",
                1, 2, 1, 0,  // admitted→linked via link,advanced
                1_700_000_001_000, None).unwrap();
            // forAtom query
            let json = events_for_atom_json(
                conn, "atom-RT").unwrap();
            // Verify shape (manual string checks since no serde)
            assert!(json.starts_with("["));
            assert!(json.ends_with("]"));
            assert!(json.contains("\"eventID\":\"ev-1\""));
            assert!(json.contains("\"eventID\":\"ev-2\""));
            assert!(json.contains("\"fromPhaseByte\":0"));
            assert!(json.contains("\"toPhaseByte\":1"));
            assert!(json.contains("\"toPhaseByte\":2"));
            assert!(json.contains("\"actionByte\":0"));
            assert!(json.contains("\"actionByte\":1"));
            assert!(json.contains("\"outcome\":0"));
            assert!(json.contains("\"recordedAtMs\":1700000000000"));
            assert!(json.contains("\"actorRef\":\"reducer\""));
            assert!(json.contains("\"actorRef\":null"));
            // Order:recorded_at_ms ASC means ev-1 first
            let p1 = json.find("\"eventID\":\"ev-1\"").unwrap();
            let p2 = json.find("\"eventID\":\"ev-2\"").unwrap();
            assert!(p1 < p2, "ev-1 must come before ev-2 by time");
            // Empty atom-id case
            let empty = events_for_atom_json(
                conn, "atom-NONE").unwrap();
            assert_eq!(empty, "[]");
            // forSession query (should include same 2 events)
            let sjson = events_for_session_json(
                conn, "sess-RT").unwrap();
            assert!(sjson.contains("\"eventID\":\"ev-1\""));
            assert!(sjson.contains("\"eventID\":\"ev-2\""));
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    // FFI-layer probe+fill round-trip test
    #[test]
    fn events_for_atom_ffi_probe_fill() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_atom_lifecycle_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            append_event(
                conn, "ffi-ev-1", "ffi-atom-1", "ffi-sess-1",
                0, 1, 0, 0,
                1_700_000_000_000, None).unwrap();
        });
        let aid = "ffi-atom-1";
        // probe call:out_buf=null, out_capacity=0 → returns needed
        let needed = unsafe {
            bas_l8_atom_lifecycle_events_for_atom(
                engine,
                aid.as_ptr() as *const c_char, aid.len(),
                std::ptr::null_mut(), 0,
            )
        };
        assert!(needed > 0, "probe must return positive size");
        // fill call
        let mut buf = vec![0u8; needed as usize];
        let written = unsafe {
            bas_l8_atom_lifecycle_events_for_atom(
                engine,
                aid.as_ptr() as *const c_char, aid.len(),
                buf.as_mut_ptr(), buf.len(),
            )
        };
        assert_eq!(written, needed,
            "fill written must match probe needed");
        let json = std::str::from_utf8(&buf).unwrap();
        assert!(json.contains("\"eventID\":\"ffi-ev-1\""));
        assert!(json.contains("\"actorRef\":null"));
        // small-buffer rejection
        let mut tiny = vec![0u8; 1];
        let rc = unsafe {
            bas_l8_atom_lifecycle_events_for_atom(
                engine,
                aid.as_ptr() as *const c_char, aid.len(),
                tiny.as_mut_ptr(), tiny.len(),
            )
        };
        assert_eq!(rc, -3, "too-small buffer must reject");
        unsafe { bas_l8_engine_close(engine); }
    }

    // JSON escape correctness
    #[test]
    fn events_json_escapes_special_chars() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_atom_lifecycle_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            // actor_ref with quotes + backslash + newline
            append_event(
                conn, "ev-esc", "atom-esc", "sess-esc",
                0, 1, 0, 0,
                1_700_000_000_000,
                Some("actor \"quoted\"\\with\nnewline")).unwrap();
            let json = events_for_atom_json(
                conn, "atom-esc").unwrap();
            // Verify the escape sequences are present
            assert!(json.contains("\\\""));
            assert!(json.contains("\\\\"));
            assert!(json.contains("\\n"));
            // And that the JSON is still parseable structure
            assert!(json.starts_with("["));
            assert!(json.ends_with("]"));
        });
        unsafe { bas_l8_engine_close(engine); }
    }
}
