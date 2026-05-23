// SPDX:internal
//
// version_tree.rs — chapter 八百九十九 / M3185
//
// L8 unification MED-risk migration #4 per RFC。 Ports
// BASSQLiteHostConstitutionVersionTreeStore (schema 014:
// host_constitution_version_tree)。
//
// Adds first BLOB FFI support to bas-l8-engine for the 32-byte
// signature_hash column。 Pattern:pass `(ptr: *const u8, len:
// usize)` for raw bytes;use rusqlite's `params!` which accepts
// `&[u8]` directly。

use std::os::raw::{c_char, c_int};
use rusqlite::Connection;
use rusqlite::params;

use crate::L8Engine;

const SCHEMA_014: &str = r#"
CREATE TABLE IF NOT EXISTS host_constitution_version_tree (
    version_id TEXT PRIMARY KEY NOT NULL,
    vault_id TEXT NOT NULL,
    parent_version_id TEXT,
    created_at_ms INTEGER NOT NULL,
    signature_hash BLOB NOT NULL,
    is_rollback_point INTEGER NOT NULL DEFAULT 0
        CHECK (is_rollback_point IN (0, 1)),
    merged_from_json TEXT
);
CREATE INDEX IF NOT EXISTS hcvt_vault_idx
  ON host_constitution_version_tree(vault_id, created_at_ms);
CREATE INDEX IF NOT EXISTS hcvt_parent_idx
  ON host_constitution_version_tree(parent_version_id);
CREATE INDEX IF NOT EXISTS hcvt_rollback_idx
  ON host_constitution_version_tree(is_rollback_point);
CREATE INDEX IF NOT EXISTS hcvt_created_at_idx
  ON host_constitution_version_tree(created_at_ms);
"#;

pub fn init_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_014)?;
    Ok(())
}

pub fn append_version(
    conn: &Connection,
    version_id: &str,
    vault_id: &str,
    parent_version_id: Option<&str>,
    created_at_ms: i64,
    signature_hash: &[u8],
    is_rollback_point: bool,
    merged_from_json: Option<&str>,
) -> rusqlite::Result<()> {
    conn.execute(
        "INSERT INTO host_constitution_version_tree (
            version_id, vault_id, parent_version_id,
            created_at_ms, signature_hash,
            is_rollback_point, merged_from_json
         ) VALUES (?, ?, ?, ?, ?, ?, ?)",
        params![
            version_id, vault_id, parent_version_id,
            created_at_ms, signature_hash,
            if is_rollback_point { 1i32 } else { 0i32 },
            merged_from_json,
        ],
    )?;
    Ok(())
}

pub fn count_versions(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM host_constitution_version_tree",
        [], |row| row.get(0))
}

pub fn count_versions_for_vault(
    conn: &Connection,
    vault_id: &str,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM host_constitution_version_tree
         WHERE vault_id = ?",
        params![vault_id], |row| row.get(0))
}

pub fn count_rollback_points_for_vault(
    conn: &Connection,
    vault_id: &str,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM host_constitution_version_tree
         WHERE vault_id = ? AND is_rollback_point = 1",
        params![vault_id], |row| row.get(0))
}

// MARK: - FFI

