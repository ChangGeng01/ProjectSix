// SPDX:internal
// MARK: - BASCSystemBridge
// chapter 七百一 / M2167 第一刀 — C pilot target SCAFFOLD
//                                  placeholder header (orig)
// chapter 七百三 / M2175 第一刀 — first real C functions
//                                  added (bas_monotonic_nanos
//                                  + bas_monotonic_nanos
//                                  _version)。
// chapter 七百九 / M2197 第一刀 — placeholder declaration
//                                  removed (zero callers
//                                  in the substrate;the
//                                  "backward source compat"
//                                  comment never had a
//                                  real caller to protect)。

#ifndef BAS_CSYSTEM_BRIDGE_H
#define BAS_CSYSTEM_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

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

/// Read the calling process's resident memory size
/// (RSS) in bytes into `*out`。 Wraps
/// `mach_task_basic_info` on Apple platforms (XNU
/// task-port query,no syscall in the userspace fast
/// path)。 Useful for cascade telemetry / leak
/// detection in long-running brain hosts。
///
/// **Apple platforms only**: substrate ships
/// Apple-only in production。 Non-Apple fallback
/// returns -3 (unsupported platform) — substrate's
/// production deployment never hits this branch but
/// the contract is documented for cross-compile
/// inspection。
///
/// - Parameter out:non-null pointer to receive the
///   resident-memory byte count。
/// - Returns:0 on success,negative on error。
///   - -1 = null `out` pointer
///   - -2 = `task_info` Mach call failed
///   - -3 = unsupported platform (non-Apple build host)
///
/// **Thread-safety**:reentrant + lock-free。 The
/// Mach task port is a process-wide handle that
/// task_info() may safely query from any thread。
int32_t bas_process_resident_memory_bytes(uint64_t *out);

/// ABI / behavior version pin for
/// `bas_process_resident_memory_bytes`。 Currently 1。
int32_t bas_process_resident_memory_bytes_version(void);

#ifdef __cplusplus
}
#endif

#endif /* BAS_CSYSTEM_BRIDGE_H */
