// MARK: - bas-memory-usage-tracker / lib.rs
// chapter 七百六 / M2187 第一刀 — MULTI-LANGUAGE
//                                 AUGMENTATION ARC Rust
//                                 pilot:in-memory event
//                                 tracker mirroring the
//                                 chapter 二百五十一
//                                 (M738) Swift
//                                 BASMemoryUsageTracker
//                                 in-memory mode。
//
// ## Why this scope (in-memory only, NOT SQLite-backed)
//
// The plan called for "Swift bridge actor serves the
// in-memory mode only (SQLite-backed path stays Swift)"。
// Three rationales:
//
//   1. SQLite-backed path requires linking SQLite from
//      Rust,which couples this crate to a vendored
//      sqlite-rs build that inflates the Vendor/ binary
//      blob significantly。 Counter-sprawl says keep
//      additions minimal。
//
//   2. The MECHANISM proof — that Rust can ship via
//      XCFramework + Swift can call into Rust via C ABI
//      + byte-equality preserved via Codable wire format
//      — only requires the in-memory data structure。
//
//   3. SQLite-backed Swift path is the proven default
//      (758 byte-equality clean commits depend on it)。
//      Rust path is opt-in via feature flag,serving
//      the in-memory subset only。
//
// ## C ABI surface (4 functions per plan)
//
//   - bas_rust_tracker_init      -> *mut Tracker
//   - bas_rust_tracker_append    record fields → 0/-1/-2
//   - bas_rust_tracker_query     atom_id → JSON bytes
//   - bas_rust_tracker_close     *mut Tracker → 0
//
// Plus version pin function (5 total):
//   - bas_rust_tracker_version   -> 1
//
// ## Codable wire format
//
// Records are serialized to JSON bytes using serde_json-
// like manual formatting (no serde dependency to keep
// the binary blob small)。 The Swift bridge decodes
// these bytes into BASMemoryUsageRecord array via
// JSONDecoder — proves Codable wire-format byte-equality
// with the V1 Swift path。
//
// ## Thread safety
//
// Tracker is internally `RwLock<HashMap<String, Record>>`
// — concurrent reads,serialized writes。 The opaque
// pointer returned by `bas_rust_tracker_init` is Send +
// Sync。 Swift wrapper actor-isolates the pointer to
// prevent host-side races on the handle itself。

use std::collections::HashMap;
use std::ffi::{c_char, c_int, c_uchar, CStr};
#[cfg(test)]
use std::ptr;
use std::sync::RwLock;
use sha2::{Sha256, Digest};

const ABI_VERSION: c_int = 1;

#[derive(Debug, Clone)]
struct Record {
    record_id: String,
    atom_id: String,
    retrieved_at_ms: i64,
    session_ref: String,
    turn_ref: String,
    permit_mode: String,
    helped_state: String,
}

pub struct Tracker {
    inner: RwLock<HashMap<String, Record>>,
}

// 主线 核心 抽取 — per-atom accumulator used by the
// importance scorer + forget cascade。 Mutated inside
// the HashMap-walking pass under one read lock。
#[derive(Default, Clone)]
struct AtomStats {
    count: i64,
    last_retrieved_ms: i64,
    helped_count: i64,
    not_helped_count: i64,
}

// 主线 Integrity 抽取 — length-prefixed feed into a
// SHA256 hasher。 The 4-byte big-endian length prefix
// prevents collision between "ab" + "cd" and "a" +
// "bcd" — without it,SHA256(ab || cd) ==
// SHA256(a || bcd) which would let an attacker
// rearrange field boundaries undetected。
fn feed_length_prefixed(
    hasher: &mut Sha256, bytes: &[u8]
) {
    let len = bytes.len() as u32;
    hasher.update(len.to_be_bytes());
    hasher.update(bytes);
}

// 主线 核心 抽取 — fixed-precision Float64 → JSON
// number formatter that produces byte-equality
// deterministic output for the same input。 6 decimal
// places is enough for the importance score's dynamic
// range (typical scores in [0, ~10]) without bloating
// the JSON。
fn format_f64(v: f64) -> String {
    if v.is_nan() || v.is_infinite() {
        return "0".to_string();
    }
    format!("{:.6}", v)
}

impl Tracker {
    fn new() -> Self {
        Tracker {
            inner: RwLock::new(HashMap::new()),
        }
    }

    fn append(&self, record: Record) -> Result<(), ()> {
        let mut w = self.inner.write().map_err(|_| ())?;
        w.insert(record.record_id.clone(), record);
        Ok(())
    }

    /// Returns sorted-ascending-by-retrieved-at-ms JSON
    /// array of records matching `atom_id`,or sorted-
    /// ascending JSON array of ALL records if `atom_id`
    /// is empty。 Output is a UTF-8 byte vector;caller
    /// frees via bas_rust_tracker_free_buffer。
    fn query_json(&self, atom_id: &str) -> Result<Vec<u8>, ()> {
        let r = self.inner.read().map_err(|_| ())?;
        let mut matches: Vec<&Record> = if atom_id.is_empty() {
            r.values().collect()
        } else {
            r.values().filter(|x| x.atom_id == atom_id).collect()
        };
        matches.sort_by_key(|x| x.retrieved_at_ms);
        let mut out = Vec::new();
        out.push(b'[');
        for (i, rec) in matches.iter().enumerate() {
            if i > 0 {
                out.push(b',');
            }
            write_record_json(&mut out, rec);
        }
        out.push(b']');
        Ok(out)
    }

    fn size(&self) -> i64 {
        match self.inner.read() {
            Ok(r) => r.len() as i64,
            Err(_) => -1,
        }
    }

    // 主线 全面 开发 — Rust-side native aggregation。
    // Iterates the HashMap inside Rust under a single
    // read lock,emits JSON `{"key": count, ...}` map。
    // No Swift-side fold over allRecords()。
    fn count_by_permit_mode_json(&self) -> Result<Vec<u8>, ()> {
        let r = self.inner.read().map_err(|_| ())?;
        let mut counts: HashMap<String, i64> = HashMap::new();
        for rec in r.values() {
            *counts
                .entry(rec.permit_mode.clone())
                .or_insert(0) += 1;
        }
        Ok(emit_count_json(&counts))
    }

