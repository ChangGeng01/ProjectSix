// SPDX:internal
//
// bas-l8-engine — chapter 八百九十四 / M3160
//
// L8 Rust unification per Docs/L8_RUST_UNIFICATION_RFC.md
// (chapter 八百九十三 RFC)。 SQL = source of truth + Rust = hot
// path + Swift = orchestration + Apple boundary。
//
// This crate is the SKELETON shipping the engine handle +
// abi_version + open/close lifecycle。 Subsequent chapters
// (八百九十五+) migrate individual Swift SQLite actors to use
// this engine via per-store FFI surfaces。
//
// # Architecture
//
//   Swift actor (orchestration)
//        ↓ FFI
//   bas_l8_engine_init(path) → *mut L8Engine
//        ↓ owns
//   rusqlite::Connection
//        ↓ owns
//   SQLite WAL-mode DB on disk
//
// # ABI stability
//
// All public functions return i32 status codes (mirrors the
// existing bas_rust_tracker_* idiom):
//   0  → success
//   -1 → null pointer / invalid input
//   -2 → SQLite error (check engine's last_error_code)
//   -3 → string encoding error (UTF-8 / length)
//   -4 → schema migration failure
//
// # Multi-engine support
//
// Per RFC open question 1:multiple engines are supported (test
// isolation matters)。 Each `bas_l8_engine_init` returns a
// distinct handle;the caller manages lifecycle via close。
//
// # Schema migrations
//
// Per RFC open question 4:schemas are embedded via include_str!
// at build time (no IO at init)。 This skeleton ships ZERO
// schemas — subsequent migration chapters add per-store
// schemas as needed。

use std::ffi::CStr;
use std::os::raw::{c_char, c_int};
use std::path::PathBuf;
use std::sync::Mutex;

use rusqlite::Connection;

// chapter 八百九十五 / M3165 — LOW-risk pilot migration module
pub mod deletion_manifest;
// chapter 八百九十七 / M3175 — MED-risk migration #2: atom lifecycle
pub mod atom_lifecycle;
// chapter 八百九十八 / M3180 — MED-risk migration #3: user state
pub mod user_state;
// chapter 八百九十九 / M3185 — MED-risk migration #4: version tree
//                              (adds first BLOB FFI support)
pub mod version_tree;
// chapter 九百 / M3190 — MED-risk migration #5: vector index
//                        (UPSERT + variable-size embedding BLOB)
pub mod vector_index;
// chapter 九百一 / M3195 — HIGH-risk migration #1: event log
//                          (per-turn append + auto-sequence + prune)
pub mod event_log;
// chapter 九百二 / M3200 — HIGH-risk migration #2 SCOPED:
//                          MemoryUsageTracker records table only
//                          (UPSERT-only-helped_state on conflict)
pub mod memory_usage_records;
// chapter 九百二.5 / M3205 — sub-chapter 2:
//                            MemoryUsageTracker replay_log + audit_log
//                            (append-only,2 tables in 1 module)
pub mod memory_usage_logs;
// chapter 九百二.6 / M3210 — sub-chapter 3:
//                            MemoryUsageTracker notes + bundles + tombstones
//                            (closes out the 6-table port,FTS5 deferred)
pub mod memory_usage_extras;
// chapter 九百三 / M3215 — HIGH-risk migration #3:
//                          BASHostConstitutionSQLiteStorage
//                          (1 table,UPSERT updates ALL non-PK
//                           columns,DELETE for remove)
pub mod host_constitution_vault;

// MARK: - ABI version

