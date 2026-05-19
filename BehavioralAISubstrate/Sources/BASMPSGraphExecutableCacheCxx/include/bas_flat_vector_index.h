// SPDX:internal
//
// bas_flat_vector_index.h — chapter 七百三 第五刀 / M2175
//
// C ABI declarations for the C++ flat-scan vector NN index。

#ifndef BAS_FLAT_VECTOR_INDEX_H
#define BAS_FLAT_VECTOR_INDEX_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Create an opaque flat-index handle with the given vector
/// dimension。 Returns NULL on dim=0。
void *bas_flat_index_create(uint32_t dim);

/// Destroy the handle + release all stored vectors。
void bas_flat_index_destroy(void *handle);

/// Add a vector with caller-supplied id。 Returns:
///   0  = success
///  -1  = null pointer
///  -2  = vec_len mismatch with dim
///  -3  = duplicate id
int32_t bas_flat_index_add(
    void *handle,
    const char *id,
    const float *vec,
    uint32_t vec_len);

/// Number of entries currently in the index。
uint64_t bas_flat_index_count(void *handle);

/// Remove an entry by id。 Returns:
///   0  = success
///  -1  = null pointer
///  -2  = id not found
int32_t bas_flat_index_remove(
    void *handle, const char *id);

/// Search for top K nearest neighbors by cosine similarity。
/// Returns actual number of hits (≤ k)。
int32_t bas_flat_index_search_top_k(
    void *handle,
    const float *query,
    uint32_t query_len,
    uint32_t k,
    const char **out_ids,
    float *out_scores);

/// Compute L2 norm of a stored entry's vector by id。
int32_t bas_flat_index_entry_norm(
    void *handle, const char *id, float *out_norm);

/// ABI version pin。
int32_t bas_flat_index_abi_version(void);

#ifdef __cplusplus
}
#endif

#endif /* BAS_FLAT_VECTOR_INDEX_H */
