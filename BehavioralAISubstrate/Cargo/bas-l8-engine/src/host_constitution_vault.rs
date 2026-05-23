// SPDX:internal
//
// host_constitution_vault.rs — chapter 九百三 / M3215
//
// L8 unification HIGH-risk migration #3 per RFC。 Ports
// BASHostConstitutionSQLiteStorage:single-table schema
// holding one vault per row,with mirror columns for SQL
// filtering plus a full Codable JSON payload column。
//
// # Why single chapter
//
// Unlike chapter 902 (6 tables → 3 sub-chapters),HostConstitution
// storage is only:
//   - 621 LOC
//   - 7 public funcs
//   - 1 table
//
// Per RFC migration sequence this is the 3rd HIGH-risk store
// (after EventLog ch 901 + MemoryUsageTracker ch 902-902.6)。 The
// shape matches user_state (ch 898) — single-table UPSERT with
// JSON payload — but with 7 mirror columns instead of 4。
//
// # Schema (V1,byte-equality preserved from chapter 二百四十九)
//
//   CREATE TABLE host_constitution_vaults (
//     vault_id TEXT PRIMARY KEY NOT NULL,
//     host_id TEXT NOT NULL,
//     constitution_id TEXT NOT NULL,
//     active_version TEXT NOT NULL,
//     schema_version TEXT NOT NULL,
//     version_signature TEXT NOT NULL,
//     last_updated_at_ms INTEGER NOT NULL,
//     payload_json TEXT NOT NULL
//   );
//   CREATE INDEX host_constitution_host_idx
//     ON host_constitution_vaults(host_id);
//
// # UPSERT semantics (different from records-table!)
//
// Unlike `memory_usage_records` (only helped_state updates on
// conflict),host_constitution_vaults updates ALL non-PK
// columns on conflict。 The mirror columns track the latest
// snapshot's metadata。 This matches Swift `upsertVault` exactly。

use std::os::raw::{c_char, c_int};
use rusqlite::Connection;
use rusqlite::params;

use crate::L8Engine;

const SCHEMA_HOST_CONSTITUTION_VAULTS: &str = r#"
CREATE TABLE IF NOT EXISTS host_constitution_vaults (
    vault_id TEXT PRIMARY KEY NOT NULL,
    host_id TEXT NOT NULL,
    constitution_id TEXT NOT NULL,
    active_version TEXT NOT NULL,
    schema_version TEXT NOT NULL,
    version_signature TEXT NOT NULL,
    last_updated_at_ms INTEGER NOT NULL,
    payload_json TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS host_constitution_host_idx
  ON host_constitution_vaults(host_id);
-- chapter 九百二十 / M3305 HIGH-4 fix:index for chapter 913
-- all_vault_metadata hot path (ORDER BY last_updated_at_ms
-- DESC LIMIT N)。 Previously no index → full table scan +
-- sort。 At ~50 vaults today nobody notices,but at session
-- boot with multi-host scenarios this scales linearly。
CREATE INDEX IF NOT EXISTS host_constitution_updated_idx
  ON host_constitution_vaults(last_updated_at_ms DESC);
"#;

pub fn init_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_HOST_CONSTITUTION_VAULTS)?;
    Ok(())
}

/// UPSERT one vault。 Returns Ok(true) if a new row was
/// inserted, Ok(false) if an existing row was replaced
/// (mirrors Swift `save(_:) -> Bool` semantics)。
pub fn upsert_vault(
    conn: &Connection,
    vault_id: &str,
    host_id: &str,
    constitution_id: &str,
    active_version: &str,
    schema_version: &str,
    version_signature: &str,
    last_updated_at_ms: i64,
    payload_json: &str,
) -> rusqlite::Result<bool> {
    // chapter 九百十九 / M3300 CRITICAL fix C3 (vault)
    conn.execute("BEGIN IMMEDIATE TRANSACTION", [])?;
    let existed: bool = conn.query_row(
        "SELECT 1 FROM host_constitution_vaults
         WHERE vault_id = ? LIMIT 1",
        params![vault_id],
        |_| Ok(true),
    ).unwrap_or(false);
    let insert_result = conn.execute(
        "INSERT INTO host_constitution_vaults (
            vault_id, host_id, constitution_id,
            active_version, schema_version,
            version_signature, last_updated_at_ms,
            payload_json
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(vault_id) DO UPDATE SET
            host_id = excluded.host_id,
            constitution_id = excluded.constitution_id,
            active_version = excluded.active_version,
            schema_version = excluded.schema_version,
            version_signature = excluded.version_signature,
            last_updated_at_ms = excluded.last_updated_at_ms,
            payload_json = excluded.payload_json",
        params![
            vault_id, host_id, constitution_id,
            active_version, schema_version,
            version_signature, last_updated_at_ms,
            payload_json],
    );
    match insert_result {
        Ok(_) => {
            conn.execute("COMMIT", [])?;
            Ok(!existed)
        }
        Err(e) => {
            let _ = conn.execute("ROLLBACK", []);
            Err(e)
        }
    }
}

