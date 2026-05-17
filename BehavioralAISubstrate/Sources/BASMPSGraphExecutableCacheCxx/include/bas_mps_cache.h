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

#ifdef __cplusplus
}
#endif

#endif /* BAS_MPS_CACHE_H */
