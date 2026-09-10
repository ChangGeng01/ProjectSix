// SPDX:internal
//
// memory_usage_logs.rs — chapter 九百二.5 / M3205
//
// L8 unification HIGH-risk migration #2 sub-chapter 2 per RFC。
// Ports the 2 sibling append-only Codable log tables of
// BASMemoryUsageTracker:
//
//   - memory_usage_replay_log (BASReplayLogEntry)
//   - memory_usage_audit_log  (BASAuditLogEntry)
//
// Both are pure append-only INSERT (Swift never UPSERTs or
// UPDATEs these — fresh UUIDs minted per entry,no dup paths)。
// Schemas have a PK on the id column,so duplicate id =
// SQLite UNIQUE constraint error → propagated up as -2 per
// the standard FFI convention。
//
// # Schemas (byte-equality preserved from chapter 二百四十八)
//
//   CREATE TABLE memory_usage_replay_log (
//     event_id TEXT PRIMARY KEY NOT NULL,
//     event_type TEXT NOT NULL,
//     payload TEXT NOT NULL,
//     recorded_at_ms INTEGER NOT NULL
//   );
//   CREATE INDEX memory_usage_replay_log_time_idx
//     ON memory_usage_replay_log(recorded_at_ms);
//
//   CREATE TABLE memory_usage_audit_log (
//     entry_id TEXT PRIMARY KEY NOT NULL,
//     actor TEXT NOT NULL,
//     action TEXT NOT NULL,
//     detail TEXT NOT NULL,
//     recorded_at_ms INTEGER NOT NULL
//   );
//   CREATE INDEX memory_usage_audit_log_time_idx
//     ON memory_usage_audit_log(recorded_at_ms);

use std::os::raw::{c_char, c_int};
use rusqlite::Connection;
use rusqlite::params;

use crate::L8Engine;

const SCHEMA_REPLAY_LOG: &str = r#"
CREATE TABLE IF NOT EXISTS memory_usage_replay_log (
    event_id TEXT PRIMARY KEY NOT NULL,
    event_type TEXT NOT NULL,
    payload TEXT NOT NULL,
    recorded_at_ms INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS memory_usage_replay_log_time_idx
  ON memory_usage_replay_log(recorded_at_ms);
"#;

const SCHEMA_AUDIT_LOG: &str = r#"
CREATE TABLE IF NOT EXISTS memory_usage_audit_log (
    entry_id TEXT PRIMARY KEY NOT NULL,
    actor TEXT NOT NULL,
    action TEXT NOT NULL,
    detail TEXT NOT NULL,
    recorded_at_ms INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS memory_usage_audit_log_time_idx
  ON memory_usage_audit_log(recorded_at_ms);
"#;

pub fn init_replay_log_schema(
    conn: &Connection,
) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_REPLAY_LOG)?;
    Ok(())
}

pub fn init_audit_log_schema(
    conn: &Connection,
) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_AUDIT_LOG)?;
    Ok(())
}

// MARK: - Replay log

pub fn append_replay_log(
    conn: &Connection,
    event_id: &str,
    event_type: &str,
    payload: &str,
    recorded_at_ms: i64,
) -> rusqlite::Result<()> {
    conn.execute(
        "INSERT INTO memory_usage_replay_log (
            event_id, event_type, payload, recorded_at_ms
         ) VALUES (?, ?, ?, ?)",
        params![event_id, event_type, payload, recorded_at_ms],
    )?;
    Ok(())
}

pub fn count_replay_log(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM memory_usage_replay_log",
        [], |row| row.get(0))
}

/// Returns the most-recent replay log entry's recorded_at_ms
/// for ordering verification, or -1 if no entries。 Tests use
/// this to confirm ORDER BY recorded_at_ms DESC parity with
/// Swift's `replayLogEntriesViaSQL` ASC sort。
pub fn latest_replay_log_time(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    let r: Option<i64> = conn.query_row(
        "SELECT recorded_at_ms FROM memory_usage_replay_log
         ORDER BY recorded_at_ms DESC LIMIT 1",
        [], |row| row.get(0)
    ).ok();
    Ok(r.unwrap_or(-1))
}

// MARK: - Audit log

pub fn append_audit_log(
    conn: &Connection,
    entry_id: &str,
    actor: &str,
    action: &str,
    detail: &str,
    recorded_at_ms: i64,
) -> rusqlite::Result<()> {
    conn.execute(
        "INSERT INTO memory_usage_audit_log (
            entry_id, actor, action, detail, recorded_at_ms
         ) VALUES (?, ?, ?, ?, ?)",
        params![entry_id, actor, action, detail, recorded_at_ms],
    )?;
    Ok(())
}

pub fn count_audit_log(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM memory_usage_audit_log",
        [], |row| row.get(0))
}

pub fn latest_audit_log_time(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    let r: Option<i64> = conn.query_row(
        "SELECT recorded_at_ms FROM memory_usage_audit_log
         ORDER BY recorded_at_ms DESC LIMIT 1",
        [], |row| row.get(0)
    ).ok();
    Ok(r.unwrap_or(-1))
}

