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

// MARK: - bas-tokenizer (chapter 七百二十二 第二刀 / M2282)
//
// Byte-level BPE tokenizer。 Opaque `Tokenizer` handle is
// constructed from caller-supplied vocab + merges buffers in a
// length-prefixed BIG-ENDIAN wire format:
//
//   vocab_buf:
//     [u32 count]
//     repeated count times:
//       [u32 token_byte_len][token bytes][u32 id]
//
//   merges_buf:
//     [u32 count]
//     repeated count times:
//       [u32 left_byte_len][left bytes]
//       [u32 right_byte_len][right bytes]
//       [u32 rank]
//
// Encode + decode are two-phase: first call with `out_capacity=0`
// (and corresponding null `out_*` pointer) returns the required
// size,then realloc + retry。 Mirrors how the Swift bridge
// (`BASAutoRouteRanker.bpeEncode/bpeDecode`) handles unknown-size
// outputs without leaking allocation back into Rust。

/// Opaque tokenizer handle returned by `bas_tokenizer_new`。
/// Caller MUST eventually call `bas_tokenizer_free` to release。
typedef struct BasTokenizer BasTokenizer;

/// ABI version pin for the bas-tokenizer surface。 Bumping
/// requires synchronizing BASAutoRouteRanker mirror constant +
/// drift tests。
int32_t bas_tokenizer_abi_version(void);

/// Construct a tokenizer from serialized vocab + merges buffers。
/// Returns NULL on:
///   - null pointer with non-zero length
///   - malformed wire format (length-prefix underrun)
BasTokenizer* bas_tokenizer_new(
    const uint8_t* vocab_buf, size_t vocab_len,
    const uint8_t* merges_buf, size_t merges_len,
    uint32_t unk_id);

/// Release a tokenizer handle。 Safe to call on NULL (no-op)。
void bas_tokenizer_free(BasTokenizer* tok);

/// Encode `text_utf8` (must be valid UTF-8) into up to
/// `out_capacity` token IDs。 Returns the FULL ID count produced
/// (including overflow);when the return exceeds `out_capacity`,
/// the caller should realloc + retry。 First-pass discovery
/// call uses `out_ids=NULL, out_capacity=0`。
///
/// Returns:
///   >= 0 = number of IDs produced
///   -1   = null pointer
///   -2   = invalid UTF-8 input bytes
int64_t bas_tokenizer_encode(
    const BasTokenizer* tok,
    const uint8_t* text_utf8, size_t text_len,
    uint32_t* out_ids, size_t out_capacity);

/// Decode `n_ids` token IDs into up to `out_capacity` UTF-8
/// bytes。 Returns the FULL byte count produced。 First-pass
/// discovery uses `out_utf8=NULL, out_capacity=0`。
///
/// Returns:
///   >= 0 = number of UTF-8 bytes produced
///   -1   = null pointer
///   -2   = decoded bytes are not valid UTF-8
int64_t bas_tokenizer_decode(
    const BasTokenizer* tok,
    const uint32_t* ids, size_t n_ids,
    uint8_t* out_utf8, size_t out_capacity);

/// Vocab size。 Returns -1 on null pointer。
int64_t bas_tokenizer_vocab_size(const BasTokenizer* tok);

// MARK: - bas-retrieval-ranker math kernels (chapter 七百四 第三刀)
//
// Pure float32 cosine + L2 + batched-cosine。 Swift callers
// route through `BASCognitiveBrain.cosineSimilarityRust(_:_:)`
// when they want CPU-side math without the Metal dispatch cost。
// On vectors of small dimension (< 256) the Rust path is
// typically faster than spinning up a Metal compute pipeline。

int32_t bas_ranker_cosine_similarity(
    const float* a,
    size_t a_len,
    const float* b,
    size_t b_len,
    float* out_score);

int32_t bas_ranker_l2_norm(
    const float* v,
    size_t v_len,
    float* out_norm);

