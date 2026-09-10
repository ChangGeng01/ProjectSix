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
///   - 18 = chapter 九百二十六 / M3335 (+bas_l8_engine_pragma_
///          value_i64 — diagnostic FFI required by 6th-pass
///          review fix CRITICAL-3:enables tests to verify
///          PRAGMA values were actually applied on the
///          engine's OWN connection,not a separate raw
///          sqlite3 connection that returns SQLite defaults)
const ABI_VERSION: i32 = 18;

/// Return the current ABI version for cross-checking by Swift
/// consumers。
#[no_mangle]
pub extern "C" fn bas_l8_engine_abi_version() -> i32 {
    ABI_VERSION
}

/// chapter 九百三十九 / M3400 fix MED-3 — extracted from
/// open() + open_in_memory() duplicate `conn.busy_timeout(4500)`
/// call sites per 11P-MED-1 / 12P-MED-3 deferred items。 Sentinel
/// 4500 ms differs from rusqlite 0.32 default (5000) so revert
/// detection works (see ch 931 rusqlite-default coincidence fix)。
pub(crate) const BUSY_TIMEOUT_MS: u64 = 4500;

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
        // chapter 九百三十二 / M3365 fix HIGH-1 — foreign_keys
        // is a 3rd-instance rusqlite-default coincidence (the
        // bundled SQLite 3.46 is compiled with `SQLITE_DEFAULT_
        // FOREIGN_KEYS=1`,so this pragma_update is a no-op on
        // the current build)。 Pragma_update kept for explicit
        // intent + as a guard against future libsqlite3-sys
        // version bumps flipping the compile-time default。
        // Post-pragma read-back hardening matches journal_mode
        // verification pattern (NH7 / ch 923) — surface silent
        // regression instead of relying on default coincidence。
        conn.pragma_update(None, "foreign_keys", "ON")?;
        let fk_on: i64 = conn.query_row(
            "PRAGMA foreign_keys", [], |row| row.get(0))?;
        if fk_on != 1 {
            return Err(rusqlite::Error::SqliteFailure(
                rusqlite::ffi::Error::new(
                    rusqlite::ffi::SQLITE_ERROR),
                Some(format!(
                    "expected foreign_keys=1 after PRAGMA, \
                     got {}", fk_on))));
        }
        // chapter 九百二十 / M3305 MED-17 fix:set
        // wal_autocheckpoint to 1024 pages (~4 MB at 4KB
        // pages) — long-running sessions don't accumulate
        // unbounded WAL growth。 At 1000 writes/sec for an
        // hour without checkpoint,WAL can hit hundreds of
        // MB on iOS。
        //
        // chapter 九百二十七 / M3340 fix CRITICAL-1:value
        // bumped 1000 → 1024 specifically to differ from
        // SQLite's compile-time default。 The ch 925/926
        // `testWalAutocheckpointReadFromEngineConnection`
        // was fake-coverage when value matched default —
        // test passed even if this pragma_update were
        // reverted。 1024 is a power-of-2 sentinel that
        // (a) keeps the「~4 MB WAL bound」 intent intact
        // (1024 × 4 KB = 4 MiB,closer to the comment than
        // 1000),(b) is detectably non-default so the test
        // fails on revert,(c) has negligible production
        // impact (24-page delta = ~96 KB at 4 KB pages)。
        conn.pragma_update(None,
            "wal_autocheckpoint", 1024)?;
        // chapter 九百二十二 / M3315 CRITICAL fix NC2:set
        // busy_timeout so multi-engine writes RETRY on
        // SQLITE_BUSY instead of failing immediately。 The
        // chapter 919 BEGIN IMMEDIATE wraps assume callers
        // will block briefly when another engine holds the
        // RESERVED lock。 Without busy_timeout,every
        // concurrent multi-engine write returns -2 instantly
        // — degrading the multi-engine race protection to
        // race-fails-loudly-and-often。
        //
        // chapter 九百三十一 / M3360 fix CRITICAL-3:value
        // bumped 5000 → 4500 because rusqlite 0.32 sets
        // sqlite3_busy_timeout(db, 5000) AUTOMATICALLY in
        // InnerConnection::open_with_flags (inner_connection.
        // rs:119)。 The previous 5000 value was indistinguish-
        // able from rusqlite's default — the busy_timeout
        // test assertion passed even if THIS line were
        // removed entirely。 4500 is a non-default sentinel
        // that makes the test actually detect revert。 5%
        // delta from default has negligible production
        // impact (multi-engine retry budget 4.5s vs 5.0s)。
        conn.busy_timeout(
            std::time::Duration::from_millis(BUSY_TIMEOUT_MS))?;
        // chapter 九百二十三 fix NH7:verify journal_mode
        // actually became WAL,not silently fall through to
        // delete mode on a read-only filesystem。
        // chapter 九百二十四 / M3325 fix NH3:use a more
        // accurate rusqlite::Error variant。 The previous
        // SqliteSingleThreadedMode was semantically unrelated
        // to journal mode and misled debuggers。 SqliteFailure
        // with a descriptive error message is the right shape。
        let mode: String = conn.query_row(
            "PRAGMA journal_mode", [],
            |row| row.get(0))?;
        if mode.to_lowercase() != "wal" {
            return Err(rusqlite::Error::SqliteFailure(
                rusqlite::ffi::Error::new(
                    rusqlite::ffi::SQLITE_ERROR),
                Some(format!(
                    "expected journal_mode=WAL after PRAGMA,\
                     got {:?}",
                    mode))));
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
        // chapter 九百三十二 / M3365 fix HIGH-1 — same
        // foreign_keys post-pragma read-back as open() to
        // surface silent regression on libsqlite3-sys default
        // flips。 See open() comment for 3rd-rusqlite-default
        // coincidence rationale。
        conn.pragma_update(None, "foreign_keys", "ON")?;
        let fk_on: i64 = conn.query_row(
            "PRAGMA foreign_keys", [], |row| row.get(0))?;
        if fk_on != 1 {
            return Err(rusqlite::Error::SqliteFailure(
                rusqlite::ffi::Error::new(
                    rusqlite::ffi::SQLITE_ERROR),
                Some(format!(
                    "expected foreign_keys=1 after PRAGMA, \
                     got {}", fk_on))));
        }
        // chapter 九百二十二 fix NC2:busy_timeout for
        // consistency with disk-backed engine (in-memory
        // can still see contention between threads)。
        // chapter 九百三十一 / M3360:value bumped 5000 → 4500
        // sentinel,see open() comment for rationale。
        conn.busy_timeout(
            std::time::Duration::from_millis(BUSY_TIMEOUT_MS))?;
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
    // chapter 九百四十二 / M3415 fix HIGH-1 (14P) — i32 overflow guard
    let safe_needed = match safe_i32_size(needed) {
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
/// chapter 九百二十六 / M3335 fix CRITICAL-3 — diagnostic
/// FFI helper that reads a PRAGMA value from the engine's
/// OWN connection。 The ch 925 `testWalAutocheckpointIs1000`
/// test opened a separate raw sqlite3 connection and read
/// the PRAGMA there — but PRAGMA wal_autocheckpoint is
/// per-connection (SQLite's compile-time default is 1000),
/// so the test passed even if the ch 920 fix were reverted。
///
/// This helper enables tests to verify PRAGMA values that
/// were actually applied on the engine's connection。 Returns:
///   -1 → null engine
///   -3 → null name or invalid UTF-8
///   -2 → SQLite error
///   ≥0 → the PRAGMA's integer value
///
/// SAFETY:caller must pass valid pointers + lengths。
#[no_mangle]
pub unsafe extern "C" fn bas_l8_engine_pragma_value_i64(
    engine: *const L8Engine,
    name_utf8: *const c_char,
    name_len: usize,
) -> i64 {
    if engine.is_null() { return -1; }
    let name = match cstr_to_str(name_utf8, name_len) {
        Some(s) => s,
        None => return -3,
    };
    // Whitelist of pragmas we expose for test diagnostics。
    // Restricted to integer pragmas that return NON-NEGATIVE
    // values only。
    //
    // chapter 九百三十九 / M3400 fix MED-4 (9P-MED-3 carryover):
    // REMOVED `cache_size` from whitelist because PRAGMA
    // cache_size can return NEGATIVE values (negative = number
    // of KiB to use,positive = number of pages)。 Negative
    // returns collide with -1/-2/-3 error sentinels making the
    // value indistinguishable from null-engine/SQLite-error/
    // invalid-name。 No production code reads cache_size via
    // this FFI today,so removal is safe。 Future need:
    // re-add with separate out-parameter for value.
    //
    // All remaining whitelist entries are documented as
    // returning non-negative values:
    //   wal_autocheckpoint: pages (≥ 0)
    //   busy_timeout: ms (≥ 0)
    //   synchronous: 0..3 enum
    //   journal_size_limit: bytes (≥ 0, -1 means no limit but
    //     that's the SET-only form; query returns positive)
    //   page_size: bytes (positive power of 2)
    //   user_version: caller-stamped (positive by convention)
    //   max_page_count: positive
    //   foreign_keys: 0/1 (added ch 944 per 16P-test-3 — gives
    //     ch 932 12P-HIGH-1 post-pragma read-back guard a
    //     diagnostic test backing it)
    let allowed = ["wal_autocheckpoint", "busy_timeout",
        "synchronous", "journal_size_limit", "page_size",
        "user_version", "max_page_count", "foreign_keys"];
    if !allowed.contains(&name) {
        return -3;
    }
    let engine_ref = unsafe { &*engine };
    let val: Result<i64, rusqlite::Error> =
        engine_ref.with_conn(|conn| {
            conn.query_row(
                &format!("PRAGMA {}", name),
                [],
                |row| row.get(0),
            )
        });
    match val {
        Ok(v) => v,
        Err(_) => -2,
    }
}

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

/// chapter 九百四十一 / M3410 fix HIGH — i32 overflow guard
/// for probe+fill JSON FFIs。 The 5 substance bridges
/// (atom_lifecycle / deletion_manifest / user_state /
/// version_tree / event_log) return `needed as i32` to
/// signal「JSON bytes required」 to Swift。 If the JSON
/// concatenation exceeds 2.1 GB (i32::MAX),the cast
/// silently wraps to negative,which Swift interprets as
/// a FFI error code,silently dropping the read。
///
/// Callers should call this helper before `as i32` casts
/// — returns Err(-4) when the size would overflow,Ok(value)
/// when safe。 -4 is a new sentinel distinct from -1 (null)
/// / -2 (SQLite error) / -3 (UTF-8 / buffer-too-small)。
///
/// Usage:
/// ```ignore
/// let needed = bytes.len();
/// let n = match safe_i32_size(needed) { Ok(n) => n, Err(c) => return c };
/// ```
pub(crate) fn safe_i32_size(needed: usize) -> Result<i32, i32> {
    if needed > i32::MAX as usize {
        Err(-4)
    } else {
        Ok(needed as i32)
    }
}

/// chapter 九百二十四 / M3325 CRITICAL fix — RAII guard for
/// transactional state。 The ch 922 `transactional` helper
/// covered the Err-return path of the body closure,but the
/// panic-unwind path between BEGIN IMMEDIATE and the match
/// block left the Connection with an open transaction +
/// poisoned the Mutex,wedging the engine on next access。
///
/// In DEBUG builds (panic = unwind),Drop runs during stack
/// unwinding,so this guard's Drop impl runs ROLLBACK even
/// when the closure panicked。 In RELEASE (panic = abort),
/// the process exits immediately on panic so engine-wedge
/// can't happen — but the guard is still correct discipline。
struct TxGuard<'a> {
    conn: &'a Connection,
    committed: bool,
}

impl<'a> Drop for TxGuard<'a> {
    fn drop(&mut self) {
        if !self.committed {
            // Best-effort ROLLBACK。 If the connection is
            // in a bad state,we can't do better than this。
            let _ = self.conn.execute("ROLLBACK", []);
        }
    }
}

impl<'a> TxGuard<'a> {
    fn new(conn: &'a Connection) -> rusqlite::Result<Self> {
        conn.execute("BEGIN IMMEDIATE TRANSACTION", [])?;
        Ok(TxGuard { conn, committed: false })
    }

    fn commit(mut self) -> rusqlite::Result<()> {
        self.conn.execute("COMMIT", [])?;
        self.committed = true;
        // Drop will run but `committed` is now true so
        // no ROLLBACK
        Ok(())
    }
}

/// chapter 九百二十四 / M3325 CRITICAL fix — RAII-guarded
/// transactional helper。 Replaces the ch 922 match-based
/// version with a TxGuard that guarantees ROLLBACK on ANY
/// error path INCLUDING panic-unwind (in DEBUG builds)。
///
/// Behavior:
/// - body returns Ok → COMMIT → return Ok(value)
/// - body returns Err → guard Drop runs ROLLBACK → return Err
/// - body panics → guard Drop runs ROLLBACK → unwind continues
/// - COMMIT fails → guard Drop runs ROLLBACK → return Err
///
/// Previously the panic-unwind path leaked the transaction
/// and wedged the engine on next caller's BEGIN IMMEDIATE。
pub(crate) fn transactional<F, T>(
    conn: &Connection,
    body: F,
) -> rusqlite::Result<T>
where
    F: FnOnce(&Connection) -> rusqlite::Result<T>,
{
    let guard = TxGuard::new(conn)?;
    let result = body(conn)?;
    guard.commit()?;
    Ok(result)
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

    // chapter 九百四十一 / M3410 — verify the new overflow
    // guard works correctly:both boundary cases (i32::MAX
    // boundary + just-over-boundary) + happy path。
    #[test]
    fn safe_i32_size_returns_value_below_boundary() {
        assert_eq!(safe_i32_size(0), Ok(0));
        assert_eq!(safe_i32_size(100), Ok(100));
        assert_eq!(safe_i32_size(i32::MAX as usize), Ok(i32::MAX));
    }

    #[test]
    fn safe_i32_size_rejects_overflow() {
        // Just past i32::MAX → returns -4 sentinel
        assert_eq!(
            safe_i32_size(i32::MAX as usize + 1),
            Err(-4));
        assert_eq!(
            safe_i32_size(usize::MAX),
            Err(-4));
    }

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
        // 926: 17→18 +bas_l8_engine_pragma_value_i64
        //            (diagnostic FFI per 6th-pass review CRITICAL-3
        //             — enables real wal_autocheckpoint test
        //             that doesn't open separate raw connection).
        assert_eq!(bas_l8_engine_abi_version(), 18);
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

    // chapter 九百二十六 / M3335 fix CRITICAL-4 — panic-safety
    // regression guard for the ch 924 NC1 TxGuard RAII fix。
    //
    // Without the guard:a closure that panics between
    // `BEGIN IMMEDIATE` and `COMMIT` leaves the connection
    // in transactional state forever。 With the guard:Drop
    // runs during unwind and ROLLBACK fires。 The next
    // `transactional` call on the same connection must be
    // able to BEGIN IMMEDIATE again。
    //
    // Test strategy:
    //  1. Open in-memory engine + init event_log schema
    //  2. Call `transactional(conn, |conn| { panic!() })`
    //     inside catch_unwind — guard's Drop must fire
    //  3. Call `transactional(conn, |conn| { Ok(...) })`
    //     immediately after — must succeed (engine not wedged)
    //
    // Without TxGuard the third step would fail with
    // "cannot start a transaction within a transaction"。
    //
    // NOTE: Cargo.toml release profile uses panic=abort,so
    // this test only validates DEBUG semantics。 But Drop is
    // the intended correctness guarantor even in release —
    // we just can't observe it via panic in release builds。
    #[test]
    fn tx_guard_rollback_on_panic_unwinds_cleanly() {
        use std::panic::{catch_unwind, AssertUnwindSafe};

        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0)
        };
        assert!(!engine.is_null());
        let init_rc = unsafe {
            crate::event_log
                ::bas_l8_event_log_init_schema(engine)
        };
        assert_eq!(init_rc, 0);
        let engine_ref = unsafe { &*engine };

        // Step 1: cause a panic INSIDE transactional body
        let panic_result = catch_unwind(AssertUnwindSafe(|| {
            let _: rusqlite::Result<i64> = engine_ref
                .with_conn(|conn| {
                    transactional(conn, |_inner_conn| {
                        panic!("intentional panic mid-tx");
                    })
                });
        }));
        assert!(panic_result.is_err(),
            "panic must propagate out of transactional");

        // Step 2: next transactional must succeed (engine
        // not wedged in BEGIN-without-COMMIT state)。 If
        // TxGuard Drop didn't fire,this would fail with
        // "cannot start a transaction within a transaction"。
        let recovery_result: rusqlite::Result<i64> =
            engine_ref.with_conn(|conn| {
                transactional(conn, |c2| {
                    c2.query_row(
                        "SELECT 42", [], |r| r.get(0))
                })
            });
        assert_eq!(recovery_result.unwrap(), 42,
            "engine must not be wedged after panicking tx");

        unsafe { bas_l8_engine_close(engine); }
    }

    // chapter 九百二十六 / M3335 fix CRITICAL-1 regression
    // guard — verify the conditional UNIQUE index migration
    // produces correct index count on fresh AND legacy DBs。
    //
    // chapter 九百二十七 / M3340 fix CRITICAL-2 — superseded
    // by `fresh_db_table_level_unique_constraint_intact` below
    // which uses PRAGMA index_list origin='c' to distinguish
    // table-level UNIQUE auto-index from migration-created
    // explicit index。 The OLD test (kept below) is a
    // tautology — passes whether table-level UNIQUE exists OR
    // not,because the migration fallback creates an equivalent
    // explicit index in either case。 User's 7th-pass
    // reversibility experiment (removing UNIQUE constraint
    // from table) proved this: 75/75 tests passed unchanged。
    //
    // The OLD test is kept as a guard against the「2 unique
    // indexes on fresh DB」 regression that ch 924 introduced
    // (which the new test ALSO catches via auto-index check),
    // but it cannot be the sole UNIQUE-constraint guard。
    #[test]
    fn fresh_db_has_exactly_one_unique_on_session_seq() {
        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0)
        };
        let init_rc = unsafe {
            crate::event_log
                ::bas_l8_event_log_init_schema(engine)
        };
        assert_eq!(init_rc, 0);
        let engine_ref = unsafe { &*engine };

        // Count unique indexes on event_log(session_id,
        // sequence_number)。 We query sqlite_master + filter
        // index_list to find UNIQUE indexes spanning exactly
        // those two columns。
        let count: i64 = engine_ref.with_conn(|conn| {
            // Get all indexes for event_log
            let mut stmt = conn.prepare(
                "SELECT name FROM sqlite_master \
                 WHERE type='index' AND tbl_name='event_log'")?;
            let names: Vec<String> = stmt
                .query_map([], |r| r.get::<_, String>(0))?
                .filter_map(|r| r.ok())
                .collect();
            // Count UNIQUE indexes where the columns are
            // exactly [session_id, sequence_number] in order
            let mut count: i64 = 0;
            for name in &names {
                // Skip non-unique indexes
                let info_q = format!(
                    "PRAGMA index_info('{}')", name);
                let list_q = format!(
                    "PRAGMA index_list('event_log')");
                // Check unique flag
                let mut unique_stmt = conn.prepare(&list_q)?;
                let is_unique: bool = unique_stmt
                    .query_map([], |r| Ok((
                        r.get::<_, String>(1)?,
                        r.get::<_, i64>(2)? != 0)))?
                    .filter_map(|r| r.ok())
                    .find(|(n, _)| n == name)
                    .map(|(_, u)| u)
                    .unwrap_or(false);
                if !is_unique { continue; }
                // Check columns are exactly [session_id,
                // sequence_number]
                let mut info_stmt = conn.prepare(&info_q)?;
                let cols: Vec<String> = info_stmt
                    .query_map([], |r| r.get::<_, String>(2))?
                    .filter_map(|r| r.ok())
                    .collect();
                if cols == vec!["session_id".to_string(),
                    "sequence_number".to_string()] {
                    count += 1;
                }
            }
            Ok::<i64, rusqlite::Error>(count)
        }).unwrap();

        assert_eq!(count, 1,
            "fresh DB must have EXACTLY 1 unique index on \
             (session_id, sequence_number) — auto-index from \
             table-level UNIQUE constraint。 ch 926 fixed the \
             ch 924 bug that created 2 (auto + explicit)");

        unsafe { bas_l8_engine_close(engine); }
    }

    // chapter 九百二十七 / M3340 fix CRITICAL-2 — REAL
    // regression guard for the ch 919 C4 UNIQUE constraint。
    // The old `fresh_db_has_exactly_one_unique_on_session_seq`
    // is a tautology because the migration fallback creates
    // an equivalent explicit index whenever the table-level
    // UNIQUE is missing — so「exactly 1 unique index」 is
    // true in BOTH (constraint present) AND (constraint
    // absent + migration fallback) cases。
    //
    // This test specifically asserts that the unique index
    // has origin='u' (created by a UNIQUE constraint,not by
    // a user CREATE INDEX statement)。 PRAGMA index_list
    // returns an origin column with values per SQLite docs
    // (https://www.sqlite.org/pragma.html#pragma_index_list):
    //   'c' = created by a CREATE INDEX statement
    //         (including CREATE UNIQUE INDEX)
    //   'u' = created by a UNIQUE constraint
    //   'pk' = created by a PRIMARY KEY constraint
    //
    // If the table-level UNIQUE were removed,SQLite would
    // not auto-create the 'u'-origin index,and migration
    // would create a 'c'-origin index instead — this test
    // would FAIL,catching the regression that ch 926's
    // earlier test missed (verified empirically:user's
    // 7th-pass reversibility experiment removed UNIQUE and
    // old test still passed because migration fallback
    // created a 'c'-origin explicit index)。
    #[test]
    fn fresh_db_table_level_unique_constraint_intact() {
        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0)
        };
        let init_rc = unsafe {
            crate::event_log
                ::bas_l8_event_log_init_schema(engine)
        };
        assert_eq!(init_rc, 0);
        let engine_ref = unsafe { &*engine };

        let has_constraint_unique: bool = engine_ref
            .with_conn(|conn| {
                // PRAGMA index_list returns:
                //   seq | name | unique | origin | partial
                let mut stmt = conn.prepare(
                    "PRAGMA index_list('event_log')")?;
                let rows: Vec<(String, bool, String)> = stmt
                    .query_map([], |r| Ok((
                        r.get::<_, String>(1)?,           // name
                        r.get::<_, i64>(2)? != 0,         // unique
                        r.get::<_, String>(3)?,           // origin
                    )))?
                    .filter_map(|r| r.ok())
                    .collect();
                let mut found = false;
                for (name, is_unique, origin) in rows {
                    if !is_unique || origin != "u" {
                        continue;
                    }
                    let info_q = format!(
                        "PRAGMA index_info('{}')", name);
                    let mut info_stmt = conn.prepare(&info_q)?;
                    let cols: Vec<String> = info_stmt
                        .query_map([], |r|
                            r.get::<_, String>(2))?
                        .filter_map(|r| r.ok())
                        .collect();
                    if cols == vec![
                        "session_id".to_string(),
                        "sequence_number".to_string(),
                    ] {
                        found = true;
                        break;
                    }
                }
                Ok::<bool, rusqlite::Error>(found)
            }).unwrap();

        assert!(has_constraint_unique,
            "fresh DB MUST have a UNIQUE-CONSTRAINT-origin \
             (origin='u') unique index covering \
             (session_id, sequence_number) — proves the \
             table-level UNIQUE constraint exists at the \
             schema level,not just via migration fallback \
             (which would create 'c'-origin explicit index)");

        unsafe { bas_l8_engine_close(engine); }
    }

    // chapter 九百二十七 / M3340 fix CRITICAL-2 — functional
    // test of the UNIQUE constraint via direct SQL insert。
    // The previous tests check the schema invariant; this
    // test checks the runtime invariant by attempting a
    // duplicate insert via raw SQL (bypassing the FFI auto-
    // increment that protects against accidental collisions)。
    //
    // Even with migration fallback (explicit index instead
    // of table-level constraint),this test passes because
    // BOTH paths create a unique index that rejects the
    // duplicate。 So it's a positive-only guard — the
    // table-level vs explicit distinction is enforced by
    // the sibling `fresh_db_table_level_unique_constraint_
    // intact` test above。
    #[test]
    fn fresh_db_rejects_duplicate_session_seq_via_direct_sql() {
        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0)
        };
        let init_rc = unsafe {
            crate::event_log
                ::bas_l8_event_log_init_schema(engine)
        };
        assert_eq!(init_rc, 0);
        let engine_ref = unsafe { &*engine };

        // First insert via direct SQL — succeeds
        let result1 = engine_ref.with_conn(|conn| {
            conn.execute(
                "INSERT INTO event_log \
                 (event_id, session_id, sequence_number, \
                  timestamp_ms, kind, risk_band, payload_json) \
                 VALUES ('evt-A', 'sess-X', 0, 100, \
                         'k', 'low', '{}')",
                [],
            )
        });
        assert!(result1.is_ok(),
            "first direct-SQL insert succeeds");

        // Second insert with SAME (session_id, sequence_number)
        // but DIFFERENT event_id — must FAIL via UNIQUE
        // constraint (covers schema-level OR migration-explicit
        // path; either enforces uniqueness)
        let result2 = engine_ref.with_conn(|conn| {
            conn.execute(
                "INSERT INTO event_log \
                 (event_id, session_id, sequence_number, \
                  timestamp_ms, kind, risk_band, payload_json) \
                 VALUES ('evt-B', 'sess-X', 0, 200, \
                         'k', 'low', '{}')",
                [],
            )
        });
        assert!(result2.is_err(),
            "duplicate (session_id, sequence_number) MUST be \
             rejected by UNIQUE constraint when inserted via \
             direct SQL — proves the runtime invariant beyond \
             the FFI auto-increment that protects accidental \
             collisions");

        unsafe { bas_l8_engine_close(engine); }
    }

    // chapter 九百二十七 / M3340 fix HIGH-1 — regression guard
    // for the ch 926 HIGH-1 MAX_EMBEDDING_BYTES cap on the
    // cosine_topk FFI's query_blob_len parameter。 The Swift
    // test in ch 926 hits the Swift-side cap at 16384 floats
    // BEFORE reaching the FFI,so the Rust cap was untested。
    // This test calls the FFI directly with oversized input。
    #[test]
    fn cosine_topk_ffi_rejects_oversized_query_blob() {
        use std::os::raw::c_char;
        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0)
        };
        let init_rc = unsafe {
            crate::vector_index
                ::bas_l8_vector_index_init_schema(engine)
        };
        assert_eq!(init_rc, 0);

        // 65540 bytes = 65536 cap + 4 — just over the cap
        let oversize: Vec<u8> = vec![0u8; 65_540];
        let domain = b"d1";
        let mut out_rowids = vec![0i64; 5];
        let mut out_scores = vec![0f32; 5];

        let rc = unsafe {
            crate::vector_index
                ::bas_l8_vector_index_cosine_topk_for_domain(
                    engine,
                    domain.as_ptr() as *const c_char,
                    domain.len(),
                    oversize.as_ptr(),
                    oversize.len(),
                    5,
                    out_rowids.as_mut_ptr(),
                    out_scores.as_mut_ptr())
        };
        assert_eq!(rc, -3,
            "oversized query_blob_len (> MAX_EMBEDDING_BYTES) \
             MUST be rejected at FFI boundary with -3 — \
             prevents Vec::with_capacity OOM-abort attack");

        // Also test the with_skipped variant
        let mut out_skipped: i64 = 0;
        let rc2 = unsafe {
            crate::vector_index
                ::bas_l8_vector_index_cosine_topk_for_domain_with_skipped(
                    engine,
                    domain.as_ptr() as *const c_char,
                    domain.len(),
                    oversize.as_ptr(),
                    oversize.len(),
                    5,
                    out_rowids.as_mut_ptr(),
                    out_scores.as_mut_ptr(),
                    &mut out_skipped)
        };
        assert_eq!(rc2, -3,
            "with_skipped variant must ALSO reject oversized \
             query_blob_len");

        unsafe { bas_l8_engine_close(engine); }
    }

    // chapter 九百二十六 / M3335 — verify the diagnostic PRAGMA
    // helper reads the engine's OWN connection (not a fresh
    // connection that gets SQLite's compile-time default)。
    //
    // ch 920 set wal_autocheckpoint=1000 on the engine's
    // connection。 ch 925's fake test opened a separate raw
    // sqlite3 connection (default 1000) so the assertion
    // passed for the wrong reason。 This test reads from the
    // engine's OWN connection via the new FFI helper。
    #[test]
    fn pragma_value_helper_reads_engine_connection() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        let path = tmp.path().to_str().unwrap();
        let path_bytes = path.as_bytes();
        let engine = unsafe {
            bas_l8_engine_init(
                path_bytes.as_ptr() as *const c_char,
                path_bytes.len())
        };
        let name = "wal_autocheckpoint";
        let name_bytes = name.as_bytes();
        let value = unsafe {
            bas_l8_engine_pragma_value_i64(
                engine,
                name_bytes.as_ptr() as *const c_char,
                name_bytes.len())
        };
        // chapter 九百二十七 / M3340 fix CRITICAL-1 — value
        // bumped from 1000 (SQLite default,was fake-coverage)
        // to 1024 (power-of-2 sentinel,detectably non-default)。
        // If someone reverts the ch 920 pragma_update call,
        // this assertion fails — proving real revertibility
        // guard。 See lib.rs:181-198 for the rationale。
        assert_eq!(value, 1024,
            "wal_autocheckpoint must be 1024 on engine \
             connection (ch 920 fix verified via diagnostic FFI; \
             ch 927 sentinel value differs from SQLite default 1000)");

        // Also verify busy_timeout (ch 922 NC2 fix)。
        //
        // chapter 九百三十一 / M3360 fix CRITICAL-3:value
        // bumped 5000 → 4500 because rusqlite 0.32 sets
        // sqlite3_busy_timeout(db, 5000) AUTOMATICALLY in
        // open_with_flags — previous「5000 differs from
        // SQLite default 0」 comment was WRONG (rusqlite
        // intercepts before the C-level default applies)。
        // 4500 is non-default-of-rusqlite sentinel making
        // the test actually detect ch 922 fix revert。
        let busy_name = "busy_timeout";
        let busy_bytes = busy_name.as_bytes();
        let busy = unsafe {
            bas_l8_engine_pragma_value_i64(
                engine,
                busy_bytes.as_ptr() as *const c_char,
                busy_bytes.len())
        };
        assert_eq!(busy, 4500,
            "busy_timeout must be 4500 ms on engine \
             connection (ch 922 NC2 fix + ch 931 sentinel — \
             rusqlite default is 5000,so 4500 is the only \
             value that proves OUR pragma_update ran)");

        unsafe { bas_l8_engine_close(engine); }
    }

    // chapter 九百二十六 / M3335 fix CRITICAL-4 (NH1 schema
    // migration regression guard) — verify the conditional
    // migration adds the explicit unique index to a LEGACY
    // pre-ch-919 DB that lacks the table-level UNIQUE。
    //
    // Strategy: create a connection,manually create the
    // event_log table with the PRE-ch-919 schema (no UNIQUE
    // constraint),then call init_schema and verify the
    // explicit index got added。
    #[test]
    fn legacy_db_gets_explicit_unique_index_added() {
        let conn = rusqlite::Connection::open_in_memory()
            .unwrap();
        // Pre-ch-919 schema: no UNIQUE constraint
        conn.execute_batch(r#"
            CREATE TABLE event_log (
                event_id TEXT PRIMARY KEY NOT NULL,
                session_id TEXT NOT NULL,
                sequence_number INTEGER NOT NULL,
                timestamp_ms INTEGER NOT NULL,
                kind TEXT NOT NULL,
                risk_band TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                payload_format INTEGER NOT NULL DEFAULT 1,
                payload_blob BLOB
            );
        "#).unwrap();
        // Verify pre-state: no explicit unique index yet
        let pre_count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM sqlite_master \
             WHERE type='index' \
               AND name='event_log_session_seq_uniq'",
            [],
            |r| r.get(0),
        ).unwrap();
        assert_eq!(pre_count, 0,
            "legacy DB starts without explicit unique index");

        // Run init_schema (which runs the migration)
        crate::event_log::init_schema(&conn).unwrap();

        // Post-state: explicit unique index MUST exist
        let post_count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM sqlite_master \
             WHERE type='index' \
               AND name='event_log_session_seq_uniq'",
            [],
            |r| r.get(0),
        ).unwrap();
        assert_eq!(post_count, 1,
            "legacy DB migration must create \
             event_log_session_seq_uniq explicit index");

        // Verify uniqueness is now enforced: insert two
        // rows with same (session_id, sequence_number)
        // — the second must fail with constraint error
        conn.execute(
            "INSERT INTO event_log (event_id, session_id, \
             sequence_number, timestamp_ms, kind, risk_band, \
             payload_json) VALUES \
             ('e1', 's1', 0, 100, 'k', 'low', '{}')",
            [],
        ).unwrap();
        let err = conn.execute(
            "INSERT INTO event_log (event_id, session_id, \
             sequence_number, timestamp_ms, kind, risk_band, \
             payload_json) VALUES \
             ('e2', 's1', 0, 200, 'k', 'low', '{}')",
            [],
        );
        assert!(err.is_err(),
            "duplicate (session_id, sequence_number) must \
             be rejected after migration");
    }

    // chapter 九百二十六 / M3335 — explicit Mutex poison recovery
    // regression guard for ch 919 C5 fix。
    //
    // The `tx_guard_rollback_on_panic` test above implicitly
    // exercises this (panic poisons mutex,subsequent with_conn
    // must succeed),but this test is SCOPED to the C5 fix
    // alone — no transactional semantics involved。 If someone
    // reverts the `.unwrap_or_else(|p| p.into_inner())` back to
    // `.unwrap()`,this test fails while tx_guard_rollback might
    // still pass for unrelated reasons。
    #[test]
    fn mutex_poison_recovery_keeps_engine_usable() {
        use std::panic::{catch_unwind, AssertUnwindSafe};

        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0)
        };
        let engine_ref = unsafe { &*engine };

        // Trigger a panic while the mutex is held — poisons it
        let panic_result = catch_unwind(AssertUnwindSafe(|| {
            let _: i64 = engine_ref.with_conn(|_conn| {
                panic!("intentional panic inside with_conn");
            });
        }));
        assert!(panic_result.is_err());

        // Next with_conn MUST succeed (poison recovery via
        // into_inner)。 If C5 were reverted,this would panic
        // with PoisonError unwrap。
        let value: i64 = engine_ref.with_conn(|conn| {
            conn.query_row("SELECT 7", [], |r| r.get(0))
                .unwrap_or(-1)
        });
        assert_eq!(value, 7,
            "with_conn must succeed after mutex poison \
             (ch 919 C5 fix unwrap_or_else(into_inner))");

        unsafe { bas_l8_engine_close(engine); }
    }

    // chapter 九百二十六 / M3335 — explicit transactional rollback
    // test for ch 922 NC1 fix。 The `tx_guard_rollback_on_panic`
    // test covers the panic-unwind path,but the Err-return
    // path of the closure also needs a regression guard。
    #[test]
    fn transactional_rolls_back_on_err_return() {
        let conn = rusqlite::Connection::open_in_memory()
            .unwrap();
        conn.execute_batch(
            "CREATE TABLE t (id INT PRIMARY KEY, v INT);"
        ).unwrap();
        conn.execute("INSERT INTO t VALUES (1, 100)", [])
            .unwrap();

        // Body that inserts a row,then returns Err — must
        // rollback so the insert does NOT persist
        let result: rusqlite::Result<()> = transactional(
            &conn,
            |c| {
                c.execute("INSERT INTO t VALUES (2, 200)", [])?;
                Err(rusqlite::Error::QueryReturnedNoRows)
            });
        assert!(result.is_err());

        let count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM t", [], |r| r.get(0))
            .unwrap();
        assert_eq!(count, 1,
            "transactional must ROLLBACK on Err return — \
             without ch 922 NC1 fix the INSERT 2,200 would \
             persist as a non-transactional partial write");

        // Verify next transactional still works (engine
        // not wedged in BEGIN-without-COMMIT state)
        let success: rusqlite::Result<i64> = transactional(
            &conn,
            |c| c.query_row("SELECT 99", [], |r| r.get(0)));
        assert_eq!(success.unwrap(), 99);
    }
}