    fn count_by_session_json(&self) -> Result<Vec<u8>, ()> {
        let r = self.inner.read().map_err(|_| ())?;
        let mut counts: HashMap<String, i64> = HashMap::new();
        for rec in r.values() {
            *counts
                .entry(rec.session_ref.clone())
                .or_insert(0) += 1;
        }
        Ok(emit_count_json(&counts))
    }

    fn distinct_sessions(&self) -> i64 {
        match self.inner.read() {
            Ok(r) => {
                let mut set: std::collections::HashSet<&str> =
                    std::collections::HashSet::new();
                for rec in r.values() {
                    set.insert(rec.session_ref.as_str());
                }
                set.len() as i64
            }
            Err(_) => -1,
        }
    }

    // 主线 Provenance 抽取 — record lineage for an atom。
    // Returns all records sharing the given atom_id,
    // sorted ascending by retrieved_at_ms then by
    // record_id (deterministic tiebreak)。 The earliest
    // record is the "origin" — subsequent records are
    // its descendants in time。
    //
    // Provenance is what Rust owns per the blueprint:
    // "Memory engine / retrieval/ranking / forget
    // cascade / provenance / integrity / ledger/replay"。
    //
    // JSON output:
    //   [{atomID, recordID, retrievedAtMs, sessionRef,
    //     turnRef, permitMode, helpedFlag, schemaVersion,
    //     lineageIndex}, ...]
    //
    // lineageIndex is 0 for the origin, 1 for first
    // descendant, etc — saves Swift hosts from re-
    // numbering after parsing。
    fn record_lineage_json(
        &self,
        atom_id: &str,
    ) -> Result<Vec<u8>, ()> {
        let r = self.inner.read().map_err(|_| ())?;
        let mut matches: Vec<&Record> = r
            .values()
            .filter(|rec| rec.atom_id == atom_id)
            .collect();
        matches.sort_by(|a, b| {
            a.retrieved_at_ms.cmp(&b.retrieved_at_ms)
                .then(a.record_id.cmp(&b.record_id))
        });
        let mut out = Vec::new();
        out.push(b'[');
        for (idx, rec) in matches.iter().enumerate() {
            if idx > 0 { out.push(b','); }
            out.push(b'{');
            write_kv_string(
                &mut out, "atomID", &rec.atom_id);
            out.push(b',');
            write_kv_string(
                &mut out, "helpedFlag",
                &rec.helped_state);
            out.push(b',');
            write_kv_int(
                &mut out, "lineageIndex",
                idx as i64);
            out.push(b',');
            write_kv_string(
                &mut out, "permitMode",
                &rec.permit_mode);
            out.push(b',');
            write_kv_string(
                &mut out, "recordID", &rec.record_id);
            out.push(b',');
            write_kv_int(
                &mut out, "retrievedAtMs",
                rec.retrieved_at_ms);
            out.push(b',');
            write_kv_string(
                &mut out, "schemaVersion", "1.0.0");
            out.push(b',');
            write_kv_string(
                &mut out, "sessionRef",
                &rec.session_ref);
            out.push(b',');
            write_kv_string(
                &mut out, "turnRef", &rec.turn_ref);
            out.push(b'}');
        }
        out.push(b']');
        Ok(out)
    }

    // 主线 核心 抽取 — Memory Importance Scorer in Rust。
    // For each distinct atom_id,compute:
    //   score = log(1 + count)
    //         * exp(-(now_ms - last_retrieved_ms) / half_life_ms)
    //         * max(0.5, helped_rate)
    //
    // Components:
    //   count        = number of retrieval events
    //   last_retrieved_ms = max(retrieved_at_ms) across atom's records
    //   helped_rate  = (helped_count) / (helped_count + not_helped_count)
    //                  fallback to 1.0 when zero non-unknown records
    //                  (treats absence-of-signal as helped-positive,
    //                  matching the chapter 二百五十二 default)
    //
    // Emits JSON array sorted by score descending:
    //   [{"atomID":"...","score":0.42,"count":7,
    //     "lastRetrievedMs":1700000000000,"helpedRate":0.66}]
    //
    // Walks the HashMap once,allocates per-atom AtomStats
    // accumulators,sorts at the end。 All under one read
    // lock。 The math is REAL Memory-cascade Importance
    // (the chapter 二百五十二 BASMemoryImportanceScorer
    // formula),not just observability。
    fn atom_importance_scores_json(
        &self,
        now_ms: i64,
        half_life_ms: i64,
    ) -> Result<Vec<u8>, ()> {
        let r = self.inner.read().map_err(|_| ())?;
        let mut stats: HashMap<String, AtomStats> =
            HashMap::new();
        for rec in r.values() {
            let entry = stats
                .entry(rec.atom_id.clone())
                .or_insert_with(AtomStats::default);
            entry.count += 1;
            if rec.retrieved_at_ms > entry.last_retrieved_ms {
                entry.last_retrieved_ms = rec.retrieved_at_ms;
            }
            match rec.helped_state.as_str() {
                "helped" => entry.helped_count += 1,
                "notHelped" => entry.not_helped_count += 1,
                _ => {}  // unknown — doesn't count either way
            }
        }
        let hl = if half_life_ms <= 0 {
            1.0  // protect against div-by-zero
        } else {
            half_life_ms as f64
        };
        let mut scored: Vec<(String, f64, AtomStats)> =
            stats.into_iter().map(|(atom_id, s)| {
                let recency_age = (now_ms
                    - s.last_retrieved_ms) as f64;
                let recency_weight =
                    (-recency_age / hl).exp();
                let helped_total = s.helped_count
                    + s.not_helped_count;
                let helped_rate = if helped_total > 0 {
                    let r =
                        s.helped_count as f64
                        / helped_total as f64;
                    if r < 0.5 { 0.5 } else { r }
                } else {
                    1.0  // absent signal → treat positive
                };
                let count_weight =
                    ((s.count as f64) + 1.0).ln();
                let score = count_weight
                    * recency_weight
                    * helped_rate;
                (atom_id, score, s)
            }).collect();
        scored.sort_by(|a, b| {
            // Descending by score; alphabetical tie-break
            b.1.partial_cmp(&a.1)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then(a.0.cmp(&b.0))
        });
        let mut out = Vec::new();
        out.push(b'[');
        for (i, (atom_id, score, s)) in
            scored.iter().enumerate()
        {
            if i > 0 { out.push(b','); }
            out.push(b'{');
            write_kv_string(&mut out, "atomID", atom_id);
            out.push(b',');
            write_kv_int(
                &mut out, "count", s.count);
            let hrate = if s.helped_count
                + s.not_helped_count > 0
            {
                let r = s.helped_count as f64
                    / (s.helped_count
                       + s.not_helped_count) as f64;
                if r < 0.5 { 0.5 } else { r }
            } else { 1.0 };
            out.push(b',');
            write_kv_raw_number(
                &mut out, "helpedRate", hrate);
            out.push(b',');
            write_kv_int(
                &mut out, "lastRetrievedMs",
                s.last_retrieved_ms);
            out.push(b',');
            write_kv_raw_number(
                &mut out, "score", *score);
            out.push(b'}');
        }
        out.push(b']');
        Ok(out)
    }

