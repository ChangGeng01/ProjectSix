// SPDX:internal
//
// deletion_manifest.rs — chapter 八百九十五 / M3165
//
// L8 Rust unification LOW-risk pilot migration per
// Docs/L8_RUST_UNIFICATION_RFC.md。 Ports schema 015 +
// `BASSQLiteHostConstitutionDeletionManifestStore` SQL queries
// to Rust + rusqlite。 Append-only forensic trail for L5 host
// constitution deletes (cascade / selective / rollback)。
//
// Byte-equality with the Swift actor's INSERT/SELECT shapes is
// the wiring invariant — chapter 896 Swift bridge byte-eq tests
// will pin this。 This chapter ships the Rust module only。
//
// # Schema (embedded via include_str! per RFC q4)
//
// CREATE TABLE host_constitution_deletion_manifest (
//   manifest_id TEXT PRIMARY KEY,
//   vault_id TEXT NOT NULL,
//   target_refs_json TEXT NOT NULL,
//   deletion_type TEXT NOT NULL,  -- cascade / selective / rollback
//   applied_at_ms INTEGER NOT NULL,
//   cascaded_refs_json TEXT,
//   version_ref TEXT
// );
// + 4 indexes per chapter 七百六十九 / M2496

use std::os::raw::{c_char, c_int};
use rusqlite::Connection;
use rusqlite::params;

use crate::L8Engine;

// MARK: - Embedded schema (per RFC q4: include_str! at build time)

/// Schema 015 SQL — pinned at chapter 七百六十九 / M2496。
/// Embedded so no IO at init + reproducible builds。
const SCHEMA_015: &str = r#"
CREATE TABLE IF NOT EXISTS host_constitution_deletion_manifest (
    manifest_id TEXT PRIMARY KEY NOT NULL,
    vault_id TEXT NOT NULL,
    target_refs_json TEXT NOT NULL,
    deletion_type TEXT NOT NULL CHECK (deletion_type IN
        ('cascade', 'selective', 'rollback')),
    applied_at_ms INTEGER NOT NULL,
    cascaded_refs_json TEXT,
    version_ref TEXT
);
CREATE INDEX IF NOT EXISTS hcdm_vault_idx
  ON host_constitution_deletion_manifest(vault_id, applied_at_ms);
CREATE INDEX IF NOT EXISTS hcdm_applied_at_idx
  ON host_constitution_deletion_manifest(applied_at_ms);
CREATE INDEX IF NOT EXISTS hcdm_deletion_type_idx
  ON host_constitution_deletion_manifest(deletion_type);
CREATE INDEX IF NOT EXISTS hcdm_version_ref_idx
  ON host_constitution_deletion_manifest(version_ref);
"#;

// MARK: - Schema init (idempotent)

/// Initialize schema 015 on the connection。 Idempotent —
/// existing tables/indexes pass through CREATE IF NOT EXISTS。
pub fn init_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_015)?;
    Ok(())
}

// MARK: - Pure-Rust operations (callable from tests + FFI)

pub fn append_manifest(
    conn: &Connection,
    manifest_id: &str,
    vault_id: &str,
    target_refs_json: &str,
    deletion_type: &str,
    applied_at_ms: i64,
    cascaded_refs_json: Option<&str>,
    version_ref: Option<&str>,
) -> rusqlite::Result<()> {
    conn.execute(
        "INSERT INTO host_constitution_deletion_manifest (
            manifest_id, vault_id, target_refs_json,
            deletion_type, applied_at_ms,
            cascaded_refs_json, version_ref
         ) VALUES (?, ?, ?, ?, ?, ?, ?)",
        params![
            manifest_id, vault_id, target_refs_json,
            deletion_type, applied_at_ms,
            cascaded_refs_json, version_ref,
        ],
    )?;
    Ok(())
}

pub fn count_manifests(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM host_constitution_deletion_manifest",
        [],
        |row| row.get(0),
    )
}

pub fn count_manifests_for_vault(
    conn: &Connection,
    vault_id: &str,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM host_constitution_deletion_manifest
         WHERE vault_id = ?",
        params![vault_id],
        |row| row.get(0),
    )
}

