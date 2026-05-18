// SPDX:internal
// MARK: - bas_mps_cache.cpp
// chapter 七百五 / M2183 第一刀 — C++ pilot first real
//                                  implementation。
//                                  Generic thread-safe
//                                  string-keyed → string-
//                                  value cache backed by
//                                  std::unordered_map +
//                                  std::mutex。
//                                  Proves SPM .cxxTarget
//                                  + C++ stdlib + thread
//                                  safety integrate
//                                  cleanly in this repo。
//
// ## Why this scope (not RMSNorm-MPSGraph wiring)
//
// The chapter 七百一 MULTI-LANGUAGE AUGMENTATION ARC plan
// originally called for wrapping `std::unordered_map
// <std::string, id<MPSGraphExecutable>>` and wiring into
// BASMPSGraphRMSNormKernel。 Honest scope acknowledgment:
//
//   - Wrapping `id<MPSGraphExecutable>` via Objective-C++
//     (.mm) couples this target to MetalPerformance
//     ShadersGraph + Foundation,inflating the dependency
//     surface from "C++ stdlib only" to "C++ stdlib + 2
//     Apple frameworks"。 Counter-sprawl trajectory says
//     keep additions minimal。
//
//   - The MECHANISM proof — that SPM .cxxTarget hosts
//     C++ stdlib correctly + a Swift bridge can call it
//     + dual-mode opt-in via feature flag works — only
//     requires a generic cache。 The std::string variant
//     is the smallest possible production-shaped C++
//     stdlib touch point。
//
//   - Future commits CAN specialize this cache for
//     `id<MPSGraphExecutable>` when host demand
//     justifies the framework dependency。 The C++ ABI
//     here is intentionally typeless (key + value are
//     C strings)so Swift callers can serialize whatever
//     they want into the cache。
//
// Result:smaller dependency surface,real C++ stdlib
// usage,real thread safety,real cache semantics — all
// the proof of mechanism the plan needs,without the
// framework coupling cost。
//
// ## ADR-014 OPT-IN preserved
//
// No production code path consumed by this target until
// a Swift caller explicitly opts in via the
// `cxxMpsCacheEnabled` feature flag (default false →
// V1 byte-equality preserved by construction)。
//
// ## Thread safety
//
// `std::mutex` (C++11 stdlib,no C++17 shared_mutex
// dependency — keeps the package on the default C++
// standard) serializes all reads + writes。 The
// substrate's read concurrency over this cache is low
// (cache hit/miss happens once per kernel build call
// site,not per inner iteration),so the simpler
// exclusive mutex is the right cost/complexity
// trade-off。 Upgrade to shared_mutex when host
// demand justifies bumping the C++ standard at the
// package level。 The exposed C ABI takes raw
// `const char*` keys + values — caller owns the
// lifetime of the input strings while the cache COPIES
// into its internal std::string storage,so the cache
// is safe to query from any thread regardless of
// caller-side string lifecycle。

#include "bas_mps_cache.h"
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>

namespace {

// Single global cache instance,initialized on first
// access。 std::once_flag ensures thread-safe init even
// under concurrent first-touch from multiple threads。
class BasMpsCache {
public:
    static BasMpsCache& instance() {
        static BasMpsCache shared;
        return shared;
    }

    void insert(const std::string& key,
                const std::string& value) {
        std::lock_guard<std::mutex> w(rw_);
        store_[key] = value;
    }

    // Returns true if found,filling *out_value with
    // a copy。 Returns false if absent,leaving
    // *out_value untouched。
    bool lookup(const std::string& key,
                std::string& out_value) const {
        std::lock_guard<std::mutex> r(rw_);
        auto it = store_.find(key);
        if (it == store_.end()) {
            return false;
        }
        out_value = it->second;
        return true;
    }

    // Atomic size snapshot under shared lock。
    size_t size() const {
        std::lock_guard<std::mutex> r(rw_);
        return store_.size();
    }