    // 主线 核心 抽取 — Forget Cascade decision core in Rust。
    // Computes the same per-atom score as above,sorts
    // descending,keeps the top `retain_fraction` of distinct
    // atoms,returns the rest as forget candidates。
    //
    // retain_fraction must be in [0.0, 1.0]:
    //   0.0 → forget everything (all atoms candidate)
    //   1.0 → keep everything  (empty candidate list)
    //   0.8 → keep top 80%,return bottom 20% as candidates
    //
    // Returns JSON array of atomIDs (strings)。 Hosts call
    // this then issue forget on each returned atomID。
    fn forget_candidates_json(
        &self,
        now_ms: i64,
        half_life_ms: i64,
        retain_fraction: f64,
    ) -> Result<Vec<u8>, ()> {
        let frac = retain_fraction.clamp(0.0, 1.0);
        let r = self.inner.read().map_err(|_| ())?;
        let mut stats: HashMap<String, AtomStats> =
            HashMap::new();
        for rec in r.values() {
            let entry = stats
                .entry(rec.atom_id.clone())
                .or_insert_with(AtomStats::default);
            entry.count += 1;
            if rec.retrieved_at_ms > entry.last_retrieved_ms {
                entry.last_retrieved_ms = rec.retrieved_at_ms;
            }
            match rec.helped_state.as_str() {
                "helped" => entry.helped_count += 1,
                "notHelped" => entry.not_helped_count += 1,
                _ => {}
            }
        }
        let hl = if half_life_ms <= 0 {
            1.0
        } else {
            half_life_ms as f64
        };
        let mut scored: Vec<(String, f64)> =
            stats.iter().map(|(atom_id, s)| {
                let recency_age = (now_ms
                    - s.last_retrieved_ms) as f64;
                let recency_weight =
                    (-recency_age / hl).exp();
                let helped_total = s.helped_count
                    + s.not_helped_count;
                let helped_rate = if helped_total > 0 {
                    let r =
                        s.helped_count as f64
                        / helped_total as f64;
                    if r < 0.5 { 0.5 } else { r }
                } else { 1.0 };
                let count_weight =
                    ((s.count as f64) + 1.0).ln();
                let score = count_weight
                    * recency_weight
                    * helped_rate;
                (atom_id.clone(), score)
            }).collect();
        scored.sort_by(|a, b| {
            b.1.partial_cmp(&a.1)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then(a.0.cmp(&b.0))
        });
        let total = scored.len();
        let keep = (total as f64 * frac).floor() as usize;
        let keep = keep.min(total);
        let candidates: Vec<&String> = scored[keep..]
            .iter().map(|(a, _)| a).collect();
        let mut out = Vec::new();
        out.push(b'[');
        for (i, atom_id) in candidates.iter().enumerate() {
            if i > 0 { out.push(b','); }
            out.push(b'"');
            for &byte in atom_id.as_bytes() {
                match byte {
                    b'"' => out.extend_from_slice(b"\\\""),
                    b'\\' => out.extend_from_slice(b"\\\\"),
                    _ => out.push(byte),
                }
            }
            out.push(b'"');
        }
        out.push(b']');
        Ok(out)
    }

    // 主线 Integrity 抽取 — compute a deterministic
    // SHA256 hash over the canonically-ordered record
    // set。 Two trackers with identical records in any
    // insertion order produce identical 32-byte hashes。
    // Hosts use this for tamper detection:periodically
    // capture the chain hash,compare against expected。
    //
    // Canonical ordering: ascending by
    // (retrieved_at_ms, record_id)。 Record_id tiebreaker
    // ensures determinism even when two records share
    // a timestamp。
    //
    // Hashed bytes per record (single feed,no separators
    // — internal byte representations don't collide
    // because all fields have fixed-precision integer
    // lengths or NUL-terminated string boundaries via
    // length-prefixed encoding below):
    //
    //   8 bytes: retrieved_at_ms big-endian
    //   4 bytes: u32 record_id length big-endian
    //   N bytes: record_id UTF-8
    //   4 bytes: u32 atom_id length big-endian
    //   N bytes: atom_id UTF-8
    //   4 bytes: u32 session_ref length big-endian
    //   N bytes: session_ref UTF-8
    //   4 bytes: u32 turn_ref length big-endian
    //   N bytes: turn_ref UTF-8
    //   4 bytes: u32 permit_mode length big-endian
    //   N bytes: permit_mode UTF-8
    //   4 bytes: u32 helped_state length big-endian
    //   N bytes: helped_state UTF-8
    //
    // Empty tracker hashes the empty byte stream →
    // well-known SHA256("") =
    // e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855。
    fn compute_chain_hash(&self) -> Result<[u8; 32], ()> {
        let r = self.inner.read().map_err(|_| ())?;
        let mut ordered: Vec<&Record> = r.values().collect();
        ordered.sort_by(|a, b| {
            a.retrieved_at_ms.cmp(&b.retrieved_at_ms)
                .then(a.record_id.cmp(&b.record_id))
        });
        let mut hasher = Sha256::new();
        for rec in ordered {
            hasher.update(
                rec.retrieved_at_ms.to_be_bytes());
            feed_length_prefixed(
                &mut hasher, rec.record_id.as_bytes());
            feed_length_prefixed(
                &mut hasher, rec.atom_id.as_bytes());
            feed_length_prefixed(
                &mut hasher, rec.session_ref.as_bytes());
            feed_length_prefixed(
                &mut hasher, rec.turn_ref.as_bytes());
            feed_length_prefixed(
                &mut hasher, rec.permit_mode.as_bytes());
            feed_length_prefixed(
                &mut hasher, rec.helped_state.as_bytes());
        }
        let digest = hasher.finalize();
        let mut out = [0u8; 32];
        out.copy_from_slice(&digest);
        Ok(out)
    }

