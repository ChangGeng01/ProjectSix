// SPDX:internal
//
// vector_index.rs — chapter 九百 / M3190
//
// L8 unification MED-risk migration #5 per RFC。 Ports
// `BASSQLiteVectorIndexStorage` (vector_index schema)。 Per-turn
// retrieval hot path (preload at session start;upserts on insert)。
//
// Embedding stored as BLOB (variable size = dim × 4 bytes per
// f32 normalized embedding)。 Builds on chapter 八百九十九 BLOB FFI
// pattern。 UPSERT semantics:returns 1 on insert,0 on replace。

use std::os::raw::{c_char, c_int};
use rusqlite::Connection;
use rusqlite::params;

use crate::L8Engine;

const SCHEMA_VECTOR_INDEX: &str = r#"
CREATE TABLE IF NOT EXISTS vector_index (
    atom_id TEXT PRIMARY KEY NOT NULL,
    dimension INTEGER NOT NULL,
    provider_version TEXT NOT NULL,
    embedding_blob BLOB NOT NULL,
    domain TEXT NOT NULL,
    metadata_json TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS vector_index_provider_idx
  ON vector_index(provider_version);
CREATE INDEX IF NOT EXISTS vector_index_domain_idx
  ON vector_index(domain);
"#;

pub fn init_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_VECTOR_INDEX)?;
    Ok(())
}

/// UPSERT semantics: returns true if newly inserted,false
/// if existing atom_id was replaced (matches Swift
/// `BASSQLiteVectorIndexStorage.upsert` return shape)。
pub fn upsert_entry(
    conn: &Connection,
    atom_id: &str,
    dimension: i64,
    provider_version: &str,
    embedding_blob: &[u8],
    domain: &str,
    metadata_json: &str,
) -> rusqlite::Result<bool> {
    let existed: bool = conn.query_row(
        "SELECT 1 FROM vector_index WHERE atom_id = ? LIMIT 1",
        params![atom_id], |_| Ok(true),
    ).unwrap_or(false);
    conn.execute(
        "INSERT OR REPLACE INTO vector_index (
            atom_id, dimension, provider_version,
            embedding_blob, domain, metadata_json
         ) VALUES (?, ?, ?, ?, ?, ?)",
        params![
            atom_id, dimension, provider_version,
            embedding_blob, domain, metadata_json,
        ],
    )?;
    Ok(!existed)
}

pub fn remove_entry(
    conn: &Connection,
    atom_id: &str,
) -> rusqlite::Result<bool> {
    let n = conn.execute(
        "DELETE FROM vector_index WHERE atom_id = ?",
        params![atom_id])?;
    Ok(n > 0)
}

pub fn count_entries(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM vector_index",
        [], |row| row.get(0))
}

pub fn count_entries_for_domain(
    conn: &Connection,
    domain: &str,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM vector_index WHERE domain = ?",
        params![domain], |row| row.get(0))
}

pub fn count_entries_for_provider(
    conn: &Connection,
    provider_version: &str,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM vector_index
         WHERE provider_version = ?",
        params![provider_version], |row| row.get(0))
}

// MARK: - FFI

