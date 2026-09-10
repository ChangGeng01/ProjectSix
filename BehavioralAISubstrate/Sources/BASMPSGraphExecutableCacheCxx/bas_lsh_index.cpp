// SPDX:internal
//
// bas_lsh_index.cpp — chapter 七百五 第三刀 / M2198
//
// Random-projection Locality-Sensitive Hashing index for
// approximate nearest-neighbor retrieval。 Sub-linear lookup
// for large corpora where exact cosine over every entry would
// be too slow。
//
// ## Algorithm: Random-Projection LSH for cosine
//
// For unit vectors u + v, cosine(u, v) = u · v。 Sign-based LSH
// for cosine works as follows:
//   1. Pick H random hyperplanes (Gaussian-distributed normal
//      vectors) in R^dim。
//   2. For each entry x: hash bit h_i = (random_plane_i · x > 0)。
//   3. Concatenate the H bits into a binary code。
//   4. Two vectors with high cosine similarity → many bits in
//      common (Hamming distance is a proxy for cosine distance)。
//
// To avoid winner-takes-all collisions, we use TABLES copies of
// the H-bit hash (each table has its own random hyperplanes)。
// Query lookup ORs together the table-buckets the query hashes
// into; only the candidates from those buckets get scored with
// exact cosine。
//
// ## Tunable parameters
//
//   - dim     : input vector dimension (caller-set)
//   - H       : bits per table (8 by default → 256 buckets per table)
//   - TABLES  : number of independent hash tables (4 by default)
//
// At 8 bits × 4 tables = 32 bits of hash info per entry → ~4M
// distinguishable codes。 For a corpus of 10k vectors,each
// bucket contains ~2.5 entries on average → tiny scan cost。
//
// ## Surface
//
// All extern "C" — Swift consumers via the BASMPSGraph
// ExecutableCacheCxx module map。
//
//   - bas_lsh_create(dim, bits_per_table, num_tables, seed)
//   - bas_lsh_add(handle, id, vec)
//   - bas_lsh_search(handle, query, k, out_ids, out_scores)
//   - bas_lsh_count(handle)
//   - bas_lsh_destroy(handle)

#include "include/bas_lsh_index.h"

#include <vector>
#include <string>
#include <cmath>
#include <unordered_map>
#include <unordered_set>
#include <random>
#include <algorithm>

namespace {

struct Entry {
    std::string id;
    std::vector<float> vec;
    float norm;       // pre-computed L2 norm for cosine sim
};

struct Table {
    /// `bits_per_table` × `dim` random Gaussian hyperplane normals。
    /// Indexed as hyperplanes[bit * dim + d]。
    std::vector<float> hyperplanes;
    /// Bucket → list of entry indices。
    std::unordered_map<uint32_t,
        std::vector<size_t>> buckets;
};

struct LSHIndex {
    size_t dim;
    uint32_t bits_per_table;
    uint32_t num_tables;
    std::vector<Entry> entries;
    std::vector<Table> tables;
    /// Caller-supplied seed → deterministic test fixtures。
    uint64_t seed;

    LSHIndex(size_t d, uint32_t bits, uint32_t nt,
        uint64_t s)
        : dim(d), bits_per_table(bits),
          num_tables(nt), seed(s)
    {
        tables.resize(nt);
        std::mt19937_64 rng(s);
        std::normal_distribution<float> gauss(0.0f, 1.0f);
        for (auto &t : tables) {
            t.hyperplanes.resize(bits * dim);
            for (auto &h : t.hyperplanes) {
                h = gauss(rng);
            }
        }
    }
};

/// Compute the bucket index (concatenated bits) for a vector
/// against one table。
uint32_t compute_bucket(
    const LSHIndex *idx, size_t table_idx,
    const float *v
) {
    uint32_t bucket = 0;
    const Table &t = idx->tables[table_idx];
    for (uint32_t bit = 0; bit < idx->bits_per_table; ++bit) {
        float dot = 0.0f;
        const float *plane =
            &t.hyperplanes[bit * idx->dim];
        for (size_t d = 0; d < idx->dim; ++d) {
            dot += plane[d] * v[d];
        }
        if (dot > 0.0f) {
            bucket |= (1u << bit);
        }
    }
    return bucket;
}

float l2_norm_of(const float *v, size_t n) {
    float s = 0.0f;
    for (size_t i = 0; i < n; ++i) { s += v[i] * v[i]; }
    return std::sqrt(s);
}

float cosine_of(
    const float *a, float na,
    const float *b, float nb, size_t dim
) {
    if (na == 0.0f || nb == 0.0f) { return 0.0f; }
    float dot = 0.0f;
    for (size_t i = 0; i < dim; ++i) { dot += a[i] * b[i]; }
    return dot / (na * nb);
}

} // anonymous namespace

