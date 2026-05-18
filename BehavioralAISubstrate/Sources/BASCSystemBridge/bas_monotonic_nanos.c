// SPDX:internal
// MARK: - bas_monotonic_nanos.c
// chapter 七百三 / M2175 第一刀 — C pilot first real
//                                  function。 Wraps
//                                  `clock_gettime_nsec_np
//                                  (CLOCK_UPTIME_RAW)` on
//                                  Apple platforms (Darwin
//                                  fast-path,no syscall
//                                  on iOS/macOS/watchOS)
//                                  and falls back to
//                                  `mach_absolute_time`
//                                  + Mach timebase scaling
//                                  on older / non-Darwin
//                                  build hosts。
//
// ## Why this exists
//
// MULTI-LANGUAGE AUGMENTATION ARC chapter 七百三 C pilot
// ships the smallest possible REAL C function so the
// `.cTarget` integration mechanism is proved with real
// production code (not just a scaffold no-op)。 Picking
// monotonic-time as the proof-of-concept:
//
//   1. Smallest possible payload (one stdlib call,no
//      state)。
//   2. Apple's `clock_gettime_nsec_np(CLOCK_UPTIME_RAW)`
//      is a USERSPACE fast-path that the Swift stdlib's
//      `DispatchTime.now()` doesn't quite match — the
//      raw nsec value is useful for cross-language
//      stamping where Swift's typed wrappers add overhead。
//   3. Easy to compare against Swift V1
//      (`DispatchTime.now().uptimeNanoseconds`)for a
//      dual-mode equivalence test。
//
// ## ADR-014 OPT-IN preserved
//
// This C function is NOT called automatically anywhere
// in the substrate。 The Swift wrapper
// `BASMonotonicNanos.swift` (M2176 第二刀) exposes it via
// an opt-in actor gated by
// `BASLanguageAugmentationFeatureFlags.cBridgeEnabled`
// (default false → V1 `DispatchTime` path)。 V1
// byte-equality preserved by construction。
//
// ## Platform matrix
//
//   - iOS / macOS / tvOS / watchOS / visionOS:Darwin
//     CLOCK_UPTIME_RAW path via clock_gettime_nsec_np。
//   - Linux / non-Apple:fallback CLOCK_MONOTONIC path
//     via clock_gettime — substrate ships Apple-only so
//     this branch is documentation,never compiled in
//     production builds。

#include "bas_csystem_bridge.h"

#if __APPLE__
#include <time.h>
#else
#include <time.h>
#endif

int32_t bas_monotonic_nanos(uint64_t *out) {
    if (out == 0) {
        // Defensive null check — callers must supply a
        // valid pointer。 Returning -1 is a sentinel for
        // the Swift wrapper to translate into a typed
        // error case。
        return -1;
    }
#if __APPLE__
    // CLOCK_UPTIME_RAW measures absolute time since boot
    // EXCLUDING sleep intervals (XNU kernel semantics)。
    // _nsec_np variant returns uint64_t nanoseconds
    // directly,no timespec marshalling needed — this is
    // the userspace fast path on Apple platforms。
    *out = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    return 0;
#else
    // Linux / non-Apple fallback。 Used only for cross-
    // compile inspection;substrate never ships on these
    // platforms in production builds。
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        return -2;
    }
    *out = (uint64_t)ts.tv_sec * (uint64_t)1000000000
         + (uint64_t)ts.tv_nsec;
    return 0;
#endif
}

// Pin a version sentinel so the Swift wrapper can detect
// at runtime whether it linked against the M2175 real
// function or an older / mismatched scaffold。 Future bumps
// here REQUIRE updating
// `BASMonotonicNanosTests.testCFunctionVersionPin`。
int32_t bas_monotonic_nanos_version(void) {
    return 1;
}

#if __APPLE__
#include <mach/mach.h>
#include <mach/task.h>
#include <mach/task_info.h>
#include <mach/mach_init.h>
#endif

