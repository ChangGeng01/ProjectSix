// SPDX:internal
//
// user_state.rs — chapter 八百九十八 / M3180
//
// L8 unification MED-risk migration #3 per RFC。 Ports the
// `BASSQLiteUserStateStorage` SQL surface (schema:user_states
// table,4 cols + 1 index)。 Append-history user-state snapshots
// with idempotent insert on duplicate state_id。
//
// Schema is small + payload is opaque JSON text — clean fit
// for the existing migration template (chapter 895/897 pattern)。

use std::os::raw::{c_char, c_int};
use rusqlite::Connection;
use rusqlite::params;

use crate::L8Engine;

const SCHEMA_USER_STATES: &str = r#"
CREATE TABLE IF NOT EXISTS user_states (
    state_id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL,
    generated_at_ms INTEGER NOT NULL,
    payload_json TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS user_states_session_time_idx
  ON user_states(session_id, generated_at_ms DESC);
"#;

pub fn init_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_USER_STATES)?;
    Ok(())
}

/// Insert a state row。 Idempotent on duplicate state_id:
/// returns `Ok(false)` if the row already exists (matches
/// Swift `BASInMemoryUserStateStorage.append` semantics)。
pub fn append_state(
    conn: &Connection,
    state_id: &str,
    session_id: &str,
    generated_at_ms: i64,
    payload_json: &str,
) -> rusqlite::Result<bool> {
    // Pre-check existence to match Swift idempotency semantics
    // (returns false on duplicate,doesn't throw)。
    let exists: bool = conn.query_row(
        "SELECT 1 FROM user_states WHERE state_id = ? LIMIT 1",
        params![state_id],
        |_| Ok(true),
    ).unwrap_or(false);
    if exists {
        return Ok(false);
    }
    conn.execute(
        "INSERT INTO user_states (
            state_id, session_id, generated_at_ms, payload_json
         ) VALUES (?, ?, ?, ?)",
        params![state_id, session_id, generated_at_ms, payload_json],
    )?;
    Ok(true)
}

pub fn count_states(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM user_states",
        [], |row| row.get(0))
}

pub fn count_states_for_session(
    conn: &Connection,
    session_id: &str,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM user_states WHERE session_id = ?",
        params![session_id], |row| row.get(0))
}

/// Returns the most-recent state's generated_at_ms for a session
/// (or -1 if no states)。 Used by tests to verify ORDER BY
/// generated_at_ms DESC semantics match Swift。
pub fn latest_state_time_for_session(
    conn: &Connection,
    session_id: &str,
) -> rusqlite::Result<i64> {
    let r: Option<i64> = conn.query_row(
        "SELECT generated_at_ms FROM user_states
         WHERE session_id = ?
         ORDER BY generated_at_ms DESC LIMIT 1",
        params![session_id], |row| row.get(0)
    ).ok();
    Ok(r.unwrap_or(-1))
}

// MARK: - FFI

#[no_mangle]
pub unsafe extern "C" fn bas_l8_user_state_init_schema(
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

/// Returns:
///   1  → inserted new row
///   0  → state_id already existed (idempotent no-op)
///   -1 → null engine
///   -2 → SQLite error
///   -3 → UTF-8 decode failure
#[no_mangle]
pub unsafe extern "C" fn bas_l8_user_state_append(
    engine: *const L8Engine,
    state_id_utf8: *const c_char, state_id_len: usize,
    session_id_utf8: *const c_char, session_id_len: usize,
    generated_at_ms: i64,
    payload_json_utf8: *const c_char, payload_json_len: usize,
) -> c_int {
    if engine.is_null() { return -1; }
    let state_id = match crate::cstr_to_str(
        state_id_utf8, state_id_len) {
        Some(s) => s, None => return -3,
    };
    let session_id = match crate::cstr_to_str(
        session_id_utf8, session_id_len) {
        Some(s) => s, None => return -3,
    };
    let payload_json = match crate::cstr_to_str(
        payload_json_utf8, payload_json_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match append_state(
            conn, state_id, session_id,
            generated_at_ms, payload_json)
        {
            Ok(true) => 1,
            Ok(false) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_user_state_count(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_states(conn).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_user_state_count_for_session(
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
        count_states_for_session(conn, session_id).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_user_state_latest_time_for_session(
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
        latest_state_time_for_session(conn, session_id)
            .unwrap_or(-1)
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
    fn append_returns_true_on_insert_false_on_duplicate() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_user_state_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            assert_eq!(
                append_state(conn, "s1", "sess-A",
                    100, r#"{"v":1}"#).unwrap(), true);
            assert_eq!(
                append_state(conn, "s1", "sess-A",
                    200, r#"{"v":2}"#).unwrap(), false,
                "Duplicate state_id must return false");
            assert_eq!(count_states(conn).unwrap(), 1);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn latest_state_time_orders_by_generated_at_desc() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_user_state_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            append_state(conn, "s1", "sess-B", 100,
                "{}").unwrap();
            append_state(conn, "s2", "sess-B", 500,
                "{}").unwrap();
            append_state(conn, "s3", "sess-B", 300,
                "{}").unwrap();
            assert_eq!(
                latest_state_time_for_session(
                    conn, "sess-B").unwrap(), 500);
            assert_eq!(
                latest_state_time_for_session(
                    conn, "sess-missing").unwrap(), -1);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn ffi_append_returns_correct_codes() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_user_state_init_schema(engine) };
        let sid = "ffi-s1";
        let sess = "ffi-sess";
        let pl = "{}";
        let rc1 = unsafe {
            bas_l8_user_state_append(
                engine,
                sid.as_ptr() as *const c_char, sid.len(),
                sess.as_ptr() as *const c_char, sess.len(),
                100,
                pl.as_ptr() as *const c_char, pl.len())
        };
        assert_eq!(rc1, 1, "First insert returns 1");
        let rc2 = unsafe {
            bas_l8_user_state_append(
                engine,
                sid.as_ptr() as *const c_char, sid.len(),
                sess.as_ptr() as *const c_char, sess.len(),
                200,
                pl.as_ptr() as *const c_char, pl.len())
        };
        assert_eq!(rc2, 0, "Duplicate state_id returns 0");
        unsafe { bas_l8_engine_close(engine); }
    }
}
