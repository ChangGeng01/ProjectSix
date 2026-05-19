// SPDX:internal
//
// bas_thermal_probe.c — chapter 七百三 第五刀 / M2175
//
// Read the device's current thermal state via Darwin's
// `processInfo.thermalState`-equivalent kernel sysctl。 Exposed
// to Swift via the BASCSystemBridge module map。
//
// Returns one of:
//   0 = nominal
//   1 = fair
//   2 = serious
//   3 = critical
//  -1 = read failed (unsupported platform or sysctl error)

#include "include/bas_csystem_bridge.h"

#include <stdint.h>
#include <stddef.h>

#if defined(__APPLE__) && (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) \
    || defined(__MAC_OS_X_VERSION_MIN_REQUIRED))

#include <sys/sysctl.h>
#include <string.h>

/// Probe the current Darwin thermal state via sysctl。 On older
/// hardware that lacks the `hw.thermal_state` sysctl key, this
/// function falls back to reading `hw.thermalstate` (legacy
/// spelling)。
int32_t bas_thermal_probe(int32_t *out_state) {
    if (out_state == NULL) {
        return -1;
    }

    int state = -1;
    size_t state_size = sizeof(state);

    if (sysctlbyname("hw.thermal_state",
                     &state, &state_size, NULL, 0) == 0) {
        *out_state = (int32_t)state;
        return 0;
    }

    // Legacy spelling fallback
    if (sysctlbyname("hw.thermalstate",
                     &state, &state_size, NULL, 0) == 0) {
        *out_state = (int32_t)state;
        return 0;
    }

    *out_state = -1;
    return -1;
}

/// Coarse-bucket the thermal state into the BAS doctrine's
/// nominal/fair/serious/critical 4-bucket schema。 Returns the
/// bucket via out_bucket parameter:
///   0 = nominal     (Darwin .nominal)
///   1 = fair        (Darwin .fair)
///   2 = serious     (Darwin .serious)
///   3 = critical    (Darwin .critical)
int32_t bas_thermal_bucket(int32_t *out_bucket) {
    if (out_bucket == NULL) {
        return -1;
    }
    int32_t raw;
    int32_t rc = bas_thermal_probe(&raw);
    if (rc != 0) {
        *out_bucket = -1;
        return rc;
    }
    if (raw < 0)        { *out_bucket = -1; return -1; }
    if (raw == 0)       { *out_bucket = 0;  return 0; }
    if (raw == 1)       { *out_bucket = 1;  return 0; }
    if (raw == 2)       { *out_bucket = 2;  return 0; }
    /* raw >= 3 */        *out_bucket = 3;
    return 0;
}

/// String-ify the bucket for logging。 Returns a static string
/// (do not free)。
const char *bas_thermal_bucket_name(int32_t bucket) {
    switch (bucket) {
    case 0:  return "nominal";
    case 1:  return "fair";
    case 2:  return "serious";
    case 3:  return "critical";
    default: return "unknown";
    }
}

#else

// Non-Apple platforms: thermal probe is not available。
int32_t bas_thermal_probe(int32_t *out_state) {
    if (out_state) { *out_state = -1; }
    return -1;
}

int32_t bas_thermal_bucket(int32_t *out_bucket) {
    if (out_bucket) { *out_bucket = -1; }
    return -1;
}

const char *bas_thermal_bucket_name(int32_t bucket) {
    (void)bucket;
    return "unsupported-platform";
}

#endif
