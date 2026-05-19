// SPDX:internal
//
// bas_spsc_ring.c — chapter 七百五 第四刀 / M2199
//
// Lock-free Single-Producer Single-Consumer ring buffer using
// C11 atomics + memory ordering primitives。 The substrate's
// audit log writes are a hot path:producer threads (any actor
// that records an event) push records into this ring,a single
// consumer thread (the audit ledger flusher) drains them。 No
// locks on the producer side → no thread blocking。
//
// ## Algorithm
//
// Classic SPSC ring with separate head + tail atomic indices:
//   - head : owned by producer; consumer reads only with
//             memory_order_acquire
//   - tail : owned by consumer; producer reads only with
//             memory_order_acquire
//
// Producer (push):
//   1. Load current head (relaxed — own value)
//   2. Load current tail (acquire — pair with consumer's release)
//   3. If (head + 1) % capacity == tail → ring full,return -1
//   4. Write payload to slots[head]
//   5. Store head + 1 (release — pair with consumer's acquire)
//
// Consumer (pop):
//   1. Load current tail (relaxed — own value)
//   2. Load current head (acquire — pair with producer's release)
//   3. If head == tail → ring empty,return -1
//   4. Read payload from slots[tail]
//   5. Store tail + 1 (release — pair with producer's acquire)
//
// Capacity is power-of-two so the modulo becomes a bitmask AND
// — single instruction on every modern CPU。
//
// ## Why SPSC instead of MPMC
//
// SPSC has zero contention by design (only one producer +
// only one consumer touch each variable)。 The substrate's
// audit log fits this model: many actors call `record(event)`
// but they all funnel through a single in-process audit-ledger
// actor that owns the ring's producer side; the flusher
// thread owns the consumer side。
//
// For multi-producer scenarios callers can layer N independent
// SPSC rings + a fan-in consumer that round-robins。 Simpler
// + faster than MPMC algorithms that need CAS loops。

#include "include/bas_spsc_ring.h"

#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct BASSPSCRing {
    /// Power-of-two capacity。 The modulo becomes (i & mask)。
    uint32_t capacity;
    uint32_t mask;
    /// Payload size in bytes。 Each slot holds one payload of
    /// this exact size。 Caller cannot mix sizes within one
    /// ring。
    uint32_t payload_size;
    /// Producer-owned head index。 Producer-side relaxed load;
    /// consumer-side acquire load。 Producer increments via
    /// release store。
    _Atomic uint32_t head;
    /// Consumer-owned tail index。 Producer reads via acquire;
    /// consumer increments via release。
    _Atomic uint32_t tail;
    /// Slots — `capacity × payload_size` raw bytes,allocated
    /// contiguously to keep cache-line locality。
    uint8_t *slots;
};

/// Round up to next power-of-two。 Returns 0 on overflow。
static uint32_t round_up_pow2(uint32_t n) {
    if (n == 0) { return 1; }
    if (n & (n - 1)) {
        // Not a power of two — round up
        uint32_t p = 1;
        while (p < n) {
            uint32_t next = p << 1;
            if (next < p) { return 0; } // overflow
            p = next;
        }
        return p;
    }
    return n;
}

/// Create a new ring。 Returns NULL on invalid params or
/// allocation failure。 `capacity_hint` is rounded up to the
/// next power-of-two。
BASSPSCRing *bas_spsc_ring_create(
    uint32_t capacity_hint, uint32_t payload_size
) {
    if (payload_size == 0 || capacity_hint == 0) {
        return NULL;
    }
    uint32_t cap = round_up_pow2(capacity_hint);
    if (cap == 0 || cap < 2) {
        cap = 2;
    }
    BASSPSCRing *r = (BASSPSCRing *)
        calloc(1, sizeof(BASSPSCRing));
    if (r == NULL) { return NULL; }
    r->capacity = cap;
    r->mask = cap - 1;
    r->payload_size = payload_size;
    atomic_store_explicit(
        &r->head, 0, memory_order_relaxed);
    atomic_store_explicit(
        &r->tail, 0, memory_order_relaxed);
    r->slots = (uint8_t *)calloc(
        cap, payload_size);
    if (r->slots == NULL) {
        free(r);
        return NULL;
    }
    return r;
}