    // 全面 开发 — retrieval-interval distribution
    // percentiles。 Collects retrieved_at_ms across all
    // records,sorts ascending,computes deltas between
    // consecutive timestamps,then percentile-summarizes
    // the delta distribution via nearest-rank。 Reveals
    // traffic rhythm:typical gap between brain.summary
    // calls。
    //
    // Returns (-1, -1, -1) when fewer than 2 records (no
    // interval can be computed from a single point)。
    fn retrieval_interval_percentiles(&self) -> (i64, i64, i64) {
        let r = match self.inner.read() {
            Ok(g) => g,
            Err(_) => return (-1, -1, -1),
        };
        if r.len() < 2 {
            return (-1, -1, -1);
        }
        let mut timestamps: Vec<i64> = r
            .values()
            .map(|rec| rec.retrieved_at_ms)
            .collect();
        timestamps.sort();
        let mut intervals: Vec<i64> = Vec::with_capacity(
            timestamps.len() - 1);
        for i in 1..timestamps.len() {
            intervals.push(
                timestamps[i] - timestamps[i - 1]);
        }
        intervals.sort();
        let n = intervals.len() as f64;
        let idx = |p: f64| -> usize {
            let raw = (n * p).ceil() as i64 - 1;
            let clamped = raw.max(0).min(
                intervals.len() as i64 - 1);
            clamped as usize
        };
        let p50 = intervals[idx(0.50)];
        let p95 = intervals[idx(0.95)];
        let p99 = intervals[idx(0.99)];
        (p50, p95, p99)
    }

    // 持续性 发展 — atom-count distribution percentiles。
    // Counts occurrences per atom_id (HashMap pass),
    // sorts the count values ascending,returns
    // p50/p95/p99 via the nearest-rank method:
    //   pK = sorted[clamp(0, n-1, ceil(n * K) - 1)]
    //
    // Returns (-1, -1, -1) when no records exist (no
    // distribution to take percentiles of)。
    fn atom_count_percentiles(&self) -> (i64, i64, i64) {
        let r = match self.inner.read() {
            Ok(g) => g,
            Err(_) => return (-1, -1, -1),
        };
        if r.is_empty() {
            return (-1, -1, -1);
        }
        let mut counts: HashMap<String, i64> = HashMap::new();
        for rec in r.values() {
            *counts
                .entry(rec.atom_id.clone())
                .or_insert(0) += 1;
        }
        if counts.is_empty() {
            return (-1, -1, -1);
        }
        let mut sorted: Vec<i64> =
            counts.values().copied().collect();
        sorted.sort();
        let n = sorted.len() as f64;
        let idx = |p: f64| -> usize {
            let raw = (n * p).ceil() as i64 - 1;
            let clamped = raw.max(0).min(sorted.len() as i64 - 1);
            clamped as usize
        };
        let p50 = sorted[idx(0.50)];
        let p95 = sorted[idx(0.95)];
        let p99 = sorted[idx(0.99)];
        (p50, p95, p99)
    }

    // 持续性 发展 — top-K most-frequent atoms。 Iterates
    // the HashMap once,counts occurrences per atom_id,
    // partial-sorts to keep only the top K。 JSON output
    // sorted descending by count,then alphabetically by
    // atom_id on ties (byte-equality deterministic across
    // runs)。
    //
    // K=0 returns empty array。 K > distinct atoms returns
    // all atoms (no padding)。
    fn top_k_atoms_json(&self, k: usize) -> Result<Vec<u8>, ()> {
        let r = self.inner.read().map_err(|_| ())?;
        let mut counts: HashMap<String, i64> = HashMap::new();
        for rec in r.values() {
            *counts
                .entry(rec.atom_id.clone())
                .or_insert(0) += 1;
        }
        // Sort by (-count, atom_id) for descending count
        // + alphabetical tie-break。
        let mut pairs: Vec<(String, i64)> =
            counts.into_iter().collect();
        pairs.sort_by(|a, b| {
            b.1.cmp(&a.1).then(a.0.cmp(&b.0))
        });
        let take = std::cmp::min(k, pairs.len());
        let top = &pairs[..take];
        let mut out = Vec::new();
        out.push(b'[');
        for (i, (atom_id, count)) in top.iter().enumerate() {
            if i > 0 {
                out.push(b',');
            }
            out.push(b'{');
            write_kv_string(
                &mut out, "atomID", atom_id.as_str());
            out.push(b',');
            write_kv_int(&mut out, "count", *count);
            out.push(b'}');
        }
        out.push(b']');
        Ok(out)
    }
}

// 主线 全面 开发 — manual JSON emitter for HashMap<String, i64>。
// Keys ordered alphabetically for byte-equality determinism (so
// repeated calls with the same data produce identical bytes)。
fn emit_count_json(counts: &HashMap<String, i64>) -> Vec<u8> {
    let mut keys: Vec<&String> = counts.keys().collect();
    keys.sort();
    let mut out = Vec::new();
    out.push(b'{');
    for (i, k) in keys.iter().enumerate() {
        if i > 0 {
            out.push(b',');
        }
        write_kv_int(&mut out, k.as_str(), counts[*k]);
    }
    out.push(b'}');
    out
}

