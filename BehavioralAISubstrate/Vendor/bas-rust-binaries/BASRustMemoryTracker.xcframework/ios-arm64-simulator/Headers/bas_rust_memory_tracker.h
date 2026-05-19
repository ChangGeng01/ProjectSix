// SPDX:internal
// MARK: - bas_rust_memory_tracker.h
// chapter 七百六 / M2187 第一刀 — C ABI header for the
//                                 Rust pilot's
//                                 bas-memory-usage-
//                                 tracker crate。
//
// Hand-written (not cbindgen-generated) to keep the
// build pipeline simple — cbindgen would require a
// build-script + cbindgen dependency。 The surface is
// small (6 functions),so manual maintenance is the
// right cost/complexity trade-off until the surface
// grows past ~12 functions。
//
// MUST stay byte-identical to the Rust-side `#[no_mangle]`
// declarations in `Cargo/bas-memory-usage-tracker/src/
// lib.rs`。 The Swift bridge actor + 28 anti-drift tests
// (M2189 第三刀) include a version cross-mirror that
// asserts header + Rust-side disagree → test fails。

#ifndef BAS_RUST_MEMORY_TRACKER_H
#define BAS_RUST_MEMORY_TRACKER_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque tracker handle returned by
/// `bas_rust_tracker_init`。 Caller MUST eventually
/// call `bas_rust_tracker_close` to release。
typedef struct Tracker Tracker;

/// ABI version pin。 Currently 1。 Bumping the Rust-
/// side ABI_VERSION constant requires updating
/// `BASRustCoreBridge.cargoCrateABIVersion` + the
/// `testRustABIVersion` test simultaneously so a
/// future Swift-side caller cannot silently observe
/// behavior changes。
int32_t bas_rust_tracker_version(void);

/// Construct a fresh in-memory tracker。 Returns NULL
/// only on Rust-side allocation failure (extremely
/// rare;Box::new ::Tracker is small)。
Tracker* bas_rust_tracker_init(void);

/// Close + free a tracker。 Caller MUST NOT use the
/// handle after this call。 Returns 0 on success,-1
/// on null pointer。
int32_t bas_rust_tracker_close(Tracker* tracker);

/// Append one record。 All string parameters are NUL-
/// terminated UTF-8 owned by caller;tracker copies
/// into internal Rust String storage。
///
/// Returns:
///   - 0  = success
///   - -1 = null pointer (any of the 7 input pointers)
///   - -2 = internal error (UTF-8 decode failed or
///          lock poisoned)
int32_t bas_rust_tracker_append(
    Tracker* tracker,
    const char* record_id,
    const char* atom_id,
    int64_t retrieved_at_ms,
    const char* session_ref,
    const char* turn_ref,
    const char* permit_mode,
    const char* helped_state);

/// Query records matching `atom_id`,or all records
/// if `atom_id` is empty string。 Allocates a heap
/// buffer with JSON-encoded UTF-8 bytes,returns the
/// pointer + length via out-params。 Caller MUST call
/// `bas_rust_tracker_free_buffer` to release。
///
/// JSON format:`[{...},{...}]` array of records
/// sorted ascending by retrieved_at_ms。 Each record
/// is a JSON object with keys atomID + helpedFlag +
/// permitMode + retrievedAtMs + recordID +
/// schemaVersion + sessionRef + turnRef (alphabetical
/// order for byte-equality determinism)。
///
/// Returns:
///   - 0  = success
///   - -1 = null pointer (any of the 4 input pointers)
///   - -2 = internal error (UTF-8 decode failed or
///          lock poisoned)
int32_t bas_rust_tracker_query(
    Tracker* tracker,
    const char* atom_id,
    uint8_t** out_buf,
    size_t* out_len);

/// Release a buffer returned by `bas_rust_tracker_query`。
/// Null pointer or zero length are no-ops。
void bas_rust_tracker_free_buffer(uint8_t* buf, size_t len);

/// Tracker size snapshot (record count)。 Returns -1
/// if `tracker` is null OR if the internal RwLock is
/// poisoned (extremely rare)。
int64_t bas_rust_tracker_size(Tracker* tracker);

