// SPDX:internal
//
// bas_memory_pressure.c — chapter 七百三 第五刀 / M2175
//
// Read Darwin memory pressure + virtual memory statistics via
// host_statistics64() and sysctl。 Used by the substrate's
// runtime scheduler to gate memory-hungry inferences when the
// device is under pressure。

#include "include/bas_csystem_bridge.h"
#include <stdint.h>
#include <stddef.h>
#include <string.h>

#if defined(__APPLE__) && (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) \
    || defined(__MAC_OS_X_VERSION_MIN_REQUIRED))

#include <mach/mach_host.h>
#include <mach/host_info.h>
#include <mach/vm_statistics.h>
#include <mach/mach_init.h>
#include <sys/sysctl.h>

/// Get the total physical memory in bytes via `hw.memsize`。
int32_t bas_memory_total_bytes(int64_t *out_bytes) {
    if (out_bytes == NULL) { return -1; }
    int64_t mem = 0;
    size_t size = sizeof(mem);
    if (sysctlbyname("hw.memsize",
                     &mem, &size, NULL, 0) != 0) {
        *out_bytes = -1;
        return -1;
    }
    *out_bytes = mem;
    return 0;
}

/// Read VM statistics — free / active / inactive / wired pages
/// + the system-wide page size。 Returns 0 on success;the four
/// counters are written via out parameters。
int32_t bas_memory_vm_stats(
    int64_t *out_free,
    int64_t *out_active,
    int64_t *out_inactive,
    int64_t *out_wired,
    int64_t *out_page_size
) {
    if (out_free == NULL || out_active == NULL
        || out_inactive == NULL || out_wired == NULL
        || out_page_size == NULL) {
        return -1;
    }
    vm_size_t page_size = 0;
    if (host_page_size(mach_host_self(), &page_size)
        != KERN_SUCCESS) {
        return -1;
    }
    vm_statistics64_data_t vm_stats;
    mach_msg_type_number_t count =
        HOST_VM_INFO64_COUNT;
    if (host_statistics64(
            mach_host_self(),
            HOST_VM_INFO64,
            (host_info64_t)&vm_stats,
            &count) != KERN_SUCCESS) {
        return -1;
    }
    *out_free      = (int64_t)vm_stats.free_count;
    *out_active    = (int64_t)vm_stats.active_count;
    *out_inactive  = (int64_t)vm_stats.inactive_count;
    *out_wired     = (int64_t)vm_stats.wire_count;
    *out_page_size = (int64_t)page_size;
    return 0;
}

/// Estimate memory pressure as a 0-100 percent。 Pressure is
/// approximated as 100 * (1 - free_pages / total_pages)。
int32_t bas_memory_pressure_percent(int32_t *out_pct) {
    if (out_pct == NULL) { return -1; }
    int64_t free_p = 0, active = 0, inactive = 0, wired = 0;
    int64_t page_size = 0;
    if (bas_memory_vm_stats(
            &free_p, &active, &inactive, &wired,
            &page_size) != 0) {
        *out_pct = -1;
        return -1;
    }
    int64_t total_pages = free_p + active + inactive + wired;
    if (total_pages <= 0) {
        *out_pct = -1;
        return -1;
    }
    int64_t used_pages = total_pages - free_p;
    *out_pct = (int32_t)((used_pages * 100) / total_pages);
    return 0;
}

#else

int32_t bas_memory_total_bytes(int64_t *out_bytes) {
    if (out_bytes) { *out_bytes = -1; }
    return -1;
}

int32_t bas_memory_vm_stats(
    int64_t *out_free, int64_t *out_active,
    int64_t *out_inactive, int64_t *out_wired,
    int64_t *out_page_size
) {
    if (out_free)      { *out_free      = -1; }
    if (out_active)    { *out_active    = -1; }
    if (out_inactive)  { *out_inactive  = -1; }
    if (out_wired)     { *out_wired     = -1; }
    if (out_page_size) { *out_page_size = -1; }
    return -1;
}

int32_t bas_memory_pressure_percent(int32_t *out_pct) {
    if (out_pct) { *out_pct = -1; }
    return -1;
}

#endif

