// SPDX:internal
//
// memory_usage_extras.rs — chapter 九百二.6 / M3210
//
// L8 unification sub-chapter 3 — closes out the 6-table
// MemoryUsageTracker port by adding the remaining 3 tables:
//
//   - memory_usage_record_notes (UPSERT keyed by record_id)
//   - memory_usage_bundles (composite PK bundle_id+record_id)
//   - memory_usage_tombstones (INSERT OR REPLACE single-col PK)
//
// # FTS5 deferral
//
// The Swift actor pairs `memory_usage_record_notes` with a
// FTS5 virtual table `memory_usage_record_notes_fts` for full-
// text search。 FTS5 requires rusqlite's `bundled-full` feature
// (heavier binary footprint)。 For chapter 九百二.6 the main
// notes table ports cleanly via the same UPSERT pattern as
// records,with FTS5 deferred to sub-chapter 902.6.5 once we
// can measure the FTS path's hot-path consumer pressure (per
// 亏的不要硬上 discipline)。
//
// # Schemas (byte-equality preserved from chapter 二百四十八)
//
//   CREATE TABLE memory_usage_record_notes (
//     record_id TEXT PRIMARY KEY NOT NULL,
//     notes TEXT NOT NULL
//   );
//
//   CREATE TABLE memory_usage_bundles (
//     bundle_id TEXT NOT NULL,
//     record_id TEXT NOT NULL,
//     position_in_bundle INTEGER NOT NULL,
//     created_at_ms INTEGER NOT NULL,
//     PRIMARY KEY (bundle_id, record_id)
//   );
//   CREATE INDEX memory_usage_bundle_id_idx
//     ON memory_usage_bundles(bundle_id);
//   CREATE INDEX memory_usage_bundle_record_idx
//     ON memory_usage_bundles(record_id);
//
//   CREATE TABLE memory_usage_tombstones (
//     record_id TEXT PRIMARY KEY NOT NULL,
//     tombstoned_at_ms INTEGER NOT NULL
//   );

use std::os::raw::{c_char, c_int};
use rusqlite::Connection;
use rusqlite::params;

use crate::L8Engine;

const SCHEMA_NOTES: &str = r#"
CREATE TABLE IF NOT EXISTS memory_usage_record_notes (
    record_id TEXT PRIMARY KEY NOT NULL,
    notes TEXT NOT NULL
);
"#;

const SCHEMA_BUNDLES: &str = r#"
CREATE TABLE IF NOT EXISTS memory_usage_bundles (
    bundle_id TEXT NOT NULL,
    record_id TEXT NOT NULL,
    position_in_bundle INTEGER NOT NULL,
    created_at_ms INTEGER NOT NULL,
    PRIMARY KEY (bundle_id, record_id)
);
CREATE INDEX IF NOT EXISTS memory_usage_bundle_id_idx
  ON memory_usage_bundles(bundle_id);
CREATE INDEX IF NOT EXISTS memory_usage_bundle_record_idx
  ON memory_usage_bundles(record_id);
"#;

const SCHEMA_TOMBSTONES: &str = r#"
CREATE TABLE IF NOT EXISTS memory_usage_tombstones (
    record_id TEXT PRIMARY KEY NOT NULL,
    tombstoned_at_ms INTEGER NOT NULL
);
"#;

pub fn init_notes_schema(
    conn: &Connection,
) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_NOTES)?;
    Ok(())
}

pub fn init_bundles_schema(
    conn: &Connection,
) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_BUNDLES)?;
    Ok(())
}

pub fn init_tombstones_schema(
    conn: &Connection,
) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_TOMBSTONES)?;
    Ok(())
}

// MARK: - Notes (UPSERT-on-conflict matches Swift upsertNotesRow)

pub fn upsert_notes(
    conn: &Connection,
    record_id: &str,
    notes: &str,
) -> rusqlite::Result<()> {
    conn.execute(
        "INSERT INTO memory_usage_record_notes (
            record_id, notes
         ) VALUES (?, ?)
         ON CONFLICT(record_id) DO UPDATE SET
            notes = excluded.notes",
        params![record_id, notes],
    )?;
    Ok(())
}

