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

// MARK: - chapter 九百三十七 / M3390 — full-row version query
//
// USER-PASS finding (ch 933) #4 substance fix:the ch 899 bridge
// labeled this「Full」 in L8_ROUTED_OVERVIEW.md but shipped 3
// stub methods (`versions(forVault:)`,`rollbackPoints(forVault:)`,
// `version(forID:)`)。
//
// Complication beyond ch 934-936:`signature_hash` is BLOB (raw
// bytes) in SQL → `Data` in Swift → must be base64-encoded in JSON
// (Foundation's JSONEncoder default for Data fields)。 Implement
// base64 here without adding a crate dep (chapter 894 minimal-dep
// doctrine)。

/// Standard RFC 4648 base64 encoder。 No dependency。
fn base64_encode(input: &[u8]) -> String {
    const ALPHABET: &[u8; 64] =
        b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::with_capacity(
        (input.len() + 2) / 3 * 4);
    let mut i = 0;
    while i + 3 <= input.len() {
        let b0 = input[i] as u32;
        let b1 = input[i + 1] as u32;
        let b2 = input[i + 2] as u32;
        let v = (b0 << 16) | (b1 << 8) | b2;
        out.push(ALPHABET[((v >> 18) & 0x3F) as usize] as char);
        out.push(ALPHABET[((v >> 12) & 0x3F) as usize] as char);
        out.push(ALPHABET[((v >> 6) & 0x3F) as usize] as char);
        out.push(ALPHABET[(v & 0x3F) as usize] as char);
        i += 3;
    }
    let remaining = input.len() - i;
    if remaining == 1 {
        let b0 = input[i] as u32;
        let v = b0 << 16;
        out.push(ALPHABET[((v >> 18) & 0x3F) as usize] as char);
        out.push(ALPHABET[((v >> 12) & 0x3F) as usize] as char);
        out.push('=');
        out.push('=');
    } else if remaining == 2 {
        let b0 = input[i] as u32;
        let b1 = input[i + 1] as u32;
        let v = (b0 << 16) | (b1 << 8);
        out.push(ALPHABET[((v >> 18) & 0x3F) as usize] as char);
        out.push(ALPHABET[((v >> 12) & 0x3F) as usize] as char);
        out.push(ALPHABET[((v >> 6) & 0x3F) as usize] as char);
        out.push('=');
    }
    out
}

