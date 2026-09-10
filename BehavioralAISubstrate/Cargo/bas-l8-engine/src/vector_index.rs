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

/// chapter 九百二十六 / M3335 fix HIGH-1 — module-level cap
/// for embedding/query BLOB byte length。 Previously this
/// constant was local to `bas_l8_vector_index_upsert` at
/// line 255,which left the two cosine_topk FFIs with
/// ZERO upper bound on `query_blob_len` — a direct-FFI
/// caller passing 10 GB triggered `Vec::with_capacity`
/// abort,bypassing the Swift-side dim cap (which only
/// protects Swift call sites)。 Same OOM-via-untrusted-len
/// class as the chapter 922 NC4 `MAX_HOTPATH_LIMIT` fix。
pub(crate) const MAX_EMBEDDING_BYTES: usize = 65_536;

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
    // chapter 九百二十二 / M3315 CRITICAL fix NC1 (vector_index)
    crate::transactional(conn, |conn| {
        let existed = match conn.query_row(
            "SELECT 1 FROM vector_index WHERE atom_id = ? LIMIT 1",
            params![atom_id], |_| Ok(true),
        ) {
            Ok(true) => true,
            Err(rusqlite::Error::QueryReturnedNoRows) => false,
            Err(e) => return Err(e),
            Ok(false) => false,
        };
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
    })
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

/// chapter 九百六 / M3230 — hot-path read primitive。 Returns
/// the embedding_blob for an atom_id,or None if absent。 Used
/// by the orchestrated baseline (N round-trip FFI reads)。
pub fn read_embedding_for_atom(
    conn: &Connection,
    atom_id: &str,
) -> rusqlite::Result<Option<Vec<u8>>> {
    let r: Option<Vec<u8>> = conn.query_row(
        "SELECT embedding_blob FROM vector_index
         WHERE atom_id = ? LIMIT 1",
        params![atom_id], |row| row.get(0)
    ).ok();
    Ok(r)
}

/// chapter 一千〇六十二 / WS3 — resolve an atom_id from a vector_index
/// rowid。 The REVERSE of `read_embedding_for_atom` (atom_id →
/// embedding)。 Needed so a `cosine_topk_for_domain` caller (which
/// gets back rowids) can map those rowids to atoms — closing the
/// L8 retrieve cosineTopK hot-path takeover (audit ch1040 WS3)。
pub fn atom_id_for_rowid(
    conn: &Connection,
    rowid: i64,
) -> rusqlite::Result<Option<String>> {
    let r: Option<String> = conn.query_row(
        "SELECT atom_id FROM vector_index
         WHERE rowid = ? LIMIT 1",
        params![rowid], |row| row.get(0)
    ).ok();
    Ok(r)
}

/// chapter 九百六 / M3230 — INTEGRATED hot-path consolidation。
/// Reads all embeddings for a domain + computes cosine
/// similarity against the query + returns top-k scores in
/// ONE FFI call (vs the orchestrated baseline that needs
/// N + 1 FFI hops:N reads + 1 compute)。
///
/// Cosine similarity is computed via dot product on
/// PRE-NORMALIZED embeddings (matches Swift convention from
/// chapter 872 BASAutoRouteRanker.cosineTopKBatch)。 If the
/// caller's query is not normalized,results are dot-product
/// rather than cosine — the consumer's contract。
///
/// Returns a Vec of (rowid_in_domain, score) tuples sorted
/// descending by score,length ≤ min(k, embedding_count)。
///
/// chapter 九百十 / M3255 review fix #11:dim-mismatched rows
/// are SILENTLY SKIPPED for backward-compatibility,but the
/// new `cosine_topk_for_domain_with_skipped` variant surfaces
/// the skipped count to callers that need the diagnostic。
pub fn cosine_topk_for_domain(
    conn: &Connection,
    domain: &str,
    query: &[f32],
    k: usize,
) -> rusqlite::Result<Vec<(i64, f32)>> {
    let (top, _skipped) = cosine_topk_for_domain_with_skipped(
        conn, domain, query, k)?;
    Ok(top)
}