// MARK: - FFI: replay log

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_replay_log_init_schema(
    engine: *const L8Engine,
) -> c_int {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match init_replay_log_schema(conn) {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_replay_log_append(
    engine: *const L8Engine,
    event_id_utf8: *const c_char, event_id_len: usize,
    event_type_utf8: *const c_char, event_type_len: usize,
    payload_utf8: *const c_char, payload_len: usize,
    recorded_at_ms: i64,
) -> c_int {
    if engine.is_null() { return -1; }
    let event_id = match crate::cstr_to_str(
        event_id_utf8, event_id_len) {
        Some(s) => s, None => return -3,
    };
    let event_type = match crate::cstr_to_str(
        event_type_utf8, event_type_len) {
        Some(s) => s, None => return -3,
    };
    let payload = match crate::cstr_to_str(
        payload_utf8, payload_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match append_replay_log(
            conn, event_id, event_type, payload,
            recorded_at_ms)
        {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_replay_log_count(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_replay_log(conn).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_replay_log_latest_time(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        latest_replay_log_time(conn).unwrap_or(-1)
    })
}

// MARK: - FFI: audit log

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_audit_log_init_schema(
    engine: *const L8Engine,
) -> c_int {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match init_audit_log_schema(conn) {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_audit_log_append(
    engine: *const L8Engine,
    entry_id_utf8: *const c_char, entry_id_len: usize,
    actor_utf8: *const c_char, actor_len: usize,
    action_utf8: *const c_char, action_len: usize,
    detail_utf8: *const c_char, detail_len: usize,
    recorded_at_ms: i64,
) -> c_int {
    if engine.is_null() { return -1; }
    let entry_id = match crate::cstr_to_str(
        entry_id_utf8, entry_id_len) {
        Some(s) => s, None => return -3,
    };
    let actor = match crate::cstr_to_str(
        actor_utf8, actor_len) {
        Some(s) => s, None => return -3,
    };
    let action = match crate::cstr_to_str(
        action_utf8, action_len) {
        Some(s) => s, None => return -3,
    };
    let detail = match crate::cstr_to_str(
        detail_utf8, detail_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match append_audit_log(
            conn, entry_id, actor, action, detail,
            recorded_at_ms)
        {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_audit_log_count(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_audit_log(conn).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_audit_log_latest_time(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        latest_audit_log_time(conn).unwrap_or(-1)
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{bas_l8_engine_init, bas_l8_engine_close};

    fn make_engine() -> *mut L8Engine {
        unsafe { bas_l8_engine_init(std::ptr::null(), 0) }
    }

    #[test]
    fn replay_log_append_count_and_latest_time() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_replay_log_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            append_replay_log(conn, "e1", "txt",
                "p1", 100).unwrap();
            append_replay_log(conn, "e2", "act",
                "p2", 500).unwrap();
            append_replay_log(conn, "e3", "txt",
                "p3", 300).unwrap();
            assert_eq!(count_replay_log(conn).unwrap(), 3);
            assert_eq!(latest_replay_log_time(conn).unwrap(),
                500, "DESC ordering finds max ts");
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn replay_log_duplicate_event_id_is_sqlite_error() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_replay_log_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            append_replay_log(conn, "dup-e", "t",
                "p", 100).unwrap();
            let err = append_replay_log(conn, "dup-e", "t2",
                "p2", 200);
            assert!(err.is_err(),
                "Duplicate event_id must hit UNIQUE constraint");
            assert_eq!(count_replay_log(conn).unwrap(), 1);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn audit_log_append_count_and_latest_time() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_audit_log_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            append_audit_log(conn, "a1", "actor1",
                "view", "d1", 100).unwrap();
            append_audit_log(conn, "a2", "actor2",
                "edit", "d2", 400).unwrap();
            append_audit_log(conn, "a3", "actor3",
                "view", "d3", 250).unwrap();
            assert_eq!(count_audit_log(conn).unwrap(), 3);
            assert_eq!(latest_audit_log_time(conn).unwrap(),
                400);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn replay_and_audit_logs_are_independent_tables() {
        // Schemas don't share table names — counts must be
        // independent。
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_replay_log_init_schema(engine) };
        let _ = unsafe {
            bas_l8_memory_usage_audit_log_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            append_replay_log(conn, "r1", "t", "p",
                100).unwrap();
            append_replay_log(conn, "r2", "t", "p",
                200).unwrap();
            append_audit_log(conn, "a1", "act", "do",
                "d", 300).unwrap();
            assert_eq!(count_replay_log(conn).unwrap(), 2);
            assert_eq!(count_audit_log(conn).unwrap(), 1);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn ffi_replay_log_append_round_trip() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_replay_log_init_schema(engine) };
        let eid = "ffi-e1";
        let et = "t";
        let pl = "p";
        let rc = unsafe {
            bas_l8_memory_usage_replay_log_append(
                engine,
                eid.as_ptr() as *const c_char, eid.len(),
                et.as_ptr() as *const c_char, et.len(),
                pl.as_ptr() as *const c_char, pl.len(),
                100)
        };
        assert_eq!(rc, 0);
        // Duplicate event_id → -2
        let rc2 = unsafe {
            bas_l8_memory_usage_replay_log_append(
                engine,
                eid.as_ptr() as *const c_char, eid.len(),
                et.as_ptr() as *const c_char, et.len(),
                pl.as_ptr() as *const c_char, pl.len(),
                200)
        };
        assert_eq!(rc2, -2, "Duplicate PK returns -2");
        let cnt = unsafe {
            bas_l8_memory_usage_replay_log_count(engine) };
        assert_eq!(cnt, 1);
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn ffi_audit_log_append_round_trip() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_audit_log_init_schema(engine) };
        let eid = "ffi-a1";
        let ac = "actor";
        let act = "view";
        let d = "detail";
        let rc = unsafe {
            bas_l8_memory_usage_audit_log_append(
                engine,
                eid.as_ptr() as *const c_char, eid.len(),
                ac.as_ptr() as *const c_char, ac.len(),
                act.as_ptr() as *const c_char, act.len(),
                d.as_ptr() as *const c_char, d.len(),
                100)
        };
        assert_eq!(rc, 0);
        let cnt = unsafe {
            bas_l8_memory_usage_audit_log_count(engine) };
        assert_eq!(cnt, 1);
        unsafe { bas_l8_engine_close(engine); }
    }
}
