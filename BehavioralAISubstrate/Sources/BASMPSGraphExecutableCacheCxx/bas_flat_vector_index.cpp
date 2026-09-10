// SPDX:internal
//
// bas_flat_vector_index.cpp — chapter 七百三 第五刀 / M2175
//
// Substrate-shipped flat-scan vector nearest-neighbor index。
// Used as a fallback path when MLX / Metal aren't available on
// the host。 O(N × D) per query — fine for the substrate's
// in-memory atom counts (typically ≤ few thousand)。
//
// ## Surface
//
//   - bas_flat_index_create(dim)      → opaque handle
//   - bas_flat_index_add(handle, id, vec[]) → 0 / -1
//   - bas_flat_index_count(handle) → entry count
//   - bas_flat_index_search_top_k(handle, query[], k, out_ids[],
//                                  out_scores[]) → number of hits
//   - bas_flat_index_remove(handle, id) → 0 / -1
//   - bas_flat_index_destroy(handle)
//
// ## C linkage
//
// The header bas_flat_vector_index.h declares the
// `extern "C"` ABI so Swift consumers can call via the existing
// BASMPSGraphExecutableCacheCxx module map。

#include "include/bas_flat_vector_index.h"

#include <vector>
#include <string>
#include <cmath>
#include <algorithm>
#include <unordered_map>

namespace {

/// One stored vector + its caller-supplied id。
struct Entry {
    std::string id;
    std::vector<float> vec;
};

/// In-memory flat index。 No persistence;callers re-add on
/// startup if they want durability。
struct FlatIndex {
    size_t dim;
    std::vector<Entry> entries;
    // Secondary index id → entries[*] position for O(log N)
    // remove / lookup。
    std::unordered_map<std::string, size_t> by_id;

    explicit FlatIndex(size_t d) : dim(d) {}
};

/// L2 norm helper。
float l2_norm(const float *v, size_t n) {
    float s = 0.0f;
    for (size_t i = 0; i < n; ++i) {
        s += v[i] * v[i];
    }
    return std::sqrt(s);
}

/// Cosine similarity helper。
float cosine_sim(
    const float *a, const float *b, size_t n
) {
    float dot = 0.0f, na = 0.0f, nb = 0.0f;
    for (size_t i = 0; i < n; ++i) {
        dot += a[i] * b[i];
        na  += a[i] * a[i];
        nb  += b[i] * b[i];
    }
    if (na == 0.0f || nb == 0.0f) { return 0.0f; }
    return dot / std::sqrt(na * nb);
}

} // anonymous namespace

extern "C" {

void *bas_flat_index_create(uint32_t dim) {
    if (dim == 0) { return nullptr; }
    return new FlatIndex(dim);
}

void bas_flat_index_destroy(void *handle) {
    if (handle == nullptr) { return; }
    delete static_cast<FlatIndex *>(handle);
}

int32_t bas_flat_index_add(
    void *handle,
    const char *id,
    const float *vec,
    uint32_t vec_len
) {
    if (handle == nullptr || id == nullptr || vec == nullptr) {
        return -1;
    }
    auto *idx = static_cast<FlatIndex *>(handle);
    if (vec_len != idx->dim) { return -2; }
    std::string id_str(id);
    if (idx->by_id.find(id_str) != idx->by_id.end()) {
        return -3; // duplicate id
    }
    Entry e;
    e.id = std::move(id_str);
    e.vec.assign(vec, vec + vec_len);
    idx->by_id[e.id] = idx->entries.size();
    idx->entries.push_back(std::move(e));
    return 0;
}

uint64_t bas_flat_index_count(void *handle) {
    if (handle == nullptr) { return 0; }
    auto *idx = static_cast<FlatIndex *>(handle);
    return static_cast<uint64_t>(idx->entries.size());
}

int32_t bas_flat_index_remove(
    void *handle, const char *id
) {
    if (handle == nullptr || id == nullptr) { return -1; }
    auto *idx = static_cast<FlatIndex *>(handle);
    std::string id_str(id);
    auto it = idx->by_id.find(id_str);
    if (it == idx->by_id.end()) { return -2; }
    size_t pos = it->second;
    size_t last = idx->entries.size() - 1;
    if (pos != last) {
        // Swap-remove with last entry; update secondary index。
        idx->entries[pos] = std::move(idx->entries[last]);
        idx->by_id[idx->entries[pos].id] = pos;
    }
    idx->entries.pop_back();
    idx->by_id.erase(id_str);
    return 0;
}

/// Search for the top K nearest neighbors of `query` (by cosine
/// similarity)。 Out parameters:
///   - out_ids[]: caller-owned array of `k` const char* slots。
///                Each slot is set to the internal id pointer
///                (do NOT free)。 Strings remain valid until
///                next mutation。
///   - out_scores[]: caller-owned array of k floats; receives
///                   cosine similarities descending。
/// Returns:the actual number of hits (≤ k)。
int32_t bas_flat_index_search_top_k(
    void *handle,
    const float *query,
    uint32_t query_len,
    uint32_t k,
    const char **out_ids,
    float *out_scores
) {
    if (handle == nullptr || query == nullptr
        || out_ids == nullptr || out_scores == nullptr) {
        return -1;
    }
    auto *idx = static_cast<FlatIndex *>(handle);
    if (query_len != idx->dim) { return -2; }
    if (idx->entries.empty() || k == 0) { return 0; }

    // Score all entries
    std::vector<std::pair<float, size_t>> scored;
    scored.reserve(idx->entries.size());
    for (size_t i = 0; i < idx->entries.size(); ++i) {
        float s = cosine_sim(
            query, idx->entries[i].vec.data(),
            idx->dim);
        scored.emplace_back(s, i);
    }
    // Partial-sort to top-K
    uint32_t out_k =
        static_cast<uint32_t>(
            std::min<size_t>(k, scored.size()));
    std::partial_sort(
        scored.begin(),
        scored.begin() + out_k,
        scored.end(),
        [](const auto &a, const auto &b) {
            return a.first > b.first;
        });
    for (uint32_t r = 0; r < out_k; ++r) {
        size_t pos = scored[r].second;
        out_ids[r] = idx->entries[pos].id.c_str();
        out_scores[r] = scored[r].first;
    }
    return static_cast<int32_t>(out_k);
}

/// Compute the L2 norm of a stored entry's vector by id。
/// Useful for callers that want to inspect storage quality。
int32_t bas_flat_index_entry_norm(
    void *handle, const char *id, float *out_norm
) {
    if (handle == nullptr || id == nullptr
        || out_norm == nullptr) {
        return -1;
    }
    auto *idx = static_cast<FlatIndex *>(handle);
    std::string id_str(id);
    auto it = idx->by_id.find(id_str);
    if (it == idx->by_id.end()) { return -2; }
    const auto &e = idx->entries[it->second];
    *out_norm = l2_norm(e.vec.data(), idx->dim);
    return 0;
}

int32_t bas_flat_index_abi_version(void) {
    return 1;
}

} // extern "C"
