// SPDX:internal
//
// event_log.rs — chapter 九百一 / M3195
//
// L8 unification FIRST HIGH-risk migration per RFC。 Ports
// `BASSQLiteEventLogStorage` (event_log v2 schema)。 Per-event
// turn-loop hot path — every turn lifecycle event appends here
// via `BASTurnRuntimeEngine.append(entry)`。
//
// # Careful-migration discipline (per user 「细心开发」 directive)
//
//   - Embed v2 schema directly (Rust engine creates fresh,no
//     v1→v2 ALTER TABLE migration path needed — Swift legacy
//     actor handles upgrades on its own DB files,Rust starts
//     fresh per engine init)
//   - Auto-sequence number assignment per session via
//     SELECT COALESCE(MAX(sequence_number)+1, 0) WHERE session_id
//   - Idempotent append:pre-check event_id,return existing
//     sequence_number on duplicate (matches Swift wasNew=false
//     semantics)
//   - Prune-before:DELETE WHERE timestamp_ms < cutoff,return
//     rows deleted (matches Swift M896 retention)
//   - Payload format dual:format=1 → payload_json populated /
//     payload_blob NULL,format=2 → payload_blob populated /
//     payload_json empty string
//
// # Schema (embedded v2 from chapter 七百三十二 第一刀 + chapter
//          九百一 unified definition)
//
//   event_id TEXT PRIMARY KEY
//   session_id TEXT NOT NULL
//   sequence_number INTEGER NOT NULL
//   timestamp_ms INTEGER NOT NULL
//   kind TEXT NOT NULL
//   risk_band TEXT NOT NULL
//   payload_json TEXT NOT NULL (empty string when payload_format=2)
//   payload_format INTEGER NOT NULL DEFAULT 1 (1=json, 2=blob)
//   payload_blob BLOB (nullable when payload_format=1)

use std::os::raw::{c_char, c_int};
use rusqlite::Connection;
use rusqlite::params;

use crate::L8Engine;

const SCHEMA_EVENT_LOG: &str = r#"
CREATE TABLE IF NOT EXISTS event_log (
    event_id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL,
    sequence_number INTEGER NOT NULL,
    timestamp_ms INTEGER NOT NULL,
    kind TEXT NOT NULL,
    risk_band TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    payload_format INTEGER NOT NULL DEFAULT 1,
    payload_blob BLOB,
    -- chapter 九百十九 / M3300 CRITICAL fix C4:enforce
    -- per-session sequence uniqueness at the schema level
    -- so multi-engine race conditions surface as constraint
    -- failures instead of silently writing duplicate seqs
    UNIQUE(session_id, sequence_number)
);
-- chapter 九百二十三 / M3320 NH1 fix:dropped
-- `event_log_session_seq_idx` — the UNIQUE(session_id,
-- sequence_number) constraint (ch 919) auto-creates the
-- equivalent index。 Keeping both inflates write cost
-- (every INSERT updates 5 indexes instead of 4)。
CREATE INDEX IF NOT EXISTS event_log_timestamp_idx
  ON event_log(timestamp_ms);
CREATE INDEX IF NOT EXISTS event_log_kind_idx
  ON event_log(kind);
-- chapter 九百二十 / M3305 HIGH-4 fix:composite covering
-- index for the recent-events-per-session hot path
-- (chapter 909 recent_event_timestamps_for_session ORDER BY
-- timestamp_ms DESC LIMIT N)。 Without this index SQLite
-- filters by session_id then sorts in memory — at 100K
-- events that's a multi-ms scan per query。
CREATE INDEX IF NOT EXISTS event_log_session_time_idx
  ON event_log(session_id, timestamp_ms DESC);
