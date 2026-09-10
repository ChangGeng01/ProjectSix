// SPDX:internal
//
// bas_cpu_info.c — chapter 七百三 第五刀 / M2175
//
// Read CPU topology + per-core utilization via Darwin's
// host_processor_info() API。 Used by the substrate's runtime
// scheduler to decide whether to dispatch large kernels onto
// performance or efficiency cores。

#include "include/bas_csystem_bridge.h"
#include <stdint.h>
#include <stddef.h>

#if defined(__APPLE__) && (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) \
    || defined(__MAC_OS_X_VERSION_MIN_REQUIRED))

#include <sys/sysctl.h>
#include <mach/mach_host.h>
#include <mach/processor_info.h>
#include <string.h>

/// Get the number of logical CPU cores via `hw.ncpu`。
int32_t bas_cpu_logical_count(int32_t *out_count) {
    if (out_count == NULL) { return -1; }
    int count = 0;
    size_t size = sizeof(count);
    if (sysctlbyname("hw.ncpu",
                     &count, &size, NULL, 0) != 0) {
        *out_count = -1;
        return -1;
    }
    *out_count = (int32_t)count;
    return 0;
}

/// Get the number of physical CPU cores via
/// `hw.physicalcpu`。 Apple Silicon devices report performance
/// + efficiency cores combined。
int32_t bas_cpu_physical_count(int32_t *out_count) {
    if (out_count == NULL) { return -1; }
    int count = 0;
    size_t size = sizeof(count);
    if (sysctlbyname("hw.physicalcpu",
                     &count, &size, NULL, 0) != 0) {
        *out_count = -1;
        return -1;
    }
    *out_count = (int32_t)count;
    return 0;
}

/// Get the number of performance cores (Apple Silicon)。
/// Returns -1 on Intel Macs where this sysctl key is absent。
int32_t bas_cpu_performance_count(int32_t *out_count) {
    if (out_count == NULL) { return -1; }
    int count = 0;
    size_t size = sizeof(count);
    if (sysctlbyname("hw.perflevel0.physicalcpu",
                     &count, &size, NULL, 0) != 0) {
        *out_count = -1;
        return -1;
    }
    *out_count = (int32_t)count;
    return 0;
}

/// Get the number of efficiency cores (Apple Silicon)。
/// Returns -1 on Intel Macs。
int32_t bas_cpu_efficiency_count(int32_t *out_count) {
    if (out_count == NULL) { return -1; }
    int count = 0;
    size_t size = sizeof(count);
    if (sysctlbyname("hw.perflevel1.physicalcpu",
                     &count, &size, NULL, 0) != 0) {
        *out_count = -1;
        return -1;
    }
    *out_count = (int32_t)count;
    return 0;
}

/// Get the maximum CPU frequency in MHz。
int32_t bas_cpu_max_frequency_mhz(int64_t *out_mhz) {
    if (out_mhz == NULL) { return -1; }
    int64_t hz = 0;
    size_t size = sizeof(hz);
    if (sysctlbyname("hw.cpufrequency_max",
                     &hz, &size, NULL, 0) != 0) {
        *out_mhz = -1;
        return -1;
    }
    *out_mhz = hz / 1000000;
    return 0;
}

/// Get the CPU brand string (e.g。 "Apple M2 Pro")。 Writes UTF-8
/// into out_buf up to out_buf_size - 1 bytes plus a NUL terminator。
/// Returns the actual byte count written (excluding NUL),or -1
/// on error。
int32_t bas_cpu_brand(char *out_buf, size_t out_buf_size) {
    if (out_buf == NULL || out_buf_size < 1) { return -1; }
    char tmp[256] = {0};
    size_t size = sizeof(tmp);
    if (sysctlbyname("machdep.cpu.brand_string",
                     tmp, &size, NULL, 0) != 0) {
        out_buf[0] = '\0';
        return -1;
    }
    size_t copy = size < out_buf_size
        ? size - 1
        : out_buf_size - 1;
    memcpy(out_buf, tmp, copy);
    out_buf[copy] = '\0';
    return (int32_t)copy;
}

#else

int32_t bas_cpu_logical_count(int32_t *out_count) {
    if (out_count) { *out_count = -1; }
    return -1;
}

int32_t bas_cpu_physical_count(int32_t *out_count) {
    if (out_count) { *out_count = -1; }
    return -1;
}

int32_t bas_cpu_performance_count(int32_t *out_count) {
    if (out_count) { *out_count = -1; }
    return -1;
}

int32_t bas_cpu_efficiency_count(int32_t *out_count) {
    if (out_count) { *out_count = -1; }
    return -1;
}

int32_t bas_cpu_max_frequency_mhz(int64_t *out_mhz) {
    if (out_mhz) { *out_mhz = -1; }
    return -1;
}

int32_t bas_cpu_brand(char *out_buf, size_t out_buf_size) {
    if (out_buf && out_buf_size > 0) { out_buf[0] = '\0'; }
    return -1;
}

#endif