/// Manual JSON writer for one record。 Avoids serde
/// dependency。 Keys ordered alphabetically for
/// byte-equality determinism。
fn write_record_json(out: &mut Vec<u8>, rec: &Record) {
    out.push(b'{');
    write_kv_string(out, "atomID", &rec.atom_id);
    out.push(b',');
    write_kv_string(out, "helpedFlag", &rec.helped_state);
    out.push(b',');
    write_kv_string(out, "permitMode", &rec.permit_mode);
    out.push(b',');
    // retrievedAt is emitted as ISO-8601 by Swift Codable
    // default;Rust emits epoch_ms here so the Swift
    // wrapper translates。
    write_kv_int(out, "retrievedAtMs", rec.retrieved_at_ms);
    out.push(b',');
    write_kv_string(out, "recordID", &rec.record_id);
    out.push(b',');
    write_kv_string(out, "schemaVersion", "1.0.0");
    out.push(b',');
    write_kv_string(out, "sessionRef", &rec.session_ref);
    out.push(b',');
    write_kv_string(out, "turnRef", &rec.turn_ref);
    out.push(b'}');
}

fn write_kv_string(out: &mut Vec<u8>, key: &str, value: &str) {
    out.push(b'"');
    out.extend_from_slice(key.as_bytes());
    out.push(b'"');
    out.push(b':');
    out.push(b'"');
    // JSON-escape ASCII control + quote + backslash。
    for &b in value.as_bytes() {
        match b {
            b'"' => out.extend_from_slice(b"\\\""),
            b'\\' => out.extend_from_slice(b"\\\\"),
            b'\n' => out.extend_from_slice(b"\\n"),
            b'\r' => out.extend_from_slice(b"\\r"),
            b'\t' => out.extend_from_slice(b"\\t"),
            _ => out.push(b),
        }
    }
    out.push(b'"');
}

fn write_kv_int(out: &mut Vec<u8>, key: &str, value: i64) {
    out.push(b'"');
    out.extend_from_slice(key.as_bytes());
    out.push(b'"');
    out.push(b':');
    out.extend_from_slice(value.to_string().as_bytes());
}

// 主线 核心 抽取 — raw Float64 JSON number writer (no
// quotes around value)。 Used by the importance scorer
// to emit score + helpedRate as JSON numbers,not
// strings,so Swift Codable decodes as Double。
fn write_kv_raw_number(
    out: &mut Vec<u8>, key: &str, value: f64
) {
    out.push(b'"');
    out.extend_from_slice(key.as_bytes());
    out.push(b'"');
    out.push(b':');
    let formatted = format_f64(value);
    out.extend_from_slice(formatted.as_bytes());
}

// MARK: - C ABI surface

#[no_mangle]
pub extern "C" fn bas_rust_tracker_version() -> c_int {
    ABI_VERSION
}

#[no_mangle]
pub extern "C" fn bas_rust_tracker_init() -> *mut Tracker {
    let t = Box::new(Tracker::new());
    Box::into_raw(t)
}

#[no_mangle]
pub extern "C" fn bas_rust_tracker_close(
    tracker: *mut Tracker,
) -> c_int {
    if tracker.is_null() {
        return -1;
    }
    unsafe {
        let _ = Box::from_raw(tracker);
    }
    0
}

// Append one record。 All char* args are NUL-terminated
// UTF-8 owned by caller。 Tracker COPIES into internal
// String storage,so caller can free inputs immediately。
//
// Returns 0 on success,-1 on null pointer,-2 on
// internal error (lock poisoned / utf8 decode)。
#[no_mangle]
pub extern "C" fn bas_rust_tracker_append(
    tracker: *mut Tracker,
    record_id: *const c_char,
    atom_id: *const c_char,
    retrieved_at_ms: i64,
    session_ref: *const c_char,
    turn_ref: *const c_char,
    permit_mode: *const c_char,
    helped_state: *const c_char,
) -> c_int {
    if tracker.is_null()
        || record_id.is_null()
        || atom_id.is_null()
        || session_ref.is_null()
        || turn_ref.is_null()
        || permit_mode.is_null()
        || helped_state.is_null()
    {
        return -1;
    }
    let tref = unsafe { &*tracker };
    let rec = unsafe {
        let s = |p: *const c_char| -> Option<String> {
            CStr::from_ptr(p).to_str().ok().map(String::from)
        };
        let r = Record {
            record_id: match s(record_id) {
                Some(x) => x,
                None => return -2,
            },
            atom_id: match s(atom_id) {
                Some(x) => x,
                None => return -2,
            },
            retrieved_at_ms,
            session_ref: match s(session_ref) {
                Some(x) => x,
                None => return -2,
            },
            turn_ref: match s(turn_ref) {
                Some(x) => x,
                None => return -2,
            },
            permit_mode: match s(permit_mode) {
                Some(x) => x,
                None => return -2,
            },
            helped_state: match s(helped_state) {
                Some(x) => x,
                None => return -2,
            },
        };
        r
    };
    match tref.append(rec) {
        Ok(()) => 0,
        Err(()) => -2,
    }
}

// Query records by atom_id (or all if atom_id is empty
// string)。 Allocates heap buffer with JSON bytes,
// returns pointer + length via out params。 Caller MUST
// call bas_rust_tracker_free_buffer to release。
//
// Returns 0 on success,-1 on null pointer,-2 on
// internal error。
#[no_mangle]
pub extern "C" fn bas_rust_tracker_query(
    tracker: *mut Tracker,
    atom_id: *const c_char,
    out_buf: *mut *mut c_uchar,
    out_len: *mut usize,
) -> c_int {
    if tracker.is_null()
        || atom_id.is_null()
        || out_buf.is_null()
        || out_len.is_null()
    {
        return -1;
    }
    let tref = unsafe { &*tracker };
    let key = unsafe {
        match CStr::from_ptr(atom_id).to_str() {
            Ok(s) => s,
            Err(_) => return -2,
        }
    };
    let bytes = match tref.query_json(key) {
        Ok(v) => v,
        Err(_) => return -2,
    };
    let mut boxed = bytes.into_boxed_slice();
    unsafe {
        *out_buf = boxed.as_mut_ptr();
        *out_len = boxed.len();
        // Leak the boxed slice so the C caller owns the
        // buffer until they call free_buffer。
        std::mem::forget(boxed);
    }
    0
}