int32_t bas_ranker_batched_cosine(
    const float* query,
    size_t query_len,
    const float* corpus,
    size_t corpus_total_len,
    size_t dim,
    float* out_scores);

// MARK: - chapter 七百五 第二刀 SIMD-accelerated variants
//
// Same math as the scalar paths above but routed through the
// 4-wide unrolled implementation that LLVM auto-vectorizes to
// NEON / SSE。 Faster than the scalar baseline for dim >= 8。

int32_t bas_ranker_cosine_similarity_simd(
    const float* a,
    size_t a_len,
    const float* b,
    size_t b_len,
    float* out_score);

int32_t bas_ranker_l2_norm_simd(
    const float* v,
    size_t v_len,
    float* out_norm);

int32_t bas_ranker_batched_cosine_simd(
    const float* query,
    size_t query_len,
    const float* corpus,
    size_t corpus_total_len,
    size_t dim,
    float* out_scores);

// MARK: - chapter 七百八 第一刀 MatMul ABI
//
// f32 matrix multiplication: A (M×K) × B (K×N) = C (M×N)
// Row-major layout。 Three variants:
//
//   _naive          — reference O(MNK) impl, oracle for tests
//   _blocked        — 32×32 cache-blocked, wins on medium-large
//   _simd_blocked   — + 4-wide inner unrolling, fastest CPU path

int32_t bas_ranker_matmul_naive(
    const float* a, size_t a_len,
    const float* b, size_t b_len,
    float* c, size_t c_len,
    size_t m, size_t n, size_t k);

int32_t bas_ranker_matmul_blocked(
    const float* a, size_t a_len,
    const float* b, size_t b_len,
    float* c, size_t c_len,
    size_t m, size_t n, size_t k);

int32_t bas_ranker_matmul_simd_blocked(
    const float* a, size_t a_len,
    const float* b, size_t b_len,
    float* c, size_t c_len,
    size_t m, size_t n, size_t k);

// MARK: - chapter 七百九 第一刀 Softmax ABI

int32_t bas_ranker_softmax(
    const float* x, size_t n,
    float* out, size_t out_n);

int32_t bas_ranker_softmax_simd(
    const float* x, size_t n,
    float* out, size_t out_n);

int32_t bas_ranker_softmax_rowwise_simd(
    const float* x, size_t x_len,
    float* out, size_t out_len,
    size_t rows, size_t cols);

// MARK: - chapter 七百九 第二刀 LayerNorm ABI

int32_t bas_ranker_layer_norm(
    const float* x, size_t n,
    float* out, size_t out_n,
    float eps);

int32_t bas_ranker_layer_norm_welford(
    const float* x, size_t n,
    float* out, size_t out_n,
    float eps);

int32_t bas_ranker_layer_norm_affine_simd(
    const float* x, size_t x_len,
    const float* gamma, size_t gamma_len,
    const float* beta, size_t beta_len,
    float* out, size_t out_len,
    float eps);

/* chapter 七百十一 第二刀 — Activation C ABI:
 * Each takes a non-empty fp32 input + matching-length output。
 * Returns 0 on success,-1 on null pointer,-2 on length
 * mismatch / zero-length input。
 */
int32_t bas_ranker_gelu_exact(
    const float* x, size_t n, float* out, size_t out_n);
int32_t bas_ranker_gelu_exact_simd(
    const float* x, size_t n, float* out, size_t out_n);
int32_t bas_ranker_gelu_tanh_approx(
    const float* x, size_t n, float* out, size_t out_n);
int32_t bas_ranker_gelu_tanh_approx_simd(
    const float* x, size_t n, float* out, size_t out_n);
int32_t bas_ranker_silu(
    const float* x, size_t n, float* out, size_t out_n);
int32_t bas_ranker_silu_simd(
    const float* x, size_t n, float* out, size_t out_n);