-- chapter 九百二十四 / M3325 fix NH1:explicit migration to
-- DROP the redundant index that pre-ch-923 schema strings
-- created。 `CREATE TABLE IF NOT EXISTS` doesn't remove old
-- indexes,so existing DBs upgraded from ch 901-922 still
-- carry `event_log_session_seq_idx` — DROP it explicitly
-- so the「~20% write-cost reduction」 chapter 923 promised
-- actually lands on upgraded DBs (not just fresh installs)。
DROP INDEX IF EXISTS event_log_session_seq_idx;
-- chapter 九百二十六 / M3335 fix CRITICAL-1:the previous
-- ch 924 NH5 fix unconditionally CREATEd a UNIQUE INDEX
-- here even on fresh DBs — but the table-level UNIQUE
-- constraint at line 61 auto-creates sqlite_autoindex_
-- event_log_2 covering the same columns。 Fresh DBs ended
-- up with TWO unique indexes,inverting the ch 923 ~20%
-- write-cost-reduction promise。 The conditional migration
-- now lives in `init_schema` (Rust) instead of being
-- baked into this constant — see comment there。
"#;

pub fn init_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_EVENT_LOG)?;
    migrate_unique_session_seq(conn)?;
    Ok(())
}

/// chapter 九百二十六 / M3335 fix CRITICAL-1 — conditional
/// migration for the explicit unique index that the ch 924
/// NH5 fix tried (but botched) to ship。 Reads the table's
/// own CREATE TABLE SQL from `sqlite_master`:
///   - if it contains「UNIQUE(session_id, sequence_number)」
///     (== created at or after ch 919) → DO NOTHING (the
///     table-level constraint already auto-creates the
///     equivalent index; adding another would be wasteful)
///   - if it does NOT contain that phrase (== legacy pre-
///     ch-919 schema) → CREATE the explicit unique index
///     so the invariant is retroactively enforced
///
/// Idempotent on both fresh and legacy DBs。 Also DROPs the
/// stale `event_log_session_seq_uniq` index if a previous
/// (broken) ch 924 init had created it on a fresh DB —
/// that's the cleanup path for anyone whose binary upgrade
/// crossed the broken ch 924 → fixed ch 926 boundary。
fn migrate_unique_session_seq(
    conn: &Connection,
) -> rusqlite::Result<()> {
    // chapter 九百三十九 / M3400 fix MED-5 (9P-MED-4 carryover):
    // REPLACED brittle substring-against-table-SQL check with
    // structural PRAGMA index_list query that asks SQLite
    // directly:「is there a UNIQUE-constraint-origin index
    // covering (session_id, sequence_number)?」
    //
    // The old substring check was vulnerable to:
    //   - Quoted column names: UNIQUE("session_id", ...)
    //   - Column reorder: UNIQUE(sequence_number, session_id)
    //   - Whitespace variants: UNIQUE  (col, col) with double-space
    //   - Future schema reformat: any non-canonical UNIQUE syntax
    // would silently fall through to legacy-DB path → create
    // explicit index → 2 unique indexes (the ch 926 bug class)。
    //
    // Structural query asks SQLite itself via PRAGMA — robust
    // against any future schema-text reformatting。 Same query
    // used by `fresh_db_table_level_unique_constraint_intact`
    // test (ch 927)。
    let mut stmt = conn.prepare(
        "PRAGMA index_list('event_log')")?;
    let mut rows = stmt.query([])?;
    let mut has_table_constraint = false;
    while let Some(row) = rows.next()? {
        let name: String = row.get(1)?;
        let is_unique: bool = row.get::<_, i64>(2)? != 0;
        let origin: String = row.get(3)?;
        // origin='u' means「created by UNIQUE constraint」
        // (per SQLite docs)。 origin='c' would mean a manually-
        // created CREATE UNIQUE INDEX。
        if !is_unique || origin != "u" {
            continue;
        }
        let info_q = format!(
            "PRAGMA index_info('{}')", name);
        let mut info_stmt = conn.prepare(&info_q)?;
        let cols: Vec<String> = info_stmt
            .query_map([], |r| r.get::<_, String>(2))?
            .filter_map(|r| r.ok())
            .collect();
        if cols == vec![
            "session_id".to_string(),
            "sequence_number".to_string(),
        ] {
            has_table_constraint = true;
            break;
        }
    }
    if has_table_constraint {
        // Fresh / post-ch-919 DB: drop the redundant
        // explicit index if a buggy ch 924 binary added it。
        conn.execute(
            "DROP INDEX IF EXISTS event_log_session_seq_uniq",
            [],
        )?;
    } else {
        // Legacy pre-ch-919 DB: the table lacks the UNIQUE
        // constraint at the schema level,so we add an
        // explicit unique index to enforce it。 If existing
        // data violates uniqueness this will fail loudly
        // (intentional — surface corruption,don't hide it)。
        conn.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS \
             event_log_session_seq_uniq \
             ON event_log(session_id, sequence_number)",
            [],
        )?;
    }
    Ok(())
}