// MARK: - bas_process_resident_memory_bytes
// 主线 全面 提升 — C pilot second function。 Wraps
// mach_task_basic_info to expose the calling process's
// resident memory size (RSS) for cascade telemetry。
// Useful for brain hosts running long-lived sessions
// (leak detection,memory pressure monitoring)。
int32_t bas_process_resident_memory_bytes(uint64_t *out) {
    if (out == 0) {
        return -1;
    }
#if __APPLE__
    mach_task_basic_info_data_t info;
    mach_msg_type_number_t count =
        MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kr = task_info(
        mach_task_self(),
        MACH_TASK_BASIC_INFO,
        (task_info_t)&info,
        &count);
    if (kr != KERN_SUCCESS) {
        return -2;
    }
    *out = (uint64_t)info.resident_size;
    return 0;
#else
    // Non-Apple build hosts: substrate ships
    // Apple-only,this branch is documentation only。
    (void)out;
    return -3;
#endif
}

int32_t bas_process_resident_memory_bytes_version(void) {
    return 1;
}

#if __APPLE__
#include <sys/sysctl.h>
#endif

// MARK: - bas_thread_count
// 主线 解构 重构 — wraps task_threads to return the
// active Mach thread count for the calling process。
int32_t bas_thread_count(int32_t *out) {
    if (out == 0) {
        return -1;
    }
#if __APPLE__
    thread_act_array_t threads = 0;
    mach_msg_type_number_t count = 0;
    kern_return_t kr = task_threads(
        mach_task_self(), &threads, &count);
    if (kr != KERN_SUCCESS) {
        *out = 0;
        return -2;
    }
    *out = (int32_t)count;
    // Release the thread-port handles + the array
    // allocation — task_threads transfers ownership to
    // caller per Apple's documentation。
    for (mach_msg_type_number_t i = 0; i < count; i++) {
        mach_port_deallocate(
            mach_task_self(), threads[i]);
    }
    vm_deallocate(
        mach_task_self(),
        (vm_address_t)threads,
        count * sizeof(thread_act_t));
    return 0;
#else
    *out = 0;
    return -3;
#endif
}

int32_t bas_thread_count_version(void) {
    return 1;
}

// MARK: - bas_cpu_count_logical
// 主线 解构 重构 — wraps sysctl(CTL_HW, HW_NCPU) to
// return the host's logical CPU count。
int32_t bas_cpu_count_logical(int32_t *out) {
    if (out == 0) {
        return -1;
    }
#if __APPLE__
    int mib[2] = { CTL_HW, HW_NCPU };
    int value = 0;
    size_t size = sizeof(value);
    if (sysctl(mib, 2, &value, &size, 0, 0) != 0) {
        *out = 0;
        return -2;
    }
    *out = (int32_t)value;
    return 0;
#else
    *out = 0;
    return -3;
#endif
}

int32_t bas_cpu_count_logical_version(void) {
    return 1;
}

#if __APPLE__
#include <sys/time.h>
#endif

// MARK: - bas_system_uptime_seconds
// 主线 解构 重构 Round 3 — host uptime via
// sysctl(KERN_BOOTTIME) + gettimeofday delta。
int32_t bas_system_uptime_seconds(int64_t *out) {
    if (out == 0) {
        return -1;
    }
#if __APPLE__
    struct timeval boottime;
    int mib[2] = { CTL_KERN, KERN_BOOTTIME };
    size_t size = sizeof(boottime);
    if (sysctl(mib, 2, &boottime, &size, 0, 0) != 0) {
        *out = 0;
        return -2;
    }
    struct timeval now;
    if (gettimeofday(&now, 0) != 0) {
        *out = 0;
        return -2;
    }
    *out = (int64_t)(now.tv_sec - boottime.tv_sec);
    return 0;
#else
    *out = 0;
    return -3;
#endif
}

int32_t bas_system_uptime_seconds_version(void) {
    return 1;
}

// MARK: - bas_physical_memory_bytes
// 主线 解构 重构 Round 3 — total physical RAM via
// sysctl(HW_MEMSIZE)。 64-bit value on Apple silicon
// (the legacy HW_PHYSMEM is 32-bit and tops at 4 GB —
// HW_MEMSIZE is the modern replacement)。
int32_t bas_physical_memory_bytes(uint64_t *out) {
    if (out == 0) {
        return -1;
    }
#if __APPLE__
    int mib[2] = { CTL_HW, HW_MEMSIZE };
    uint64_t value = 0;
    size_t size = sizeof(value);
    if (sysctl(mib, 2, &value, &size, 0, 0) != 0) {
        *out = 0;
        return -2;
    }
    *out = value;
    return 0;
#else
    *out = 0;
    return -3;
#endif
}

int32_t bas_physical_memory_bytes_version(void) {
    return 1;
}