pub fn count_notes(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM memory_usage_record_notes",
        [], |row| row.get(0))
}

/// Returns the notes text for a record_id,or None if missing。
pub fn notes_for_record(
    conn: &Connection,
    record_id: &str,
) -> rusqlite::Result<Option<String>> {
    let r: Option<String> = conn.query_row(
        "SELECT notes FROM memory_usage_record_notes
         WHERE record_id = ? LIMIT 1",
        params![record_id], |row| row.get(0)
    ).ok();
    Ok(r)
}

// MARK: - Bundles (composite PK, Swift transaction-wrapped insert)

/// Insert a single bundle row。 Composite-PK violation
/// (bundle_id, record_id) bubbles up as rusqlite::Error。
/// Tests for full-bundle insertion call this in a loop。
pub fn insert_bundle_row(
    conn: &Connection,
    bundle_id: &str,
    record_id: &str,
    position_in_bundle: i64,
    created_at_ms: i64,
) -> rusqlite::Result<()> {
    conn.execute(
        "INSERT INTO memory_usage_bundles (
            bundle_id, record_id,
            position_in_bundle, created_at_ms
         ) VALUES (?, ?, ?, ?)",
        params![bundle_id, record_id,
            position_in_bundle, created_at_ms],
    )?;
    Ok(())
}

pub fn count_bundles_rows(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM memory_usage_bundles",
        [], |row| row.get(0))
}

/// Number of distinct bundles (GROUP BY bundle_id COUNT)。
pub fn count_distinct_bundles(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(DISTINCT bundle_id)
         FROM memory_usage_bundles",
        [], |row| row.get(0))
}

pub fn count_records_in_bundle(
    conn: &Connection,
    bundle_id: &str,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM memory_usage_bundles
         WHERE bundle_id = ?",
        params![bundle_id], |row| row.get(0))
}

// MARK: - Tombstones (INSERT OR REPLACE matches Swift insertTombstone)

pub fn upsert_tombstone(
    conn: &Connection,
    record_id: &str,
    tombstoned_at_ms: i64,
) -> rusqlite::Result<()> {
    conn.execute(
        "INSERT OR REPLACE INTO memory_usage_tombstones (
            record_id, tombstoned_at_ms
         ) VALUES (?, ?)",
        params![record_id, tombstoned_at_ms],
    )?;
    Ok(())
}

pub fn count_tombstones(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM memory_usage_tombstones",
        [], |row| row.get(0))
}

pub fn is_tombstoned(
    conn: &Connection,
    record_id: &str,
) -> rusqlite::Result<bool> {
    let found: Option<i64> = conn.query_row(
        "SELECT 1 FROM memory_usage_tombstones
         WHERE record_id = ? LIMIT 1",
        params![record_id], |row| row.get(0)
    ).ok();
    Ok(found.is_some())
}