/// chapter 九百十 / M3255 review fix #11 — surfaces the count
/// of dim-mismatched rows that the cosine_topk silently
/// skipped。 Production consumers can detect provider upgrades
/// that left mixed-dim corpora behind。
pub fn cosine_topk_for_domain_with_skipped(
    conn: &Connection,
    domain: &str,
    query: &[f32],
    k: usize,
) -> rusqlite::Result<(Vec<(i64, f32)>, usize)> {
    let mut stmt = conn.prepare(
        "SELECT rowid, embedding_blob FROM vector_index
         WHERE domain = ?"
    )?;
    let mut rows = stmt.query(params![domain])?;
    let mut top: Vec<(i64, f32)> = Vec::with_capacity(k);
    let mut skipped: usize = 0;
    while let Some(row) = rows.next()? {
        let rowid: i64 = row.get(0)?;
        let blob: Vec<u8> = row.get(1)?;
        // Decode embedding_blob as little-endian f32 array
        let dim = blob.len() / 4;
        if dim != query.len() {
            skipped += 1;
            continue;  // Skip dim mismatches
        }
        let mut score: f32 = 0.0;
        for i in 0..dim {
            let start = i * 4;
            let b0 = blob[start];
            let b1 = blob[start + 1];
            let b2 = blob[start + 2];
            let b3 = blob[start + 3];
            let v = f32::from_le_bytes([b0, b1, b2, b3]);
            score += v * query[i];
        }
        // chapter 九百十八 / M3295 fix:NaN/Inf scores indicate
        // corrupted embedding bytes (e.g. byte-level disk
        // corruption,bit-flipped storage)。 Treat as dim-
        // mismatch:count as skipped + don't pollute top-k。
        if !score.is_finite() {
            skipped += 1;
            continue;
        }
        // Insertion into top-k heap (k is small,linear insert OK)
        if top.len() < k {
            top.push((rowid, score));
            top.sort_unstable_by(|a, b|
                b.1.partial_cmp(&a.1)
                    .unwrap_or(std::cmp::Ordering::Equal));
        } else if let Some(min) = top.last() {
            if score > min.1 {
                top.pop();
                top.push((rowid, score));
                top.sort_unstable_by(|a, b|
                    b.1.partial_cmp(&a.1)
                        .unwrap_or(std::cmp::Ordering::Equal));
            }
        }
    }
    Ok((top, skipped))
}

/// audit M-l MED-4 (x-concurrency) — ATOMIC top-k that returns
/// `(atom_id, score)` directly。 The base `cosine_topk_for_domain`
/// returns transient ROWIDS which the Swift caller then resolved to
/// atom_ids in K SEPARATE FFI calls;the Mutex only made each single
/// call atomic, so a concurrent remove/upsert between the top-k call
/// and a rowid→atom_id resolution let SQLite ROWID REUSE remap a rowid
/// to a DIFFERENT atom (wrong recall) or drop it (silent miss)。 This
/// variant reads `atom_id` in the SAME scan — no rowid round-trip, so
/// there is no reuse window at all — and the whole op runs under ONE
/// `with_conn` Mutex hold at the FFI boundary。
///
/// Ordering is TOTAL and content-derived: `(score DESC, atom_id ASC)`。
/// That also fixes the deferred K-th-boundary MEMBERSHIP determinism —
/// at an exact score tie the base variant's membership was rowid-decided
/// (rowids are reassigned on every in-memory ADR-037 rebuild); atom_id
/// is content-derived and stable across rebuilds。
pub fn cosine_topk_atom_ids_for_domain(
    conn: &Connection,
    domain: &str,
    query: &[f32],
    k: usize,
) -> rusqlite::Result<Vec<(String, f32)>> {
    let mut stmt = conn.prepare(
        "SELECT atom_id, embedding_blob FROM vector_index
         WHERE domain = ?"
    )?;
    let mut rows = stmt.query(params![domain])?;
    // Total order: higher score first; at an exact tie, smaller atom_id
    // first (content-derived ⇒ deterministic membership + order)。
    let better_first = |a: &(String, f32), b: &(String, f32)|
        b.1.partial_cmp(&a.1)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| a.0.cmp(&b.0));
    let mut top: Vec<(String, f32)> = Vec::with_capacity(k);
    while let Some(row) = rows.next()? {
        let atom_id: String = row.get(0)?;
        let blob: Vec<u8> = row.get(1)?;
        let dim = blob.len() / 4;
        if dim != query.len() {
            continue;  // dim mismatch — same skip policy as the base variant
        }
        let mut score: f32 = 0.0;
        for i in 0..dim {
            let start = i * 4;
            let v = f32::from_le_bytes([
                blob[start], blob[start + 1],
                blob[start + 2], blob[start + 3]]);
            score += v * query[i];
        }
        if !score.is_finite() {
            continue;  // corrupted bytes — skip, don't pollute top-k
        }
        if top.len() < k {
            top.push((atom_id, score));
            top.sort_unstable_by(&better_first);
        } else {
            // `top` is sorted best-first, so `last` is the current worst。
            let worst = top.last().unwrap();
            let cand_wins = match score.partial_cmp(&worst.1)
                .unwrap_or(std::cmp::Ordering::Equal)
            {
                std::cmp::Ordering::Greater => true,
                std::cmp::Ordering::Less => false,
                std::cmp::Ordering::Equal => atom_id < worst.0,
            };
            if cand_wins {
                top.pop();
                top.push((atom_id, score));
                top.sort_unstable_by(&better_first);
            }
        }
    }
    Ok(top)
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
    // chapter 九百二十 / M3305 HIGH-5 fix:bound embedding
    // size to prevent OOM-via-upsert。 4 bytes per f32 ×
    // 16384 max dim = 65536 bytes per embedding。 Production
    // embeddings are 384-1536 dim;the cap is generous。
    //
    // chapter 九百二十六 / M3335 fix HIGH-1:moved to module-
    // level `MAX_EMBEDDING_BYTES` so cosine_topk FFI variants
    // can reuse the same cap on the QUERY blob path (see
    // bas_l8_vector_index_cosine_topk_for_domain*)。
    if embedding_len > MAX_EMBEDDING_BYTES {
        return -3;  // oversized BLOB rejected
    }
    // chapter 九百二十二 / M3315 CRITICAL fix NC5:enforce
    // that declared dimension matches actual BLOB byte
    // length。 Without this,stored `dimension` column can
    // lie about BLOB size,and cosine_topk derives
    // dim = blob.len() / 4 ignoring the stored dimension。
    // Non-4-aligned BLOB lengths also rejected here so
    // cosine_topk doesn't silently truncate corrupted rows。
    if embedding_len % 4 != 0 {
        return -3;  // BLOB length not 4-aligned
    }
    if (dimension as usize).saturating_mul(4) != embedding_len {
        return -3;  // dimension/blob length mismatch
    }
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

