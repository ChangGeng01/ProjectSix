// SPDX:internal
//
// memory_usage_records.rs — chapter 九百二 / M3200
//
// L8 unification HIGH-risk migration #2 per RFC — scoped to ONLY
// the `memory_usage_records` table of BASMemoryUsageTracker
// (1 of 6 tables in that 2,714-LOC actor)。 Per 「细心」 discipline
// the remaining 5 tables (replay_log,audit_log,record_notes,
// bundles,tombstones) ship in subsequent sub-chapters。
//
// # Why split
//
// BASMemoryUsageTracker is the largest single L8 actor (32 funcs,
// 6 tables)。 「细心继续」 means scoping each Rust port to one table
// per chapter so each migration gets:
//   - Full schema byte-equality verification
//   - UPSERT idempotency tests
//   - Per-atom + per-session count parity tests
//   - A focused Swift bridge that doesn't bloat to 1000+ lines
//
// # Schema (V1,byte-equality preserved from chapter 二百四十八)
//
//   CREATE TABLE memory_usage_records (
//     record_id TEXT PRIMARY KEY NOT NULL,
//     atom_id TEXT NOT NULL,
//     retrieved_at_ms INTEGER NOT NULL,
//     session_ref TEXT NOT NULL,
//     turn_ref TEXT NOT NULL,
//     permit_mode TEXT NOT NULL,
//     helped_state TEXT NOT NULL  -- "unknown"|"helped"|"notHelped"
//   );
//   CREATE INDEX memory_usage_atom_idx
//     ON memory_usage_records(atom_id);
//   CREATE INDEX memory_usage_session_idx
//     ON memory_usage_records(session_ref);
//
// The composite covering index `memory_usage_atom_time_idx` is
// LAZILY created via Swift `ensureCoveringIndex()` — chapter 902
// preserves that lazy semantics (Rust does NOT create it on
// `init_schema`)。 Sub-chapter 902.7 will add an explicit
// `ensure_covering_index` FFI if the consolidation needs it。
//
// # UPSERT semantics
//
// `upsert_record` mirrors the Swift `upsertRecord` impl:
//
//   INSERT INTO memory_usage_records (...) VALUES (?, ..., ?)
//   ON CONFLICT(record_id) DO UPDATE SET
//       helped_state = excluded.helped_state
//
// Importantly,ONLY `helped_state` is updated on conflict — all
// other columns stay at their original insert values。 This matches
// the host's `markHelped(recordID:helped:)` use case (post-LLM
// signal updates the flag without rewriting the rest of the record)。

use std::os::raw::{c_char, c_int};
use rusqlite::Connection;
use rusqlite::params;

use crate::L8Engine;

const SCHEMA_MEMORY_USAGE_RECORDS: &str = r#"
CREATE TABLE IF NOT EXISTS memory_usage_records (
    record_id TEXT PRIMARY KEY NOT NULL,
    atom_id TEXT NOT NULL,
    retrieved_at_ms INTEGER NOT NULL,
    session_ref TEXT NOT NULL,
    turn_ref TEXT NOT NULL,
    permit_mode TEXT NOT NULL,
    helped_state TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS memory_usage_atom_idx
  ON memory_usage_records(atom_id);
CREATE INDEX IF NOT EXISTS memory_usage_session_idx
  ON memory_usage_records(session_ref);
"#;

pub fn init_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_MEMORY_USAGE_RECORDS)?;
    Ok(())
}