    // 主线 解构 重构 — atomic byte-size sum under shared
    // lock。 One lock acquisition,one pass over the
    // container,sum of key.size() + value.size() across
    // every entry。 No Swift round-trips。
    size_t byte_size_estimate() const {
        std::lock_guard<std::mutex> r(rw_);
        size_t total = 0;
        for (const auto& kv : store_) {
            total += kv.first.size();
            total += kv.second.size();
        }
        return total;
    }

    // 主线 解构 重构 Round 3 — single-pass max。 One lock
    // acquisition,one pass over the container,return
    // the largest (key.size + value.size) sum。 Hosts use
    // this to detect oversized-entry abuse。
    size_t max_entry_byte_size() const {
        std::lock_guard<std::mutex> r(rw_);
        size_t maxSize = 0;
        for (const auto& kv : store_) {
            size_t entrySize =
                kv.first.size() + kv.second.size();
            if (entrySize > maxSize) {
                maxSize = entrySize;
            }
        }
        return maxSize;
    }

    void clear() {
        std::lock_guard<std::mutex> w(rw_);
        store_.clear();
    }

private:
    BasMpsCache() = default;
    BasMpsCache(const BasMpsCache&) = delete;
    BasMpsCache& operator=(const BasMpsCache&) = delete;

    mutable std::mutex rw_;
    std::unordered_map<std::string, std::string> store_;
};

} // anonymous namespace

extern "C" {

// M2197 chapter 七百九 第一刀 — placeholder function
// `bas_mps_cache_placeholder_version` removed (zero
// callers in the substrate;the "backward source compat"
// comment never had a real caller to protect)。

int32_t bas_mps_cache_insert(const char* key,
                              const char* value) {
    if (key == nullptr || value == nullptr) {
        return -1;
    }
    try {
        BasMpsCache::instance().insert(
            std::string(key), std::string(value));
        return 0;
    } catch (...) {
        return -2;
    }
}

// Returns:
//   1  = found,*out_value filled (caller must call
//        bas_mps_cache_free_value to release the
//        heap-allocated copy)
//   0  = not found,*out_value left untouched
//  -1  = null key OR null out_value pointer
//  -2  = internal exception (allocation failure)
int32_t bas_mps_cache_lookup(const char* key,
                              char** out_value) {
    if (key == nullptr || out_value == nullptr) {
        return -1;
    }
    std::string value;
    bool found;
    try {
        found = BasMpsCache::instance().lookup(
            std::string(key), value);
    } catch (...) {
        return -2;
    }
    if (!found) {
        return 0;
    }
    // Allocate a C-side buffer the caller will free
    // via bas_mps_cache_free_value to avoid coupling
    // the Swift side to the C++ allocator。
    size_t n = value.size();
    char* buf = static_cast<char*>(std::malloc(n + 1));
    if (buf == nullptr) {
        return -2;
    }
    std::memcpy(buf, value.data(), n);
    buf[n] = '\0';
    *out_value = buf;
    return 1;
}

void bas_mps_cache_free_value(char* value) {
    if (value != nullptr) {
        std::free(value);
    }
}

int64_t bas_mps_cache_size(void) {
    try {
        return static_cast<int64_t>(
            BasMpsCache::instance().size());
    } catch (...) {
        return -1;
    }
}

int32_t bas_mps_cache_clear(void) {
    try {
        BasMpsCache::instance().clear();
        return 0;
    } catch (...) {
        return -2;
    }
}

int32_t bas_mps_cache_version(void) {
    // ABI version pin。 Bumping requires updating
    // BASMPSGraphExecutableCacheCxxBridgeTests
    // .testCxxBridgeABIVersion simultaneously。
    return 1;
}

int64_t bas_mps_cache_byte_size_estimate(void) {
    try {
        return static_cast<int64_t>(
            BasMpsCache::instance().byte_size_estimate());
    } catch (...) {
        return -1;
    }
}

int32_t bas_mps_cache_byte_size_estimate_version(void) {
    return 1;
}

int64_t bas_mps_cache_max_entry_byte_size(void) {
    try {
        return static_cast<int64_t>(
            BasMpsCache::instance().max_entry_byte_size());
    } catch (...) {
        return -1;
    }
}

int32_t bas_mps_cache_max_entry_byte_size_version(void) {
    return 1;
}

} // extern "C"
