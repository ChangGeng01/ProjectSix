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
///   - 15 = chapter 九百十 / M3255 (+vector_index.cosine_topk_for_
///          domain_with_skipped — arc seal,surfaces dim-
///          mismatch counter for provider-upgrade diagnostics)
///   - 16 = chapter 九百十一 / M3260 (+memory_usage_records.
///          recent_for_atom — hot-path consolidation #3,
///          extends ch 906 + 909 pattern to records table)
///   - 17 = chapter 九百十三 / M3270 (+host_constitution_vault.
///          all_metadata — hot-path consolidation #4,
///          completes the pattern across all 4 major stores)
const ABI_VERSION: i32 = 17;

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
        // chapter 九百二十 / M3305 MED-17 fix:set
        // wal_autocheckpoint to 1000 pages (~4MB) — SQLite's
        // default,but explicitly pinning it ensures
        // long-running sessions don't accumulate unbounded
        // WAL growth。 At 1000 writes/sec for an hour without
        // checkpoint,WAL can hit hundreds of MB on iOS。
        conn.pragma_update(None,
            "wal_autocheckpoint", 1000)?;
        // chapter 九百二十二 / M3315 CRITICAL fix NC2:set
        // busy_timeout so multi-engine writes RETRY on
        // SQLITE_BUSY instead of failing immediately。 The
        // chapter 919 BEGIN IMMEDIATE wraps assume callers
        // will block briefly when another engine holds the
        // RESERVED lock。 Without busy_timeout,every
        // concurrent multi-engine write returns -2 instantly
        // — degrading the multi-engine race protection to
        // race-fails-loudly-and-often。
        conn.busy_timeout(
            std::time::Duration::from_millis(5000))?;
        // chapter 九百二十三 fix NH7:verify journal_mode
        // actually became WAL,not silently fall through to
        // delete mode on a read-only filesystem。
        let mode: String = conn.query_row(
            "PRAGMA journal_mode", [],
            |row| row.get(0))?;
        if mode.to_lowercase() != "wal" {
            return Err(rusqlite::Error::SqliteSingleThreadedMode);
        }
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
        // chapter 九百二十二 fix NC2:busy_timeout for
        // consistency with disk-backed engine (in-memory
        // can still see contention between threads)。
        conn.busy_timeout(
            std::time::Duration::from_millis(5000))?;
        Ok(L8Engine {
            conn: Mutex::new(conn),
            db_path: PathBuf::from(":memory:"),
        })
    }

    /// Access the connection under the mutex (subsequent
    /// chapter migration functions use this)。
    ///
    /// chapter 九百十九 / M3300 CRITICAL fix C5:recover from
    /// `PoisonError` instead of `.unwrap()` (which panics)。
    /// Previously,a single rusqlite panic between statements
    /// would poison the Mutex,then every subsequent FFI call
    /// would panic on `.unwrap()` — engine wedged forever
    /// until process restart (no recovery path,deinit only
    /// runs at app exit)。 With `unwrap_or_else(|p| p.into_
    /// inner())` we accept the poisoned state and continue
    /// — the underlying SQLite Connection is generally
    /// recoverable;rusqlite handles statement-level errors
    /// internally。
    pub fn with_conn<F, R>(&self, f: F) -> R
    where
        F: FnOnce(&Connection) -> R,
    {
        let guard = self.conn.lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
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
/// # Semantics (chapter 九百十五 / M3280 correctness fix C1)
///
/// REJECTS `len == 0` with `None` — empty strings are NOT
/// valid for PK / required-field columns。 The previous
/// chapter 九百七 behavior (returning `Some("")` for `len==0`)
/// opened a real data-corruption path:`record_id=""`,
/// `vault_id=""`, etc. silently landed as real SQLite rows
/// because no caller picked up the validation responsibility
/// the doc said callers MUST take。
///
/// For the ONE legitimate empty-string case (event_log
/// format=2 binary path's `payload_json_len = 0`),use the
/// sibling `cstr_to_str_allowing_empty` helper at that
/// specific call site only。
///
/// Return codes:
/// - `len == 0` → `None` (rejected as required-field violation)
/// - `ptr.is_null()` with `len > 0` → `None` (contract violation)
/// - Valid UTF-8 → `Some(s)`
/// - Invalid UTF-8 → `None`
pub(crate) fn cstr_to_str<'a>(
    ptr: *const c_char,
    len: usize,
) -> Option<&'a str> {
    if ptr.is_null() || len == 0 {
        return None;
    }
    let bytes = unsafe {
        core::slice::from_raw_parts(ptr as *const u8, len)
    };
    std::str::from_utf8(bytes).ok()
}

