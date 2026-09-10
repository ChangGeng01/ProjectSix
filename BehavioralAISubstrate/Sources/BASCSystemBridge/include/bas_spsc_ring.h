// SPDX:internal
//
// bas_spsc_ring.h — chapter 七百五 第四刀 / M2199
//
// C ABI for the lock-free SPSC ring buffer。

#ifndef BAS_SPSC_RING_H
#define BAS_SPSC_RING_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque ring handle。
typedef struct BASSPSCRing BASSPSCRing;

/// Create a ring with at least `capacity_hint` slots,each
/// holding `payload_size` bytes。 Capacity is rounded up to the
/// next power-of-two for the bitmask-indexing fast path。
BASSPSCRing *bas_spsc_ring_create(
    uint32_t capacity_hint, uint32_t payload_size);

/// Destroy + release。
void bas_spsc_ring_destroy(BASSPSCRing *ring);

uint32_t bas_spsc_ring_capacity(BASSPSCRing *ring);
uint32_t bas_spsc_ring_payload_size(BASSPSCRing *ring);

/// Approximate buffered count (racy)。 For telemetry only。
uint32_t bas_spsc_ring_size_approx(BASSPSCRing *ring);

/// Producer-side push of one payload。 Returns 0 / -1 (full) /
/// -2 (null pointer)。
int32_t bas_spsc_ring_push(
    BASSPSCRing *ring, const void *payload);

/// Consumer-side pop of one payload into `out`。 Returns 0 /
/// -1 (empty) / -2 (null pointer)。
int32_t bas_spsc_ring_pop(
    BASSPSCRing *ring, void *out);

/// Bulk push from contiguous buffer。 Returns actual pushed (≤
/// count)。
int32_t bas_spsc_ring_push_bulk(
    BASSPSCRing *ring,
    const void *payloads,
    uint32_t count);

/// Bulk pop into contiguous buffer。 Returns actual popped。
int32_t bas_spsc_ring_pop_bulk(
    BASSPSCRing *ring,
    void *payloads,
    uint32_t count);

/// ABI version pin。
int32_t bas_spsc_ring_abi_version(void);

#ifdef __cplusplus
}
#endif

#endif /* BAS_SPSC_RING_H */