/// 主线 全面 开发 — Rust-side native aggregation FFI。
/// Iterates the HashMap inside Rust under one read lock,
/// emits JSON `{"permit_mode": count, ...}` map sorted
/// alphabetically by key (byte-equality deterministic)。
/// Caller MUST call `bas_rust_tracker_free_buffer` to
/// release。
///
/// Returns:
///   - 0  = success
///   - -1 = null pointer
///   - -2 = internal error (lock poisoned)
int32_t bas_rust_tracker_count_by_permit_mode(
    Tracker* tracker,
    uint8_t** out_buf,
    size_t* out_len);

/// Counterpart of `count_by_permit_mode` grouping by
/// session_ref instead of permit_mode。
int32_t bas_rust_tracker_count_by_session(
    Tracker* tracker,
    uint8_t** out_buf,
    size_t* out_len);

/// Number of distinct `session_ref` values across all
/// records。 Returns -1 if `tracker` is null OR lock
/// poisoned。
int64_t bas_rust_tracker_distinct_sessions(
    Tracker* tracker);

/// ABI version pin for the aggregation surface added
/// this commit。 Currently 1。 Separate from
/// `bas_rust_tracker_version` so future aggregation-
/// surface changes don't force a bump on the main pin。
int32_t bas_rust_tracker_aggregation_version(void);

/// 持续性 发展 — top-K most-frequent atoms via Rust-
/// native iteration + partial sort。 Returns JSON array
/// `[{"atomID": "...", "count": N}, ...]` sorted
/// descending by count,alphabetical tie-break。
/// Caller MUST call `bas_rust_tracker_free_buffer` to
/// release the returned buffer。
///
/// Returns:
///   - 0  = success
///   - -1 = null pointer
///   - -2 = internal error (lock poisoned)
int32_t bas_rust_tracker_top_k_atoms(
    Tracker* tracker,
    size_t k,
    uint8_t** out_buf,
    size_t* out_len);

/// ABI version pin for `bas_rust_tracker_top_k_atoms`。
int32_t bas_rust_tracker_top_k_atoms_version(void);

/// 持续性 发展 — atom-count distribution percentiles
/// via Rust-native sort under one read lock。 Fills the
/// three out-params with p50 / p95 / p99 of the count-
/// per-atom distribution。
///
/// Returns -1 for all three percentile values when no
/// records exist (no distribution)。
///
/// Returns:
///   - 0  = success (out-params filled)
///   - -1 = null pointer (any of 4)
int32_t bas_rust_tracker_atom_count_percentiles(
    Tracker* tracker,
    int64_t* p50_out,
    int64_t* p95_out,
    int64_t* p99_out);

/// ABI version pin for
/// `bas_rust_tracker_atom_count_percentiles`。
int32_t bas_rust_tracker_atom_count_percentiles_version(void);

/// 主线 核心 抽取 — Memory Importance Scorer in Rust。
/// For each distinct atom_id,computes:
///   score = log(1 + count)
///         * exp(-(now_ms - last_retrieved_ms) / half_life_ms)
///         * max(0.5, helped_rate)
///
/// Emits JSON array sorted by score descending:
///   [{"atomID":"...","count":N,"helpedRate":0.NN,
///     "lastRetrievedMs":N,"score":N.NNNNNN}]
///
/// Caller MUST call `bas_rust_tracker_free_buffer` to
/// release the returned buffer。
///
/// Returns:
///   - 0  = success
///   - -1 = null pointer
///   - -2 = internal error (lock poisoned)
int32_t bas_rust_tracker_atom_importance_scores(
    Tracker* tracker,
    int64_t now_ms,
    int64_t half_life_ms,
    uint8_t** out_buf,
    size_t* out_len);

/// ABI version pin for
/// `bas_rust_tracker_atom_importance_scores`。
int32_t bas_rust_tracker_atom_importance_scores_version(void);

/// 主线 核心 抽取 — Forget Cascade decision FFI。
/// Computes the same per-atom score as
/// `atom_importance_scores`,sorts descending,keeps
/// the top `retain_fraction` of distinct atoms,returns
/// the rest as forget candidates。
///
/// retain_fraction is clamped to [0.0, 1.0]:
///   0.0 → all atoms candidate (forget everything)
///   1.0 → empty candidate list (keep everything)
///   0.8 → keep top 80%,return bottom 20%
///
/// Emits JSON array of atomID strings。 Caller MUST call
/// `bas_rust_tracker_free_buffer` to release。
///
/// Returns:
///   - 0  = success
///   - -1 = null pointer
///   - -2 = internal error (lock poisoned)
int32_t bas_rust_tracker_forget_candidates(
    Tracker* tracker,
    int64_t now_ms,
    int64_t half_life_ms,
    double retain_fraction,
    uint8_t** out_buf,
    size_t* out_len);

