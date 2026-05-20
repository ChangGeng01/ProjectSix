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