/// Returns the payload_json for a vault_id,or None if absent。
pub fn fetch_payload_json(
    conn: &Connection,
    vault_id: &str,
) -> rusqlite::Result<Option<String>> {
    let r: Option<String> = conn.query_row(
        "SELECT payload_json FROM host_constitution_vaults
         WHERE vault_id = ? LIMIT 1",
        params![vault_id], |row| row.get(0)
    ).ok();
    Ok(r)
}

/// Returns the payload_json for the first vault matching host_id
/// (typical single-host case),or None if no such vault。
pub fn fetch_first_payload_for_host(
    conn: &Connection,
    host_id: &str,
) -> rusqlite::Result<Option<String>> {
    let r: Option<String> = conn.query_row(
        "SELECT payload_json FROM host_constitution_vaults
         WHERE host_id = ? LIMIT 1",
        params![host_id], |row| row.get(0)
    ).ok();
    Ok(r)
}

/// DELETE one vault by vault_id。 Returns Ok(true) if a row
/// was removed,Ok(false) if vault_id was unknown。
pub fn delete_vault(
    conn: &Connection,
    vault_id: &str,
) -> rusqlite::Result<bool> {
    let n = conn.execute(
        "DELETE FROM host_constitution_vaults
         WHERE vault_id = ?",
        params![vault_id],
    )?;
    Ok(n > 0)
}

pub fn count_vaults(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM host_constitution_vaults",
        [], |row| row.get(0))
}

pub fn count_for_host(
    conn: &Connection,
    host_id: &str,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM host_constitution_vaults
         WHERE host_id = ?",
        params![host_id], |row| row.get(0))
}

/// chapter 九百十三 / M3270 — hot-path consolidation #4
/// (extending chapters 906 + 909 + 911 pattern to vault)。
///
/// Returns all vaults' (rowid, last_updated_at_ms) tuples
/// sorted DESC by last_updated_at_ms。 Boot-time loadAll
/// metadata path:caller can iterate all vaults' update
/// timestamps in ONE FFI call (vs N round-trip rowid + ts
/// fetches in the orchestrated baseline)。
///
/// Does NOT load full payloads — those are big JSON blobs,
/// caller fetches by rowid as needed via existing per-vault
/// FFIs。 The win comes from skipping N FFI hops on the
/// metadata scan that drives「which vaults need refresh」
/// decisions at session boot。
pub fn all_vault_metadata(
    conn: &Connection,
    limit: usize,
) -> rusqlite::Result<Vec<(i64, i64)>> {
    let mut stmt = conn.prepare(
        "SELECT rowid, last_updated_at_ms
           FROM host_constitution_vaults
          ORDER BY last_updated_at_ms DESC
          LIMIT ?"
    )?;
    let mut rows = stmt.query(params![limit as i64])?;
    let mut out: Vec<(i64, i64)> = Vec::with_capacity(limit);
    while let Some(row) = rows.next()? {
        let rowid: i64 = row.get(0)?;
        let ts: i64 = row.get(1)?;
        out.push((rowid, ts));
    }
    Ok(out)
}