/// Bump this when the C ABI surface changes (add/remove/rename
/// functions OR change parameter shapes)。 Swift consumers
/// cross-check via `bas_l8_engine_abi_version()` at module init。
///
/// History:
///   - 1 = chapter 八百九十四 / M3160 (engine skeleton:
///         abi_version + init + close + db_path)
///   - 2 = chapter 八百九十五 / M3165 (+deletion_manifest module:
///         init_schema + append + count + count_for_vault)
///   - 3 = chapter 八百九十七 / M3175 (+atom_lifecycle module:
///         init_schema + append + count + count_for_atom +
///         count_for_session)
///   - 4 = chapter 八百九十八 / M3180 (+user_state module:
///         init_schema + append + count + count_for_session +
///         latest_time_for_session)
///   - 5 = chapter 八百九十九 / M3185 (+version_tree module:
///         init_schema + append [first BLOB FFI] + count +
///         count_for_vault + count_rollback_points)
///   - 6 = chapter 九百 / M3190 (+vector_index module:
///         init_schema + upsert + remove + count +
///         count_for_domain + count_for_provider)
///   - 7 = chapter 九百一 / M3195 (+event_log module:
///         init_schema + append [auto-sequence + idempotent] +
///         count + count_for_session + count_for_kind +
///         next_sequence + prune_before)
///   - 8 = chapter 九百二 / M3200 (+memory_usage_records module
///         SCOPED to records table only:init_schema + upsert
///         [helped_state-only on conflict] + count +
///         usage_count_for_atom + count_for_session +
///         helped_state_for_record)
///   - 9 = chapter 九百二.5 / M3205 (+memory_usage_logs module:
///         replay_log + audit_log append-only tables —
///         init_schema×2 + append×2 + count×2 + latest_time×2)
///   - 10 = chapter 九百二.6 / M3210 (+memory_usage_extras module:
///          notes [UPSERT] + bundles [composite PK] +
///          tombstones [INSERT OR REPLACE] — closes 6-table port)
///   - 11 = chapter 九百三 / M3215 (+host_constitution_vault module:
///          init_schema + upsert + payload_for_id + first_payload_
///          for_host + delete + count + count_for_host)
///   - 12 = chapter 九百四 / M3220 (+memory_usage_records.update_
///          helped_state — markHelped UPDATE-only primitive that
///          does NOT insert placeholder rows on unknown record_id)
///   - 13 = chapter 九百六 / M3230 (+vector_index.read_embedding_
///          for_atom + cosine_topk_for_domain — hot-path
///          consolidation primitives for chapter 905 trigger)
///   - 14 = chapter 九百九 / M3250 (+event_log.recent_timestamps_
///          for_session — hot-path consolidation #2,extends
///          chapter 906 pattern to event_log)
const ABI_VERSION: i32 = 14;

/// Return the current ABI version for cross-checking by Swift
/// consumers。
#[no_mangle]
pub extern "C" fn bas_l8_engine_abi_version() -> i32 {
    ABI_VERSION
}

// MARK: - Engine handle (opaque from Swift's perspective)

/// Engine handle wrapping a rusqlite Connection。 The Mutex
/// guards the connection for thread-safe access from any Swift
/// actor isolation context。 Per RFC: Swift never sees the
/// internal Connection,only the opaque *mut L8Engine pointer。
pub struct L8Engine {
    conn: Mutex<Connection>,
    db_path: PathBuf,
}

impl L8Engine {
    /// Open a new SQLite connection at the given path with
    /// WAL journal mode + synchronous=NORMAL + foreign_keys=ON
    /// per substrate's existing Swift actor conventions。
    fn open(path: PathBuf) -> Result<Self, rusqlite::Error> {
        let conn = Connection::open(&path)?;
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.pragma_update(None, "synchronous", "NORMAL")?;
        conn.pragma_update(None, "foreign_keys", "ON")?;
        Ok(L8Engine {
            conn: Mutex::new(conn),
            db_path: path,
        })
    }

    /// Open in-memory connection (test isolation per RFC
    /// open question 1)。
    fn open_in_memory() -> Result<Self, rusqlite::Error> {
        let conn = Connection::open_in_memory()?;
        conn.pragma_update(None, "synchronous", "NORMAL")?;
        conn.pragma_update(None, "foreign_keys", "ON")?;
        Ok(L8Engine {
            conn: Mutex::new(conn),
            db_path: PathBuf::from(":memory:"),
        })
    }

    /// Access the connection under the mutex (subsequent
    /// chapter migration functions use this)。
    pub fn with_conn<F, R>(&self, f: F) -> R
    where
        F: FnOnce(&Connection) -> R,
    {
        let guard = self.conn.lock().unwrap();
        f(&guard)
    }

    /// Path the engine was opened at (or ":memory:")。 Used by
    /// diagnostics + Swift-side audit trails。
    pub fn db_path(&self) -> &PathBuf {
        &self.db_path
    }
}

// MARK: - FFI: engine open / close