// MARK: - chapter 九百三十五 / M3380 — full-row manifests query
//
// USER-PASS finding (ch 933) #2 substance fix:the ch 896 bridge
// labeled this「Full」 in L8_ROUTED_OVERVIEW.md but shipped
// `return []` + assertionFailure() stubs。 Recipe matches ch 934
// (atom_lifecycle):manual JSON construction + probe+fill FFI。
//
// JSON shape:array of `BASHostConstitutionDeletionRecord` Codable
// objects — manifestID,vaultID,targetRefsJson,deletionType,
// appliedAtMs,cascadedRefsJson (optional),versionRef (optional)。

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
    manifest_id: &str,
    vault_id: &str,
    target_refs_json: &str,
    deletion_type: &str,
    applied_at_ms: i64,
    cascaded_refs_json: Option<String>,
    version_ref: Option<String>,
) -> String {
    let mut out = String::from("{");
    out.push_str(&format!(
        "\"manifestID\":\"{}\",", escape_json(manifest_id)));
    out.push_str(&format!(
        "\"vaultID\":\"{}\",", escape_json(vault_id)));
    out.push_str(&format!(
        "\"targetRefsJson\":\"{}\",",
        escape_json(target_refs_json)));
    out.push_str(&format!(
        "\"deletionType\":\"{}\",",
        escape_json(deletion_type)));
    out.push_str(&format!(
        "\"appliedAtMs\":{}", applied_at_ms));
    match cascaded_refs_json {
        Some(s) => out.push_str(&format!(
            ",\"cascadedRefsJson\":\"{}\"", escape_json(&s))),
        None => out.push_str(",\"cascadedRefsJson\":null"),
    }
    match version_ref {
        Some(s) => out.push_str(&format!(
            ",\"versionRef\":\"{}\"", escape_json(&s))),
        None => out.push_str(",\"versionRef\":null"),
    }
    out.push('}');
    out
}

pub fn manifests_for_vault_json(
    conn: &Connection,
    vault_id: &str,
) -> rusqlite::Result<String> {
    let mut stmt = conn.prepare(
        "SELECT manifest_id, vault_id, target_refs_json, \
                deletion_type, applied_at_ms, \
                cascaded_refs_json, version_ref \
         FROM host_constitution_deletion_manifest \
         WHERE vault_id = ? \
         ORDER BY applied_at_ms")?;
    let mut rows = stmt.query(params![vault_id])?;
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
            row.get::<_, i64>(4)?,
            row.get::<_, Option<String>>(5)?,
            row.get::<_, Option<String>>(6)?,
        );
        out.push_str(&json);
    }
    out.push(']');
    Ok(out)
}

pub fn manifests_for_type_json(
    conn: &Connection,
    deletion_type: &str,
) -> rusqlite::Result<String> {
    let mut stmt = conn.prepare(
        "SELECT manifest_id, vault_id, target_refs_json, \
                deletion_type, applied_at_ms, \
                cascaded_refs_json, version_ref \
         FROM host_constitution_deletion_manifest \
         WHERE deletion_type = ? \
         ORDER BY applied_at_ms")?;
    let mut rows = stmt.query(params![deletion_type])?;
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
            row.get::<_, i64>(4)?,
            row.get::<_, Option<String>>(5)?,
            row.get::<_, Option<String>>(6)?,
        );
        out.push_str(&json);
    }
    out.push(']');
    Ok(out)
}

// MARK: - FFI surface