/* chapter 七百十二 第二刀 — Batched ledger seal + chain verify。
 * Per architectural matrix: Rust owns ledger/replay + integrity
 * hash。 Each call here collapses what would otherwise be N
 * Swift→Rust FFI round-trips into one。
 *
 * Wire format for canonicals_buf: concatenation of length-prefixed
 *   payloads,where each payload is laid out as
 *       [u32_be length][payload bytes]
 *   The buffer must encode exactly `n` records,no padding。
 *
 * Wire format for *_self_hashes_n_x_32: n × 32 contiguous bytes。
 */
int32_t bas_ranker_ledger_seal(
    const uint8_t* canonical, size_t canonical_len,
    uint8_t* out_32);
int32_t bas_ranker_ledger_seal_batch(
    const uint8_t* initial_32,
    const uint8_t* canonicals_buf, size_t canonicals_buf_len,
    size_t n,
    uint8_t* out_self_hashes_n_x_32);
int32_t bas_ranker_ledger_verify_chain(
    const uint8_t* initial_32,
    const uint8_t* canonicals_buf, size_t canonicals_buf_len,
    const uint8_t* expected_self_hashes_n_x_32,
    size_t n,
    uint8_t* out_tip_32);

/* chapter 七百十三 第四刀 — Forget cascade + provenance C ABI。
 * Per architectural matrix:Rust owns forget cascade +
 * provenance + integrity hash duties。
 *
 * Wire format for record_ids_buf / target_ids_buf:
 *   concatenation of length-prefixed UTF-8 strings:
 *       [u32_be length][utf8 bytes]
 *   The buffer must encode exactly the declared count。
 */
int32_t bas_ranker_forget_cascade_filter(
    const uint8_t* record_ids_buf, size_t record_ids_buf_len,
    size_t n_records,
    const uint8_t* target_ids_buf, size_t target_ids_buf_len,
    size_t n_targets,
    size_t* out_kept_indices,
    size_t* out_removed_indices,
    size_t* out_kept_count,
    size_t* out_removed_count);

/* Provenance gate。 Returns 0..7 (see provenance::rejection_code)
 * or -1 on null pointer / bad ordinal。 Tier ordinal:
 *   0 = Illustrative
 *   1 = AiAdvisory
 *   2 = PeerReviewed
 *   3 = DomainExpertReviewed
 * Rejection codes:
 *   0 = permitted
 *   1 = training_corpus malformed-length
 *   2 = trained_weights malformed-length
 *   3 = training_corpus malformed-content
 *   4 = trained_weights malformed-content
 *   5 = below_production_tier
 *   6 = non_production_tier_carries_attestation
 *   7 = missing_attestation_for_production_tier
 */
/* chapter 七百十九 第一刀 — lookup-table hex encoder。
 * Encodes `n` input bytes as 2*n lowercase hex ASCII chars into
 * the caller-owned out buffer。 ~25× faster than Swift's
 * String(format: "%02x") loop。
 * Returns 0 on success,-1 on null pointer,-2 on shape mismatch。
 */
int32_t bas_ranker_bytes_to_hex_lower(
    const uint8_t* bytes, size_t n,
    uint8_t* out, size_t out_len);

/* chapter 七百二十一 第一刀 — lookup-table hex decoder。
 * Decodes `n_hex_chars` hex ASCII chars (case-insensitive) into
 * the caller-owned out buffer of size n_hex_chars / 2 bytes。
 * Returns bytes-written count on success,or:
 *   -1 on null pointer
 *   -2 on odd hex_len
 *   -3 on non-hex character
 *   -4 on out_len too small
 * ~40-60× faster than Swift's chunks().map { UInt8(_, radix:16) }
 * idiom per chapter 七百二十一 第二刀 measurement。
 */
int64_t bas_ranker_hex_to_bytes(
    const uint8_t* hex, size_t n_hex_chars,
    uint8_t* out, size_t out_len);

