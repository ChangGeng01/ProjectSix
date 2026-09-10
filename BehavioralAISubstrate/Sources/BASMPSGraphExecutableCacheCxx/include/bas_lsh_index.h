// SPDX:internal
//
// bas_lsh_index.h — chapter 七百五 第三刀 / M2198
//
// C ABI declarations for the random-projection LSH index。

#ifndef BAS_LSH_INDEX_H
#define BAS_LSH_INDEX_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Create an opaque LSH handle。 Returns NULL on invalid params
/// (dim=0, bits_per_table=0 or >30, num_tables=0)。
void *bas_lsh_create(
    uint32_t dim,
    uint32_t bits_per_table,
    uint32_t num_tables,
    uint64_t seed);

/// Destroy + release。
void bas_lsh_destroy(void *handle);

/// Entry count。
uint64_t bas_lsh_count(void *handle);

/// Add a (id, vector) entry。 Returns 0 on success,-1 on null
/// pointer,-2 on dim mismatch。
int32_t bas_lsh_add(
    void *handle,
    const char *id,
    const float *vec,
    uint32_t vec_len);

/// Search for top K NN by approximate cosine similarity。
/// Out arrays receive const char* (do NOT free) + float scores。
/// Returns number of hits (≤ k)。
int32_t bas_lsh_search(
    void *handle,
    const float *query,
    uint32_t query_len,
    uint32_t k,
    const char **out_ids,
    float *out_scores);

/// Diagnostic: avg bucket size across all tables。
int32_t bas_lsh_avg_bucket_size(
    void *handle, float *out_avg);

/// ABI version pin。
int32_t bas_lsh_abi_version(void);

#ifdef __cplusplus
}
#endif

#endif /* BAS_LSH_INDEX_H */