/// Initialize schema 015 on the engine's connection。
/// Idempotent。 Returns 0 on success,-1 on null engine,
/// -2 on SQLite error。
///
/// # Safety
/// `engine` must be a valid pointer from
/// `bas_l8_engine_init` and not closed。
#[no_mangle]
pub unsafe extern "C" fn bas_l8_deletion_manifest_init_schema(
    engine: *const L8Engine,
) -> c_int {
    if engine.is_null() {
        return -1;
    }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match init_schema(conn) {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

/// Append a manifest row。 All string args are length-prefixed
/// UTF-8 (no NUL terminator assumed)。 Optional fields use
/// `*_len == 0` to mean SQL NULL。
///
/// Returns 0 on success,-1 on null engine / invalid input,
/// -2 on SQLite error (likely SQLITE_CONSTRAINT for duplicate
/// manifest_id),-3 on UTF-8 decode failure。
///
/// # Safety
/// All `*const c_char` pointers must point to `*_len` valid
/// UTF-8 bytes (or be null if the corresponding `*_len == 0`
/// for optional fields)。
#[no_mangle]
pub unsafe extern "C" fn bas_l8_deletion_manifest_append(
    engine: *const L8Engine,
    manifest_id_utf8: *const c_char,
    manifest_id_len: usize,
    vault_id_utf8: *const c_char,
    vault_id_len: usize,
    target_refs_json_utf8: *const c_char,
    target_refs_json_len: usize,
    deletion_type_utf8: *const c_char,
    deletion_type_len: usize,
    applied_at_ms: i64,
    cascaded_refs_json_utf8: *const c_char,
    cascaded_refs_json_len: usize,
    version_ref_utf8: *const c_char,
    version_ref_len: usize,
) -> c_int {
    if engine.is_null() {
        return -1;
    }
    // Decode required strings
    let manifest_id = match crate::cstr_to_str(
        manifest_id_utf8, manifest_id_len)
    {
        Some(s) => s,
        None => return -3,
    };
    let vault_id = match crate::cstr_to_str(
        vault_id_utf8, vault_id_len)
    {
        Some(s) => s,
        None => return -3,
    };
    let target_refs_json = match crate::cstr_to_str(
        target_refs_json_utf8, target_refs_json_len)
    {
        Some(s) => s,
        None => return -3,
    };
    let deletion_type = match crate::cstr_to_str(
        deletion_type_utf8, deletion_type_len)
    {
        Some(s) => s,
        None => return -3,
    };
    // Decode optional strings (len == 0 → None for SQL NULL)
    let cascaded_refs_json = if cascaded_refs_json_len == 0 {
        None
    } else {
        match crate::cstr_to_str(
            cascaded_refs_json_utf8, cascaded_refs_json_len)
        {
            Some(s) => Some(s),
            None => return -3,
        }
    };
    let version_ref = if version_ref_len == 0 {
        None
    } else {
        match crate::cstr_to_str(
            version_ref_utf8, version_ref_len)
        {
            Some(s) => Some(s),
            None => return -3,
        }
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match append_manifest(
            conn, manifest_id, vault_id, target_refs_json,
            deletion_type, applied_at_ms,
            cascaded_refs_json, version_ref)
        {
            Ok(()) => 0,
            Err(_) => -2,
        }
    })
}

/// Count manifests total (across all vaults)。 Returns count or
/// -1 on null engine,-2 on SQLite error。
#[no_mangle]
pub unsafe extern "C" fn bas_l8_deletion_manifest_count(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() {
        return -1;
    }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_manifests(conn).unwrap_or(-2)
    })
}

/// Count manifests for a specific vault。 Returns count or
/// -1 on null,-2 on SQLite error,-3 on UTF-8 decode failure。
///
/// # Safety
/// `vault_id_utf8` must point to `vault_id_len` valid UTF-8 bytes。
#[no_mangle]
pub unsafe extern "C" fn bas_l8_deletion_manifest_count_for_vault(
    engine: *const L8Engine,
    vault_id_utf8: *const c_char,
    vault_id_len: usize,
) -> i64 {
    if engine.is_null() {
        return -1;
    }
    let vault_id = match crate::cstr_to_str(
        vault_id_utf8, vault_id_len)
    {
        Some(s) => s,
        None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_manifests_for_vault(conn, vault_id).unwrap_or(-2)
    })
}

// chapter 九百三十五 / M3380 — full-row manifests JSON FFI
// USER-PASS substance fix #2 (ch 933 follow-through)。
// Probe + fill pattern matching ch 934 atom_lifecycle FFI。