void bas_spsc_ring_destroy(BASSPSCRing *r) {
    if (r == NULL) { return; }
    free(r->slots);
    free(r);
}

uint32_t bas_spsc_ring_capacity(BASSPSCRing *r) {
    return r ? r->capacity : 0;
}

uint32_t bas_spsc_ring_payload_size(BASSPSCRing *r) {
    return r ? r->payload_size : 0;
}

/// Approximate count of buffered items — racy but useful for
/// telemetry。 Reads both head + tail relaxed,returns
/// (head - tail) & mask。 Producer + consumer may have advanced
/// since this read,so callers use this for "roughly how full"
/// not "exact size"。
uint32_t bas_spsc_ring_size_approx(BASSPSCRing *r) {
    if (r == NULL) { return 0; }
    uint32_t head = atomic_load_explicit(
        &r->head, memory_order_relaxed);
    uint32_t tail = atomic_load_explicit(
        &r->tail, memory_order_relaxed);
    return (head - tail) & r->mask;
}

/// Producer-side push。 Returns:
///   0  = success
///   -1 = ring is full
///   -2 = null pointer (ring or payload)
int32_t bas_spsc_ring_push(
    BASSPSCRing *r, const void *payload
) {
    if (r == NULL || payload == NULL) { return -2; }
    uint32_t head = atomic_load_explicit(
        &r->head, memory_order_relaxed);
    uint32_t tail = atomic_load_explicit(
        &r->tail, memory_order_acquire);
    uint32_t next = (head + 1) & r->mask;
    if (next == (tail & r->mask)) {
        // Full
        return -1;
    }
    memcpy(
        r->slots + ((head & r->mask) * r->payload_size),
        payload, r->payload_size);
    atomic_store_explicit(
        &r->head, head + 1, memory_order_release);
    return 0;
}

/// Consumer-side pop。 Returns:
///   0  = success (payload copied into `out`)
///   -1 = ring is empty
///   -2 = null pointer
int32_t bas_spsc_ring_pop(
    BASSPSCRing *r, void *out
) {
    if (r == NULL || out == NULL) { return -2; }
    uint32_t tail = atomic_load_explicit(
        &r->tail, memory_order_relaxed);
    uint32_t head = atomic_load_explicit(
        &r->head, memory_order_acquire);
    if (head == tail) {
        // Empty
        return -1;
    }
    memcpy(
        out,
        r->slots + ((tail & r->mask) * r->payload_size),
        r->payload_size);
    atomic_store_explicit(
        &r->tail, tail + 1, memory_order_release);
    return 0;
}

/// Bulk push — push up to `count` payloads from the contiguous
/// buffer。 Returns the actual number successfully pushed (≤
/// count) — stops at first full-ring。 Useful for callers
/// batching many records at once。
int32_t bas_spsc_ring_push_bulk(
    BASSPSCRing *r,
    const void *payloads,
    uint32_t count
) {
    if (r == NULL || payloads == NULL) { return -2; }
    const uint8_t *p = (const uint8_t *)payloads;
    uint32_t pushed = 0;
    for (uint32_t i = 0; i < count; ++i) {
        int32_t rc = bas_spsc_ring_push(
            r, p + i * r->payload_size);
        if (rc != 0) { break; }
        ++pushed;
    }
    return (int32_t)pushed;
}

/// Bulk pop — pop up to `count` payloads into the contiguous
/// buffer。 Returns actual number popped (≤ count)。
int32_t bas_spsc_ring_pop_bulk(
    BASSPSCRing *r,
    void *payloads,
    uint32_t count
) {
    if (r == NULL || payloads == NULL) { return -2; }
    uint8_t *p = (uint8_t *)payloads;
    uint32_t popped = 0;
    for (uint32_t i = 0; i < count; ++i) {
        int32_t rc = bas_spsc_ring_pop(
            r, p + i * r->payload_size);
        if (rc != 0) { break; }
        ++popped;
    }
    return (int32_t)popped;
}

int32_t bas_spsc_ring_abi_version(void) {
    return 1;
}