// MARK: - chapter 九百六 / M3230 hot-path consolidation FFI

/// Read one embedding_blob for an atom_id (probe-mode buffer
/// read)。 Probe (null buf + 0 capacity) returns required size。
/// -2 = atom_id not found,-1 = null engine,-3 = UTF-8 fail。
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_vector_index_read_embedding_for_atom(
    engine: *const L8Engine,
    atom_id_utf8: *const c_char, atom_id_len: usize,
    out_buf: *mut u8, out_capacity: usize,
) -> i32 {
    if engine.is_null() { return -1; }
    let atom_id = match crate::cstr_to_str(
        atom_id_utf8, atom_id_len) {
        Some(s) => s, None => return -3,
    };
    let engine_ref = unsafe { &*engine };
    let blob: Option<Vec<u8>> = engine_ref.with_conn(|conn| {
        read_embedding_for_atom(conn, atom_id)
            .unwrap_or(None)
    });
    let bytes = match blob {
        Some(v) => v,
        None => return -2,
    };
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

/// chapter 一千〇六十二 / WS3 — resolve a vector_index rowid back to
/// its atom_id (UTF-8, probe-mode buffer read)。 Probe (null buf +
/// 0 capacity) returns the required byte size。 The REVERSE of
/// `read_embedding_for_atom`; lets a `cosine_topk_for_domain` caller
/// map the returned rowids to atoms (the L8 retrieve cosineTopK
/// hot-path takeover — audit ch1040 WS3)。
/// -2 = rowid not found,-1 = null engine。
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_vector_index_atom_id_for_rowid(
    engine: *const L8Engine,
    rowid: i64,
    out_buf: *mut u8, out_capacity: usize,
) -> i32 {
    if engine.is_null() { return -1; }
    let engine_ref = unsafe { &*engine };
    let aid: Option<String> = engine_ref.with_conn(|conn| {
        atom_id_for_rowid(conn, rowid).unwrap_or(None)
    });
    let s = match aid {
        Some(v) => v,
        None => return -2,
    };
    let bytes = s.as_bytes();
    let needed = bytes.len();
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

/// chapter 九百十 / M3255 review fix #11 — same as cosine_topk_
/// for_domain but also writes the dim-mismatch skipped count
/// to `out_skipped` (caller-allocated i64)。 Same return code
/// space as the base variant。 Use this in production to
/// detect mixed-dim corpora after provider upgrades。
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_vector_index_cosine_topk_for_domain_with_skipped(
    engine: *const L8Engine,
    domain_utf8: *const c_char, domain_len: usize,
    query_blob: *const u8, query_blob_len: usize,
    k: usize,
    out_rowids: *mut i64,
    out_scores: *mut f32,
    out_skipped: *mut i64,
) -> i32 {
    if engine.is_null() { return -1; }
    if k == 0 || k > crate::MAX_HOTPATH_LIMIT { return -4; }
    if out_rowids.is_null() || out_scores.is_null()
        || out_skipped.is_null() {
        return -3;
    }
    let domain = match crate::cstr_to_str(
        domain_utf8, domain_len) {
        Some(s) => s, None => return -3,
    };
    if query_blob.is_null() || query_blob_len == 0
        || query_blob_len % 4 != 0 {
        return -3;
    }
    // chapter 九百二十六 / M3335 fix HIGH-1:cap query blob
    // size — without this a direct-FFI caller passing
    // query_blob_len = 10_000_000_000 triggers
    // Vec::with_capacity(2.5B) abort,bypassing the
    // Swift-side 16384-float dim cap (only protects
    // BASRoutedVectorIndexStorage call sites)。
    if query_blob_len > MAX_EMBEDDING_BYTES {
        return -3;
    }
    let q_dim = query_blob_len / 4;
    let mut query: Vec<f32> = Vec::with_capacity(q_dim);
    let q_slice = unsafe {
        core::slice::from_raw_parts(query_blob, query_blob_len)
    };
    for i in 0..q_dim {
        let start = i * 4;
        query.push(f32::from_le_bytes([
            q_slice[start], q_slice[start + 1],
            q_slice[start + 2], q_slice[start + 3]]));
    }
    // chapter 九百二十六 / M3335 fix HIGH-2:Rust-side NaN/
    // Inf guard for direct-FFI callers (the ch 924 NH4
    // Swift-side check at BASRoutedVectorIndexStorage.
    // swift:342 only protects the [Float] overload — the
    // [UInt8] queryBytes overload and non-Swift FFI
    // consumers reach this path without prior validation)。
    if !query.iter().all(|f| f.is_finite()) {
        return -3;
    }
    let engine_ref = unsafe { &*engine };
    let result = engine_ref.with_conn(|conn| {
        cosine_topk_for_domain_with_skipped(
            conn, domain, &query, k)
    });
    let (topk, skipped) = match result {
        Ok(v) => v,
        Err(_) => return -2,
    };
    let n = topk.len();
    let rowids_slice = unsafe {
        core::slice::from_raw_parts_mut(out_rowids, n) };
    let scores_slice = unsafe {
        core::slice::from_raw_parts_mut(out_scores, n) };
    for (i, (rid, sc)) in topk.iter().enumerate() {
        rowids_slice[i] = *rid;
        scores_slice[i] = *sc;
    }
    unsafe { *out_skipped = skipped as i64; }
    n as i32
}

/// INTEGRATED cosine top-k: reads all embeddings for a domain
/// + computes dot-product score against the query + returns
/// top-k in ONE FFI call。 The caller provides:
///   - query_blob: query embedding as f32 little-endian bytes
///   - k: desired top-k count
///   - out_rowids: caller-allocated [i64; k] buffer for rowids
///   - out_scores: caller-allocated [f32; k] buffer for scores
///
/// Returns the actual count written (≤ k),or:
///   -1 → null engine
///   -2 → SQLite error
///   -3 → UTF-8 decode failure / query alignment / null buffers
///   -4 → k == 0
///
/// Buffers MUST be valid for at least k * sizeof(i64) / f32
/// bytes respectively。
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_vector_index_cosine_topk_for_domain(
    engine: *const L8Engine,
    domain_utf8: *const c_char, domain_len: usize,
    query_blob: *const u8, query_blob_len: usize,
    k: usize,
    out_rowids: *mut i64,
    out_scores: *mut f32,
) -> i32 {
    if engine.is_null() { return -1; }
    if k == 0 || k > crate::MAX_HOTPATH_LIMIT { return -4; }
    if out_rowids.is_null() || out_scores.is_null() {
        return -3;
    }
    let domain = match crate::cstr_to_str(
        domain_utf8, domain_len) {
        Some(s) => s, None => return -3,
    };
    if query_blob.is_null() || query_blob_len == 0
        || query_blob_len % 4 != 0
    {
        return -3;
    }
    // chapter 九百二十六 / M3335 fix HIGH-1 (mirrors variant
    // above):cap query blob size to prevent OOM via
    // direct-FFI consumer passing untrusted len。
    if query_blob_len > MAX_EMBEDDING_BYTES {
        return -3;
    }
    // Decode query bytes as f32 little-endian
    let q_dim = query_blob_len / 4;
    let mut query: Vec<f32> = Vec::with_capacity(q_dim);
    let q_slice = unsafe {
        core::slice::from_raw_parts(query_blob, query_blob_len)
    };
    for i in 0..q_dim {
        let start = i * 4;
        let b0 = q_slice[start];
        let b1 = q_slice[start + 1];
        let b2 = q_slice[start + 2];
        let b3 = q_slice[start + 3];
        query.push(f32::from_le_bytes([b0, b1, b2, b3]));
    }
    // chapter 九百二十六 / M3335 fix HIGH-2 (mirrors variant
    // above):Rust-side NaN/Inf guard for direct-FFI
    // callers that bypass the [Float] Swift overload。
    if !query.iter().all(|f| f.is_finite()) {
        return -3;
    }
    let engine_ref = unsafe { &*engine };
    let topk: Result<Vec<(i64, f32)>, rusqlite::Error> =
        engine_ref.with_conn(|conn| {
            cosine_topk_for_domain(conn, domain, &query, k)
        });
    let topk = match topk {
        Ok(v) => v,
        Err(_) => return -2,
    };
    let n = topk.len();
    let rowids_slice = unsafe {
        core::slice::from_raw_parts_mut(out_rowids, n)
    };
    let scores_slice = unsafe {
        core::slice::from_raw_parts_mut(out_scores, n)
    };
    for (i, (rid, sc)) in topk.iter().enumerate() {
        rowids_slice[i] = *rid;
        scores_slice[i] = *sc;
    }
    n as i32
}

/// audit M-l MED-4 — ATOMIC `(atom_id, score)` top-k in ONE FFI call。
/// Fixes the multi-call TOCTOU: the base variant returns transient rowids
/// that the caller resolved separately, so a concurrent write between the
/// top-k and a rowid→atom_id resolution let SQLite ROWID REUSE remap the
/// rowid to a DIFFERENT atom。 Here the whole read runs under ONE
/// `with_conn` Mutex hold and `atom_id` is read in the SAME scan (no rowid
/// round-trip)。
///
/// Writes the top-`n` scores into `out_scores` and the `n` atom_ids
/// NEWLINE-joined UTF-8 into `out_ids_buf` (atom_ids are TEXT ids — never
/// contain '\n')。 `*out_ids_needed` is ALWAYS set to the required ids byte
/// length;when `out_ids_buf` is null or too small the ids are NOT written
/// — the caller re-allocates to `*out_ids_needed` and calls again (each
/// call's (scores, ids) are internally self-consistent because atom_id is
/// read directly, so a retry is still a valid top-k)。 In practice atom_ids
/// are bounded (UUID/hash), so a generously-sized buffer makes it one call。
///
/// Returns n (count written, ≤ k) or:
///   -1 null engine · -2 SQLite error · -3 bad args/query · -4 k out of range
#[no_mangle]
pub unsafe extern "C" fn
bas_l8_vector_index_cosine_topk_atom_ids_for_domain(
    engine: *const L8Engine,
    domain_utf8: *const c_char, domain_len: usize,
    query_blob: *const u8, query_blob_len: usize,
    k: usize,
    out_scores: *mut f32,
    out_ids_buf: *mut u8, out_ids_capacity: usize,
    out_ids_needed: *mut i64,
) -> i32 {
    if engine.is_null() { return -1; }
    if k == 0 || k > crate::MAX_HOTPATH_LIMIT { return -4; }
    if out_scores.is_null() || out_ids_needed.is_null() {
        return -3;
    }
    let domain = match crate::cstr_to_str(
        domain_utf8, domain_len) {
        Some(s) => s, None => return -3,
    };
    if query_blob.is_null() || query_blob_len == 0
        || query_blob_len % 4 != 0
    {
        return -3;
    }
    if query_blob_len > MAX_EMBEDDING_BYTES {
        return -3;
    }
    let q_dim = query_blob_len / 4;
    let mut query: Vec<f32> = Vec::with_capacity(q_dim);
    let q_slice = unsafe {
        core::slice::from_raw_parts(query_blob, query_blob_len)
    };
    for i in 0..q_dim {
        let start = i * 4;
        query.push(f32::from_le_bytes([
            q_slice[start], q_slice[start + 1],
            q_slice[start + 2], q_slice[start + 3]]));
    }
    if !query.iter().all(|f| f.is_finite()) {
        return -3;
    }
    let engine_ref = unsafe { &*engine };
    let topk: Result<Vec<(String, f32)>, rusqlite::Error> =
        engine_ref.with_conn(|conn| {
            cosine_topk_atom_ids_for_domain(conn, domain, &query, k)
        });
    let topk = match topk {
        Ok(v) => v,
        Err(_) => return -2,
    };
    let n = topk.len();
    let scores_slice = unsafe {
        core::slice::from_raw_parts_mut(out_scores, n)
    };
    for (i, (_id, sc)) in topk.iter().enumerate() {
        scores_slice[i] = *sc;
    }
    // atom_ids joined by '\n' (ids never contain a newline)。
    let joined: String = topk.iter()
        .map(|(id, _)| id.as_str())
        .collect::<Vec<&str>>()
        .join("\n");
    let needed = joined.len();
    unsafe { *out_ids_needed = needed as i64; }
    if !out_ids_buf.is_null() && out_ids_capacity >= needed {
        unsafe {
            core::ptr::copy_nonoverlapping(
                joined.as_ptr(), out_ids_buf, needed);
        }
    }
    n as i32
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

    // chapter 九百六 / M3230 hot-path consolidation tests

    fn pack_f32_le(values: &[f32]) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(values.len() * 4);
        for v in values {
            bytes.extend_from_slice(&v.to_le_bytes());
        }
        bytes
    }

    #[test]
    fn read_embedding_for_atom_round_trips_bytes() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_vector_index_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let emb = pack_f32_le(&[1.0, 2.0, 3.0, 4.0]);
            upsert_entry(conn, "a-1", 4, "p", &emb,
                "d", "{}").unwrap();
            let read = read_embedding_for_atom(
                conn, "a-1").unwrap();
            assert_eq!(read, Some(emb.clone()));
            let miss = read_embedding_for_atom(
                conn, "missing").unwrap();
            assert_eq!(miss, None);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn cosine_topk_returns_ordered_scores() {
        // Construct 3 embeddings + a query that ranks them
        // unambiguously。 Verify top-k returns in descending
        // score order。
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_vector_index_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            // dim=4 embeddings
            // a-1: aligned with query → highest score
            // a-2: half-aligned
            // a-3: orthogonal → zero score
            let e1 = pack_f32_le(&[1.0, 0.0, 0.0, 0.0]);
            let e2 = pack_f32_le(&[0.5, 0.0, 0.0, 0.0]);
            let e3 = pack_f32_le(&[0.0, 1.0, 0.0, 0.0]);
            upsert_entry(conn, "a-1", 4, "p", &e1,
                "dom", "{}").unwrap();
            upsert_entry(conn, "a-2", 4, "p", &e2,
                "dom", "{}").unwrap();
            upsert_entry(conn, "a-3", 4, "p", &e3,
                "dom", "{}").unwrap();
            let query: Vec<f32> = vec![1.0, 0.0, 0.0, 0.0];
            let top = cosine_topk_for_domain(
                conn, "dom", &query, 3).unwrap();
            assert_eq!(top.len(), 3);
            // Top score = 1.0 (a-1), then 0.5 (a-2), then 0.0 (a-3)
            assert!(
                (top[0].1 - 1.0).abs() < 1e-5,
                "Top score expected ~1.0, got {}", top[0].1);
            assert!(
                (top[1].1 - 0.5).abs() < 1e-5,
                "2nd score expected ~0.5, got {}", top[1].1);
            assert!(
                top[2].1.abs() < 1e-5,
                "3rd score expected ~0.0, got {}", top[2].1);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    // audit M-l MED-4 — the atomic (atom_id, score) variant returns
    // atom_ids DIRECTLY (no rowid round-trip ⇒ no rowid-reuse TOCTOU).
    #[test]
    fn cosine_topk_atom_ids_returns_ordered_atom_ids() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_vector_index_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let e1 = pack_f32_le(&[1.0, 0.0, 0.0, 0.0]);
            let e2 = pack_f32_le(&[0.5, 0.0, 0.0, 0.0]);
            let e3 = pack_f32_le(&[0.0, 1.0, 0.0, 0.0]);
            upsert_entry(conn, "atom-alpha", 4, "p", &e1,
                "dom", "{}").unwrap();
            upsert_entry(conn, "atom-beta", 4, "p", &e2,
                "dom", "{}").unwrap();
            upsert_entry(conn, "atom-gamma", 4, "p", &e3,
                "dom", "{}").unwrap();
            let query: Vec<f32> = vec![1.0, 0.0, 0.0, 0.0];
            let top = cosine_topk_atom_ids_for_domain(
                conn, "dom", &query, 3).unwrap();
            assert_eq!(top.len(), 3);
            assert_eq!(top[0].0, "atom-alpha");   // score 1.0
            assert_eq!(top[1].0, "atom-beta");    // score 0.5
            assert_eq!(top[2].0, "atom-gamma");   // score 0.0
            assert!((top[0].1 - 1.0).abs() < 1e-5);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    // audit M-l MED-4 — deterministic K-th-boundary MEMBERSHIP at an exact
    // score tie: decided by content-derived atom_id (ASC), NOT by rowid
    // (which the in-memory engine reassigns on every rebuild). Insertion
    // order C,A,B must NOT affect the result.
    #[test]
    fn cosine_topk_atom_ids_tiebreak_deterministic_by_atom_id() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_vector_index_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let e = pack_f32_le(&[1.0, 0.0, 0.0, 0.0]);  // all identical ⇒ same score
            upsert_entry(conn, "id-C", 4, "p", &e, "dom", "{}").unwrap();
            upsert_entry(conn, "id-A", 4, "p", &e, "dom", "{}").unwrap();
            upsert_entry(conn, "id-B", 4, "p", &e, "dom", "{}").unwrap();
            let query: Vec<f32> = vec![1.0, 0.0, 0.0, 0.0];
            let top = cosine_topk_atom_ids_for_domain(
                conn, "dom", &query, 2).unwrap();
            assert_eq!(top.len(), 2);
            // all tie ⇒ the two SMALLEST atom_ids win, in ASC order:
            assert_eq!(top[0].0, "id-A");
            assert_eq!(top[1].0, "id-B");   // id-C evicted at the k-boundary
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn cosine_topk_eviction_branch_exercised() {
        // chapter 九百七 review fix #2:explicitly exercise
        // the `top.len() >= k` eviction branch (previously
        // untested,algorithm correct but coverage gap)。
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_vector_index_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            // 5 embeddings,k=2 — eviction must drop the
            // 3 worst,return only 2 highest
            let scores: [f32; 5] = [0.1, 0.5, 0.9, 0.7, 0.3];
            for (i, s) in scores.iter().enumerate() {
                let e = pack_f32_le(&[*s]);
                upsert_entry(conn, &format!("a-{}", i), 1,
                    "p", &e, "dom", "{}").unwrap();
            }
            let q: Vec<f32> = vec![1.0];
            let top = cosine_topk_for_domain(
                conn, "dom", &q, 2).unwrap();
            assert_eq!(top.len(), 2,
                "Eviction must keep exactly k entries");
            // Top 2 scores: 0.9, 0.7
            assert!((top[0].1 - 0.9).abs() < 1e-5);
            assert!((top[1].1 - 0.7).abs() < 1e-5);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn cosine_topk_returns_fewer_when_k_exceeds_corpus() {
        // chapter 九百七 review fix #12 (MED → escalated):
        // k > N must return N entries,not crash。
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_vector_index_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let e = pack_f32_le(&[1.0]);
            upsert_entry(conn, "only-one", 1, "p", &e,
                "dom", "{}").unwrap();
            let q: Vec<f32> = vec![1.0];
            let top = cosine_topk_for_domain(
                conn, "dom", &q, 100).unwrap();
            assert_eq!(top.len(), 1,
                "k > corpus returns corpus.len() entries");
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn cosine_topk_empty_domain_returns_empty() {
        // chapter 九百七 review fix #13 (MED → escalated):
        // empty domain returns empty Vec,not error。
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_vector_index_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let q: Vec<f32> = vec![1.0];
            let top = cosine_topk_for_domain(
                conn, "empty-domain", &q, 10).unwrap();
            assert_eq!(top.len(), 0);
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn cosine_topk_treats_nan_scores_as_skipped() {
        // chapter 九百十八 / M3295 fix:NaN scores from corrupt
        // embedding bytes don't pollute top-k results。
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_vector_index_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            // dim=2 embeddings
            let clean = pack_f32_le(&[1.0, 0.0]);
            // Construct NaN-bearing bytes (0x7F_C0_00_00 LE)
            let mut nan_bytes: Vec<u8> = vec![0, 0, 0xC0, 0x7F];
            nan_bytes.extend_from_slice(&[0, 0, 0, 0]);
            assert!(f32::from_le_bytes(
                [nan_bytes[0], nan_bytes[1],
                 nan_bytes[2], nan_bytes[3]]).is_nan());
            upsert_entry(conn, "clean", 2, "p", &clean,
                "dom", "{}").unwrap();
            upsert_entry(conn, "nan", 2, "p", &nan_bytes,
                "dom", "{}").unwrap();
            let q = vec![1.0_f32, 0.0];
            let (top, skipped) =
                cosine_topk_for_domain_with_skipped(
                    conn, "dom", &q, 5).unwrap();
            assert_eq!(top.len(), 1,
                "NaN row excluded from top-k");
            assert_eq!(skipped, 1,
                "NaN row counted as skipped");
            // The one returned score is finite
            assert!(top[0].1.is_finite());
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn cosine_topk_with_skipped_returns_mismatch_count() {
        // chapter 九百十 review fix #11:dim mismatches are
        // counted instead of silently dropped。
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_vector_index_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            // 1 good (dim=2) + 2 mismatched (dim=3)
            let e_match = pack_f32_le(&[1.0, 0.0]);
            let e_skip1 = pack_f32_le(&[1.0, 0.0, 0.0]);
            let e_skip2 = pack_f32_le(&[0.5, 0.5, 0.5]);
            upsert_entry(conn, "ok", 2, "p", &e_match,
                "dom", "{}").unwrap();
            upsert_entry(conn, "bad1", 3, "p", &e_skip1,
                "dom", "{}").unwrap();
            upsert_entry(conn, "bad2", 3, "p", &e_skip2,
                "dom", "{}").unwrap();
            let q = vec![1.0_f32, 0.0];
            let (top, skipped) =
                cosine_topk_for_domain_with_skipped(
                    conn, "dom", &q, 5).unwrap();
            assert_eq!(top.len(), 1,
                "Only dim-matched row returned");
            assert_eq!(skipped, 2,
                "Skipped count surfaces dim-mismatched rows");
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn cosine_topk_skips_dimension_mismatches() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_vector_index_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let e_match = pack_f32_le(&[1.0, 0.0]);
            let e_skip = pack_f32_le(&[1.0, 0.0, 0.0]);
            upsert_entry(conn, "good", 2, "p", &e_match,
                "dom", "{}").unwrap();
            upsert_entry(conn, "bad-dim", 3, "p", &e_skip,
                "dom", "{}").unwrap();
            let q = vec![1.0_f32, 0.0];
            let top = cosine_topk_for_domain(
                conn, "dom", &q, 5).unwrap();
            assert_eq!(top.len(), 1,
                "Only dim-matched row returned");
        });
        unsafe { bas_l8_engine_close(engine); }
    }

    #[test]
    fn ffi_cosine_topk_writes_results() {
        let engine = make_engine();
        let _ = unsafe {
            bas_l8_vector_index_init_schema(engine) };
        let engine_ref = unsafe { &*engine };
        engine_ref.with_conn(|conn| {
            let e1 = pack_f32_le(&[1.0, 0.0]);
            let e2 = pack_f32_le(&[0.0, 1.0]);
            upsert_entry(conn, "x", 2, "p", &e1,
                "ffidom", "{}").unwrap();
            upsert_entry(conn, "y", 2, "p", &e2,
                "ffidom", "{}").unwrap();
        });
        let dom = "ffidom";
        let q = pack_f32_le(&[1.0, 0.0]);
        let mut rowids = [0i64; 2];
        let mut scores = [0f32; 2];
        let n = unsafe {
            bas_l8_vector_index_cosine_topk_for_domain(
                engine,
                dom.as_ptr() as *const c_char, dom.len(),
                q.as_ptr(), q.len(),
                2,
                rowids.as_mut_ptr(),
                scores.as_mut_ptr())
        };
        assert_eq!(n, 2);
        // First score = 1.0 (perfect match), second ~0.0
        assert!((scores[0] - 1.0).abs() < 1e-5);
        assert!(scores[1].abs() < 1e-5);
        unsafe { bas_l8_engine_close(engine); }
    }
}