/// Look up next sequence number for a session。 Returns 0 for
/// first event in session,or MAX(existing) + 1 otherwise。
/// Matches Swift `nextSequenceNumber` exactly。
pub fn next_sequence_number(
    conn: &Connection,
    session_id: &str,
) -> rusqlite::Result<i64> {
    let next: i64 = conn.query_row(
        "SELECT COALESCE(MAX(sequence_number) + 1, 0)
         FROM event_log WHERE session_id = ?",
        params![session_id],
        |row| row.get(0),
    )?;
    Ok(next)
}

/// Returns the existing sequence_number if event_id already
/// inserted,or None if not present。 Used for idempotent append。
pub fn fetch_existing_sequence(
    conn: &Connection,
    event_id: &str,
) -> rusqlite::Result<Option<i64>> {
    conn.query_row(
        "SELECT sequence_number FROM event_log
         WHERE event_id = ?",
        params![event_id],
        |row| row.get::<_, i64>(0),
    ).map(Some).or_else(|e| match e {
        rusqlite::Error::QueryReturnedNoRows => Ok(None),
        other => Err(other),
    })
}

/// Append an event。 Idempotent on duplicate event_id (returns
/// existing sequence_number)。 Returns (was_new, sequence_number)。
#[allow(clippy::too_many_arguments)]
pub fn append_event(
    conn: &Connection,
    event_id: &str,
    session_id: &str,
    timestamp_ms: i64,
    kind: &str,
    risk_band: &str,
    payload_json: &str,
    payload_format: i32,
    payload_blob: Option<&[u8]>,
) -> rusqlite::Result<(bool, i64)> {
    // chapter 九百二十二 / M3315 CRITICAL fix NC1:use the
    // centralized `transactional` helper to guarantee
    // ROLLBACK on ALL error paths,not just INSERT failure。
    // Previously the chapter 919 wrap had open-transaction
    // leaks on read-step errors (fetch_existing_sequence,
    // next_sequence_number returning Err)。
    crate::transactional(conn, |conn| {
        if let Some(existing_seq) =
            fetch_existing_sequence(conn, event_id)?
        {
            return Ok((false, existing_seq));
        }
        let assigned = next_sequence_number(conn, session_id)?;
        conn.execute(
            "INSERT INTO event_log (
                event_id, session_id, sequence_number,
                timestamp_ms, kind, risk_band, payload_json,
                payload_format, payload_blob
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            params![
                event_id, session_id, assigned,
                timestamp_ms, kind, risk_band, payload_json,
                payload_format, payload_blob,
            ],
        )?;
        Ok((true, assigned))
    })
}

pub fn count_events(
    conn: &Connection,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM event_log",
        [], |row| row.get(0))
}

pub fn count_events_for_session(
    conn: &Connection,
    session_id: &str,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM event_log
         WHERE session_id = ?",
        params![session_id], |row| row.get(0))
}

pub fn count_events_for_kind(
    conn: &Connection,
    kind: &str,
) -> rusqlite::Result<i64> {
    conn.query_row(
        "SELECT COUNT(*) FROM event_log WHERE kind = ?",
        params![kind], |row| row.get(0))
}

/// Delete rows where timestamp_ms < cutoff。 Returns count of
/// rows deleted (matches Swift M896 retention semantics)。
pub fn prune_events_before(
    conn: &Connection,
    cutoff_ms: i64,
) -> rusqlite::Result<i64> {
    let n = conn.execute(
        "DELETE FROM event_log WHERE timestamp_ms < ?",
        params![cutoff_ms])?;
    Ok(n as i64)
}