// MARK: - FFI

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_host_constitution_vault_init_schema(
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
///   1  → new row inserted
///   0  → existing row replaced (UPSERT)
///   -1 → null engine
///   -2 → SQLite error
///   -3 → UTF-8 decode failure
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_host_constitution_vault_upsert(
    engine: *const L8Engine,
    vault_id_utf8: *const c_char, vault_id_len: usize,
    host_id_utf8: *const c_char, host_id_len: usize,
    constitution_id_utf8: *const c_char,
    constitution_id_len: usize,
    active_version_utf8: *const c_char,
    active_version_len: usize,
    schema_version_utf8: *const c_char,
    schema_version_len: usize,
    version_signature_utf8: *const c_char,
    version_signature_len: usize,
    last_updated_at_ms: i64,
    payload_json_utf8: *const c_char,
    payload_json_len: usize,
) -> c_int {
    if engine.is_null() { return -1; }
    let vault_id = match crate::cstr_to_str(
        vault_id_utf8, vault_id_len) {
        Some(s) => s, None => return -3,
    };
    let host_id = match crate::cstr_to_str(
        host_id_utf8, host_id_len) {
        Some(s) => s, None => return -3,
    };
    let constitution_id = match crate::cstr_to_str(
        constitution_id_utf8, constitution_id_len) {
        Some(s) => s, None => return -3,
    };
    let active_version = match crate::cstr_to_str(
        active_version_utf8, active_version_len) {
        Some(s) => s, None => return -3,
    };
    let schema_version = match crate::cstr_to_str(
        schema_version_utf8, schema_version_len) {
        Some(s) => s, None => return -3,
    };
    let version_signature = match crate::cstr_to_str(
        version_signature_utf8, version_signature_len) {
        Some(s) => s, None => return -3,
    };
    let payload_json = match crate::cstr_to_str(
        payload_json_utf8, payload_json_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match upsert_vault(
            conn, vault_id, host_id, constitution_id,
            active_version, schema_version,
            version_signature, last_updated_at_ms,
            payload_json)
        {
            Ok(true) => 1,
            Ok(false) => 0,
            Err(_) => -2,
        }
    })
}