// MARK: - FFI: notes

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_notes_init_schema(
    engine: *const L8Engine,
) -> c_int {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match init_notes_schema(conn) {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_notes_upsert(
    engine: *const L8Engine,
    record_id_utf8: *const c_char, record_id_len: usize,
    notes_utf8: *const c_char, notes_len: usize,
) -> c_int {
    if engine.is_null() { return -1; }
    let record_id = match crate::cstr_to_str(
        record_id_utf8, record_id_len) {
        Some(s) => s, None => return -3,
    };
    let notes = match crate::cstr_to_str(
        notes_utf8, notes_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match upsert_notes(conn, record_id, notes) {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_notes_count(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_notes(conn).unwrap_or(-2)
    })
}

/// Returns the notes byte length (writes into out_buf up to
/// out_capacity)。 Probe mode (null buf + zero capacity)
/// returns required size。 -2 = record_id not found,
/// -1 = null engine,-3 = UTF-8 decode failure。
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_notes_for_record(
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
    let notes_opt: Option<String> = engine_ref.with_conn(|conn| {
        notes_for_record(conn, record_id).unwrap_or(None)
    });
    let notes_str = match notes_opt {
        Some(s) => s,
        None => return -2,
    };
    let bytes = notes_str.as_bytes();
    let needed = bytes.len();
    // chapter 九百四十二 / M3415 fix HIGH-1 (14P) — i32 overflow guard
    let safe_needed = match crate::safe_i32_size(needed) {
        Ok(n) => n, Err(c) => return c,
    };
    if out_buf.is_null() || out_capacity < needed {
        return safe_needed;
    }
    unsafe {
        core::ptr::copy_nonoverlapping(
            bytes.as_ptr(), out_buf, needed);
    }
    safe_needed
}

// MARK: - FFI: bundles

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_bundles_init_schema(
    engine: *const L8Engine,
) -> c_int {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match init_bundles_schema(conn) {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_bundles_insert_row(
    engine: *const L8Engine,
    bundle_id_utf8: *const c_char, bundle_id_len: usize,
    record_id_utf8: *const c_char, record_id_len: usize,
    position_in_bundle: i64,
    created_at_ms: i64,
) -> c_int {
    if engine.is_null() { return -1; }
    let bundle_id = match crate::cstr_to_str(
        bundle_id_utf8, bundle_id_len) {
        Some(s) => s, None => return -3,
    };
    let record_id = match crate::cstr_to_str(
        record_id_utf8, record_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match insert_bundle_row(
            conn, bundle_id, record_id,
            position_in_bundle, created_at_ms)
        {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_bundles_total_rows(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_bundles_rows(conn).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_bundles_distinct_count(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_distinct_bundles(conn).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_bundles_count_in_bundle(
    engine: *const L8Engine,
    bundle_id_utf8: *const c_char, bundle_id_len: usize,
) -> i64 {
    if engine.is_null() { return -1; }
    let bundle_id = match crate::cstr_to_str(
        bundle_id_utf8, bundle_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_records_in_bundle(conn, bundle_id).unwrap_or(-2)
    })
}

// MARK: - FFI: tombstones

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_tombstones_init_schema(
    engine: *const L8Engine,
) -> c_int {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match init_tombstones_schema(conn) {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_tombstones_upsert(
    engine: *const L8Engine,
    record_id_utf8: *const c_char, record_id_len: usize,
    tombstoned_at_ms: i64,
) -> c_int {
    if engine.is_null() { return -1; }
    let record_id = match crate::cstr_to_str(
        record_id_utf8, record_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match upsert_tombstone(
            conn, record_id, tombstoned_at_ms)
        {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_tombstones_count(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_tombstones(conn).unwrap_or(-2)
    })
}

/// Returns 1 if record_id has a tombstone row, 0 otherwise。
/// -1 = null engine,-3 = UTF-8 decode failure。
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_memory_usage_tombstones_is_tombstoned(
    engine: *const L8Engine,
    record_id_utf8: *const c_char, record_id_len: usize,
) -> c_int {
    if engine.is_null() { return -1; }
    let record_id = match crate::cstr_to_str(
        record_id_utf8, record_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match is_tombstoned(conn, record_id) {
            Ok(true) => 1,
            Ok(false) => 0,
            Err(_) => -2,
        }
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
    fn notes_upsert_idempotent() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_notes_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            upsert_notes(conn, "r1", "orig").unwrap();
            assert_eq!(count_notes(conn).unwrap(), 1);
            // UPSERT-on-conflict updates notes column
            upsert_notes(conn, "r1", "updated").unwrap();
            assert_eq!(count_notes(conn).unwrap(), 1,
                "Still 1 row after UPSERT");
            assert_eq!(
                notes_for_record(conn, "r1").unwrap(),
                Some("updated".to_string()));
            assert_eq!(
                notes_for_record(conn, "missing").unwrap(),
                None);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn bundles_composite_pk_rejects_duplicate_pair() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_bundles_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            insert_bundle_row(conn, "b1", "r1", 0,
                100).unwrap();
            insert_bundle_row(conn, "b1", "r2", 1,
                100).unwrap();
            insert_bundle_row(conn, "b2", "r1", 0,
                200).unwrap();
            // (b1, r1) is a duplicate composite PK
            let err = insert_bundle_row(conn, "b1", "r1",
                99, 999);
            assert!(err.is_err(),
                "Duplicate (bundle_id, record_id) → error");
            assert_eq!(count_bundles_rows(conn).unwrap(), 3);
            assert_eq!(count_distinct_bundles(conn).unwrap(),
                2);
            assert_eq!(count_records_in_bundle(
                conn, "b1").unwrap(), 2);
            assert_eq!(count_records_in_bundle(
                conn, "b2").unwrap(), 1);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn tombstones_insert_or_replace_is_idempotent() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_tombstones_init_schema(
                engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            upsert_tombstone(conn, "r1", 100).unwrap();
            upsert_tombstone(conn, "r1", 200).unwrap();
            upsert_tombstone(conn, "r2", 300).unwrap();
            assert_eq!(count_tombstones(conn).unwrap(), 2);
            assert!(is_tombstoned(conn, "r1").unwrap());
            assert!(is_tombstoned(conn, "r2").unwrap());
            assert!(!is_tombstoned(conn, "missing").unwrap());
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn ffi_all_three_tables_independent() {
        // Insert into each table and verify counts isolate。
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_notes_init_schema(engine) };
        let _ = unsafe {
            bas_l8_memory_usage_bundles_init_schema(engine) };
        let _ = unsafe {
            bas_l8_memory_usage_tombstones_init_schema(
                engine) };
        let r = "r1";
        let n = "hello";
        let rc1 = unsafe {
            bas_l8_memory_usage_notes_upsert(
                engine,
                r.as_ptr() as *const c_char, r.len(),
                n.as_ptr() as *const c_char, n.len())
        };
        assert_eq!(rc1, 0);
        let b = "b1";
        let rc2 = unsafe {
            bas_l8_memory_usage_bundles_insert_row(
                engine,
                b.as_ptr() as *const c_char, b.len(),
                r.as_ptr() as *const c_char, r.len(),
                0, 100)
        };
        assert_eq!(rc2, 0);
        let rc3 = unsafe {
            bas_l8_memory_usage_tombstones_upsert(
                engine,
                r.as_ptr() as *const c_char, r.len(),
                500)
        };
        assert_eq!(rc3, 0);
        assert_eq!(unsafe {
            bas_l8_memory_usage_notes_count(engine) }, 1);
        assert_eq!(unsafe {
            bas_l8_memory_usage_bundles_total_rows(engine) },
            1);
        assert_eq!(unsafe {
            bas_l8_memory_usage_tombstones_count(engine) },
            1);
        let is_t = unsafe {
            bas_l8_memory_usage_tombstones_is_tombstoned(
                engine,
                r.as_ptr() as *const c_char, r.len())
        };
        assert_eq!(is_t, 1);
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn ffi_notes_probe_returns_required_size() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_memory_usage_notes_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            upsert_notes(conn, "rp", "long note text")
                .unwrap();
        });
        let rid = "rp";
        let needed = unsafe {
            bas_l8_memory_usage_notes_for_record(
                engine,
                rid.as_ptr() as *const c_char, rid.len(),
                std::ptr::null_mut(), 0)
        };
        assert_eq!(needed, "long note text".len() as i32);
        let mut buf = vec![0u8; needed as usize];
        let written = unsafe {
            bas_l8_memory_usage_notes_for_record(
                engine,
                rid.as_ptr() as *const c_char, rid.len(),
                buf.as_mut_ptr(), buf.len())
        };
        assert_eq!(written, needed);
        assert_eq!(&buf[..], b"long note text");
        // Missing record → -2
        let missing = "no-such";
        let rc = unsafe {
            bas_l8_memory_usage_notes_for_record(
                engine,
                missing.as_ptr() as *const c_char,
                missing.len(),
                std::ptr::null_mut(), 0)
        };
        assert_eq!(rc, -2);
        unsafe { bas_l8_engine_close(engine); }
    }
}
