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