#[no_mangle]
pub unsafe extern "C" fn bas_l8_vector_index_init_schema(
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

/// UPSERT entry。 Returns 1 on insert,0 on replace,-1 null
/// engine,-2 SQLite error,-3 UTF-8 decode failure。
#[no_mangle]
pub unsafe extern "C" fn bas_l8_vector_index_upsert(
    engine: *const L8Engine,
    atom_id_utf8: *const c_char, atom_id_len: usize,
    dimension: i64,
    provider_version_utf8: *const c_char,
    provider_version_len: usize,
    embedding_bytes: *const u8, embedding_len: usize,
    domain_utf8: *const c_char, domain_len: usize,
    metadata_json_utf8: *const c_char, metadata_json_len: usize,
) -> c_int {
    if engine.is_null() { return -1; }
    let atom_id = match crate::cstr_to_str(
        atom_id_utf8, atom_id_len) {
        Some(s) => s, None => return -3,
    };
    let provider_version = match crate::cstr_to_str(
        provider_version_utf8, provider_version_len) {
        Some(s) => s, None => return -3,
    };
    let domain = match crate::cstr_to_str(
        domain_utf8, domain_len) {
        Some(s) => s, None => return -3,
    };
    let metadata_json = match crate::cstr_to_str(
        metadata_json_utf8, metadata_json_len) {
        Some(s) => s, None => return -3,
    };
    if embedding_bytes.is_null() && embedding_len > 0 {
        return -3;
    }
    let embedding: &[u8] = if embedding_len == 0 {
        &[]
    } else {
        unsafe {
            core::slice::from_raw_parts(
                embedding_bytes, embedding_len)
        }
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match upsert_entry(
            conn, atom_id, dimension, provider_version,
            embedding, domain, metadata_json)
        {
            Ok(true) => 1,
            Ok(false) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_vector_index_remove(
    engine: *const L8Engine,
    atom_id_utf8: *const c_char, atom_id_len: usize,
) -> c_int {
    if engine.is_null() { return -1; }
    let atom_id = match crate::cstr_to_str(
        atom_id_utf8, atom_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match remove_entry(conn, atom_id) {
            Ok(true) => 1,
            Ok(false) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_vector_index_count(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_entries(conn).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_vector_index_count_for_domain(
    engine: *const L8Engine,
    domain_utf8: *const c_char, domain_len: usize,
) -> i64 {
    if engine.is_null() { return -1; }
    let domain = match crate::cstr_to_str(
        domain_utf8, domain_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_entries_for_domain(conn, domain).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_vector_index_count_for_provider(
    engine: *const L8Engine,
    provider_version_utf8: *const c_char,
    provider_version_len: usize,
) -> i64 {
    if engine.is_null() { return -1; }
    let provider_version = match crate::cstr_to_str(
        provider_version_utf8, provider_version_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_entries_for_provider(conn, provider_version)
            .unwrap_or(-2)
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
    fn upsert_returns_true_on_insert_false_on_replace() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_vector_index_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            // Mock 4-dim f32 embedding = 16 bytes
            let emb_v1 = [0x10u8; 16];
            let emb_v2 = [0x20u8; 16];
            assert_eq!(
                upsert_entry(conn, "atom-1", 4, "p-v1",
                    &emb_v1, "domain-A", "{}").unwrap(),
                true, "First insert returns true");
            assert_eq!(
                upsert_entry(conn, "atom-1", 4, "p-v1",
                    &emb_v2, "domain-A", "{}").unwrap(),
                false, "Replace returns false");
            assert_eq!(count_entries(conn).unwrap(), 1,
                "Total count still 1 after replace");
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn remove_returns_correct_bool() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_vector_index_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let emb = [0u8; 16];
            upsert_entry(conn, "x", 4, "pv", &emb, "d",
                "{}").unwrap();
            assert_eq!(
                remove_entry(conn, "x").unwrap(), true);
            assert_eq!(
                remove_entry(conn, "x").unwrap(), false,
                "Re-remove returns false");
            assert_eq!(count_entries(conn).unwrap(), 0);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn per_domain_and_per_provider_counts() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_vector_index_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let emb = [0u8; 16];
            upsert_entry(conn, "a1", 4, "p-v1", &emb,
                "d-A", "{}").unwrap();
            upsert_entry(conn, "a2", 4, "p-v1", &emb,
                "d-A", "{}").unwrap();
            upsert_entry(conn, "a3", 4, "p-v2", &emb,
                "d-B", "{}").unwrap();
            assert_eq!(count_entries(conn).unwrap(), 3);
            assert_eq!(
                count_entries_for_domain(
                    conn, "d-A").unwrap(), 2);
            assert_eq!(
                count_entries_for_provider(
                    conn, "p-v1").unwrap(), 2);
            assert_eq!(
                count_entries_for_provider(
                    conn, "p-v2").unwrap(), 1);
        });
        unsafe { bas_l8_engine_close(engine); }
    }
}
