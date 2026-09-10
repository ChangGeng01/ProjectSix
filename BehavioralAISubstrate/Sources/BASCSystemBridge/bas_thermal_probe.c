// SPDX:internal
//
// bas_thermal_probe.c — chapter 七百三 第五刀 / M2175
//
// audit M-e #4 (comment-lie fix) — the original comment claimed this reads
// "Darwin's processInfo.thermalState-equivalent kernel sysctl". THAT SYSCTL
// DOES NOT EXIST。 Apple platforms expose thermal state ONLY through the
// userspace `ProcessInfo.thermalState` API (NSProcessInfoThermalState) —
// there is no `hw.thermal_state` / `hw.thermalstate` (or any) sysctl OID for
// it (empirically confirmed;the old fake sysctl dance ALWAYS returned -1)。
//
// This function is therefore a DELIBERATE unsupported stub that ALWAYS
// returns -1 on Apple platforms。 It has NO production caller: the real
// thermal source is `BASSystemProbe`, which reads `ProcessInfo.thermalState`
// directly。 It is kept (not deleted) as a bridge placeholder;full removal
// (git-mv to Experiments/) is an operator call per the deletion-aversion
// rule。 Callers MUST route thermal decisions through ProcessInfo and NEVER
// map the -1 return to `.nominal` (that would be fail-open on a hot device)。
//
// Returns one of:
//   0..3 = nominal/fair/serious/critical — NEVER produced on Apple (no sysctl)
//  -1    = unsupported / read failed (the only value on Apple platforms)

#include "include/bas_csystem_bridge.h"

#include <stdint.h>
#include <stddef.h>

#if defined(__APPLE__) && (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) \
    || defined(__MAC_OS_X_VERSION_MIN_REQUIRED))

#include <sys/sysctl.h>
#include <string.h>

/// audit M-e #4 — HONEST unsupported stub。 There is no thermal-state sysctl
/// on Apple platforms (the removed `hw.thermal_state` / `hw.thermalstate`
/// probes are unknown OIDs that always fail);thermal state lives only in
/// `ProcessInfo.thermalState`。 This ALWAYS returns -1 — it does NOT pretend
/// to succeed。 The fake sysctl dance was removed so the code no longer
/// implies a capability it never had (comment-vs-code honesty)。
int32_t bas_thermal_probe(int32_t *out_state) {
    if (out_state == NULL) {
        return -1;
    }
    // No thermal sysctl exists on Darwin — fail closed, honestly + always。
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
