// SPDX:internal
// MARK: - BASMPSGraphExecutableCacheCxx placeholder
// chapter 七百一 / M2167 第一刀 — C++ pilot SCAFFOLD
//                                  no-op source。
//
// Real `bas_mps_cache_lookup` / `bas_mps_cache_insert`
// land at chapter 705 / M2183 第一刀。 This scaffold
// ships a minimal no-op function so SPM compiles the
// .cxxTarget and the multi-language scaffold proves
// end-to-end at chapter 701 / M2167 第一刀。

#include "bas_mps_cache.h"

extern "C" int32_t bas_mps_cache_placeholder_version(void) {
    // Scaffold-version sentinel:0 means "scaffold only,
    // no real C++ wrapper shipped yet"。 chapter 705 第一刀
    // will replace this with bas_mps_cache_lookup +
    // bas_mps_cache_insert wrapping std::unordered_map<
    // std::string, id<MPSGraphExecutable>>。
    return 0;
}