fn escape_json(s: &str) -> String {
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

fn row_to_json(
    version_id: &str,
    vault_id: &str,
    parent_version_id: Option<String>,
    created_at_ms: i64,
    signature_hash: Vec<u8>,
    is_rollback_point: bool,
    merged_from_json: Option<String>,
) -> String {
    let mut out = String::from("{");
    out.push_str(&format!(
        "\"versionID\":\"{}\",", escape_json(version_id)));
    out.push_str(&format!(
        "\"vaultID\":\"{}\",", escape_json(vault_id)));
    match parent_version_id {
        Some(s) => out.push_str(&format!(
            "\"parentVersionID\":\"{}\",", escape_json(&s))),
        None => out.push_str("\"parentVersionID\":null,"),
    }
    out.push_str(&format!(
        "\"createdAtMs\":{},", created_at_ms));
    // Foundation JSONEncoder encodes Data as base64 by default
    out.push_str(&format!(
        "\"signatureHash\":\"{}\",",
        base64_encode(&signature_hash)));
    out.push_str(&format!(
        "\"isRollbackPoint\":{}",
        if is_rollback_point { "true" } else { "false" }));
    match merged_from_json {
        Some(s) => out.push_str(&format!(
            ",\"mergedFromJson\":\"{}\"", escape_json(&s))),
        None => out.push_str(",\"mergedFromJson\":null"),
    }
    out.push('}');
    out
}

pub fn versions_for_vault_json(
    conn: &Connection,
    vault_id: &str,
) -> rusqlite::Result<String> {
    // chapter 九百四十四 / M3425 fix HIGH — implicit MAX_HOTPATH_LIMIT cap
    let mut stmt = conn.prepare(
        "SELECT version_id, vault_id, parent_version_id, \
                created_at_ms, signature_hash, \
                is_rollback_point, merged_from_json \
         FROM host_constitution_version_tree \
         WHERE vault_id = ? \
         ORDER BY created_at_ms \
         LIMIT ?")?;
    let mut rows = stmt.query(params![
        vault_id, crate::MAX_HOTPATH_LIMIT as i64])?;
    let mut out = String::from("[");
    let mut first = true;
    while let Some(row) = rows.next()? {
        if !first { out.push(','); }
        first = false;
        let json = row_to_json(
            &row.get::<_, String>(0)?,
            &row.get::<_, String>(1)?,
            row.get::<_, Option<String>>(2)?,
            row.get::<_, i64>(3)?,
            row.get::<_, Vec<u8>>(4)?,
            row.get::<_, i64>(5)? != 0,
            row.get::<_, Option<String>>(6)?,
        );
        out.push_str(&json);
    }
    out.push(']');
    Ok(out)
}

pub fn rollback_points_for_vault_json(
    conn: &Connection,
    vault_id: &str,
) -> rusqlite::Result<String> {
    // chapter 九百四十四 / M3425 fix HIGH — implicit MAX_HOTPATH_LIMIT cap
    let mut stmt = conn.prepare(
        "SELECT version_id, vault_id, parent_version_id, \
                created_at_ms, signature_hash, \
                is_rollback_point, merged_from_json \
         FROM host_constitution_version_tree \
         WHERE vault_id = ? AND is_rollback_point = 1 \
         ORDER BY created_at_ms \
         LIMIT ?")?;
    let mut rows = stmt.query(params![
        vault_id, crate::MAX_HOTPATH_LIMIT as i64])?;
    let mut out = String::from("[");
    let mut first = true;
    while let Some(row) = rows.next()? {
        if !first { out.push(','); }
        first = false;
        let json = row_to_json(
            &row.get::<_, String>(0)?,
            &row.get::<_, String>(1)?,
            row.get::<_, Option<String>>(2)?,
            row.get::<_, i64>(3)?,
            row.get::<_, Vec<u8>>(4)?,
            row.get::<_, i64>(5)? != 0,
            row.get::<_, Option<String>>(6)?,
        );
        out.push_str(&json);
    }
    out.push(']');
    Ok(out)
}

pub fn version_for_id_json(
    conn: &Connection,
    version_id: &str,
) -> rusqlite::Result<Option<String>> {
    let r = conn.query_row(
        "SELECT version_id, vault_id, parent_version_id, \
                created_at_ms, signature_hash, \
                is_rollback_point, merged_from_json \
         FROM host_constitution_version_tree \
         WHERE version_id = ?",
        params![version_id],
        |row| Ok(row_to_json(
            &row.get::<_, String>(0)?,
            &row.get::<_, String>(1)?,
            row.get::<_, Option<String>>(2)?,
            row.get::<_, i64>(3)?,
            row.get::<_, Vec<u8>>(4)?,
            row.get::<_, i64>(5)? != 0,
            row.get::<_, Option<String>>(6)?,
        )));
    match r {
        Ok(s) => Ok(Some(s)),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(e),
    }
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
    // chapter 九百二十三 / M3320 NH3 fix:bound
    // signature_hash size (32 SHA256 / 64 SHA512 — cap at 64)
    if signature_hash_len > crate::MAX_SIGNATURE_HASH_BYTES {
        return -3;
    }
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

// chapter 九百三十七 / M3390 — full-row version JSON FFI
// (USER-PASS substance fix #4)。 Probe + fill pattern。
// `signature_hash` BLOB → base64 string in JSON (Foundation
// JSONEncoder default for Codable Data fields)。

unsafe fn versions_json_ffi(
    engine: *const L8Engine,
    key_utf8: *const c_char,
    key_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
    by_vault: bool,
    rollback_only: bool,
) -> i32 {
    if engine.is_null() { return -1; }
    let key = match crate::cstr_to_str(key_utf8, key_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    let json_result = engine_ref.with_conn(|conn| {
        if by_vault && rollback_only {
            rollback_points_for_vault_json(conn, key)
        } else if by_vault {
            versions_for_vault_json(conn, key)
        } else {
            // by_id case — wraps Optional into "[]" or "[obj]"
            // ACTUALLY: separate FFI below for single-obj case
            unreachable!()
        }
    });
    let json = match json_result {
        Ok(s) => s, Err(_) => return -2,
    };
    let bytes = json.as_bytes();
    let needed = bytes.len();
    // chapter 九百四十一 / M3410 fix HIGH — i32 overflow guard
    let safe_needed = match crate::safe_i32_size(needed) {
        Ok(n) => n, Err(c) => return c,
    };
    if out_buf.is_null() || out_capacity == 0 {
        return safe_needed;
    }
    if out_capacity < needed { return -3; }
    unsafe {
        std::ptr::copy_nonoverlapping(
            bytes.as_ptr(), out_buf, needed);
    }
    safe_needed
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_version_tree_versions_for_vault(
    engine: *const L8Engine,
    vault_id_utf8: *const c_char, vault_id_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
) -> i32 {
    versions_json_ffi(
        engine, vault_id_utf8, vault_id_len,
        out_buf, out_capacity, true, false)
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_version_tree_rollback_points_for_vault(
    engine: *const L8Engine,
    vault_id_utf8: *const c_char, vault_id_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
) -> i32 {
    versions_json_ffi(
        engine, vault_id_utf8, vault_id_len,
        out_buf, out_capacity, true, true)
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_version_tree_for_id(
    engine: *const L8Engine,
    version_id_utf8: *const c_char, version_id_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
) -> i32 {
    if engine.is_null() { return -1; }
    let key = match crate::cstr_to_str(
        version_id_utf8, version_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    let res = engine_ref.with_conn(|conn| {
        version_for_id_json(conn, key)
    });
    let opt = match res { Ok(o) => o, Err(_) => return -2 };
    let json = match opt {
        Some(s) => s,
        None => return 0, // not found
    };
    let bytes = json.as_bytes();
    let needed = bytes.len();
    if needed == 0 { return 0; }
    // chapter 九百四十一 / M3410 fix HIGH — i32 overflow guard
    let safe_needed = match crate::safe_i32_size(needed) {
        Ok(n) => n, Err(c) => return c,
    };
    if out_buf.is_null() || out_capacity == 0 {
        return safe_needed;
    }
    if out_capacity < needed { return -3; }
    unsafe {
        std::ptr::copy_nonoverlapping(
            bytes.as_ptr(), out_buf, needed);
    }
    safe_needed
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

    // chapter 九百三十七 / M3390 — base64 encoder unit test
    #[test]
    fn base64_encode_matches_rfc4648() {
        // Test vectors from RFC 4648 §10
        assert_eq!(base64_encode(b""), "");
        assert_eq!(base64_encode(b"f"), "Zg==");
        assert_eq!(base64_encode(b"fo"), "Zm8=");
        assert_eq!(base64_encode(b"foo"), "Zm9v");
        assert_eq!(base64_encode(b"foob"), "Zm9vYg==");
        assert_eq!(base64_encode(b"fooba"), "Zm9vYmE=");
        assert_eq!(base64_encode(b"foobar"), "Zm9vYmFy");
        // 32-byte SHA-256 length (most common signature_hash)
        let sha = vec![0xABu8; 32];
        assert_eq!(base64_encode(&sha).len(), 44,
            "32 bytes encodes to 44 base64 chars");
    }

    // chapter 九百三十七 / M3390 — versions JSON round-trip
    #[test]
    fn versions_for_vault_json_round_trip() {
        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0) };
        let _ = unsafe {
            bas_l8_version_tree_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let sig1 = vec![0x01, 0x02, 0x03];
            let sig2 = vec![0xff, 0xfe, 0xfd];
            append_version(conn, "v1", "vault-RT",
                None, 100, &sig1, false, None).unwrap();
            append_version(conn, "v2", "vault-RT",
                Some("v1"), 200, &sig2, true,
                Some("[\"src-1\",\"src-2\"]")).unwrap();
            let json = versions_for_vault_json(
                conn, "vault-RT").unwrap();
            assert!(json.contains("\"versionID\":\"v1\""));
            assert!(json.contains("\"versionID\":\"v2\""));
            assert!(json.contains("\"parentVersionID\":\"v1\""));
            assert!(json.contains("\"parentVersionID\":null"));
            assert!(json.contains("\"isRollbackPoint\":true"));
            assert!(json.contains("\"isRollbackPoint\":false"));
            // base64: [0x01,0x02,0x03] = "AQID"
            assert!(json.contains("\"signatureHash\":\"AQID\""));
            // base64: [0xff,0xfe,0xfd] = "//79"
            assert!(json.contains("\"signatureHash\":\"//79\""));
            // ordering: created_at_ms ASC
            let p1 = json.find("\"versionID\":\"v1\"").unwrap();
            let p2 = json.find("\"versionID\":\"v2\"").unwrap();
            assert!(p1 < p2);
            // rollback_points filter
            let rb = rollback_points_for_vault_json(
                conn, "vault-RT").unwrap();
            assert!(rb.contains("\"versionID\":\"v2\""));
            assert!(!rb.contains("\"versionID\":\"v1\""));
            // version_for_id
            let one = version_for_id_json(conn, "v1").unwrap();
            assert!(one.is_some());
            assert!(one.unwrap().contains("\"versionID\":\"v1\""));
            let missing = version_for_id_json(
                conn, "no-such").unwrap();
            assert!(missing.is_none());
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn version_for_id_ffi_probe_fill() {
        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0) };
        let _ = unsafe {
            bas_l8_version_tree_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let sig = vec![0xaa; 32];
            append_version(conn, "ffi-v", "ffi-vault",
                None, 100, &sig, false, None).unwrap();
        });
        let vid = "ffi-v";
        // probe
        let needed = unsafe {
            bas_l8_version_tree_for_id(
                engine,
                vid.as_ptr() as *const c_char, vid.len(),
                std::ptr::null_mut(), 0)
        };
        assert!(needed > 0);
        let mut buf = vec![0u8; needed as usize];
        let written = unsafe {
            bas_l8_version_tree_for_id(
                engine,
                vid.as_ptr() as *const c_char, vid.len(),
                buf.as_mut_ptr(), buf.len())
        };
        assert_eq!(written, needed);
        let json = std::str::from_utf8(&buf).unwrap();
        assert!(json.contains("\"versionID\":\"ffi-v\""));
        // not found returns 0
        let missing = "no-such";
        let rc = unsafe {
            bas_l8_version_tree_for_id(
                engine,
                missing.as_ptr() as *const c_char,
                missing.len(),
                std::ptr::null_mut(), 0)
        };
        assert_eq!(rc, 0);
        unsafe { bas_l8_engine_close(engine); }
    }
}