/// chapter 九百十五 / M3280 review fix C1 — explicit
/// empty-allowing variant for ONE use case:event_log
/// format=2 binary payloads where `payload_json_len = 0`
/// is semantically valid (the data lives in the BLOB)。
///
/// Returns:
/// - `len == 0` → `Some("")` (legitimate empty payload)
/// - `ptr.is_null()` with `len > 0` → `None`
/// - Valid UTF-8 → `Some(s)`
/// - Invalid UTF-8 → `None`
///
/// Use this ONLY where the schema column accepts empty
/// strings as semantically meaningful。 All PK columns must
/// use the strict `cstr_to_str` instead。
pub(crate) fn cstr_to_str_allowing_empty<'a>(
    ptr: *const c_char,
    len: usize,
) -> Option<&'a str> {
    if len == 0 {
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

/// chapter 九百二十二 / M3315 CRITICAL fix NC4 — shared
/// upper bound for any caller-supplied limit parameter
/// across the 4 hot-path consolidation FFIs。 100k entries
/// × 16 bytes = ~1.6 MB worst-case allocation,well within
/// safe production bounds for top-k / recent-N queries。
/// Without this bound,a direct-FFI consumer passing
/// `limit = usize::MAX` triggers `Vec::with_capacity` abort
/// — bypassing the Swift-side `limitCap` (which only
/// protects Swift call sites)。
pub(crate) const MAX_HOTPATH_LIMIT: usize = 100_000;

/// chapter 九百二十三 / M3320 NH3 fix — BLOB upper bounds
/// for the 3 OTHER blob-accepting FFIs that ch 920 missed
/// (only vector_index.embedding_blob was capped previously)。
///
/// - signature_hash: 64 bytes covers SHA256 (32) and SHA512
///   (64); SHA3-256/512 fit too
/// - payload_blob (event_log binary format=2): 1 MiB —
///   audit envelopes / replay frames are KB-scale today
/// - payload_json: 16 MiB — SQLite default string limit
pub(crate) const MAX_SIGNATURE_HASH_BYTES: usize = 64;
pub(crate) const MAX_PAYLOAD_BLOB_BYTES: usize = 1_048_576;
pub(crate) const MAX_PAYLOAD_JSON_BYTES: usize = 16_777_216;

/// chapter 九百二十二 / M3315 CRITICAL fix NC1 — run a
/// transactional body inside BEGIN IMMEDIATE + COMMIT,
/// guaranteeing ROLLBACK on ANY error path including
/// errors from intermediate `?` operators in the body。
/// Previously the chapter 919 wraps had open-transaction
/// leaks on read-step errors (fetch_existing_sequence,
/// SELECT pre-check) that didn't go through the final
/// match block。 Centralizing the pattern here avoids
/// repeating the bug across 5 modules。
pub(crate) fn transactional<F, T>(
    conn: &Connection,
    body: F,
) -> rusqlite::Result<T>
where
    F: FnOnce(&Connection) -> rusqlite::Result<T>,
{
    conn.execute("BEGIN IMMEDIATE TRANSACTION", [])?;
    let result = body(conn);
    match result {
        Ok(v) => {
            match conn.execute("COMMIT", []) {
                Ok(_) => Ok(v),
                Err(e) => {
                    // COMMIT failed — try ROLLBACK to
                    // leave connection in clean state
                    let _ = conn.execute("ROLLBACK", []);
                    Err(e)
                }
            }
        }
        Err(e) => {
            // Body returned Err — ALWAYS rollback
            let _ = conn.execute("ROLLBACK", []);
            Err(e)
        }
    }
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
        // 910: 14→15 vector_index.cosine_topk_for_domain_with_
        //            skipped (arc seal,surfaces dim-mismatch).
        // 911: 15→16 records.recent_for_atom hot-path #3.
        // 913: 16→17 vault.all_metadata hot-path #4.
        assert_eq!(bas_l8_engine_abi_version(), 17);
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
    fn cstr_to_str_rejects_empty_and_null() {
        // chapter 九百十五 / M3280 fix C1:cstr_to_str is now
        // STRICT — rejects len=0 with None。 The chapter 907
        // empty-string-permissive behavior opened a real data-
        // corruption path (empty PKs silently inserted)。
        assert_eq!(
            cstr_to_str(std::ptr::null(), 0),
            None,
            "len=0 rejected (was Some(\"\") in ch 907)");
        let bytes = b"hi";
        assert_eq!(
            cstr_to_str(bytes.as_ptr() as *const c_char, 0),
            None,
            "len=0 rejected regardless of ptr non-null");
        assert_eq!(
            cstr_to_str(std::ptr::null(), 5),
            None,
            "ptr=null with len>0 still returns None");
        assert_eq!(
            cstr_to_str(bytes.as_ptr() as *const c_char, 2),
            Some("hi"));
    }

    #[test]
    fn cstr_to_str_allowing_empty_accepts_empty() {
        // chapter 九百十五 / M3280 fix C1:opt-in helper for
        // the ONE legitimate empty-string case (event_log
        // format=2 binary payload)。 PK fields use the strict
        // cstr_to_str instead。
        assert_eq!(
            cstr_to_str_allowing_empty(std::ptr::null(), 0),
            Some(""));
        let bytes = b"hi";
        assert_eq!(
            cstr_to_str_allowing_empty(
                bytes.as_ptr() as *const c_char, 0),
            Some(""));
        assert_eq!(
            cstr_to_str_allowing_empty(std::ptr::null(), 5),
            None,
            "ptr=null with len>0 still returns None even in lenient mode");
        assert_eq!(
            cstr_to_str_allowing_empty(
                bytes.as_ptr() as *const c_char, 2),
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

    #[test]
    fn chapter_920_composite_indexes_are_actually_used() {
        // chapter 九百二十三 / M3320 NH6 fix:verify the
        // chapter 920 indexes are actually picked by SQLite's
        // query planner for the hot-path queries that
        // motivated them。 Without EXPLAIN QUERY PLAN
        // verification,the indexes could exist but be
        // ignored by the optimizer (wrong stats, wrong
        // column order, etc.)。
        let tmp = tempfile::NamedTempFile::new().unwrap();
        let path = tmp.path().to_str().unwrap();
        let path_bytes = path.as_bytes();
        let engine = unsafe {
            bas_l8_engine_init(
                path_bytes.as_ptr() as *const c_char,
                path_bytes.len())
        };
        assert!(!engine.is_null());
        let _ = unsafe {
            crate::event_log
                ::bas_l8_event_log_init_schema(engine) };
        let _ = unsafe {
            crate::memory_usage_records
                ::bas_l8_memory_usage_records_init_schema(
                    engine) };
        let _ = unsafe {
            crate::host_constitution_vault
                ::bas_l8_host_constitution_vault_init_schema(
                    engine) };

        let engine_ref = unsafe { &*engine };

        // Verify event_log_session_time_idx for ch 909 hot path
        let plan_event: String = engine_ref.with_conn(|c| {
            let mut plan_strs = vec![];
            let mut stmt = c.prepare(
                "EXPLAIN QUERY PLAN
                 SELECT timestamp_ms, sequence_number
                   FROM event_log
                  WHERE session_id = ?
                  ORDER BY timestamp_ms DESC LIMIT 10"
            ).unwrap();
            let mut rows = stmt.query(["s"]).unwrap();
            while let Ok(Some(r)) = rows.next() {
                let detail: String = r.get(3).unwrap();
                plan_strs.push(detail);
            }
            plan_strs.join(" | ")
        });
        assert!(
            plan_event.contains("event_log_session_time_idx"),
            "ch 920 event_log composite index not used by\
             planner. EXPLAIN: {}",
            plan_event);

        // Verify memory_usage_atom_time_idx for ch 911 hot path
        let plan_records: String = engine_ref.with_conn(|c| {
            let mut plan_strs = vec![];
            let mut stmt = c.prepare(
                "EXPLAIN QUERY PLAN
                 SELECT retrieved_at_ms, helped_state
                   FROM memory_usage_records
                  WHERE atom_id = ?
                  ORDER BY retrieved_at_ms DESC LIMIT 10"
            ).unwrap();
            let mut rows = stmt.query(["a"]).unwrap();
            while let Ok(Some(r)) = rows.next() {
                let detail: String = r.get(3).unwrap();
                plan_strs.push(detail);
            }
            plan_strs.join(" | ")
        });
        assert!(
            plan_records.contains(
                "memory_usage_atom_time_idx"),
            "ch 920 records composite index not used by\
             planner. EXPLAIN: {}",
            plan_records);

        // Verify host_constitution_updated_idx for ch 913
        let plan_vault: String = engine_ref.with_conn(|c| {
            let mut plan_strs = vec![];
            let mut stmt = c.prepare(
                "EXPLAIN QUERY PLAN
                 SELECT rowid, last_updated_at_ms
                   FROM host_constitution_vaults
                  ORDER BY last_updated_at_ms DESC LIMIT 10"
            ).unwrap();
            let mut rows = stmt.query([]).unwrap();
            while let Ok(Some(r)) = rows.next() {
                let detail: String = r.get(3).unwrap();
                plan_strs.push(detail);
            }
            plan_strs.join(" | ")
        });
        assert!(
            plan_vault.contains(
                "host_constitution_updated_idx"),
            "ch 920 vault timestamp index not used by\
             planner. EXPLAIN: {}",
            plan_vault);
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn mutex_connection_serializes_native_thread_contention() {
        // chapter 九百十五 / M3280 fix H9 — true Mutex<Connection>
        // stress test。 The chapter 908 Swift test serialized on
        // the Swift actor boundary BEFORE hitting Mutex<Connection>,
        // so the Rust mutex was never actually stress-tested。
        //
        // This test bypasses Swift entirely:N std::thread workers
        // share an Arc<&L8Engine> via raw pointer + Mutex protection。
        // Each thread does K reads + K writes against the same
        // engine。 Asserts no lost writes,no deadlock。
        use std::sync::Arc;
        use std::sync::atomic::{AtomicI32, Ordering};
        use std::thread;

        // Use a disk-backed engine so threads share a real SQLite
        // file (in-memory engines can be quirky under MT)
        let tmp = tempfile::NamedTempFile::new().unwrap();
        let path = tmp.path().to_str().unwrap();
        let path_bytes = path.as_bytes();
        let engine_ptr = unsafe {
            bas_l8_engine_init(
                path_bytes.as_ptr() as *const c_char,
                path_bytes.len())
        };
        assert!(!engine_ptr.is_null());

        // Init schemas via the modules we'll exercise
        let init_rc = unsafe {
            crate::event_log
                ::bas_l8_event_log_init_schema(engine_ptr)
        };
        assert_eq!(init_rc, 0);

        // Wrap the engine ptr in a struct that's Send + Sync for
        // the thread::spawn boundary。 Engine internally uses
        // Mutex<Connection> so this is safe。
        struct EnginePtr(*const L8Engine);
        unsafe impl Send for EnginePtr {}
        unsafe impl Sync for EnginePtr {}
        let shared = Arc::new(EnginePtr(engine_ptr));

        const N_THREADS: usize = 16;
        const K_OPS_PER_THREAD: usize = 25;
        let succeeded = Arc::new(AtomicI32::new(0));

        let mut handles = vec![];
        for tid in 0..N_THREADS {
            let s = Arc::clone(&shared);
            let counter = Arc::clone(&succeeded);
            handles.push(thread::spawn(move || {
                for i in 0..K_OPS_PER_THREAD {
                    let event_id =
                        format!("mt-{}-{}", tid, i);
                    let session_id =
                        format!("sess-{}", tid % 4);
                    let kind = "chat";
                    let risk = "low";
                    let pj = "{}";
                    let mut was_new: i32 = -1;
                    let seq = unsafe {
                        crate::event_log
                            ::bas_l8_event_log_append(
                            s.0,
                            event_id.as_ptr() as *const c_char,
                            event_id.len(),
                            session_id.as_ptr()
                                as *const c_char,
                            session_id.len(),
                            (tid * 1000 + i) as i64,
                            kind.as_ptr() as *const c_char,
                            kind.len(),
                            risk.as_ptr() as *const c_char,
                            risk.len(),
                            pj.as_ptr() as *const c_char,
                            pj.len(),
                            1,
                            std::ptr::null(), 0,
                            &mut was_new)
                    };
                    if seq >= 0 && was_new == 1 {
                        counter.fetch_add(1, Ordering::SeqCst);
                    }
                }
            }));
        }
        for h in handles { h.join().unwrap(); }

        // Expected: N_THREADS × K_OPS_PER_THREAD = 400 distinct
        // event_ids,all newly inserted (no lost writes)
        let total = succeeded.load(Ordering::SeqCst);
        assert_eq!(total,
            (N_THREADS * K_OPS_PER_THREAD) as i32,
            "All concurrent writes must succeed under Mutex<Connection>");

        // Verify SQLite agrees
        let final_count = unsafe {
            crate::event_log
                ::bas_l8_event_log_count(engine_ptr)
        };
        assert_eq!(final_count,
            (N_THREADS * K_OPS_PER_THREAD) as i64,
            "SQLite count matches successful appends");

        unsafe { bas_l8_engine_close(engine_ptr); }
    }
}
