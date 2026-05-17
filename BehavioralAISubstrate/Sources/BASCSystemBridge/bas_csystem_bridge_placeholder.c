// SPDX:internal
// MARK: - BASCSystemBridge placeholder
// chapter 七百一 / M2167 第一刀 — C pilot SCAFFOLD
//                                  no-op source。
//
// Real `bas_monotonic_nanos(uint64_t *out)` lands at
// chapter 703 / M2175 第一刀。 This scaffold ships a
// minimal no-op function so SPM compiles the .cTarget
// and the multi-language scaffold proves end-to-end at
// chapter 701 / M2167 第一刀。

#include "bas_csystem_bridge.h"

int32_t bas_csystem_bridge_placeholder_version(void) {
    /* Scaffold-version sentinel:0 means "scaffold only,
     * no real C function shipped yet"。 chapter 703
     * 第一刀 will replace this with bas_monotonic_nanos
     * returning the real CLOCK_UPTIME_RAW value。 */
    return 0;
}