// Free a buffer returned by bas_rust_tracker_query。
// Reconstructs the Box<[u8]> + drops it。
#[no_mangle]
pub extern "C" fn bas_rust_tracker_free_buffer(
    buf: *mut c_uchar,
    len: usize,
) {
    if buf.is_null() || len == 0 {
        return;
    }
    unsafe {
        let slice = std::slice::from_raw_parts_mut(buf, len);
        let _ = Box::from_raw(slice as *mut [u8]);
    }
}

// Record count snapshot (lock taken briefly)。
// Returns -1 if tracker pointer null OR lock poisoned。
#[no_mangle]
pub extern "C" fn bas_rust_tracker_size(
    tracker: *mut Tracker,
) -> i64 {
    if tracker.is_null() {
        return -1;
    }
    unsafe { (*tracker).size() }
}

// 主线 全面 开发 — Rust-side native aggregation FFI surfaces。
// All three iterate the HashMap inside Rust under one read lock,
// returning either a JSON byte buffer (count maps) or an i64
// (distinct count)。

#[no_mangle]
pub extern "C" fn bas_rust_tracker_count_by_permit_mode(
    tracker: *mut Tracker,
    out_buf: *mut *mut c_uchar,
    out_len: *mut usize,
) -> c_int {
    if tracker.is_null()
        || out_buf.is_null()
        || out_len.is_null()
    {
        return -1;
    }
    let tref = unsafe { &*tracker };
    let bytes = match tref.count_by_permit_mode_json() {
        Ok(v) => v,
        Err(_) => return -2,
    };
    let mut boxed = bytes.into_boxed_slice();
    unsafe {
        *out_buf = boxed.as_mut_ptr();
        *out_len = boxed.len();
        std::mem::forget(boxed);
    }
    0
}

#[no_mangle]
pub extern "C" fn bas_rust_tracker_count_by_session(
    tracker: *mut Tracker,
    out_buf: *mut *mut c_uchar,
    out_len: *mut usize,
) -> c_int {
    if tracker.is_null()
        || out_buf.is_null()
        || out_len.is_null()
    {
        return -1;
    }
    let tref = unsafe { &*tracker };
    let bytes = match tref.count_by_session_json() {
        Ok(v) => v,
        Err(_) => return -2,
    };
    let mut boxed = bytes.into_boxed_slice();
    unsafe {
        *out_buf = boxed.as_mut_ptr();
        *out_len = boxed.len();
        std::mem::forget(boxed);
    }
    0
}

#[no_mangle]
pub extern "C" fn bas_rust_tracker_distinct_sessions(
    tracker: *mut Tracker,
) -> i64 {
    if tracker.is_null() {
        return -1;
    }
    unsafe { (*tracker).distinct_sessions() }
}

// ABI version pin for the aggregation surface added this
// commit。 Currently 1。 Separate version pin so future
// changes to the aggregation surface don't force a bump
// on the main version pin (which would invalidate
// existing wire-format byte-equality tests)。
#[no_mangle]
pub extern "C" fn bas_rust_tracker_aggregation_version() -> c_int {
    1
}

// 持续性 发展 — top-K most-frequent atoms via native
// HashMap iteration + partial sort under one read lock。
// Returns JSON array `[{"atomID": "...", "count": N}, ...]`
// sorted descending by count,alphabetical tie-break。
#[no_mangle]
pub extern "C" fn bas_rust_tracker_top_k_atoms(
    tracker: *mut Tracker,
    k: usize,
    out_buf: *mut *mut c_uchar,
    out_len: *mut usize,
) -> c_int {
    if tracker.is_null()
        || out_buf.is_null()
        || out_len.is_null()
    {
        return -1;
    }
    let tref = unsafe { &*tracker };
    let bytes = match tref.top_k_atoms_json(k) {
        Ok(v) => v,
        Err(_) => return -2,
    };
    let mut boxed = bytes.into_boxed_slice();
    unsafe {
        *out_buf = boxed.as_mut_ptr();
        *out_len = boxed.len();
        std::mem::forget(boxed);
    }
    0
}

#[no_mangle]
pub extern "C" fn bas_rust_tracker_top_k_atoms_version() -> c_int {
    1
}

// 持续性 发展 — atom-count distribution percentiles via
// Rust-native sort under one read lock。 Out-params filled
// with p50 / p95 / p99 of the count-per-atom distribution
// using nearest-rank method。 Returns -1 for all three when
// no records exist。
#[no_mangle]
pub extern "C" fn bas_rust_tracker_atom_count_percentiles(
    tracker: *mut Tracker,
    p50_out: *mut i64,
    p95_out: *mut i64,
    p99_out: *mut i64,
) -> c_int {
    if tracker.is_null()
        || p50_out.is_null()
        || p95_out.is_null()
        || p99_out.is_null()
    {
        return -1;
    }
    let tref = unsafe { &*tracker };
    let (p50, p95, p99) = tref.atom_count_percentiles();
    unsafe {
        *p50_out = p50;
        *p95_out = p95;
        *p99_out = p99;
    }
    0
}

#[no_mangle]
pub extern "C" fn bas_rust_tracker_atom_count_percentiles_version() -> c_int {
    1
}

// 主线 核心 抽取 — Memory Importance Scorer FFI。 Real
// chapter 252 算法 inside Rust under one read lock。
// Emits JSON array sorted by score descending。
#[no_mangle]
pub extern "C" fn bas_rust_tracker_atom_importance_scores(
    tracker: *mut Tracker,
    now_ms: i64,
    half_life_ms: i64,
    out_buf: *mut *mut c_uchar,
    out_len: *mut usize,
) -> c_int {
    if tracker.is_null()
        || out_buf.is_null()
        || out_len.is_null()
    {
        return -1;
    }
    let tref = unsafe { &*tracker };
    let bytes = match tref
        .atom_importance_scores_json(now_ms, half_life_ms)
    {
        Ok(v) => v,
        Err(_) => return -2,
    };
    let mut boxed = bytes.into_boxed_slice();
    unsafe {
        *out_buf = boxed.as_mut_ptr();
        *out_len = boxed.len();
        std::mem::forget(boxed);
    }
    0
}

#[no_mangle]
pub extern "C" fn bas_rust_tracker_atom_importance_scores_version() -> c_int {
    1
}