/// UPSERT one retrieval record。 On INSERT all columns are
/// written;on CONFLICT only `helped_state` is updated (matches
/// Swift `upsertRecord` exactly)。 The host's `markHelped`
/// flow re-issues an UPSERT with the new helped flag — the
/// other columns retain their original insert values。
///
/// Returns:
///   Ok(true)  → new row inserted
///   Ok(false) → existing row's helped_state was updated
pub fn upsert_record(
    conn: &Connection,
    record_id: &str,
    atom_id: &str,
    retrieved_at_ms: i64,
    session_ref: &str,
    turn_ref: &str,
    permit_mode: &str,
    helped_state: &str,
) -> rusqlite::Result<bool> {
    // Pre-check existence to mirror Swift wasNew-on-insert
    // semantics (Swift insert/upsert distinction)。
    let existed: bool = conn.query_row(
        "SELECT 1 FROM memory_usage_records
         WHERE record_id = ? LIMIT 1",
        params![record_id],
        |_| Ok(true),
    ).unwrap_or(false);
    conn.execute(
        "INSERT INTO memory_usage_records (
            record_id, atom_id, retrieved_at_ms,
            session_ref, turn_ref, permit_mode, helped_state
         ) VALUES (?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(record_id) DO UPDATE SET
            helped_state = excluded.helped_state",
        params![
            record_id, atom_id, retrieved_at_ms,
            session_ref, turn_ref, permit_mode, helped_state],
    )?;
    Ok(!existed)
}

pub fn count_records(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM memory_usage_records",
        [], |row| row.get(0))
}

pub fn usage_count_for_atom(
    conn: &Connection,
    atom_id: &str,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM memory_usage_records
         WHERE atom_id = ?",
        params![atom_id], |row| row.get(0))
}

pub fn count_for_session(
    conn: &Connection,
    session_ref: &str,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM memory_usage_records
         WHERE session_ref = ?",
        params![session_ref], |row| row.get(0))
}

/// Returns the current `helped_state` for the given record_id,
/// or None if the record_id is unknown。 Used by tests to verify
/// markHelped UPSERT semantics propagate through Rust。
pub fn helped_state_for_record(
    conn: &Connection,
    record_id: &str,
) -> rusqlite::Result<Option<String>> {
    let r: Option<String> = conn.query_row(
        "SELECT helped_state FROM memory_usage_records
         WHERE record_id = ? LIMIT 1",
        params![record_id], |row| row.get(0)
    ).ok();
    Ok(r)
}