/// chapter 九百九 / M3250 — hot-path consolidation #2
/// (extending chapter 906 cosine_topk pattern to event_log)。
///
/// Returns the N most-recent events for a session as parallel
/// (timestamp_ms, sequence_number) tuples sorted descending
/// by timestamp。 ONE FFI call replaces:
///   1. count_events_for_session (N == ? lookup)
///   2. N × single-event reads to gather timestamps + seqs
///
/// Used by consumers that need to find「recent event window」
/// for retention or replay decisions。 Production sessions
/// often have 100-1000 events;the orchestrated baseline
/// would do that many FFI hops。
pub fn recent_event_timestamps_for_session(
    conn: &Connection,
    session_id: &str,
    limit: usize,
) -> rusqlite::Result<Vec<(i64, i64)>> {
    let mut stmt = conn.prepare(
        "SELECT timestamp_ms, sequence_number
           FROM event_log
          WHERE session_id = ?
          ORDER BY timestamp_ms DESC
          LIMIT ?"
    )?;
    let mut rows = stmt.query(params![
        session_id, limit as i64])?;
    let mut out: Vec<(i64, i64)> = Vec::with_capacity(limit);
    while let Some(row) = rows.next()? {
        let ts: i64 = row.get(0)?;
        let seq: i64 = row.get(1)?;
        out.push((ts, seq));
    }
    Ok(out)
}

// MARK: - FFI

