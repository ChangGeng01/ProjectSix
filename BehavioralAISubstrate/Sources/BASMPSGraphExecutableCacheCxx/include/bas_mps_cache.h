// SPDX:internal
// MARK: - BASMPSGraphExecutableCacheCxx
// chapter 七百一 / M2167 第一刀 — C++ pilot target
//                                  SCAFFOLD placeholder (orig)
// chapter 七百五 / M2183 第一刀 — first real functions
//                                  added (bas_mps_cache_insert
//                                  / lookup / size / clear /
//                                  free_value / version)。
// chapter 七百九 / M2197 第一刀 — placeholder declaration
//                                  removed (zero callers
//                                  in the substrate;the
//                                  "backward source compat"
//                                  comment never had a
//                                  real caller to protect)。

#ifndef BAS_MPS_CACHE_H
#define BAS_MPS_CACHE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Insert (or overwrite) `key` → `value`。
///
/// - Parameters:`key` + `value` are NUL-terminated UTF-8
///   C strings,owned by the caller。 Cache copies into
///   internal `std::string` storage so the caller can
///   free the inputs immediately。
/// - Returns:0 on success,-1 if either pointer is null,
///   -2 on internal allocation failure。
int32_t bas_mps_cache_insert(const char* key,
                              const char* value);

/// Look up `key`。 If present,allocates a heap copy of
/// the value into `*out_value` and returns 1。 Caller MUST
/// call `bas_mps_cache_free_value(*out_value)` to release。
///
/// - Returns:
///   - 1  = found,*out_value filled
///   - 0  = not found,*out_value left untouched
///   - -1 = null `key` OR null `out_value` pointer
///   - -2 = internal exception (allocation failure)
int32_t bas_mps_cache_lookup(const char* key,
                              char** out_value);

/// Release a value buffer returned by
/// `bas_mps_cache_lookup`。 Null pointer is a no-op。
void bas_mps_cache_free_value(char* value);

/// Current cache size (number of entries)。 Returns -1
/// on internal exception (extremely rare;cache
/// implementation only throws on memory allocation
/// failure during size())。
int64_t bas_mps_cache_size(void);

/// Empty the cache。 Returns 0 on success,-2 on internal
/// exception。
int32_t bas_mps_cache_clear(void);

/// ABI / behavior version pin。 Currently 1。 Bumping
/// requires updating `BASMPSGraphExecutableCacheCxxBridge
/// Tests.testCxxBridgeABIVersion` simultaneously so a
/// future Swift-side caller cannot silently observe a
/// behavior change。
int32_t bas_mps_cache_version(void);

/// 主线 解构 重构 — sum the byte sizes of every stored
/// key + value under a single mutex acquisition,returning
/// an estimated memory footprint of the cache contents。
///
/// Doing this from Swift would require iterating keys (no
/// such API today) AND doing N+1 lock acquisitions (one per
/// lookup)。 Pushing the iteration into C++ keeps it under
/// one lock and inside the language that owns the container
/// — exact 术业有专攻 example。
///
/// Returns the sum of `key.size() + value.size()` across
/// the cache。 Excludes std::string per-instance overhead
/// (typically 24-32 bytes per entry on libc++ small-string-
/// optimization),excludes std::unordered_map node + bucket
/// overhead。 Hosts wanting a tighter estimate can add a
/// per-entry constant on top of this number。
///
/// - Returns:
///   - >= 0: estimated content bytes
///   - -1:   internal exception (extremely rare;only on
///           allocation failure during iteration)
int64_t bas_mps_cache_byte_size_estimate(void);

/// ABI / behavior version pin for
/// `bas_mps_cache_byte_size_estimate`。 Currently 1。
int32_t bas_mps_cache_byte_size_estimate_version(void);

#ifdef __cplusplus
}
#endif

#endif /* BAS_MPS_CACHE_H */