// MARK: - FFI

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_records_init_schema(
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
///   0  → row existed,helped_state updated
///   -1 → null engine
///   -2 → SQLite error
///   -3 → UTF-8 decode failure
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_records_upsert(
    engine: *const L8Engine,
    record_id_utf8: *const c_char, record_id_len: usize,
    atom_id_utf8: *const c_char, atom_id_len: usize,
    retrieved_at_ms: i64,
    session_ref_utf8: *const c_char, session_ref_len: usize,
    turn_ref_utf8: *const c_char, turn_ref_len: usize,
    permit_mode_utf8: *const c_char, permit_mode_len: usize,
    helped_state_utf8: *const c_char, helped_state_len: usize,
) -> c_int {
    if engine.is_null() { return -1; }
    let record_id = match crate::cstr_to_str(
        record_id_utf8, record_id_len) {
        Some(s) => s, None => return -3,
    };
    let atom_id = match crate::cstr_to_str(
        atom_id_utf8, atom_id_len) {
        Some(s) => s, None => return -3,
    };
    let session_ref = match crate::cstr_to_str(
        session_ref_utf8, session_ref_len) {
        Some(s) => s, None => return -3,
    };
    let turn_ref = match crate::cstr_to_str(
        turn_ref_utf8, turn_ref_len) {
        Some(s) => s, None => return -3,
    };
    let permit_mode = match crate::cstr_to_str(
        permit_mode_utf8, permit_mode_len) {
        Some(s) => s, None => return -3,
    };
    let helped_state = match crate::cstr_to_str(
        helped_state_utf8, helped_state_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match upsert_record(
            conn, record_id, atom_id, retrieved_at_ms,
            session_ref, turn_ref, permit_mode, helped_state)
        {
            Ok(true) => 1,
            Ok(false) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_records_count(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_records(conn).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_records_usage_count_for_atom(
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
        usage_count_for_atom(conn, atom_id).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_records_count_for_session(
    engine: *const L8Engine,
    session_ref_utf8: *const c_char, session_ref_len: usize,
) -> i64 {
    if engine.is_null() { return -1; }
    let session_ref = match crate::cstr_to_str(
        session_ref_utf8, session_ref_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_for_session(conn, session_ref).unwrap_or(-2)
    })
}

/// Returns the helped_state byte length + writes it into
/// `out_buf` (up to `out_capacity` bytes)。 Probe mode (null buf
/// + zero capacity) returns the required size only。
///
/// Returns:
///   -1 → null engine
///   -2 → record not found
///   -3 → UTF-8 decode failure
///   ≥0 → bytes written (or required size if probe)
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_records_helped_state_for_record(
    engine: *const L8Engine,
    record_id_utf8: *const c_char, record_id_len: usize,
    out_buf: *mut u8, out_capacity: usize,
) -> i32 {
    if engine.is_null() { return -1; }
    let record_id = match crate::cstr_to_str(
        record_id_utf8, record_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    let helped: Option<String> = engine_ref.with_conn(|conn| {
        helped_state_for_record(conn, record_id)
            .unwrap_or(None)
    });
    let helped_str = match helped {
        Some(s) => s,
        None => return -2,
    };
    let bytes = helped_str.as_bytes();
    let needed = bytes.len();
    if out_buf.is_null() || out_capacity < needed {
        return needed as i32;
    }
    unsafe {
        core::ptr::copy_nonoverlapping(
            bytes.as_ptr(), out_buf, needed);
    }
    needed as i32
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{bas_l8_engine_init, bas_l8_engine_close};

    fn make_engine() -> *mut L8Engine {
        unsafe { bas_l8_engine_init(std::ptr::null(), 0) }
    }

    #[test]
    fn upsert_returns_true_on_insert_false_on_conflict() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_records_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            // First insert
            assert_eq!(upsert_record(conn, "r1", "atom-A",
                100, "sess-1", "turn-1", "permitted",
                "unknown").unwrap(), true);
            // Same record_id — UPSERT updates helped_state
            assert_eq!(upsert_record(conn, "r1", "atom-A",
                100, "sess-1", "turn-1", "permitted",
                "helped").unwrap(), false,
                "UPSERT on existing record_id must return false");
            assert_eq!(count_records(conn).unwrap(), 1);
            assert_eq!(
                helped_state_for_record(conn, "r1").unwrap(),
                Some("helped".to_string()));
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn upsert_only_updates_helped_state_on_conflict() {
        // Critical Swift parity:on conflict, ONLY helped_state
        // is updated。 Other columns retain original insert values。
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_records_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            upsert_record(conn, "r2", "atom-orig",
                500, "sess-orig", "turn-orig", "mode-orig",
                "unknown").unwrap();
            // Re-upsert with DIFFERENT non-helped fields → ignored
            upsert_record(conn, "r2", "atom-CHANGED",
                999, "sess-CHANGED", "turn-CHANGED",
                "mode-CHANGED", "notHelped").unwrap();
            // Verify original fields preserved
            let row: (String, i64, String, String, String, String) =
                conn.query_row(
                    "SELECT atom_id, retrieved_at_ms, session_ref,
                            turn_ref, permit_mode, helped_state
                     FROM memory_usage_records
                     WHERE record_id = ?",
                    params!["r2"],
                    |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?,
                            r.get(3)?, r.get(4)?, r.get(5)?))
                ).unwrap();
            assert_eq!(row.0, "atom-orig",
                "atom_id must NOT change on conflict");
            assert_eq!(row.1, 500,
                "retrieved_at_ms must NOT change on conflict");
            assert_eq!(row.2, "sess-orig",
                "session_ref must NOT change on conflict");
            assert_eq!(row.3, "turn-orig");
            assert_eq!(row.4, "mode-orig");
            assert_eq!(row.5, "notHelped",
                "helped_state MUST update");
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn usage_count_for_atom_filters_correctly() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_records_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            upsert_record(conn, "r1", "atom-A", 100,
                "s1", "t1", "p", "unknown").unwrap();
            upsert_record(conn, "r2", "atom-A", 200,
                "s2", "t2", "p", "unknown").unwrap();
            upsert_record(conn, "r3", "atom-B", 300,
                "s1", "t3", "p", "unknown").unwrap();
            assert_eq!(usage_count_for_atom(
                conn, "atom-A").unwrap(), 2);
            assert_eq!(usage_count_for_atom(
                conn, "atom-B").unwrap(), 1);
            assert_eq!(usage_count_for_atom(
                conn, "atom-missing").unwrap(), 0);
            // Session-scoped count
            assert_eq!(count_for_session(
                conn, "s1").unwrap(), 2);
            assert_eq!(count_for_session(
                conn, "s2").unwrap(), 1);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn ffi_upsert_returns_correct_codes() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_records_init_schema(engine) };
        let rid = "ffi-r1";
        let aid = "ffi-atom";
        let sid = "ffi-sess";
        let tid = "ffi-turn";
        let pm = "permitted";
        let h1 = "unknown";
        let h2 = "helped";
        let rc1 = unsafe {
            bas_l8_memory_usage_records_upsert(
                engine,
                rid.as_ptr() as *const c_char, rid.len(),
                aid.as_ptr() as *const c_char, aid.len(),
                100,
                sid.as_ptr() as *const c_char, sid.len(),
                tid.as_ptr() as *const c_char, tid.len(),
                pm.as_ptr() as *const c_char, pm.len(),
                h1.as_ptr() as *const c_char, h1.len())
        };
        assert_eq!(rc1, 1, "First insert returns 1");
        let rc2 = unsafe {
            bas_l8_memory_usage_records_upsert(
                engine,
                rid.as_ptr() as *const c_char, rid.len(),
                aid.as_ptr() as *const c_char, aid.len(),
                100,
                sid.as_ptr() as *const c_char, sid.len(),
                tid.as_ptr() as *const c_char, tid.len(),
                pm.as_ptr() as *const c_char, pm.len(),
                h2.as_ptr() as *const c_char, h2.len())
        };
        assert_eq!(rc2, 0,
            "UPSERT on existing record_id returns 0");
        let cnt = unsafe {
            bas_l8_memory_usage_records_count(engine) };
        assert_eq!(cnt, 1);
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn ffi_helped_state_probe_returns_required_size() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_records_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            upsert_record(conn, "rp", "a", 1, "s", "t",
                "p", "notHelped").unwrap();
        });
        let rid = "rp";
        // Probe
        let needed = unsafe {
            bas_l8_memory_usage_records_helped_state_for_record(
                engine,
                rid.as_ptr() as *const c_char, rid.len(),
                std::ptr::null_mut(), 0)
        };
        assert_eq!(needed, "notHelped".len() as i32);
        // Real read
        let mut buf = vec![0u8; needed as usize];
        let written = unsafe {
            bas_l8_memory_usage_records_helped_state_for_record(
                engine,
                rid.as_ptr() as *const c_char, rid.len(),
                buf.as_mut_ptr(), buf.len())
        };
        assert_eq!(written, "notHelped".len() as i32);
        assert_eq!(&buf[..], b"notHelped");
        // Missing record_id → -2
        let missing = "missing-rid";
        let rc = unsafe {
            bas_l8_memory_usage_records_helped_state_for_record(
                engine,
                missing.as_ptr() as *const c_char,
                missing.len(),
                std::ptr::null_mut(), 0)
        };
        assert_eq!(rc, -2);
        unsafe { bas_l8_engine_close(engine); }
    }
}
