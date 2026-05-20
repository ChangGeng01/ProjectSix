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

/// 持续性 发展 — process CPU time via `getrusage(RUSAGE_SELF)`。
/// Returns user + system CPU time in microseconds via two
/// out-params。 Complements wall-clock latency:wall-clock
/// includes I/O wait + sleep,CPU time only counts cycles
/// the kernel scheduled FOR this process。 Hosts use the
/// ratio to detect "GPU heavy" (low CPU time,high wall
/// clock) vs "CPU bound" calls。
///
/// **Apple platforms only**:Non-Apple fallback returns -3。
///
/// - Parameters:
///   - out_user:non-null pointer to receive user CPU
///     microseconds
///   - out_system:non-null pointer to receive system
///     CPU microseconds
/// - Returns:0 on success,negative on error。
///   - -1 = null out pointer (either)
///   - -2 = `getrusage` call failed
///   - -3 = unsupported platform
///
/// **Thread-safety**:reentrant + lock-free。 getrusage
/// is safe to call from any thread。
int32_t bas_process_cpu_time_micros(
    int64_t *out_user,
    int64_t *out_system);

/// ABI / behavior version pin for
/// `bas_process_cpu_time_micros`。 Currently 1。
int32_t bas_process_cpu_time_micros_version(void);

/// 持续性 发展 — process block I/O counts via
/// `getrusage(RUSAGE_SELF)` ru_inblock / ru_oublock。
/// Hosts use this to detect "is my brain doing
/// unexpectedly heavy disk work" (e.g. SQL pilot WAL
/// flushes,Codable persistence)。 Returns the
/// CUMULATIVE counts since process start;hosts take
/// differences across snapshots for rate dashboards。
///
/// **Apple platforms only**:Non-Apple fallback returns
/// -3 with out-params zeroed。
///
/// - Parameters:
///   - out_in:non-null pointer to receive input block
///     count (reads)
///   - out_out:non-null pointer to receive output block
///     count (writes)
/// - Returns:0 on success,negative on error。
///   - -1 = null out pointer (either)
///   - -2 = `getrusage` syscall failed
///   - -3 = unsupported platform
int32_t bas_process_disk_io_blocks(
    int64_t *out_in,
    int64_t *out_out);

/// ABI / behavior version pin for
/// `bas_process_disk_io_blocks`。 Currently 1。
int32_t bas_process_disk_io_blocks_version(void);

// MARK: - chapter 七百三 第五刀 / M2175 — C widening
//
// New probes added in this chapter:
//   - bas_thermal_probe          : raw Darwin thermal state
//   - bas_thermal_bucket         : 4-bucket coarse classification
//   - bas_thermal_bucket_name    : static string-ify helper
//   - bas_cpu_logical_count      : hw.ncpu
//   - bas_cpu_physical_count     : hw.physicalcpu
//   - bas_cpu_performance_count  : Apple Silicon perflevel0
//   - bas_cpu_efficiency_count   : Apple Silicon perflevel1
//   - bas_cpu_max_frequency_mhz  : peak CPU frequency
//   - bas_cpu_brand              : machdep.cpu.brand_string
//   - bas_memory_total_bytes     : hw.memsize
//   - bas_memory_vm_stats        : 4-counter VM snapshot
//   - bas_memory_pressure_percent: 0-100 pressure estimate

#include <stddef.h>

int32_t bas_thermal_probe(int32_t *out_state);
int32_t bas_thermal_bucket(int32_t *out_bucket);
const char *bas_thermal_bucket_name(int32_t bucket);

int32_t bas_cpu_logical_count(int32_t *out_count);
int32_t bas_cpu_physical_count(int32_t *out_count);
int32_t bas_cpu_performance_count(int32_t *out_count);
int32_t bas_cpu_efficiency_count(int32_t *out_count);
int32_t bas_cpu_max_frequency_mhz(int64_t *out_mhz);
int32_t bas_cpu_brand(char *out_buf, size_t out_buf_size);

int32_t bas_memory_total_bytes(int64_t *out_bytes);
int32_t bas_memory_vm_stats(
    int64_t *out_free,
    int64_t *out_active,
    int64_t *out_inactive,
    int64_t *out_wired,
    int64_t *out_page_size);
int32_t bas_memory_pressure_percent(int32_t *out_pct);

// MARK: - chapter 七百六十一 — L1 partial C system probes
//
// New probes added in this chapter:
//   - bas_wallclock_nanos      : sleep-INCLUSIVE clock via
//                                 mach_absolute_time + timebase
//   - bas_task_phys_footprint  : richer memory probe via
//                                 TASK_VM_INFO (phys_footprint +
//                                 compressed memory)

/// chapter 七百六十一 第一刀 — sleep-INCLUSIVE monotonic clock
/// via `mach_absolute_time()` + Mach timebase scaling。
/// Counterpart to `bas_monotonic_nanos` (CLOCK_UPTIME_RAW
/// which EXCLUDES sleep)。 The L1 thermal scheduler uses BOTH
/// values:turn duration via the sleep-excluded clock,sleep-
/// latency via this sleep-included clock。
///
/// **Apple platforms only**:Non-Apple fallback returns -3。
///
/// - Parameter out:non-null pointer to receive nanoseconds since
///   boot (sleep-included)。
/// - Returns:0 on success,negative on error。
///   - -1 = null `out` pointer
///   - -2 = `mach_timebase_info` initialization failed
///   - -3 = unsupported platform
///
/// **Thread-safety**:reentrant + lock-free。 The timebase
/// cache is racily initialized to the SAME constant value by
/// multiple threads — write-write tear is benign。
int32_t bas_wallclock_nanos(uint64_t *out);

/// ABI / behavior version pin for `bas_wallclock_nanos`。
/// Currently 1。
int32_t bas_wallclock_nanos_version(void);

/// chapter 七百六十一 第二刀 — richer memory probe via
/// `task_info(TASK_VM_INFO)`。 Counterpart to
/// `bas_process_resident_memory_bytes` (which uses the simpler
/// `mach_task_basic_info` and only returns RSS)。 This entry
/// exposes:
///   - phys_footprint   : OS-tracked「memory footprint」 used
///                         by jetsam pressure decisions
///   - compressed       : pages compressed by the VM compressor
///   - internal         : private (anonymous) memory
///
/// All values are in BYTES。 Used by chapter L1 thermal +
/// memory schedulers to detect approaching jetsam thresholds
/// before the kernel kills the process。
///
/// **Apple platforms only**:Non-Apple fallback returns -3。
///
/// - Parameters:
///   - out_phys_footprint :non-null pointer to receive
///     phys_footprint bytes
///   - out_compressed     :non-null pointer to receive
///     compressed bytes
///   - out_internal       :non-null pointer to receive
///     internal (anonymous) bytes
/// - Returns:0 on success,negative on error。
///   - -1 = null out pointer
///   - -2 = `task_info` Mach call failed
///   - -3 = unsupported platform
///
/// **Thread-safety**:reentrant + lock-free。
int32_t bas_task_phys_footprint(
    uint64_t *out_phys_footprint,
    uint64_t *out_compressed,
    uint64_t *out_internal);

/// ABI / behavior version pin for `bas_task_phys_footprint`。
/// Currently 1。
int32_t bas_task_phys_footprint_version(void);

#ifdef __cplusplus
}
#endif

#endif /* BAS_CSYSTEM_BRIDGE_H */