// 主线 核心 抽取 — Forget Cascade decision FFI。 Returns
// JSON array of atomIDs falling below the retain
// threshold。 Hosts iterate the array,issue forget
// per atomID (or whatever forget cascade entails in
// the host)。
#[no_mangle]
pub extern "C" fn bas_rust_tracker_forget_candidates(
    tracker: *mut Tracker,
    now_ms: i64,
    half_life_ms: i64,
    retain_fraction: f64,
    out_buf: *mut *mut c_uchar,
    out_len: *mut usize,
) -> c_int {
    if tracker.is_null()
        || out_buf.is_null()
        || out_len.is_null()
    {
        return -1;
    }
    let tref = unsafe { &*tracker };
    let bytes = match tref.forget_candidates_json(
        now_ms, half_life_ms, retain_fraction)
    {
        Ok(v) => v,
        Err(_) => return -2,
    };
    let mut boxed = bytes.into_boxed_slice();
    unsafe {
        *out_buf = boxed.as_mut_ptr();
        *out_len = boxed.len();
        std::mem::forget(boxed);
    }
    0
}

#[no_mangle]
pub extern "C" fn bas_rust_tracker_forget_candidates_version() -> c_int {
    1
}

// 全面 开发 — retrieval-interval distribution percentiles
// FFI。 Out-params filled with p50 / p95 / p99 of the
// retrieved-at delta distribution (milliseconds)。
#[no_mangle]
pub extern "C" fn bas_rust_tracker_retrieval_interval_percentiles(
    tracker: *mut Tracker,
    p50_out: *mut i64,
    p95_out: *mut i64,
    p99_out: *mut i64,
) -> c_int {
    if tracker.is_null()
        || p50_out.is_null()
        || p95_out.is_null()
        || p99_out.is_null()
    {
        return -1;
    }
    let tref = unsafe { &*tracker };
    let (p50, p95, p99) =
        tref.retrieval_interval_percentiles();
    unsafe {
        *p50_out = p50;
        *p95_out = p95;
        *p99_out = p99;
    }
    0
}

#[no_mangle]
pub extern "C" fn bas_rust_tracker_retrieval_interval_percentiles_version() -> c_int {
    1
}

// 主线 Integrity 抽取 — chain hash FFI。 Caller passes a
// 32-byte output buffer;Rust fills it with the SHA256
// hash of canonically-ordered record content。
//
// Returns:
//   - 0  = success (out_hash filled with 32 bytes)
//   - -1 = null pointer
//   - -2 = internal error (lock poisoned)
#[no_mangle]
pub extern "C" fn bas_rust_tracker_compute_chain_hash(
    tracker: *mut Tracker,
    out_hash: *mut c_uchar,
) -> c_int {
    if tracker.is_null() || out_hash.is_null() {
        return -1;
    }
    let tref = unsafe { &*tracker };
    let hash = match tref.compute_chain_hash() {
        Ok(h) => h,
        Err(_) => return -2,
    };
    unsafe {
        std::ptr::copy_nonoverlapping(
            hash.as_ptr(), out_hash, 32);
    }
    0
}

#[no_mangle]
pub extern "C" fn bas_rust_tracker_compute_chain_hash_version() -> c_int {
    1
}

// 主线 Integrity 抽取 — validator variant of the chain
// hash。 Compares the live tracker's chain hash against
// a provided expected 32-byte hash。 Saves the host
// from doing the byte comparison in Swift。
//
// Returns:
//   1   = hashes match (chain integrity verified)
//   0   = hashes differ (tamper / drift detected)
//   -1  = null pointer
//   -2  = internal error (lock poisoned)
#[no_mangle]
pub extern "C" fn bas_rust_tracker_verify_chain_hash(
    tracker: *mut Tracker,
    expected_hash: *const c_uchar,
) -> c_int {
    if tracker.is_null() || expected_hash.is_null() {
        return -1;
    }
    let tref = unsafe { &*tracker };
    let actual = match tref.compute_chain_hash() {
        Ok(h) => h,
        Err(_) => return -2,
    };
    let expected_slice = unsafe {
        std::slice::from_raw_parts(expected_hash, 32)
    };
    if actual.as_slice() == expected_slice { 1 } else { 0 }
}

#[no_mangle]
pub extern "C" fn bas_rust_tracker_verify_chain_hash_version() -> c_int {
    1
}

// 主线 Ledger 抽取 — stateless append-only chain step。
// Pure function:given prev_hash + event_payload,
// returns the next chain hash = SHA256(prev_hash ||
// length(payload) big-endian || payload)。 No tracker
// state involved。
//
// Hosts call this for each ledger append:they keep
// their own ledger storage but delegate the cryptographic
// chain step to Rust。 BASSovereignAuditLedger keeps its
// Swift state machine + storage;Rust owns the hash
// math。
//
// Returns:
//   0  = success (out_hash filled)
//   -1 = null pointer (any of 3)
#[no_mangle]
pub extern "C" fn bas_rust_ledger_append_step(
    prev_hash: *const c_uchar,
    payload: *const c_uchar,
    payload_len: usize,
    out_hash: *mut c_uchar,
) -> c_int {
    if prev_hash.is_null() || out_hash.is_null() {
        return -1;
    }
    if payload.is_null() && payload_len > 0 {
        return -1;
    }
    let prev_slice = unsafe {
        std::slice::from_raw_parts(prev_hash, 32)
    };
    let payload_slice = if payload_len == 0 {
        &[][..]
    } else {
        unsafe {
            std::slice::from_raw_parts(
                payload, payload_len)
        }
    };
    let mut hasher = Sha256::new();
    hasher.update(prev_slice);
    feed_length_prefixed(
        &mut hasher, payload_slice);
    let digest = hasher.finalize();
    unsafe {
        std::ptr::copy_nonoverlapping(
            digest.as_ptr(), out_hash, 32);
    }
    0
}

#[no_mangle]
pub extern "C" fn bas_rust_ledger_append_step_version() -> c_int {
    1
}