#[no_mangle]
pub unsafe extern "C" fn bas_l8_version_tree_init_schema(
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

/// Append a version row。 signature_hash is BLOB (raw bytes,
/// no length prefix)。 Optional fields use `*_len == 0` to
/// mean SQL NULL。
#[no_mangle]
pub unsafe extern "C" fn bas_l8_version_tree_append(
    engine: *const L8Engine,
    version_id_utf8: *const c_char, version_id_len: usize,
    vault_id_utf8: *const c_char, vault_id_len: usize,
    parent_version_id_utf8: *const c_char,
    parent_version_id_len: usize,
    created_at_ms: i64,
    signature_hash_bytes: *const u8, signature_hash_len: usize,
    is_rollback_point: u8,  // 0 or 1
    merged_from_json_utf8: *const c_char,
    merged_from_json_len: usize,
) -> c_int {
    if engine.is_null() { return -1; }
    let version_id = match crate::cstr_to_str(
        version_id_utf8, version_id_len) {
        Some(s) => s, None => return -3,
    };
    let vault_id = match crate::cstr_to_str(
        vault_id_utf8, vault_id_len) {
        Some(s) => s, None => return -3,
    };
    let parent_version_id = if parent_version_id_len == 0 {
        None
    } else {
        match crate::cstr_to_str(
            parent_version_id_utf8,
            parent_version_id_len) {
            Some(s) => Some(s),
            None => return -3,
        }
    };
    let merged_from_json = if merged_from_json_len == 0 {
        None
    } else {
        match crate::cstr_to_str(
            merged_from_json_utf8,
            merged_from_json_len) {
            Some(s) => Some(s),
            None => return -3,
        }
    };
    // Blob bytes — null-with-zero-len is OK but empty hash is
    // a constraint failure at SQL level (NOT NULL)。
    if signature_hash_bytes.is_null()
        && signature_hash_len > 0 {
        return -3;
    }
    let signature_hash: &[u8] = if signature_hash_len == 0 {
        &[]
    } else {
        unsafe {
            core::slice::from_raw_parts(
                signature_hash_bytes, signature_hash_len)
        }
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match append_version(
            conn, version_id, vault_id, parent_version_id,
            created_at_ms, signature_hash,
            is_rollback_point != 0,
            merged_from_json)
        {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_version_tree_count(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_versions(conn).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_version_tree_count_for_vault(
    engine: *const L8Engine,
    vault_id_utf8: *const c_char, vault_id_len: usize,
) -> i64 {
    if engine.is_null() { return -1; }
    let vault_id = match crate::cstr_to_str(
        vault_id_utf8, vault_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_versions_for_vault(conn, vault_id).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_version_tree_count_rollback_points(
    engine: *const L8Engine,
    vault_id_utf8: *const c_char, vault_id_len: usize,
) -> i64 {
    if engine.is_null() { return -1; }
    let vault_id = match crate::cstr_to_str(
        vault_id_utf8, vault_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_rollback_points_for_vault(
            conn, vault_id).unwrap_or(-2)
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
    fn append_with_blob_signature_hash() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_version_tree_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let hash = [0x42u8; 32];  // 32-byte SHA256 stub
            append_version(
                conn, "v1", "vault-A", None, 100,
                &hash, false, None).unwrap();
            append_version(
                conn, "v2", "vault-A", Some("v1"), 200,
                &hash, true, None).unwrap();
            assert_eq!(count_versions(conn).unwrap(), 2);
            assert_eq!(
                count_versions_for_vault(conn, "vault-A").unwrap(),
                2);
            assert_eq!(
                count_rollback_points_for_vault(
                    conn, "vault-A").unwrap(),
                1, "Only v2 is rollback point");
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn ffi_append_with_blob() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_version_tree_init_schema(engine) };
        let vid = "ffi-v1";
        let vault = "ffi-vault";
        let hash = [0xAAu8; 32];
        let rc = unsafe {
            bas_l8_version_tree_append(
                engine,
                vid.as_ptr() as *const c_char, vid.len(),
                vault.as_ptr() as *const c_char, vault.len(),
                std::ptr::null(), 0,  // no parent
                500,
                hash.as_ptr(), hash.len(),
                1,  // is_rollback_point = true
                std::ptr::null(), 0,  // no merged_from
            )
        };
        assert_eq!(rc, 0);
        let count = unsafe {
            bas_l8_version_tree_count(engine) };
        assert_eq!(count, 1);
        let rb = unsafe {
            bas_l8_version_tree_count_rollback_points(
                engine,
                vault.as_ptr() as *const c_char,
                vault.len())
        };
        assert_eq!(rb, 1);
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn duplicate_version_id_constraint() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_version_tree_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let hash = [0u8; 32];
            append_version(
                conn, "dup", "v", None, 0,
                &hash, false, None).unwrap();
            let r = append_version(
                conn, "dup", "v", None, 0,
                &hash, false, None);
            assert!(r.is_err(),
                "Duplicate version_id must trip PRIMARY KEY");
        });
        unsafe { bas_l8_engine_close(engine); }
    }
}