/// Probe-mode buffer read of payload_json for vault_id。
/// Probe (null buf + 0 capacity) returns required size。
/// -2 = vault_id not found,-1 = null engine,-3 = UTF-8 fail。
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_host_constitution_vault_payload_for_id(
    engine: *const L8Engine,
    vault_id_utf8: *const c_char, vault_id_len: usize,
    out_buf: *mut u8, out_capacity: usize,
) -> i32 {
    if engine.is_null() { return -1; }
    let vault_id = match crate::cstr_to_str(
        vault_id_utf8, vault_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    let payload: Option<String> = engine_ref.with_conn(|conn| {
        fetch_payload_json(conn, vault_id).unwrap_or(None)
    });
    let payload_str = match payload {
        Some(s) => s,
        None => return -2,
    };
    let bytes = payload_str.as_bytes();
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

/// Probe-mode buffer read of first vault's payload_json for
/// host_id (matches Swift `loadFirstVault(forHostID:)`)。
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_host_constitution_vault_first_payload_for_host(
    engine: *const L8Engine,
    host_id_utf8: *const c_char, host_id_len: usize,
    out_buf: *mut u8, out_capacity: usize,
) -> i32 {
    if engine.is_null() { return -1; }
    let host_id = match crate::cstr_to_str(
        host_id_utf8, host_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    let payload: Option<String> = engine_ref.with_conn(|conn| {
        fetch_first_payload_for_host(conn, host_id)
            .unwrap_or(None)
    });
    let payload_str = match payload {
        Some(s) => s,
        None => return -2,
    };
    let bytes = payload_str.as_bytes();
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

/// Returns 1 if vault was removed, 0 if vault_id was unknown,
/// -1 = null engine, -2 = SQLite error, -3 = UTF-8 decode fail.
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_host_constitution_vault_delete(
    engine: *const L8Engine,
    vault_id_utf8: *const c_char, vault_id_len: usize,
) -> c_int {
    if engine.is_null() { return -1; }
    let vault_id = match crate::cstr_to_str(
        vault_id_utf8, vault_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match delete_vault(conn, vault_id) {
            Ok(true) => 1,
            Ok(false) => 0,
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_host_constitution_vault_count(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_vaults(conn).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn
bas_l8_host_constitution_vault_count_for_host(
    engine: *const L8Engine,
    host_id_utf8: *const c_char, host_id_len: usize,
) -> i64 {
    if engine.is_null() { return -1; }
    let host_id = match crate::cstr_to_str(
        host_id_utf8, host_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_for_host(conn, host_id).unwrap_or(-2)
    })
}

/// chapter 九百十三 / M3270 hot-path consolidation FFI #4:
/// fetch all vaults' (rowid, last_updated_at_ms) tuples
/// DESC by ts in ONE FFI call。 Returns count written
/// (≤ limit),or:
///   -1 → null engine
///   -2 → SQLite error
///   -3 → null buffers
///   -4 → limit == 0
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_host_constitution_vault_all_metadata(
    engine: *const L8Engine,
    limit: usize,
    out_rowids: *mut i64,
    out_timestamps: *mut i64,
) -> c_int {
    if engine.is_null() { return -1; }
    if limit == 0 { return -4; }
    if out_rowids.is_null() || out_timestamps.is_null() {
        return -3;
    }
    let engine_ref = unsafe { &*engine };
    let result = engine_ref.with_conn(|conn| {
        all_vault_metadata(conn, limit)
    });
    let rows = match result {
        Ok(v) => v,
        Err(_) => return -2,
    };
    let n = rows.len();
    let rid_slice = unsafe {
        core::slice::from_raw_parts_mut(out_rowids, n)
    };
    let ts_slice = unsafe {
        core::slice::from_raw_parts_mut(out_timestamps, n)
    };
    for (i, (rid, ts)) in rows.iter().enumerate() {
        rid_slice[i] = *rid;
        ts_slice[i] = *ts;
    }
    n as c_int
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{bas_l8_engine_init, bas_l8_engine_close};

    fn make_engine() -> *mut L8Engine {
        unsafe { bas_l8_engine_init(std::ptr::null(), 0) }
    }

    fn upsert_v(
        conn: &Connection,
        vid: &str, hid: &str,
    ) -> rusqlite::Result<bool> {
        upsert_vault(conn, vid, hid, "cid", "v1",
            "1.0", "sig", 100, r#"{"v":"data"}"#)
    }

    #[test]
    fn upsert_returns_true_on_insert_false_on_replace() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_host_constitution_vault_init_schema(
                engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            assert_eq!(upsert_v(conn, "v1", "h1").unwrap(),
                true);
            assert_eq!(upsert_v(conn, "v1", "h1").unwrap(),
                false, "UPSERT same vault_id returns false");
            assert_eq!(count_vaults(conn).unwrap(), 1);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn upsert_updates_ALL_non_pk_columns_on_conflict() {
        // CRITICAL Swift parity:unlike records-table (helped_
        // state only),HostConstitution UPSERT updates every
        // non-PK column。
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_host_constitution_vault_init_schema(
                engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            upsert_vault(conn, "v-pres", "h-orig", "c-orig",
                "av-orig", "sv-orig", "vsig-orig", 100,
                r#"{"orig":1}"#).unwrap();
            // Re-upsert with everything new
            upsert_vault(conn, "v-pres", "h-CHANGED",
                "c-CHANGED", "av-CHANGED", "sv-CHANGED",
                "vsig-CHANGED", 999,
                r#"{"changed":1}"#).unwrap();
            // Read mirror columns + payload_json directly
            let row: (String, String, String, String, String,
                      i64, String) =
                conn.query_row(
                    "SELECT host_id, constitution_id,
                            active_version, schema_version,
                            version_signature,
                            last_updated_at_ms, payload_json
                     FROM host_constitution_vaults
                     WHERE vault_id = ?",
                    params!["v-pres"],
                    |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?,
                            r.get(3)?, r.get(4)?, r.get(5)?,
                            r.get(6)?))
                ).unwrap();
            assert_eq!(row.0, "h-CHANGED");
            assert_eq!(row.1, "c-CHANGED");
            assert_eq!(row.2, "av-CHANGED");
            assert_eq!(row.3, "sv-CHANGED");
            assert_eq!(row.4, "vsig-CHANGED");
            assert_eq!(row.5, 999);
            assert_eq!(row.6, r#"{"changed":1}"#);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn delete_vault_returns_correct_bool() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_host_constitution_vault_init_schema(
                engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            upsert_v(conn, "v1", "h1").unwrap();
            upsert_v(conn, "v2", "h1").unwrap();
            assert_eq!(delete_vault(conn, "v1").unwrap(),
                true);
            assert_eq!(delete_vault(conn, "v1").unwrap(),
                false, "Already-deleted returns false");
            assert_eq!(delete_vault(conn, "missing").unwrap(),
                false);
            assert_eq!(count_vaults(conn).unwrap(), 1);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn fetch_first_for_host_returns_payload() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_host_constitution_vault_init_schema(
                engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            upsert_vault(conn, "v1", "h-A", "c1", "v",
                "1.0", "sig", 100, r#"{"a":1}"#).unwrap();
            upsert_vault(conn, "v2", "h-B", "c2", "v",
                "1.0", "sig", 200, r#"{"b":1}"#).unwrap();
            let r = fetch_first_payload_for_host(
                conn, "h-A").unwrap();
            assert_eq!(r, Some(r#"{"a":1}"#.to_string()));
            let r2 = fetch_first_payload_for_host(
                conn, "h-missing").unwrap();
            assert_eq!(r2, None);
            assert_eq!(count_for_host(conn, "h-A").unwrap(),
                1);
            assert_eq!(count_for_host(conn, "h-B").unwrap(),
                1);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn all_vault_metadata_returns_desc_by_ts() {
        // chapter 九百十三:integrated hot-path consolidation
        // for vault。 Verify DESC ordering + multi-vault scan。
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_host_constitution_vault_init_schema(
                engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            // 4 vaults with varying last_updated_at_ms
            upsert_vault(conn, "v1", "h", "c", "av", "sv",
                "sig", 300, "{}").unwrap();
            upsert_vault(conn, "v2", "h", "c", "av", "sv",
                "sig", 100, "{}").unwrap();
            upsert_vault(conn, "v3", "h", "c", "av", "sv",
                "sig", 500, "{}").unwrap();
            upsert_vault(conn, "v4", "h", "c", "av", "sv",
                "sig", 200, "{}").unwrap();
            let meta = all_vault_metadata(conn, 3).unwrap();
            assert_eq!(meta.len(), 3);
            assert_eq!(meta[0].1, 500);
            assert_eq!(meta[1].1, 300);
            assert_eq!(meta[2].1, 200);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn ffi_upsert_and_payload_probe() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_host_constitution_vault_init_schema(
                engine) };
        let vid = "ffi-v1";
        let hid = "ffi-h1";
        let cid = "ffi-c1";
        let av = "v";
        let sv = "1.0";
        let vsig = "sig";
        let pj = r#"{"x":42}"#;
        let rc1 = unsafe {
            bas_l8_host_constitution_vault_upsert(
                engine,
                vid.as_ptr() as *const c_char, vid.len(),
                hid.as_ptr() as *const c_char, hid.len(),
                cid.as_ptr() as *const c_char, cid.len(),
                av.as_ptr() as *const c_char, av.len(),
                sv.as_ptr() as *const c_char, sv.len(),
                vsig.as_ptr() as *const c_char, vsig.len(),
                100,
                pj.as_ptr() as *const c_char, pj.len())
        };
        assert_eq!(rc1, 1, "First insert returns 1");
        // Probe payload size
        let needed = unsafe {
            bas_l8_host_constitution_vault_payload_for_id(
                engine,
                vid.as_ptr() as *const c_char, vid.len(),
                std::ptr::null_mut(), 0)
        };
        assert_eq!(needed, pj.len() as i32);
        // Read payload
        let mut buf = vec![0u8; needed as usize];
        let written = unsafe {
            bas_l8_host_constitution_vault_payload_for_id(
                engine,
                vid.as_ptr() as *const c_char, vid.len(),
                buf.as_mut_ptr(), buf.len())
        };
        assert_eq!(written, needed);
        assert_eq!(&buf[..], pj.as_bytes());
        // Missing vault → -2
        let missing = "no-such";
        let rc = unsafe {
            bas_l8_host_constitution_vault_payload_for_id(
                engine,
                missing.as_ptr() as *const c_char,
                missing.len(),
                std::ptr::null_mut(), 0)
        };
        assert_eq!(rc, -2);
        // Delete
        let del_rc = unsafe {
            bas_l8_host_constitution_vault_delete(
                engine,
                vid.as_ptr() as *const c_char, vid.len())
        };
        assert_eq!(del_rc, 1);
        let cnt = unsafe {
            bas_l8_host_constitution_vault_count(engine) };
        assert_eq!(cnt, 0);
        unsafe { bas_l8_engine_close(engine); }
    }
}