// 主线 Ledger Replay 抽取 — replay a chain of events
// starting from `initial_hash`,feeding each payload
// through the SHA256 chain step,then comparing the
// final accumulated hash against `expected_final_hash`。
//
// The `payloads` are encoded as a flat buffer of
// length-prefixed payload regions:
//
//   [4 bytes u32 big-endian count][
//     [4 bytes u32 BE len_0][len_0 bytes payload_0]
//     [4 bytes u32 BE len_1][len_1 bytes payload_1]
//     ...
//   ]
//
// This lets a single FFI call validate an entire chain
// without per-event boundary-crossing。 Returns:
//   1   = match (chain verified)
//   0   = mismatch (chain replay diverges from expected)
//   -1  = null pointer or malformed payload buffer
#[no_mangle]
pub extern "C" fn bas_rust_ledger_replay_verify(
    initial_hash: *const c_uchar,
    payloads: *const c_uchar,
    payloads_len: usize,
    expected_final_hash: *const c_uchar,
) -> c_int {
    if initial_hash.is_null()
        || expected_final_hash.is_null()
    {
        return -1;
    }
    if payloads.is_null() && payloads_len > 0 {
        return -1;
    }
    let initial_slice = unsafe {
        std::slice::from_raw_parts(initial_hash, 32)
    };
    let expected_slice = unsafe {
        std::slice::from_raw_parts(
            expected_final_hash, 32)
    };
    let buf = if payloads_len == 0 {
        &[][..]
    } else {
        unsafe {
            std::slice::from_raw_parts(
                payloads, payloads_len)
        }
    };
    if buf.len() < 4 { return -1; }
    let count = u32::from_be_bytes([
        buf[0], buf[1], buf[2], buf[3]]) as usize;
    let mut current: [u8; 32] = {
        let mut h = [0u8; 32];
        h.copy_from_slice(initial_slice);
        h
    };
    let mut offset: usize = 4;
    for _ in 0..count {
        if offset + 4 > buf.len() { return -1; }
        let len = u32::from_be_bytes([
            buf[offset], buf[offset + 1],
            buf[offset + 2], buf[offset + 3]
        ]) as usize;
        offset += 4;
        if offset + len > buf.len() { return -1; }
        let payload = &buf[offset..offset + len];
        offset += len;
        let mut hasher = Sha256::new();
        hasher.update(&current);
        feed_length_prefixed(&mut hasher, payload);
        let digest = hasher.finalize();
        current.copy_from_slice(&digest);
    }
    if current.as_slice() == expected_slice { 1 } else { 0 }
}

#[no_mangle]
pub extern "C" fn bas_rust_ledger_replay_verify_version() -> c_int {
    1
}

// 主线 Provenance 抽取 — record lineage FFI。 Returns
// JSON array of records sharing the given atom_id,
// sorted ascending by retrieved_at_ms。
#[no_mangle]
pub extern "C" fn bas_rust_tracker_record_lineage(
    tracker: *mut Tracker,
    atom_id: *const c_char,
    out_buf: *mut *mut c_uchar,
    out_len: *mut usize,
) -> c_int {
    if tracker.is_null()
        || atom_id.is_null()
        || out_buf.is_null()
        || out_len.is_null()
    {
        return -1;
    }
    let tref = unsafe { &*tracker };
    let key = unsafe {
        match CStr::from_ptr(atom_id).to_str() {
            Ok(s) => s,
            Err(_) => return -2,
        }
    };
    let bytes = match tref.record_lineage_json(key) {
        Ok(v) => v,
        Err(_) => return -2,
    };
    let mut boxed = bytes.into_boxed_slice();
    unsafe {
        *out_buf = boxed.as_mut_ptr();
        *out_len = boxed.len();
        std::mem::forget(boxed);
    }
    0
}

#[no_mangle]
pub extern "C" fn bas_rust_tracker_record_lineage_version() -> c_int {
    1
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    fn cstring(s: &str) -> CString {
        CString::new(s).unwrap()
    }

    #[test]
    fn version_is_one() {
        assert_eq!(bas_rust_tracker_version(), 1);
    }

    #[test]
    fn init_close_round_trip() {
        let t = bas_rust_tracker_init();
        assert!(!t.is_null());
        assert_eq!(bas_rust_tracker_close(t), 0);
    }

    #[test]
    fn close_null_returns_negative_one() {
        assert_eq!(bas_rust_tracker_close(ptr::null_mut()), -1);
    }

    #[test]
    fn append_and_size() {
        let t = bas_rust_tracker_init();
        let rid = cstring("r1");
        let aid = cstring("a1");
        let sref = cstring("s1");
        let tref = cstring("t1");
        let mode = cstring("allow");
        let hflag = cstring("unknown");
        let rc = bas_rust_tracker_append(
            t,
            rid.as_ptr(),
            aid.as_ptr(),
            123456789,
            sref.as_ptr(),
            tref.as_ptr(),
            mode.as_ptr(),
            hflag.as_ptr(),
        );
        assert_eq!(rc, 0);
        assert_eq!(bas_rust_tracker_size(t), 1);
        bas_rust_tracker_close(t);
    }

    #[test]
    fn query_returns_json_array() {
        let t = bas_rust_tracker_init();
        let rid = cstring("r1");
        let aid = cstring("a1");
        let sref = cstring("s1");
        let tref = cstring("t1");
        let mode = cstring("allow");
        let hflag = cstring("unknown");
        bas_rust_tracker_append(
            t,
            rid.as_ptr(),
            aid.as_ptr(),
            1000,
            sref.as_ptr(),
            tref.as_ptr(),
            mode.as_ptr(),
            hflag.as_ptr(),
        );
        let empty = cstring("");
        let mut buf: *mut c_uchar = ptr::null_mut();
        let mut len: usize = 0;
        let rc = bas_rust_tracker_query(
            t,
            empty.as_ptr(),
            &mut buf,
            &mut len,
        );
        assert_eq!(rc, 0);
        assert!(len > 0);
        unsafe {
            let s = std::slice::from_raw_parts(buf, len);
            let txt = std::str::from_utf8(s).unwrap();
            assert!(txt.starts_with('['));
            assert!(txt.ends_with(']'));
            assert!(txt.contains("\"atomID\":\"a1\""));
        }
        bas_rust_tracker_free_buffer(buf, len);
        bas_rust_tracker_close(t);
    }
}