/// Open a new L8 engine backed by SQLite at the given path。
/// Path is UTF-8 encoded with explicit length (no NUL terminator
/// assumed — matches the existing `bas_rust_tracker_init` idiom)。
///
/// Returns a non-null `*mut L8Engine` on success,or null on
/// failure (caller can probe `bas_l8_engine_last_error_code` for
/// the SQLite error code)。
///
/// The caller is responsible for eventually calling
/// `bas_l8_engine_close` to release the connection + file handle。
/// Failure to do so leaks SQLite resources but does NOT corrupt
/// the database file (WAL handles unclean shutdown gracefully)。
///
/// # Safety
///
/// `path_utf8` must point to `path_len` valid UTF-8 bytes。
/// Caller must NOT pass `path_utf8: null` if `path_len > 0`。
#[no_mangle]
pub unsafe extern "C" fn bas_l8_engine_init(
    path_utf8: *const c_char,
    path_len: usize,
) -> *mut L8Engine {
    // Empty path → in-memory engine (test convenience)
    if path_len == 0 || path_utf8.is_null() {
        return match L8Engine::open_in_memory() {
            Ok(engine) => Box::into_raw(Box::new(engine)),
            Err(_) => std::ptr::null_mut(),
        };
    }
    let bytes = unsafe {
        core::slice::from_raw_parts(
            path_utf8 as *const u8, path_len)
    };
    let path_str = match std::str::from_utf8(bytes) {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };
    let path_buf = PathBuf::from(path_str);
    match L8Engine::open(path_buf) {
        Ok(engine) => Box::into_raw(Box::new(engine)),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Close an L8 engine + release its SQLite connection + file
/// handle。 Idempotent on null。 The engine pointer MUST NOT be
/// used after this call。
///
/// Returns 0 on success,-1 if `engine` is null (treated as
/// already-closed,not an error)。
///
/// # Safety
///
/// `engine` must be a pointer returned by a prior
/// `bas_l8_engine_init` call,or null。
#[no_mangle]
pub unsafe extern "C" fn bas_l8_engine_close(
    engine: *mut L8Engine,
) -> c_int {
    if engine.is_null() {
        return -1;
    }
    // Take ownership + drop — releases Mutex + Connection +
    // file handle + flushes WAL。
    let _ = unsafe { Box::from_raw(engine) };
    0
}

/// Returns the engine's db path as a length-prefixed UTF-8
/// buffer。 Caller passes a `*mut u8` buffer of at least
/// `out_capacity` bytes;function writes path bytes + returns
/// the byte count written (or -1 if buffer too small / engine
/// null)。 Diagnostic helper — Swift-side audit trails use this。
///
/// # Safety
///
/// `engine` must be valid + non-null。 `out_buf` must point to
/// `out_capacity` writable bytes (or null with `out_capacity==0`
/// to probe required size)。
#[no_mangle]
pub unsafe extern "C" fn bas_l8_engine_db_path(
    engine: *const L8Engine,
    out_buf: *mut u8,
    out_capacity: usize,
) -> i32 {
    if engine.is_null() {
        return -1;
    }
    let engine_ref = unsafe { &*engine };
    let path_str = engine_ref.db_path.to_string_lossy();
    let bytes = path_str.as_bytes();
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

// MARK: - CStr helper (for future migration chapter use)

/// Decode a Swift-passed UTF-8 buffer into a `&str`。
///
/// # Semantics (chapter 九百七 / M3240 review fix #1)
///
/// - `len == 0` returns `Some("")` (the empty string is a
///   VALID value for callers like event_log format=2 payload
///   where the binary path passes `payload_json_len = 0`)
/// - `ptr.is_null()` with `len > 0` returns `None` (contract
///   violation — pointer can't be null when length claims data)
/// - Invalid UTF-8 bytes return `None`
///
/// Callers that require non-empty values (e.g. PK columns)
/// MUST validate `s.is_empty()` themselves after decoding。
///
/// Prior to chapter 九百七 this function rejected `len == 0`
/// with `None`,which silently broke FFI callers attempting
/// to pass legitimate empty strings (e.g. the event_log
/// format=2 binary path)。
pub(crate) fn cstr_to_str<'a>(
    ptr: *const c_char,
    len: usize,
) -> Option<&'a str> {
    if len == 0 {
        // Empty string is a valid value。 The `ptr` may be
        // null here because the slice is zero-length anyway。
        return Some("");
    }
    if ptr.is_null() {
        return None;
    }
    let bytes = unsafe {
        core::slice::from_raw_parts(ptr as *const u8, len)
    };
    std::str::from_utf8(bytes).ok()
}

#[allow(dead_code)]
pub(crate) fn cstr_terminated_to_string(
    ptr: *const c_char,
) -> Option<String> {
    if ptr.is_null() {
        return None;
    }
    let cs = unsafe { CStr::from_ptr(ptr) };
    cs.to_str().ok().map(|s| s.to_string())
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn abi_version_pinned() {
        // If this fails, ABI changed — bump version + update
        // Swift cross-check pin。 895: 1→2 deletion_manifest,
        // 897: 2→3 atom_lifecycle, 898: 3→4 user_state,
        // 899: 4→5 version_tree (first BLOB FFI).
        // 900: 5→6 vector_index (UPSERT + variable BLOB).
        // 901: 6→7 event_log (HIGH-risk first).
        // 902: 7→8 memory_usage_records (HIGH-risk #2 SCOPED).
        // 902.5: 8→9 memory_usage_logs (replay+audit append-only).
        // 902.6: 9→10 memory_usage_extras (notes+bundles+tombstones).
        // 903: 10→11 host_constitution_vault (HIGH-risk #3 final).
        // 904: 11→12 records.update_helped_state for markHelped.
        // 906: 12→13 vector_index.cosine_topk_for_domain
        //            (hot-path consolidation per ch 905 trigger).
        // 909: 13→14 event_log.recent_timestamps_for_session
        //            (hot-path consolidation #2,extends ch 906).
        assert_eq!(bas_l8_engine_abi_version(), 14);
    }

    #[test]
    fn open_in_memory_engine_succeeds() {
        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0)
        };
        assert!(!engine.is_null(),
            "in-memory engine init must succeed");
        // Close should succeed
        let rc = unsafe { bas_l8_engine_close(engine) };
        assert_eq!(rc, 0);
    }

    #[test]
    fn close_on_null_returns_minus_one() {
        let rc = unsafe {
            bas_l8_engine_close(std::ptr::null_mut())
        };
        assert_eq!(rc, -1);
    }

    #[test]
    fn open_on_disk_with_path_succeeds() {
        let tmp = tempfile::NamedTempFile::new()
            .expect("tmp file");
        let path = tmp.path().to_str().unwrap();
        let path_bytes = path.as_bytes();
        let engine = unsafe {
            bas_l8_engine_init(
                path_bytes.as_ptr() as *const c_char,
                path_bytes.len())
        };
        assert!(!engine.is_null(),
            "on-disk engine init at {:?} must succeed", path);
        // Verify db_path round-trips
        let mut buf = vec![0u8; path_bytes.len()];
        let written = unsafe {
            bas_l8_engine_db_path(
                engine, buf.as_mut_ptr(), buf.len())
        };
        assert_eq!(written as usize, path_bytes.len());
        assert_eq!(&buf[..], path_bytes);
        let rc = unsafe { bas_l8_engine_close(engine) };
        assert_eq!(rc, 0);
    }

    #[test]
    fn db_path_probe_returns_required_size() {
        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0)
        };
        // Probe with null buf + 0 capacity → returns required
        let needed = unsafe {
            bas_l8_engine_db_path(
                engine, std::ptr::null_mut(), 0)
        };
        assert!(needed > 0,
            "probe must return positive byte count");
        assert_eq!(needed as usize, ":memory:".len());
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn multiple_engines_are_independent() {
        // Test isolation per RFC open question 1
        let e1 = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0)
        };
        let e2 = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0)
        };
        assert!(!e1.is_null() && !e2.is_null());
        assert!(e1 != e2,
            "Each init must return distinct handle");
        unsafe {
            bas_l8_engine_close(e1);
            bas_l8_engine_close(e2);
        }
    }

    #[test]
    fn cstr_to_str_empty_string_returns_some() {
        // chapter 九百七 review fix #1: empty string is valid。
        // Prior behavior was Some/None confusion that silently
        // broke event_log format=2 payload_json="" callers。
        assert_eq!(
            cstr_to_str(std::ptr::null(), 0),
            Some(""),
            "Empty string (len=0,ptr=null) returns Some(\"\")");
        let bytes = b"hi";
        assert_eq!(
            cstr_to_str(bytes.as_ptr() as *const c_char, 0),
            Some(""),
            "len=0 wins regardless of ptr non-null");
        assert_eq!(
            cstr_to_str(std::ptr::null(), 5),
            None,
            "ptr=null with len>0 still returns None");
        assert_eq!(
            cstr_to_str(bytes.as_ptr() as *const c_char, 2),
            Some("hi"));
    }

    #[test]
    fn wal_mode_is_set_on_disk_engine() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        let path = tmp.path().to_str().unwrap();
        let path_bytes = path.as_bytes();
        let engine_ptr = unsafe {
            bas_l8_engine_init(
                path_bytes.as_ptr() as *const c_char,
                path_bytes.len())
        };
        assert!(!engine_ptr.is_null());
        let engine = unsafe { &*engine_ptr };
        let mode: String = engine.with_conn(|conn| {
            conn.query_row(
                "PRAGMA journal_mode", [],
                |row| row.get(0)).unwrap()
        });
        assert_eq!(mode.to_lowercase(), "wal",
            "WAL mode must be set on disk-backed engine");
        unsafe { bas_l8_engine_close(engine_ptr); }
    }
}