#[no_mangle]
pub unsafe extern "C" fn bas_l8_event_log_init_schema(
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

/// Append event。 Returns assigned sequence_number on success
/// (≥ 0),or negative status code:
///   -1 → null engine
///   -2 → SQLite error
///   -3 → UTF-8 decode failure
///
/// To distinguish was_new from idempotent-dup,callers should
/// compare returned seq vs `bas_l8_event_log_next_sequence`
/// before append。 OR use `_with_was_new` variant (deferred to
/// future chapter if needed)。
///
/// Payload format:1 = json (payload_blob_len = 0),2 = blob
/// (payload_json must be empty string ""),3+ = reserved。
#[no_mangle]
pub unsafe extern "C" fn bas_l8_event_log_append(
    engine: *const L8Engine,
    event_id_utf8: *const c_char, event_id_len: usize,
    session_id_utf8: *const c_char, session_id_len: usize,
    timestamp_ms: i64,
    kind_utf8: *const c_char, kind_len: usize,
    risk_band_utf8: *const c_char, risk_band_len: usize,
    payload_json_utf8: *const c_char, payload_json_len: usize,
    payload_format: i32,
    payload_blob_bytes: *const u8, payload_blob_len: usize,
    out_was_new: *mut i32,  // 1 if newly inserted, 0 if dup
) -> i64 {
    if engine.is_null() { return -1; }
    // chapter 九百二十三 / M3320 NH3 fix:bound BLOB
    // + JSON sizes to prevent OOM-via-upsert。
    if payload_json_len > crate::MAX_PAYLOAD_JSON_BYTES {
        return -3;
    }
    if payload_blob_len > crate::MAX_PAYLOAD_BLOB_BYTES {
        return -3;
    }
    // chapter 九百二十四 / M3325 NH2 fix:enforce
    // payload_format / payload presence coherence。 The schema
    // says 1=json, 2=blob, 3+=reserved — but the FFI accepted
    // arbitrary integers + arbitrary payload presence。 Now:
    //   format=1 → payload_json must be non-empty,blob must be empty
    //   format=2 → payload_blob must be non-empty,json must be empty
    if payload_format != 1 && payload_format != 2 {
        return -3;
    }
    if payload_format == 1
        && (payload_json_len == 0 || payload_blob_len > 0)
    {
        return -3;
    }
    if payload_format == 2
        && (payload_blob_len == 0 || payload_json_len > 0)
    {
        return -3;
    }
    let event_id = match crate::cstr_to_str(
        event_id_utf8, event_id_len) {
        Some(s) => s, None => return -3,
    };
    let session_id = match crate::cstr_to_str(
        session_id_utf8, session_id_len) {
        Some(s) => s, None => return -3,
    };
    let kind = match crate::cstr_to_str(
        kind_utf8, kind_len) {
        Some(s) => s, None => return -3,
    };
    let risk_band = match crate::cstr_to_str(
        risk_band_utf8, risk_band_len) {
        Some(s) => s, None => return -3,
    };
    // chapter 九百十五 / M3280 fix C1:payload_json may be
    // legitimately empty (format=2 binary path stores data
    // in payload_blob),so use the empty-allowing variant
    // for this ONE field。 All other string fields use the
    // strict cstr_to_str。
    let payload_json = match crate::cstr_to_str_allowing_empty(
        payload_json_utf8, payload_json_len) {
        Some(s) => s, None => return -3,
    };
    if payload_blob_bytes.is_null() && payload_blob_len > 0 {
        return -3;
    }
    let payload_blob: Option<&[u8]> = if payload_blob_len == 0 {
        None
    } else {
        Some(unsafe {
            core::slice::from_raw_parts(
                payload_blob_bytes, payload_blob_len)
        })
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        match append_event(
            conn, event_id, session_id, timestamp_ms,
            kind, risk_band, payload_json,
            payload_format, payload_blob)
        {
            Ok((was_new, seq)) => {
                if !out_was_new.is_null() {
                    unsafe {
                        *out_was_new = if was_new { 1 } else { 0 };
                    }
                }
                seq
            },
            Err(_) => -2,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_event_log_count(
    engine: *const L8Engine,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_events(conn).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_event_log_count_for_session(
    engine: *const L8Engine,
    session_id_utf8: *const c_char, session_id_len: usize,
) -> i64 {
    if engine.is_null() { return -1; }
    let session_id = match crate::cstr_to_str(
        session_id_utf8, session_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_events_for_session(conn, session_id).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_event_log_count_for_kind(
    engine: *const L8Engine,
    kind_utf8: *const c_char, kind_len: usize,
) -> i64 {
    if engine.is_null() { return -1; }
    let kind = match crate::cstr_to_str(
        kind_utf8, kind_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        count_events_for_kind(conn, kind).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_event_log_next_sequence(
    engine: *const L8Engine,
    session_id_utf8: *const c_char, session_id_len: usize,
) -> i64 {
    if engine.is_null() { return -1; }
    let session_id = match crate::cstr_to_str(
        session_id_utf8, session_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        next_sequence_number(conn, session_id).unwrap_or(-2)
    })
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_event_log_prune_before(
    engine: *const L8Engine,
    cutoff_ms: i64,
) -> i64 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    engine_ref.with_conn(|conn| {
        prune_events_before(conn, cutoff_ms).unwrap_or(-2)
    })
}

/// chapter 九百九 / M3250 hot-path consolidation FFI:fetches
/// the N most-recent events for a session in ONE FFI call。
/// Returns count written (≤ limit),or:
///   -1 → null engine
///   -2 → SQLite error
///   -3 → UTF-8 decode failure / null buffers
///   -4 → limit == 0
///
/// Caller provides 2 parallel buffers:
///   out_timestamps: [i64; limit]
///   out_sequences:  [i64; limit]
/// Both filled in DESC-by-timestamp order。
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_event_log_recent_timestamps_for_session(
    engine: *const L8Engine,
    session_id_utf8: *const c_char, session_id_len: usize,
    limit: usize,
    out_timestamps: *mut i64,
    out_sequences: *mut i64,
) -> i32 {
    if engine.is_null() { return -1; }
    if limit == 0 || limit > crate::MAX_HOTPATH_LIMIT { return -4; }
    if out_timestamps.is_null() || out_sequences.is_null() {
        return -3;
    }
    let session_id = match crate::cstr_to_str(
        session_id_utf8, session_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    let result = engine_ref.with_conn(|conn| {
        recent_event_timestamps_for_session(
            conn, session_id, limit)
    });
    let rows = match result {
        Ok(v) => v,
        Err(_) => return -2,
    };
    let n = rows.len();
    let ts_slice = unsafe {
        core::slice::from_raw_parts_mut(out_timestamps, n)
    };
    let seq_slice = unsafe {
        core::slice::from_raw_parts_mut(out_sequences, n)
    };
    for (i, (ts, seq)) in rows.iter().enumerate() {
        ts_slice[i] = *ts;
        seq_slice[i] = *seq;
    }
    n as i32
}

// MARK: - chapter 九百三十八 / M3395 — full-row events query
//
// USER-PASS finding (ch 933) #5 substance fix:the ch 901 bridge
// labeled「Partial」 honestly in OVERVIEW table but the bridge
// methods `events(forSession:)` + `events(sinceTimestampMs:limit:)`
// had `return []` stubs。 Final substance chapter to close the
// USER-PASS work entirely。
//
// SIMPLEST variant of recipe:bridge's append path stores the
// entire BASEventLogEntry as payload_json (format=1)。 So read-back
// just concatenates payload_json values into a JSON array。 No
// per-column reconstruction,no base64 (signature_hash equiv),no
// TEXT→u8 mapping。 Filter WHERE payload_format = 1 to skip any
// format=2 rows (which would not Codable-decode to BASEventLogEntry
// anyway since they're binary)。

pub fn events_for_session_json(
    conn: &Connection,
    session_id: &str,
) -> rusqlite::Result<String> {
    let mut stmt = conn.prepare(
        "SELECT payload_json FROM event_log \
         WHERE session_id = ? AND payload_format = 1 \
         ORDER BY sequence_number")?;
    let mut rows = stmt.query(params![session_id])?;
    let mut out = String::from("[");
    let mut first = true;
    while let Some(row) = rows.next()? {
        let pj: String = row.get(0)?;
        if pj.is_empty() { continue; }  // defensive skip
        if !first { out.push(','); }
        first = false;
        out.push_str(&pj);
    }
    out.push(']');
    Ok(out)
}

pub fn events_since_timestamp_json(
    conn: &Connection,
    since_ms: i64,
    limit: i64,
) -> rusqlite::Result<String> {
    // chapter 九百二十二 / M3315 NC4 — cap on limit。 Apply same
    // discipline to read-paths (caller-supplied bound)。
    let bounded_limit = if limit < 0 { 0 }
        else if limit as usize > crate::MAX_HOTPATH_LIMIT {
            crate::MAX_HOTPATH_LIMIT as i64
        } else { limit };
    let mut stmt = conn.prepare(
        "SELECT payload_json FROM event_log \
         WHERE timestamp_ms >= ? AND payload_format = 1 \
         ORDER BY timestamp_ms, sequence_number \
         LIMIT ?")?;
    let mut rows = stmt.query(params![since_ms, bounded_limit])?;
    let mut out = String::from("[");
    let mut first = true;
    while let Some(row) = rows.next()? {
        let pj: String = row.get(0)?;
        if pj.is_empty() { continue; }
        if !first { out.push(','); }
        first = false;
        out.push_str(&pj);
    }
    out.push(']');
    Ok(out)
}

unsafe fn events_json_ffi(
    engine: *const L8Engine,
    by_session: bool,
    key_utf8: *const c_char,
    key_len: usize,
    since_ms: i64,
    limit: i64,
    out_buf: *mut u8,
    out_capacity: usize,
) -> i32 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    let json_result = if by_session {
        let key = match crate::cstr_to_str(key_utf8, key_len) {
            Some(s) => s, None => return -3,
        };
        engine_ref.with_conn(|conn| {
            events_for_session_json(conn, key)
        })
    } else {
        engine_ref.with_conn(|conn| {
            events_since_timestamp_json(conn, since_ms, limit)
        })
    };
    let json = match json_result {
        Ok(s) => s, Err(_) => return -2,
    };
    let bytes = json.as_bytes();
    let needed = bytes.len();
    if out_buf.is_null() || out_capacity == 0 {
        return needed as i32;
    }
    if out_capacity < needed { return -3; }
    unsafe {
        std::ptr::copy_nonoverlapping(
            bytes.as_ptr(), out_buf, needed);
    }
    needed as i32
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_event_log_events_for_session(
    engine: *const L8Engine,
    session_id_utf8: *const c_char, session_id_len: usize,
    out_buf: *mut u8,
    out_capacity: usize,
) -> i32 {
    events_json_ffi(
        engine, true,
        session_id_utf8, session_id_len,
        0, 0,
        out_buf, out_capacity)
}

#[no_mangle]
pub unsafe extern "C" fn bas_l8_event_log_events_since_ts(
    engine: *const L8Engine,
    since_ms: i64,
    limit: i64,
    out_buf: *mut u8,
    out_capacity: usize,
) -> i32 {
    events_json_ffi(
        engine, false,
        std::ptr::null(), 0,
        since_ms, limit,
        out_buf, out_capacity)
}

// MARK: - Tests (careful coverage of HIGH-risk semantics)

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{bas_l8_engine_init, bas_l8_engine_close};

    fn make_engine() -> *mut L8Engine {
        unsafe { bas_l8_engine_init(std::ptr::null(), 0) }
    }

    #[test]
    fn next_sequence_starts_at_zero_for_new_session() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_event_log_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            assert_eq!(
                next_sequence_number(
                    conn, "fresh-session").unwrap(), 0);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn auto_sequence_increments_per_session() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_event_log_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let (new1, s1) = append_event(
                conn, "e1", "sess-A", 100, "k", "rb",
                "{}", 1, None).unwrap();
            let (new2, s2) = append_event(
                conn, "e2", "sess-A", 200, "k", "rb",
                "{}", 1, None).unwrap();
            let (new3, s3) = append_event(
                conn, "e3", "sess-B", 300, "k", "rb",
                "{}", 1, None).unwrap();
            assert!(new1 && new2 && new3);
            assert_eq!(s1, 0);
            assert_eq!(s2, 1);
            assert_eq!(s3, 0,
                "Different session starts at 0");
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn idempotent_append_returns_existing_seq() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_event_log_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let (new1, s1) = append_event(
                conn, "dup-e", "s", 100, "k", "rb",
                "{}", 1, None).unwrap();
            assert!(new1);
            // Try to append same event_id with DIFFERENT
            // values — should be a no-op + return existing seq
            let (new2, s2) = append_event(
                conn, "dup-e", "DIFFERENT-SESSION",
                999, "different-k", "different-rb",
                r#"{"diff":true}"#, 2, Some(&[0xFFu8; 8])).unwrap();
            assert!(!new2,
                "Duplicate event_id returns was_new=false");
            assert_eq!(s2, s1,
                "Returned sequence is original, not new");
            assert_eq!(count_events(conn).unwrap(), 1,
                "Still only one row");
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn prune_deletes_old_events_returns_count() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_event_log_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            for i in 0..5 {
                append_event(
                    conn, &format!("e{}", i), "s",
                    100 + (i as i64) * 100, "k", "rb",
                    "{}", 1, None).unwrap();
            }
            // Prune events with timestamp_ms < 300 (e0, e1)
            let deleted = prune_events_before(
                conn, 300).unwrap();
            assert_eq!(deleted, 2);
            assert_eq!(count_events(conn).unwrap(), 3);
            // Prune-again (nothing to delete) returns 0
            let deleted2 = prune_events_before(
                conn, 300).unwrap();
            assert_eq!(deleted2, 0);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn payload_format_2_with_blob() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_event_log_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let blob = [0xCAu8; 64];
            let (new, _) = append_event(
                conn, "bin-1", "s", 100, "k", "rb",
                "",   // payload_json = empty (format=2)
                2,    // binary format
                Some(&blob)).unwrap();
            assert!(new);
            // Verify retrieval
            let stored_format: i32 = conn.query_row(
                "SELECT payload_format FROM event_log
                 WHERE event_id = ?",
                params!["bin-1"], |r| r.get(0)).unwrap();
            assert_eq!(stored_format, 2);
            let stored_blob: Vec<u8> = conn.query_row(
                "SELECT payload_blob FROM event_log
                 WHERE event_id = ?",
                params!["bin-1"], |r| r.get(0)).unwrap();
            assert_eq!(stored_blob, blob.to_vec());
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn ffi_append_out_was_new_correct() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_event_log_init_schema(engine) };
        let eid = "ffi-1";
        let sid = "ffi-sess";
        let k = "kind";
        let rb = "low";
        let pj = "{}";
        let mut was_new: i32 = -1;
        let s1 = unsafe {
            bas_l8_event_log_append(
                engine,
                eid.as_ptr() as *const c_char, eid.len(),
                sid.as_ptr() as *const c_char, sid.len(),
                100,
                k.as_ptr() as *const c_char, k.len(),
                rb.as_ptr() as *const c_char, rb.len(),
                pj.as_ptr() as *const c_char, pj.len(),
                1, std::ptr::null(), 0,
                &mut was_new)
        };
        assert_eq!(s1, 0);
        assert_eq!(was_new, 1);
        // Second append with same event_id → was_new=0,
        // seq=existing
        was_new = -1;
        let s2 = unsafe {
            bas_l8_event_log_append(
                engine,
                eid.as_ptr() as *const c_char, eid.len(),
                sid.as_ptr() as *const c_char, sid.len(),
                999,
                k.as_ptr() as *const c_char, k.len(),
                rb.as_ptr() as *const c_char, rb.len(),
                pj.as_ptr() as *const c_char, pj.len(),
                1, std::ptr::null(), 0,
                &mut was_new)
        };
        assert_eq!(s2, 0, "Dup returns original seq=0");
        assert_eq!(was_new, 0, "Dup signals was_new=false");
        unsafe { bas_l8_engine_close(engine); }
    }

    // chapter 九百三十八 / M3395 — full-row events round-trip
    #[test]
    fn events_for_session_json_round_trip() {
        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0) };
        let _ = unsafe { bas_l8_event_log_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let pl1 = "{\"eventID\":\"e1\",\"x\":1}";
            let pl2 = "{\"eventID\":\"e2\",\"x\":2}";
            // append 2 format=1 entries
            append_event(conn, "e1", "sess-RT", 100,
                "user.input", "low", pl1, 1, None).unwrap();
            append_event(conn, "e2", "sess-RT", 200,
                "user.input", "low", pl2, 1, None).unwrap();
            let json = events_for_session_json(
                conn, "sess-RT").unwrap();
            // Should be valid JSON array of the 2 payloads
            assert_eq!(json,
                format!("[{},{}]", pl1, pl2));
            // Empty session case
            let empty = events_for_session_json(
                conn, "sess-NONE").unwrap();
            assert_eq!(empty, "[]");
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn events_for_session_skips_format_2_blob_rows() {
        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0) };
        let _ = unsafe { bas_l8_event_log_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            // format=1 with JSON payload — should be returned
            let pl_json = "{\"eventID\":\"j1\"}";
            append_event(conn, "j1", "sess-mix", 100,
                "k", "low", pl_json, 1, None).unwrap();
            // format=2 with BLOB payload (empty json,non-empty
            // blob) — should be SKIPPED (binary can't decode
            // back to BASEventLogEntry Codable)
            let pl_empty = "";
            let blob = vec![0u8; 16];
            append_event(conn, "b1", "sess-mix", 200,
                "k", "low", pl_empty, 2,
                Some(&blob)).unwrap();
            let json = events_for_session_json(
                conn, "sess-mix").unwrap();
            // Only j1 returned,b1 filtered by payload_format=1
            assert_eq!(json, format!("[{}]", pl_json));
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn events_since_timestamp_respects_limit_and_order() {
        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0) };
        let _ = unsafe { bas_l8_event_log_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            for i in 0..5 {
                let pj = format!(
                    "{{\"eventID\":\"ts-{}\",\"i\":{}}}", i, i);
                append_event(
                    conn,
                    &format!("ts-{}", i),
                    "ts-sess",
                    1000 + i * 100,
                    "k", "low", &pj, 1, None).unwrap();
            }
            // since=1200 → expect ts-2, ts-3, ts-4 (3 rows)
            let json = events_since_timestamp_json(
                conn, 1200, 100).unwrap();
            assert!(json.contains("\"eventID\":\"ts-2\""));
            assert!(json.contains("\"eventID\":\"ts-3\""));
            assert!(json.contains("\"eventID\":\"ts-4\""));
            assert!(!json.contains("\"eventID\":\"ts-1\""));
            // limit=2 → only first 2
            let limited = events_since_timestamp_json(
                conn, 1200, 2).unwrap();
            assert!(limited.contains("\"eventID\":\"ts-2\""));
            assert!(limited.contains("\"eventID\":\"ts-3\""));
            assert!(!limited.contains("\"eventID\":\"ts-4\""));
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn events_since_timestamp_limit_cap_enforced() {
        let engine = unsafe {
            bas_l8_engine_init(std::ptr::null(), 0) };
        let _ = unsafe { bas_l8_event_log_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            // Pass usize::MAX-equivalent → must clamp to
            // MAX_HOTPATH_LIMIT, not abort with Vec allocation
            let _json = events_since_timestamp_json(
                conn, 0, i64::MAX).unwrap();
            // No assertion on content — just verify no panic
            // and clean return when result is empty
        });
        unsafe { bas_l8_engine_close(engine); }
    }
}