unsafe fn manifests_json_ffi(
    engine: *const L8Engine,
    key_utf8: *const c_char,
    key_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
    by_vault: bool,
) -> i32 {
    if engine.is_null() { return -1; }
    let key = match crate::cstr_to_str(key_utf8, key_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    let json_result = engine_ref.with_conn(|conn| {
        if by_vault {
            manifests_for_vault_json(conn, key)
        } else {
            manifests_for_type_json(conn, key)
        }
    });
    let json = match json_result {
        Ok(s) => s,
        Err(_) => return -2,
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
pub unsafe extern "C" fn bas_l8_deletion_manifest_for_vault(
    engine: *const L8Engine,
    vault_id_utf8: *const c_char, vault_id_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
) -> i32 {
    manifests_json_ffi(
        engine, vault_id_utf8, vault_id_len,
        out_buf, out_capacity, true)
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_deletion_manifest_for_type(
    engine: *const L8Engine,
    deletion_type_utf8: *const c_char, deletion_type_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
) -> i32 {
    manifests_json_ffi(
        engine, deletion_type_utf8, deletion_type_len,
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
    fn init_schema_succeeds_idempotently() {
        let engine = make_engine();
        let rc1 = unsafe {
            bas_l8_deletion_manifest_init_schema(engine)
        };
        assert_eq!(rc1, 0);
        // Second call should also succeed (idempotent)
        let rc2 = unsafe {
            bas_l8_deletion_manifest_init_schema(engine)
        };
        assert_eq!(rc2, 0);
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn init_schema_on_null_engine_returns_minus_one() {
        let rc = unsafe {
            bas_l8_deletion_manifest_init_schema(
                std::ptr::null())
        };
        assert_eq!(rc, -1);
    }

    #[test]
    fn append_manifest_basic_round_trip() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_deletion_manifest_init_schema(engine)
        };
        // Direct Rust path (no FFI)
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            append_manifest(
                conn,
                "manifest-1",
                "vault-A",
                r#"["host.v1","host.v2"]"#,
                "cascade",
                1_700_000_000_000,
                Some(r#"["dep1","dep2"]"#),
                Some("version-X"),
            ).unwrap();
            let count = count_manifests(conn).unwrap();
            assert_eq!(count, 1);
            let count_a = count_manifests_for_vault(
                conn, "vault-A").unwrap();
            assert_eq!(count_a, 1);
            let count_b = count_manifests_for_vault(
                conn, "vault-B").unwrap();
            assert_eq!(count_b, 0);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn append_manifest_ffi_round_trip() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_deletion_manifest_init_schema(engine)
        };
        let manifest_id = "manifest-2";
        let vault_id = "vault-FFI";
        let target_refs = r#"["t1"]"#;
        let dtype = "selective";
        let rc = unsafe {
            bas_l8_deletion_manifest_append(
                engine,
                manifest_id.as_ptr() as *const c_char,
                manifest_id.len(),
                vault_id.as_ptr() as *const c_char,
                vault_id.len(),
                target_refs.as_ptr() as *const c_char,
                target_refs.len(),
                dtype.as_ptr() as *const c_char,
                dtype.len(),
                1_700_000_001_000,
                std::ptr::null(), 0,  // cascaded_refs_json = NULL
                std::ptr::null(), 0,  // version_ref = NULL
            )
        };
        assert_eq!(rc, 0, "FFI append must succeed");
        let count = unsafe {
            bas_l8_deletion_manifest_count(engine)
        };
        assert_eq!(count, 1);
        let count_for_vault = unsafe {
            bas_l8_deletion_manifest_count_for_vault(
                engine,
                vault_id.as_ptr() as *const c_char,
                vault_id.len())
        };
        assert_eq!(count_for_vault, 1);
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn append_manifest_duplicate_id_returns_minus_two() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_deletion_manifest_init_schema(engine)
        };
        let mid = "dup-id";
        let vid = "vault-dup";
        let tr = "[]";
        let dt = "rollback";
        let rc1 = unsafe {
            bas_l8_deletion_manifest_append(
                engine,
                mid.as_ptr() as *const c_char, mid.len(),
                vid.as_ptr() as *const c_char, vid.len(),
                tr.as_ptr() as *const c_char, tr.len(),
                dt.as_ptr() as *const c_char, dt.len(),
                1_700_000_002_000,
                std::ptr::null(), 0,
                std::ptr::null(), 0,
            )
        };
        assert_eq!(rc1, 0);
        // Second insert with same manifest_id → SQLITE_CONSTRAINT
        let rc2 = unsafe {
            bas_l8_deletion_manifest_append(
                engine,
                mid.as_ptr() as *const c_char, mid.len(),
                vid.as_ptr() as *const c_char, vid.len(),
                tr.as_ptr() as *const c_char, tr.len(),
                dt.as_ptr() as *const c_char, dt.len(),
                1_700_000_003_000,
                std::ptr::null(), 0,
                std::ptr::null(), 0,
            )
        };
        assert_eq!(rc2, -2,
            "Duplicate manifest_id must return SQLite error");
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn deletion_type_check_constraint_enforced() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_deletion_manifest_init_schema(engine)
        };
        let mid = "bad-type";
        let vid = "v";
        let tr = "[]";
        let dt = "invalid";  // not cascade/selective/rollback
        let rc = unsafe {
            bas_l8_deletion_manifest_append(
                engine,
                mid.as_ptr() as *const c_char, mid.len(),
                vid.as_ptr() as *const c_char, vid.len(),
                tr.as_ptr() as *const c_char, tr.len(),
                dt.as_ptr() as *const c_char, dt.len(),
                0, std::ptr::null(), 0, std::ptr::null(), 0,
            )
        };
        assert_eq!(rc, -2,
            "Invalid deletion_type must trip CHECK constraint");
        unsafe { bas_l8_engine_close(engine); }
    }

    // chapter 九百三十五 / M3380 — full-row JSON round-trip
    #[test]
    fn manifests_for_vault_json_round_trip() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_deletion_manifest_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            append_manifest(
                conn, "m1", "vault-RT",
                "[\"atom-1\"]", "cascade",
                1_700_000_000_000,
                Some("[\"cascade-A\"]"),
                Some("v1")).unwrap();
            append_manifest(
                conn, "m2", "vault-RT",
                "[\"atom-2\"]", "selective",
                1_700_000_001_000,
                None, None).unwrap();
            let json = manifests_for_vault_json(
                conn, "vault-RT").unwrap();
            // Both manifests present
            assert!(json.contains("\"manifestID\":\"m1\""));
            assert!(json.contains("\"manifestID\":\"m2\""));
            // Type strings present
            assert!(json.contains("\"deletionType\":\"cascade\""));
            assert!(json.contains("\"deletionType\":\"selective\""));
            // Optional fields:both present + null
            assert!(json.contains("\"cascadedRefsJson\":\"[\\\"cascade-A\\\"]\""));
            assert!(json.contains("\"cascadedRefsJson\":null"));
            assert!(json.contains("\"versionRef\":\"v1\""));
            assert!(json.contains("\"versionRef\":null"));
            // Ordering: applied_at_ms ASC → m1 before m2
            let p1 = json.find("\"manifestID\":\"m1\"").unwrap();
            let p2 = json.find("\"manifestID\":\"m2\"").unwrap();
            assert!(p1 < p2);
            // Empty vault case
            let empty = manifests_for_vault_json(
                conn, "vault-NONE").unwrap();
            assert_eq!(empty, "[]");
            // forType query
            let cascade_json = manifests_for_type_json(
                conn, "cascade").unwrap();
            assert!(cascade_json.contains("\"manifestID\":\"m1\""));
            assert!(!cascade_json.contains("\"manifestID\":\"m2\""));
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn manifests_for_vault_ffi_probe_fill() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_deletion_manifest_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            append_manifest(
                conn, "ffi-m1", "ffi-vault",
                "[]", "cascade",
                1_700_000_000_000, None, None).unwrap();
        });
        let vid = "ffi-vault";
        let needed = unsafe {
            bas_l8_deletion_manifest_for_vault(
                engine,
                vid.as_ptr() as *const c_char, vid.len(),
                std::ptr::null_mut(), 0)
        };
        assert!(needed > 0);
        let mut buf = vec![0u8; needed as usize];
        let written = unsafe {
            bas_l8_deletion_manifest_for_vault(
                engine,
                vid.as_ptr() as *const c_char, vid.len(),
                buf.as_mut_ptr(), buf.len())
        };
        assert_eq!(written, needed);
        let json = std::str::from_utf8(&buf).unwrap();
        assert!(json.contains("\"manifestID\":\"ffi-m1\""));
        // too-small buffer rejected
        let mut tiny = vec![0u8; 1];
        let rc = unsafe {
            bas_l8_deletion_manifest_for_vault(
                engine,
                vid.as_ptr() as *const c_char, vid.len(),
                tiny.as_mut_ptr(), tiny.len())
        };
        assert_eq!(rc, -3);
        unsafe { bas_l8_engine_close(engine); }
    }
}
