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
}
