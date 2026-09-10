/*
 * bas_integrity_sentinel.h
 * Public C ABI for BehavioralAISubstrate L14 typed Integrity
 * Sentinel — structured ScanReport output。
 *
 * chapter 七百六十 第三刀 / M2453 — hand-curated header for
 * third-party C consumers + watchOS。
 *
 * Distinct from bas_sovereign_c_abi.h's `bas_sovereign_integrity_scan`
 * (which collapses output to a 4-bit hard_bits bitfield) — this
 * entry retains the full structured ScanReport so consumers can
 * log failed artifact IDs and distinguish per-kind failures。
 *
 * ABI version:1 (chapter 七百六十 第三刀 / M2453)
 *
 * Stability tier:TIER 1 (pinned by byte-equality tests in
 * Cargo/bas-integrity-sentinel/src/lib.rs)。 Changes here are
 * ABI BREAKS and require ABI_VERSION bump + Swift drift-test sync。
 *
 * Threading:pure function,no global state,no I/O。 Fully reentrant。
 */

#ifndef BAS_INTEGRITY_SENTINEL_H
#define BAS_INTEGRITY_SENTINEL_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================
 * ABI version probe
 * ============================================================ */

int32_t bas_integrity_sentinel_abi_version(void);

#define BAS_INTEGRITY_SENTINEL_HEADER_VERSION 1

/* ============================================================
 * ArtifactKind discriminants (mirror bas-sovereign-c-abi)
 * ============================================================ */

#define BAS_INTEGRITY_KIND_MODEL_OR_POLICY        0
#define BAS_INTEGRITY_KIND_SOVEREIGN_POLICY       1
#define BAS_INTEGRITY_KIND_THOUGHT_FOLD_OR_CACHE  2
#define BAS_INTEGRITY_KIND_RUNTIME_IMAGE          3

/* failed_kinds_bitmap bit positions (each = 1 << ArtifactKind_disc) */
#define BAS_INTEGRITY_KINDS_BIT_MODEL_OR_POLICY        (1u << 0)
#define BAS_INTEGRITY_KINDS_BIT_SOVEREIGN_POLICY       (1u << 1)
#define BAS_INTEGRITY_KINDS_BIT_THOUGHT_FOLD_OR_CACHE  (1u << 2)
#define BAS_INTEGRITY_KINDS_BIT_RUNTIME_IMAGE          (1u << 3)

/* HardObservations bit positions (mirror chapter 七百五十八) */
#define BAS_INTEGRITY_HARD_BIT_BR_001  0x0001
#define BAS_INTEGRITY_HARD_BIT_BR_002  0x0002
#define BAS_INTEGRITY_HARD_BIT_BR_006  0x0020
#define BAS_INTEGRITY_HARD_BIT_BR_007  0x0040

/*
 * Structured scan with full ScanReport wire output。
 *
 * Input wire formats (little-endian):
 *
 *   claims_buf:
 *     count: uint32 LE
 *     per claim:
 *       id_len:    uint16 LE
 *       id_bytes:  utf-8
 *       hash_len:  uint16 LE
 *       hash_bytes: utf-8
 *       kind:      uint8 (BAS_INTEGRITY_KIND_*)
 *
 *   fingerprints_buf:
 *     count: uint32 LE
 *     per fingerprint:
 *       id_len:    uint16 LE
 *       id_bytes:  utf-8
 *       hash_len:  uint16 LE
 *       hash_bytes: utf-8 (lowercased on read for compare)
 *
 * Output wire format (little-endian):
 *
 *   offset 0..3 : failed_id_count (uint32 LE)
 *   offset 4    : failed_kinds_bitmap (uint8) — OR of
 *                 BAS_INTEGRITY_KINDS_BIT_*
 *   offset 5    : observed_self_mutation (uint8, 0 or 1)
 *   offset 6..7 : hard_bits (uint16 LE,projection onto
 *                 BR-001 / BR-002 / BR-006 / BR-007 bitfield)
 *   offset 8+   : per failed_id (failed_id_count times):
 *                   id_len    : uint16 LE
 *                   id_bytes  : utf-8
 *
 * Required output capacity = 8 (fixed prefix)
 *                          + sum_over_failed_ids (2 + id_len)
 *
 * Two-phase capacity discovery:
 *   1. Call with out_report_buf=NULL,out_report_capacity=0
 *      → returns required size (always ≥ 8 for the prefix)
 *   2. Allocate `required` bytes;call again → returns same value,
 *      writes the structured report
 *
 * Behavior (mirrors BASSovereignIntegritySentinel.scan):
 *   1. Unknown claim id (no entry in fingerprints) → FAIL
 *      (conservative)
 *   2. Hash compare is case-insensitive (both sides lowercased
 *      before compare)
 *   3. observed_self_mutation OR's into BR-007 (bit 6 of hard_bits)
 *      even if all runtime-image claims pass
 *   4. failed_artifact_ids ordering = claim insertion order
 *   5. failed_kinds_bitmap = OR of failed kinds (no implicit
 *      ordering — it's a set)
 *
 * Returns:
 *    ≥ 0 — required/written byte count (always ≥ 8)
 *   -1  — null pointer + non-zero length,or any negative length
 *   -2  — wire-format parse failure (truncated / non-UTF-8 /
 *         unknown kind code 4..255)
 *
 * Reentrant:yes。 No global state。
 */
int32_t bas_integrity_sentinel_scan(
    const uint8_t* claims_buf,
    int32_t claims_len,
    const uint8_t* fingerprints_buf,
    int32_t fingerprints_len,
    int32_t observed_self_mutation,
    uint8_t* out_report_buf,
    int32_t out_report_capacity
);

#ifdef __cplusplus
}
#endif

#endif /* BAS_INTEGRITY_SENTINEL_H */