extern "C" {

void *bas_lsh_create(
    uint32_t dim,
    uint32_t bits_per_table,
    uint32_t num_tables,
    uint64_t seed
) {
    if (dim == 0 || bits_per_table == 0
        || bits_per_table > 30 || num_tables == 0) {
        return nullptr;
    }
    return new LSHIndex(dim, bits_per_table, num_tables, seed);
}

void bas_lsh_destroy(void *handle) {
    if (handle == nullptr) { return; }
    delete static_cast<LSHIndex *>(handle);
}

uint64_t bas_lsh_count(void *handle) {
    if (handle == nullptr) { return 0; }
    auto *idx = static_cast<LSHIndex *>(handle);
    return static_cast<uint64_t>(idx->entries.size());
}

int32_t bas_lsh_add(
    void *handle,
    const char *id,
    const float *vec,
    uint32_t vec_len
) {
    if (handle == nullptr || id == nullptr || vec == nullptr) {
        return -1;
    }
    auto *idx = static_cast<LSHIndex *>(handle);
    if (vec_len != idx->dim) { return -2; }
    Entry e;
    e.id.assign(id);
    e.vec.assign(vec, vec + vec_len);
    e.norm = l2_norm_of(vec, vec_len);
    size_t entry_idx = idx->entries.size();
    idx->entries.push_back(std::move(e));
    for (uint32_t t = 0; t < idx->num_tables; ++t) {
        uint32_t bucket = compute_bucket(idx, t, vec);
        idx->tables[t].buckets[bucket].push_back(entry_idx);
    }
    return 0;
}

/// Search for the top K nearest neighbors of `query` (by cosine)
/// using the LSH index。 Out parameters: out_ids[k] receives
/// const char* pointers to internal id strings (do NOT free);
/// out_scores[k] receives float cosine similarities。
/// Returns the actual number of hits (≤ k)。
int32_t bas_lsh_search(
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
    auto *idx = static_cast<LSHIndex *>(handle);
    if (query_len != idx->dim) { return -2; }
    if (idx->entries.empty() || k == 0) { return 0; }

    // Collect candidate set: union of buckets the query hashes
    // into across all tables。
    std::unordered_set<size_t> candidates;
    for (uint32_t t = 0; t < idx->num_tables; ++t) {
        uint32_t bucket = compute_bucket(idx, t, query);
        auto it = idx->tables[t].buckets.find(bucket);
        if (it == idx->tables[t].buckets.end()) {
            continue;
        }
        for (size_t c : it->second) {
            candidates.insert(c);
        }
    }
    // Fallback: if zero candidates (rare for well-tuned LSH),
    // degrade to full scan for correctness。
    if (candidates.empty()) {
        for (size_t i = 0; i < idx->entries.size(); ++i) {
            candidates.insert(i);
        }
    }

    // Score each candidate exactly + pick top K
    float q_norm = l2_norm_of(query, query_len);
    std::vector<std::pair<float, size_t>> scored;
    scored.reserve(candidates.size());
    for (size_t i : candidates) {
        const Entry &e = idx->entries[i];
        float s = cosine_of(
            query, q_norm, e.vec.data(), e.norm,
            idx->dim);
        scored.emplace_back(s, i);
    }
    uint32_t out_k = static_cast<uint32_t>(
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

/// Diagnostic — report the average bucket size across all
/// tables。 A well-tuned LSH has avg ≈ corpus_size / 2^bits_per_table。
/// Returns 0 on success,-1 on null pointer。
int32_t bas_lsh_avg_bucket_size(
    void *handle, float *out_avg
) {
    if (handle == nullptr || out_avg == nullptr) {
        return -1;
    }
    auto *idx = static_cast<LSHIndex *>(handle);
    if (idx->tables.empty()) { *out_avg = 0.0f; return 0; }
    size_t total_buckets = 0;
    size_t total_entries = 0;
    for (const auto &t : idx->tables) {
        total_buckets += t.buckets.size();
        for (const auto &kv : t.buckets) {
            total_entries += kv.second.size();
        }
    }
    if (total_buckets == 0) {
        *out_avg = 0.0f;
    } else {
        *out_avg = static_cast<float>(total_entries) /
            static_cast<float>(total_buckets);
    }
    return 0;
}

int32_t bas_lsh_abi_version(void) {
    return 1;
}

} // extern "C"
