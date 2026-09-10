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
    // chapter 九百二十二 / M3315 CRITICAL fix NC1 (user_state)
    crate::transactional(conn, |conn| {
        let exists = match conn.query_row(
            "SELECT 1 FROM user_states WHERE state_id = ? LIMIT 1",
            params![state_id],
            |_| Ok(true),
        ) {
            Ok(true) => true,
            Err(rusqlite::Error::QueryReturnedNoRows) => false,
            Err(e) => return Err(e),
            Ok(false) => false,
        };
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
    })
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

// MARK: - chapter 九百三十六 / M3385 — full-row state query
//
// USER-PASS finding (ch 933) #3 substance fix:the ch 898 bridge
// labeled this「Full」 in L8_ROUTED_OVERVIEW.md but shipped
// `return nil` stubs。 Schema stores opaque `payload_json` — simpler
// than ch 934/935 because the JSON is ALREADY the wire format,no
// per-column construction needed。 Just return payload_json bytes。

/// Returns the payload_json for a specific state_id,or None if
/// not found。 Swift bridge decodes the JSON to BASUserState。
pub fn payload_for_state_id(
    conn: &Connection,
    state_id: &str,
) -> rusqlite::Result<Option<String>> {
    let r = conn.query_row(
        "SELECT payload_json FROM user_states \
         WHERE state_id = ?",
        params![state_id],
        |row| row.get::<_, String>(0),
    );
    match r {
        Ok(s) => Ok(Some(s)),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(e),
    }
}

/// Returns the payload_json for the most-recent state in a
/// session (by generated_at_ms DESC),or None if session empty。
pub fn latest_payload_for_session(
    conn: &Connection,
    session_id: &str,
) -> rusqlite::Result<Option<String>> {
    let r = conn.query_row(
        "SELECT payload_json FROM user_states \
         WHERE session_id = ? \
         ORDER BY generated_at_ms DESC LIMIT 1",
        params![session_id],
        |row| row.get::<_, String>(0),
    );
    match r {
        Ok(s) => Ok(Some(s)),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(e),
    }
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

// chapter 九百三十六 / M3385 — payload_json FFI (USER-PASS #3)
//
// Schema stores payload_json as opaque text — return as-is to
// Swift which decodes via JSONDecoder into BASUserState。
// Probe + fill pattern with ONE EXTRA return code:
//   ≥0 → bytes needed (probe) or written (fill)
//    0 → row not found (Swift treats as nil)
//   -1 → null engine
//   -2 → SQLite error
//   -3 → invalid UTF-8 input / out_capacity < needed (fill)

unsafe fn payload_json_ffi(
    engine: *const L8Engine,
    key_utf8: *const c_char,
    key_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
    by_state_id: bool,
) -> i32 {
    if engine.is_null() { return -1; }
    let key = match crate::cstr_to_str(key_utf8, key_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    let payload_result = engine_ref.with_conn(|conn| {
        if by_state_id {
            payload_for_state_id(conn, key)
        } else {
            latest_payload_for_session(conn, key)
        }
    });
    let payload_opt = match payload_result {
        Ok(p) => p,
        Err(_) => return -2,
    };
    // None → not found → return 0
    let payload = match payload_opt {
        Some(p) => p,
        None => return 0,
    };
    let bytes = payload.as_bytes();
    let needed = bytes.len();
    // Edge case:payload is empty string → return 0 (Swift can't
    // decode empty JSON anyway,treat as not-found)
    if needed == 0 { return 0; }
    // chapter 九百四十一 / M3410 fix HIGH — i32 overflow guard
    let safe_needed = match crate::safe_i32_size(needed) {
        Ok(n) => n, Err(c) => return c,
    };
    if out_buf.is_null() || out_capacity == 0 {
        return safe_needed;
    }
    if out_capacity < needed {
        return -3;
    }
    unsafe {
        std::ptr::copy_nonoverlapping(
            bytes.as_ptr(), out_buf, needed);
    }
    safe_needed
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_user_state_payload_for_id(
    engine: *const L8Engine,
    state_id_utf8: *const c_char, state_id_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
) -> i32 {
    payload_json_ffi(
        engine, state_id_utf8, state_id_len,
        out_buf, out_capacity, true)
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_user_state_latest_payload_for_session(
    engine: *const L8Engine,
    session_id_utf8: *const c_char, session_id_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
) -> i32 {
    payload_json_ffi(
        engine, session_id_utf8, session_id_len,
        out_buf, out_capacity, false)
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

    // chapter 九百三十六 / M3385 — payload_json round-trip
    #[test]
    fn payload_for_state_id_round_trip() {
        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0) };
        unsafe { bas_l8_user_state_init_schema(engine); };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let pl1 = "{\"stateID\":\"s1\",\"emotionalTrend\":0.5}";
            let pl2 = "{\"stateID\":\"s2\",\"emotionalTrend\":-0.3}";
            append_state(conn, "s1", "sess-A", 100, pl1).unwrap();
            append_state(conn, "s2", "sess-A", 200, pl2).unwrap();
            // payload_for_state_id
            let r1 = payload_for_state_id(conn, "s1").unwrap();
            assert_eq!(r1, Some(pl1.to_string()));
            let r2 = payload_for_state_id(conn, "s2").unwrap();
            assert_eq!(r2, Some(pl2.to_string()));
            let r_none = payload_for_state_id(
                conn, "missing").unwrap();
            assert_eq!(r_none, None);
            // latest_payload_for_session:DESC ORDER → s2 wins
            let latest = latest_payload_for_session(
                conn, "sess-A").unwrap();
            assert_eq!(latest, Some(pl2.to_string()));
            let none_sess = latest_payload_for_session(
                conn, "sess-NONE").unwrap();
            assert_eq!(none_sess, None);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn payload_ffi_probe_fill() {
        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0) };
        unsafe { bas_l8_user_state_init_schema(engine); };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let pl = "{\"stateID\":\"ffi-s1\",\"x\":1}";
            append_state(
                conn, "ffi-s1", "ffi-sess", 100, pl).unwrap();
        });
        let sid = "ffi-s1";
        // probe
        let needed = unsafe {
            bas_l8_user_state_payload_for_id(
                engine,
                sid.as_ptr() as *const c_char, sid.len(),
                std::ptr::null_mut(), 0)
        };
        assert!(needed > 0);
        // fill
        let mut buf = vec![0u8; needed as usize];
        let written = unsafe {
            bas_l8_user_state_payload_for_id(
                engine,
                sid.as_ptr() as *const c_char, sid.len(),
                buf.as_mut_ptr(), buf.len())
        };
        assert_eq!(written, needed);
        assert!(std::str::from_utf8(&buf).unwrap()
            .contains("\"stateID\":\"ffi-s1\""));
        // not found → 0
        let missing = "no-such-id";
        let rc = unsafe {
            bas_l8_user_state_payload_for_id(
                engine,
                missing.as_ptr() as *const c_char,
                missing.len(),
                std::ptr::null_mut(), 0)
        };
        assert_eq!(rc, 0, "not-found must return 0,not negative");
        // too-small buffer rejected
        let mut tiny = vec![0u8; 1];
        let rc2 = unsafe {
            bas_l8_user_state_payload_for_id(
                engine,
                sid.as_ptr() as *const c_char, sid.len(),
                tiny.as_mut_ptr(), tiny.len())
        };
        assert_eq!(rc2, -3);
        unsafe { bas_l8_engine_close(engine); }
    }
}