// MARK: - bas_task_phys_footprint (chapter 七百六十一 第二刀 / M2457)
//
// Richer per-process memory probe via `task_info(TASK_VM_INFO)`。
// Counterpart to `bas_process_resident_memory_bytes` (which uses
// the simpler `mach_task_basic_info` and only returns RSS)。
//
// Why three values
// ----------------
//
// - phys_footprint:the OS's official「memory footprint」 number
//                   used by jetsam pressure decisions。 Different
//                   from RSS in that it counts compressed memory
//                   AND excludes shared-clean pages。 Hosts use
//                   this to detect approaching jetsam thresholds
//                   BEFORE the kernel decides to kill the process。
// - compressed    :bytes of memory the VM compressor has compressed
//                   (effectively swap on iOS,which doesn't have
//                   traditional swap files)。 Growth here is a
//                   leading indicator of pressure。
// - internal      :private anonymous memory (heap allocations,
//                   stack pages)。 Useful for leak detection in
//                   long-running brain hosts。
//
// All values in BYTES。 Thread-safe + lock-free per Mach
// documentation。
//
// Uses `#if __APPLE__` (matching bas_monotonic_nanos.c) rather
// than the narrower `__IPHONE_OS_VERSION_MIN_REQUIRED ||
// __MAC_OS_X_VERSION_MIN_REQUIRED` guard used by the older
// memory_pressure functions in this file — `__APPLE__` is the
// correct portability gate for Mach APIs。

#if __APPLE__

#include <mach/task_info.h>
#include <mach/mach.h>
#include <mach/mach_init.h>

int32_t bas_task_phys_footprint(
    uint64_t *out_phys_footprint,
    uint64_t *out_compressed,
    uint64_t *out_internal
) {
    if (out_phys_footprint == NULL
        || out_compressed == NULL
        || out_internal == NULL) {
        return -1;
    }
    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t kr = task_info(
        mach_task_self(),
        TASK_VM_INFO,
        (task_info_t)&info,
        &count);
    if (kr != KERN_SUCCESS) {
        *out_phys_footprint = 0;
        *out_compressed = 0;
        *out_internal = 0;
        return -2;
    }
    *out_phys_footprint = (uint64_t)info.phys_footprint;
    *out_compressed     = (uint64_t)info.compressed;
    *out_internal       = (uint64_t)info.internal;
    return 0;
}

#else

int32_t bas_task_phys_footprint(
    uint64_t *out_phys_footprint,
    uint64_t *out_compressed,
    uint64_t *out_internal
) {
    if (out_phys_footprint) { *out_phys_footprint = 0; }
    if (out_compressed)     { *out_compressed     = 0; }
    if (out_internal)       { *out_internal       = 0; }
    return -3;
}

#endif

int32_t bas_task_phys_footprint_version(void) {
    return 1;
}

// MARK: - iOS 27 P6 (IOS27_PERF_ADOPTION_PLAN) — App Swap statistics
//
// vm_statistics64 rev4-rev6 fields (iPhoneOS27.0.sdk
// mach/vm_statistics.h:218 swap_count "pages currently populated in
// the swapfile"; :254 donated_count "anonymous pages queued for
// self-donation (App Swap)"). Direct evidence of the OS's
// memory-pressure RESPONSE that the naive free-page ratio cannot
// see — feeds the jetsam-endurance signal lane.
//
// COMPILE GUARD: the fields exist only in the 27-era SDK headers;
// the SPM package builds under the stable toolchain → fallback
// returns -3 (unsupported) there. RUNTIME GUARD: HOST_VM_INFO64_COUNT
// compiled against the 27 SDK covers rev6, but an older KERNEL
// returns a shorter count — out fields are preflighted and the
// returned count is checked against the offsets actually read, so
// stale stack bytes can never masquerade as data (probe honesty:
// -2, never 0-as-unknown).

#if defined(__APPLE__) && (defined(__IPHONE_27_0) || defined(__MAC_27_0))

int32_t bas_vm_swap_stats(
    uint64_t *out_swap_pages,
    uint64_t *out_donated_pages
) {
    if (out_swap_pages == NULL || out_donated_pages == NULL) {
        return -1;
    }
    vm_statistics64_data_t vm_stats;
    memset(&vm_stats, 0, sizeof(vm_stats));
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (host_statistics64(
            mach_host_self(),
            HOST_VM_INFO64,
            (host_info64_t)&vm_stats,
            &count) != KERN_SUCCESS) {
        return -1;
    }
    // Integers actually returned must cover the LAST field we read
    // (donated_count). offsetof+size in mach integer_t units.
    const mach_msg_type_number_t needed =
        (mach_msg_type_number_t)((offsetof(vm_statistics64_data_t,
                                           donated_count)
                                  + sizeof(uint64_t))
                                 / sizeof(integer_t));
    if (count < needed) {
        return -2;  // pre-rev4/5 kernel — fields not provided
    }
    *out_swap_pages    = (uint64_t)vm_stats.swap_count;
    *out_donated_pages = (uint64_t)vm_stats.donated_count;
    return 0;
}

#else

int32_t bas_vm_swap_stats(
    uint64_t *out_swap_pages,
    uint64_t *out_donated_pages
) {
    if (out_swap_pages)    { *out_swap_pages = 0; }
    if (out_donated_pages) { *out_donated_pages = 0; }
    return -3;  // SDK too old at compile time
}

#endif

int32_t bas_vm_swap_stats_version(void) {
    return 1;
}
