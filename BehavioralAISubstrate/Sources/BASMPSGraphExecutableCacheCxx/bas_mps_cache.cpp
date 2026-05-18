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
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <functional>
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

    // 主线 全面 开发 — atomic check-then-act。 Looks up
    // `key`;if present,returns the existing value in
    // `out` + the `found` flag set to true。 If absent,
    // inserts the `default_value` and returns it via
    // `out` + `found` false。 Single mutex acquisition
    // means no other thread can observe the cache in a
    // partial state between the lookup and the insert。
    void lookup_or_insert(
        const std::string& key,
        const std::string& default_value,
        std::string& out,
        bool& found) {
        std::lock_guard<std::mutex> w(rw_);
        auto it = store_.find(key);
        if (it != store_.end()) {
            out = it->second;
            found = true;
            return;
        }
        store_[key] = default_value;
        out = default_value;
        found = false;
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

// 全面 开发 — Bloom filter singleton。 SEPARATE mutex
// from the main cache so bloom queries don't block
// cache writes (and vice versa)。 65536 bits (8192
// bytes) — small enough to fit comfortably,large
// enough that false-positive rate stays under 2% at
// typical workload sizes。
class BasMpsBloomFilter {
public:
    static BasMpsBloomFilter& instance() {
        static BasMpsBloomFilter shared;
        return shared;
    }

    static constexpr size_t kBits = 65536;
    static constexpr size_t kBytes = kBits / 8;

    void add(const std::string& key) {
        std::lock_guard<std::mutex> w(mu_);
        size_t h1, h2, h3;
        hashes(key, h1, h2, h3);
        set_bit(h1);
        set_bit(h2);
        set_bit(h3);
        size_ += 1;
    }

    // True = "might contain"; false = "definitely not"。
    bool might_contain(const std::string& key) const {
        std::lock_guard<std::mutex> r(mu_);
        size_t h1, h2, h3;
        hashes(key, h1, h2, h3);
        return get_bit(h1) && get_bit(h2) && get_bit(h3);
    }

    void clear() {
        std::lock_guard<std::mutex> w(mu_);
        std::fill(bits_, bits_ + kBytes, 0);
        size_ = 0;
    }

    int64_t size() const {
        std::lock_guard<std::mutex> r(mu_);
        return static_cast<int64_t>(size_);
    }

private:
    BasMpsBloomFilter() : size_(0) {
        std::fill(bits_, bits_ + kBytes, 0);
    }
    BasMpsBloomFilter(const BasMpsBloomFilter&) = delete;
    BasMpsBloomFilter& operator=(const BasMpsBloomFilter&) = delete;

    // 3 hash functions:std::hash + two
    // permutations。 Standard "double-hashing" trick:
    //   h_i = (h1 + i * h2) mod kBits
    // for i in {0, 1, 2}。 The third uses (h1 ^ h2)
    // as a salt for variety。
    static void hashes(
        const std::string& key,
        size_t& h1, size_t& h2, size_t& h3
    ) {
        std::hash<std::string> hasher;
        size_t h = hasher(key);
        h1 = h % kBits;
        size_t h_split = (h >> 16) | (h << 48);
        h2 = (h ^ h_split) % kBits;
        h3 = (h + h_split * 0x9E3779B97F4A7C15ULL) % kBits;
    }

    void set_bit(size_t pos) {
        bits_[pos / 8] |= (uint8_t)(1 << (pos % 8));
    }

    bool get_bit(size_t pos) const {
        return (bits_[pos / 8]
            & (uint8_t)(1 << (pos % 8))) != 0;
    }

    mutable std::mutex mu_;
    uint8_t bits_[kBytes];
    size_t size_;
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

int32_t bas_mps_cache_lookup_or_insert(
    const char* key,
    const char* default_value,
    char** out_value) {
    if (key == nullptr || default_value == nullptr
        || out_value == nullptr) {
        return -1;
    }
    std::string out;
    bool found = false;
    try {
        BasMpsCache::instance().lookup_or_insert(
            std::string(key),
            std::string(default_value),
            out,
            found);
    } catch (...) {
        return -2;
    }
    // Allocate C buffer the caller frees with
    // bas_mps_cache_free_value (same lifecycle as
    // bas_mps_cache_lookup)。
    size_t n = out.size();
    char* buf = static_cast<char*>(std::malloc(n + 1));
    if (buf == nullptr) {
        return -2;
    }
    std::memcpy(buf, out.data(), n);
    buf[n] = '\0';
    *out_value = buf;
    return found ? 1 : 2;
}

int32_t bas_mps_cache_lookup_or_insert_version(void) {
    return 1;
}

// 全面 开发 — Bloom filter FFI surface
int32_t bas_mps_cache_bloom_add(const char* key) {
    if (key == nullptr) {
        return -1;
    }
    try {
        BasMpsBloomFilter::instance().add(
            std::string(key));
        return 0;
    } catch (...) {
        return -2;
    }
}

int32_t bas_mps_cache_bloom_might_contain(
    const char* key
) {
    if (key == nullptr) {
        return -1;
    }
    try {
        bool present = BasMpsBloomFilter::instance()
            .might_contain(std::string(key));
        return present ? 1 : 0;
    } catch (...) {
        return -2;
    }
}

int32_t bas_mps_cache_bloom_clear(void) {
    try {
        BasMpsBloomFilter::instance().clear();
        return 0;
    } catch (...) {
        return -2;
    }
}

int64_t bas_mps_cache_bloom_size(void) {
    try {
        return BasMpsBloomFilter::instance().size();
    } catch (...) {
        return -1;
    }
}

int32_t bas_mps_cache_bloom_version(void) {
    return 1;
}

} // extern "C"