/// ABI version pin for
/// `bas_rust_tracker_forget_candidates`。
int32_t bas_rust_tracker_forget_candidates_version(void);

/// 全面 开发 — retrieval-interval distribution
/// percentiles via Rust-native sort + delta + percentile
/// computation under one read lock。 Out-params filled
/// with p50 / p95 / p99 of the gap-between-consecutive-
/// retrievals distribution (milliseconds)。 Reveals
/// traffic rhythm:typical gap between brain.summary
/// calls。
///
/// Returns -1 for all three when fewer than 2 records
/// exist (no interval can be computed from one point)。
///
/// Returns:
///   - 0  = success (out-params filled)
///   - -1 = null pointer (any of 4)
int32_t bas_rust_tracker_retrieval_interval_percentiles(
    Tracker* tracker,
    int64_t* p50_out,
    int64_t* p95_out,
    int64_t* p99_out);

/// ABI version pin for
/// `bas_rust_tracker_retrieval_interval_percentiles`。
int32_t bas_rust_tracker_retrieval_interval_percentiles_version(void);

/// 主线 Integrity 抽取 — compute a deterministic SHA256
/// hash over the canonically-ordered (sort by
/// retrieved_at_ms then record_id) record set。 Hosts
/// use this for tamper detection:store a known-good
/// chain hash,re-compute periodically,alert on
/// divergence。
///
/// Empty tracker hashes the empty byte stream → SHA256
/// of zero bytes (e3b0c4...)。
///
/// - Parameter out_hash:32-byte buffer the caller
///   provides;Rust writes the SHA256 digest into it。
///
/// Returns:
///   - 0  = success (out_hash filled with 32 bytes)
///   - -1 = null pointer (either)
///   - -2 = internal error (lock poisoned)
int32_t bas_rust_tracker_compute_chain_hash(
    Tracker* tracker,
    uint8_t* out_hash);

/// ABI version pin for
/// `bas_rust_tracker_compute_chain_hash`。
int32_t bas_rust_tracker_compute_chain_hash_version(void);

/// 主线 Integrity 抽取 — validator variant。 Compares
/// the tracker's live chain hash against a provided
/// expected 32-byte hash。
///
/// Returns:
///   - 1  = match
///   - 0  = mismatch (tamper / drift detected)
///   - -1 = null pointer
///   - -2 = internal error (lock poisoned)
int32_t bas_rust_tracker_verify_chain_hash(
    Tracker* tracker,
    const uint8_t* expected_hash);

int32_t bas_rust_tracker_verify_chain_hash_version(void);

/// 主线 Ledger 抽取 — stateless append-only chain step。
/// Given prev_hash + payload bytes,returns the next
/// chain hash via SHA256(prev_hash || length(payload)
/// big-endian || payload)。 Pure function — no tracker
/// state involved。 Hosts use this for ledger append
/// while keeping their own storage / state machine。
///
/// Returns:
///   - 0  = success (out_hash filled with 32 bytes)
///   - -1 = null pointer (prev_hash,out_hash,or
///          payload when payload_len > 0)
int32_t bas_rust_ledger_append_step(
    const uint8_t* prev_hash,
    const uint8_t* payload,
    size_t payload_len,
    uint8_t* out_hash);

int32_t bas_rust_ledger_append_step_version(void);

/// 主线 Ledger Replay 抽取 — replay a chain of events
/// in Rust + verify final hash matches expected。
/// `payloads` is a flat length-prefixed encoding:
///   [u32 count BE][[u32 len BE][bytes payload]]...
///
/// Returns:
///   - 1  = chain replay matches expected_final_hash
///   - 0  = chain replay diverges
///   - -1 = null pointer or malformed buffer
int32_t bas_rust_ledger_replay_verify(
    const uint8_t* initial_hash,
    const uint8_t* payloads,
    size_t payloads_len,
    const uint8_t* expected_final_hash);