int32_t bas_ranker_provenance_rejection_code(
    const uint8_t* training_corpus_hash_hex,
    size_t training_corpus_hash_hex_len,
    const uint8_t* trained_weights_hash_hex,
    size_t trained_weights_hash_hex_len,
    int32_t tier_ordinal,
    int32_t has_signature_ref,
    int32_t has_issued_at);

// MARK: - chapter 七百二十三 第二刀 — Importance scorer C ABI
//
// Wire format (BIG-ENDIAN length prefixes,LE f64 values):
//
//   records_buf:
//     [u32 count]
//     repeated count times:
//       [u32 atom_id_len][atom_id bytes]
//       [i64 retrieved_at_ms]
//       [u8 helped_flag]  (0=NotHelped, 1=Helped, 2=Unknown)
//
//   tiers_buf:
//     [u32 count]
//     repeated count times:
//       [u32 atom_id_len][atom_id bytes]
//       [u8 current_tier] (0=Cold, 1=Warm, 2=Hot)
//
//   tunables_buf (56 bytes total):
//     7 × f64 little-endian。 Order:
//       promote_threshold,demote_threshold,
//       recency_half_life_seconds,frequency_saturation,
//       tier_decay_hot,tier_decay_warm,tier_decay_cold
//
//   out_scores_buf (caller-allocated):
//     [u32 count]
//     repeated count times:
//       [u32 atom_id_len][atom_id bytes]
//       [u8 current_tier]
//       [f64 recency][f64 frequency][f64 helped][f64 tier_decay]
//       [f64 total_score]
//       [u8 recommended_tier]
//       [u32 record_count]
//       [i64 computed_at_ms]
//
// Two-phase: first call with `out_capacity=0` returns the
// required size in bytes,then caller reallocs + retries。

/// Compute importance scores serialized into `out_scores_buf`。
///
/// Returns:
///   ≥ 0 = number of OUTPUT BYTES needed
///   -1  = null pointer
///   -2  = malformed inputs (length-prefix underrun OR invalid
///         enum discriminant)
int64_t bas_ranker_importance_score_all(
    const uint8_t* records_buf, size_t records_len,
    const uint8_t* tiers_buf,   size_t tiers_len,
    const uint8_t* tunables_buf, size_t tunables_len,
    int64_t now_ms,
    uint8_t* out_scores_buf, size_t out_capacity);

// MARK: - chapter 七百二十四 第二刀 — Event log binary encoder
//
// Encode one EventLogEntry to the binary wire format。 Two-phase
// like other chapter-722-style encoders — first call with
// out_capacity=0 returns the required byte count。
//
// Wire layout (matches encode_binary in bas-event-log-codec):
//   [u8 v2=2][u8 kind][u32 le entry_id_len][bytes]
//   [u32 le session_len][bytes][u32 le turn_len][bytes]
//   [i64 le ts]
//   [u8 payload_present][u32 le payload_len][bytes]?
//   [u8 provenance_present][u32 le prov_len][bytes]?
//
// Decode happens Swift-side — the binary format is trivial to
// walk in Swift,no FFI overhead needed for the read path。
//
// Returns:
//   ≥ 0 = number of OUTPUT BYTES needed
//   -1  = null pointer
//   -2  = invalid UTF-8 in any string field OR invalid kind byte
// MARK: - chapter 七百二十五 第二刀 — Aggregation C ABI
//
// Reuses the chapter 七百二十三 records wire format。 Counts the
// records that match `atom_id`。
//
// Returns:
//   ≥ 0 = matching record count
//   -1  = null pointer
//   -2  = malformed records wire format
int64_t bas_ranker_usage_count_for_atom(
    const uint8_t* records_buf, size_t records_len,
    const uint8_t* atom_id_buf, size_t atom_id_len);

// MARK: - chapter 七百二十六 第二刀 / M2302 int8 quantization
//
// Symmetric int8 quantization primitives。 Three thin pass-
// through functions exposing the bas-retrieval-ranker::quantize
// module。

