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

#ifdef __cplusplus
}
#endif

#endif /* BAS_RUST_MEMORY_TRACKER_H */