int32_t bas_rust_ledger_replay_verify_version(void);

/// 主线 Provenance 抽取 — record lineage FFI。 Returns
/// JSON array of all records sharing the given atom_id,
/// sorted ascending by retrieved_at_ms。 Each entry
/// includes a `lineageIndex` field (0 = origin,
/// N-1 = most recent descendant)。
///
/// Caller MUST call `bas_rust_tracker_free_buffer` to
/// release the returned buffer。
///
/// Returns:
///   - 0  = success
///   - -1 = null pointer
///   - -2 = internal error / UTF-8 decode failed
int32_t bas_rust_tracker_record_lineage(
    Tracker* tracker,
    const char* atom_id,
    uint8_t** out_buf,
    size_t* out_len);

int32_t bas_rust_tracker_record_lineage_version(void);

// MARK: - chapter 七百四 第一刀 / M2191 — sibling-crate ABI declarations
//
// The chapter 七百三 Rust crates (bas-substrate-core,
// bas-memory-atom-store, bas-retrieval-ranker,
// bas-canonical-bytes, bas-permit-policy, bas-event-log-codec,
// bas-runtime-frame) all force-link into the same .a as
// bas-memory-usage-tracker via the workspace deps + the
// `force_link.rs` anchor。 Declarations below let Swift call
// any of their #[no_mangle] extern "C" surface via
// `import BASRustMemoryTrackerBinary`。

/// Sum of all sibling-crate ABI versions。 Useful for Swift
/// drift tests that pin which bundle of Rust crates ships
/// in the current XCFramework。
int32_t bas_substrate_bundle_abi_total(void);

/// Count of bundled crates inside this XCFramework's
/// staticlib (currently 7)。
int32_t bas_substrate_bundle_crate_count(void);

// MARK: - bas-substrate-core (chapter 七百三 第一刀)
//
// Pure NIST SHA-256 + HMAC-SHA256 + Ed25519 + length-prefixed
// chain-step。 Swift consumers route here to retire the
// CryptoKit-only NIST-pinned sites previously blocked by
// `bas_rust_ledger_append_step`'s length-prefixed formula。

int32_t bas_substrate_core_abi_version(void);

/// Pure NIST SHA-256 of `data` → 32-byte digest written to
/// `out32`。 Returns 0 on success,-1 on null pointers。 Byte-
/// equal to CryptoKit's SHA256.hash(data:) and to the FIPS
/// 180-4 reference vectors。
int32_t bas_substrate_sha256(
    const uint8_t* data,
    size_t data_len,
    uint8_t* out32);

/// HMAC-SHA256 over `data` under `key`。 32-byte tag → `out32`。
int32_t bas_substrate_hmac_sha256(
    const uint8_t* key,
    size_t key_len,
    const uint8_t* data,
    size_t data_len,
    uint8_t* out32);

/// Length-prefixed chain step:SHA256(prev || u32_be(len) ||
/// payload) → `out32`。
int32_t bas_substrate_chain_step(
    const uint8_t* prev32,
    const uint8_t* payload,
    size_t payload_len,
    uint8_t* out32);

/// Ed25519 sign — 32-byte seed + message → 64-byte signature。
int32_t bas_substrate_ed25519_sign(
    const uint8_t* priv_seed_32,
    const uint8_t* msg,
    size_t msg_len,
    uint8_t* out_sig_64);

/// Ed25519 verify。 Returns 1 on valid, 0 on invalid, -1 on
/// null pointer error。
int32_t bas_substrate_ed25519_verify(
    const uint8_t* pub_32,
    const uint8_t* msg,
    size_t msg_len,
    const uint8_t* sig_64);

// MARK: - sibling-crate ABI version probes
//
// Each chapter-七百三 crate exposes an `abi_version()` that
// returns the crate's pinned version。 Swift drift tests pin
// these per-crate so a future Rust-side ABI bump shows up
// in the Swift test output。

int32_t bas_mas_abi_version(void);
int32_t bas_ranker_abi_version(void);
int32_t bas_canonical_bytes_abi_version(void);
int32_t bas_permit_policy_abi_version(void);
int32_t bas_event_log_abi_version(void);
int32_t bas_runtime_frame_abi_version(void);

#ifdef __cplusplus
}
#endif

#endif /* BAS_RUST_MEMORY_TRACKER_H */