// MARK: - chapter 七百二十九 第二刀 / M2317 PQ index
//
// Product Quantization approximate-NN index。 Opaque handle
// pattern (caller MUST release via bas_pq_index_free)。

typedef struct PqIndex PqIndex;

PqIndex* bas_pq_index_new(size_t dim, size_t m, size_t k);
void bas_pq_index_free(PqIndex* pq);

int32_t bas_pq_index_train(
    PqIndex* pq,
    const float* training, size_t training_len,
    size_t n_train,
    size_t iters);

int64_t bas_pq_index_add(
    PqIndex* pq,
    const float* vector, size_t vector_len);

int64_t bas_pq_index_top_k(
    const PqIndex* pq,
    const float* query, size_t query_len,
    size_t k_results,
    uint64_t* out_ids,
    float* out_distances,
    size_t out_capacity);

int64_t bas_pq_index_n_rows(const PqIndex* pq);
int64_t bas_pq_index_byte_size(const PqIndex* pq);

// MARK: - chapter 七百二十七 第二刀 / M2307 int8 cosine
//
// Quantized vector retrieval primitives — substrate's first
// quality-drift-gated production path (cosine-drift ≤ 0.01
// instead of byte-equality)。

/// Cosine between two int8-quantized vectors。 Writes the score
/// into *out_score。 Returns 0 on success,-1 on null pointer or
/// length mismatch。
int32_t bas_ranker_cosine_int8(
    const int8_t* a, size_t a_len, float scale_a,
    const int8_t* b, size_t b_len, float scale_b,
    float* out_score);

/// Batched cosine across many int8-quantized corpus rows。 Each
/// row has its own scale (heterogeneous precision)。 Returns 0
/// on success,-1 on null pointer,-2 on shape error。
int32_t bas_ranker_batched_cosine_int8(
    const int8_t* q, size_t q_len, float scale_q,
    const int8_t* corpus, size_t corpus_len,
    const float* corpus_scales, size_t corpus_scales_len,
    size_t dim,
    float* out_scores, size_t out_capacity);

/// Quantize Float32 array to int8 + scale。 Returns 0 on success,
/// -1 on null pointer or out_q_capacity < n。
int32_t bas_ranker_quantize_int8(
    const float* x, size_t n,
    int8_t* out_q, size_t out_q_capacity,
    float* out_scale);

/// Dequantize int8 + scale back to Float32。 Returns 0 on success,
/// -1 on null pointer or out_x_capacity < n。
int32_t bas_ranker_dequantize_int8(
    const int8_t* q, size_t n, float scale,
    float* out_x, size_t out_x_capacity);

/// int8 × int8 matmul producing Float32 output。 A (m×k) × B (k×n)
/// = C (m×n),all row-major。 Returns 0 on success,-1 on null
/// pointer,-2 on shape mismatch (a_len != m*k or b_len != k*n
/// or c_capacity < m*n)。
int32_t bas_ranker_matmul_int8(
    const int8_t* a, size_t a_len, float scale_a,
    const int8_t* b, size_t b_len, float scale_b,
    size_t m, size_t k, size_t n,
    float* out_c, size_t c_capacity);

int64_t bas_event_log_encode_binary(
    uint8_t kind,
    const uint8_t* entry_id, size_t entry_id_len,
    const uint8_t* session_ref, size_t session_ref_len,
    const uint8_t* turn_ref, size_t turn_ref_len,
    int64_t timestamp_ms,
    uint8_t payload_present,
    const uint8_t* payload, size_t payload_len,
    uint8_t provenance_present,
    const uint8_t* provenance, size_t provenance_len,
    uint8_t* out_buf, size_t out_capacity);

#ifdef __cplusplus
}
#endif

#endif /* BAS_RUST_MEMORY_TRACKER_H */
