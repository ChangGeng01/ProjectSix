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
