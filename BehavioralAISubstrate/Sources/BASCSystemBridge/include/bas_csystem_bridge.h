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

/// 主线 解构 重构 — read the count of active Mach
/// threads in the calling process。 Wraps `task_threads`
/// + `mach_port_deallocate` cleanup on Apple platforms。
/// Useful for cascade telemetry / runaway-task detection
/// in long-running brain hosts。
///
/// **Apple platforms only**:substrate ships
/// Apple-only in production。 Non-Apple fallback returns
/// -3 (unsupported)。
///
/// - Parameter out:non-null pointer to receive the
///   thread count。 Set to 0 on non-zero return。
/// - Returns:0 on success,negative on error。
///   - -1 = null `out` pointer
///   - -2 = `task_threads` Mach call failed
///   - -3 = unsupported platform (non-Apple build host)
///
/// **Thread-safety**:reentrant + lock-free。 task_threads
/// is a process-wide query callable from any thread。
int32_t bas_thread_count(int32_t *out);

/// ABI / behavior version pin for `bas_thread_count`。
/// Currently 1。
int32_t bas_thread_count_version(void);

/// 主线 解构 重构 — read the logical-CPU count of the
/// host via `sysctl(CTL_HW, HW_NCPU)`。 Equivalent to the
/// number of hardware threads visible to the kernel
/// scheduler (perf + efficiency cores combined on Apple
/// silicon)。 Useful for cascade telemetry / runtime
/// concurrency budgeting。
///
/// **Apple platforms only**:substrate ships
/// Apple-only in production。 Non-Apple fallback returns
/// -3 (unsupported)。
///
/// - Parameter out:non-null pointer to receive the CPU
///   count。 Set to 0 on non-zero return。
/// - Returns:0 on success,negative on error。
///   - -1 = null `out` pointer
///   - -2 = `sysctl` call failed
///   - -3 = unsupported platform (non-Apple build host)
///
/// **Thread-safety**:reentrant + lock-free。
int32_t bas_cpu_count_logical(int32_t *out);

/// ABI / behavior version pin for `bas_cpu_count_logical`。
/// Currently 1。
int32_t bas_cpu_count_logical_version(void);

/// 主线 解构 重构 Round 3 — read host uptime in seconds
/// since boot via `sysctl(CTL_KERN, KERN_BOOTTIME)`。
/// Computed by subtracting boot time from the current
/// wall-clock。 Useful for cascade telemetry / cross-
/// process correlation in long-running brain hosts。
///
/// **Apple platforms only**:Non-Apple fallback returns -3。
///
/// - Parameter out:non-null pointer to receive the
///   uptime in seconds。
/// - Returns:0 on success,negative on error。
///   - -1 = null `out` pointer
///   - -2 = `sysctl` call failed OR `gettimeofday` failed
///   - -3 = unsupported platform
int32_t bas_system_uptime_seconds(int64_t *out);

/// ABI / behavior version pin for
/// `bas_system_uptime_seconds`。 Currently 1。
int32_t bas_system_uptime_seconds_version(void);

/// 主线 解构 重构 Round 3 — read total physical RAM
/// in bytes via `sysctl(CTL_HW, HW_MEMSIZE)`。
/// Counterpart to `bas_process_resident_memory_bytes`:
/// RSS tells you how much YOU use,physical memory tells
/// you the total available。 Hosts use the ratio for
/// memory-pressure dashboards。
///
/// **Apple platforms only**:Non-Apple fallback returns -3。
///
/// - Parameter out:non-null pointer to receive bytes。
/// - Returns:0 on success,negative on error。
///   - -1 = null `out` pointer
///   - -2 = `sysctl` call failed
///   - -3 = unsupported platform
int32_t bas_physical_memory_bytes(uint64_t *out);

/// ABI / behavior version pin for
/// `bas_physical_memory_bytes`。 Currently 1。
int32_t bas_physical_memory_bytes_version(void);

#ifdef __cplusplus
}
#endif

#endif /* BAS_CSYSTEM_BRIDGE_H */
