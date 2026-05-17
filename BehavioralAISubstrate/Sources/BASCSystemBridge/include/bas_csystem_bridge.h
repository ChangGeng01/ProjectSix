// SPDX:internal
// MARK: - BASCSystemBridge
// chapter 七百一 / M2167 第一刀 — C pilot target SCAFFOLD
//                                  placeholder header (orig)
// chapter 七百三 / M2175 第一刀 — first real C functions
//                                  added (bas_monotonic_nanos
//                                  + bas_monotonic_nanos
//                                  _version)。

#ifndef BAS_CSYSTEM_BRIDGE_H
#define BAS_CSYSTEM_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Scaffold-version sentinel from M2167。 Returns 0 always。
/// Kept for backward source compatibility so a future
/// caller pinned on it does not silently break。 New
/// callers should use `bas_monotonic_nanos_version()` instead。
int32_t bas_csystem_bridge_placeholder_version(void);

/// Read a monotonic-clock nanosecond timestamp from the
/// host OS into `*out`。
///
/// On Apple platforms this calls `clock_gettime_nsec_np
/// (CLOCK_UPTIME_RAW)` which is the userspace fast path
/// (no syscall on iOS/macOS/watchOS/tvOS/visionOS)。 The
/// returned value measures absolute time since boot
/// EXCLUDING sleep intervals (XNU semantics)。
///
/// On non-Apple build hosts (Linux),falls back to
/// `clock_gettime(CLOCK_MONOTONIC, &ts)` + manual nsec
/// math。 Substrate never ships on these platforms in
/// production builds — the fallback exists for
/// cross-compile inspection only。
///
/// - Parameter out:non-null pointer to receive the
///   nanosecond timestamp。
/// - Returns:0 on success,negative on error。
///   - -1 = null `out` pointer
///   - -2 = `clock_gettime` syscall failed (non-Apple
///          fallback path only)
///
/// **Thread-safety**:reentrant + lock-free。 Safe to
/// call from any thread + any async context。 The
/// Swift wrapper at `BASMonotonicNanos.swift` adds
/// actor isolation for opt-in callers。
int32_t bas_monotonic_nanos(uint64_t *out);

/// ABI / behavior version pin。 Currently 1。 Bumping
/// requires updating `BASMonotonicNanosTests
/// .testCFunctionVersionPin` simultaneously so a
/// future Swift-side caller cannot silently observe
/// a behavior change。
int32_t bas_monotonic_nanos_version(void);

#ifdef __cplusplus
}
#endif

#endif /* BAS_CSYSTEM_BRIDGE_H */
