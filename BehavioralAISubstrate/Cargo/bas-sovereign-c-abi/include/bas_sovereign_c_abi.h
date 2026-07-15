/*
 * bas_sovereign_c_abi.h
 * Public C ABI for BehavioralAISubstrate L14 Sovereign primitives.
 *
 * chapter 七百五十八 第四刀 / M2444 — hand-curated header for
 * third-party C consumers (watchOS native apps,embedded systems,
 * game engines,legacy C runtimes,attestation chains)。
 *
 * Why hand-curated (not cbindgen-generated):third-party consumers
 * don't want to track cbindgen output drift across rustc bumps。
 * This header is the substrate's STABILITY-TIER-1 wire contract:
 * function signatures + bit positions + return codes are byte-pinned
 * by chapter 七百十六 50-entry test discipline。 Changes here are
 * ABI BREAKS and require ABI_VERSION bump + Swift drift-test sync。
 *
 * ABI version:1 (chapter 七百五十八 第一刀 / M2441)
 *
 * Stability tier (per VERSIONING.md):TIER 1 (pinned by byte-equality
 * tests in Cargo/bas-sovereign-c-abi/src/lib.rs)。
 *
 * Linker:include this header and link against the substrate
 * XCFramework's bas_memory_usage_tracker.a (which bundles all the
 * sibling crates including bas-sovereign-c-abi via force-link
 * anchors)。 On watchOS,you can also link against just
 * bas_sovereign_c_abi.a built directly from this crate's
 * `crate-type = ["staticlib"]` output (skips the full XCFramework
 * dependency tree)。
 *
 * Threading:all functions are PURE FUNCTIONS with no global state,
 * no I/O,no allocation that outlives the call。 Fully reentrant。
 */

#ifndef BAS_SOVEREIGN_C_ABI_H
#define BAS_SOVEREIGN_C_ABI_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================
 * ABI version probe
 * ============================================================ */

/*
 * Returns the ABI version this header targets。 ALWAYS call this
 * at startup and compare against the constant your consumer was
 * compiled against — refuse to proceed on mismatch。 Bumps to this
 * value are non-additive ABI BREAKS。
 */
int32_t bas_sovereign_c_abi_version(void);

/* The ABI version this header was authored against。 Compare:
 *
 *   if (bas_sovereign_c_abi_version() != BAS_SOVEREIGN_C_ABI_HEADER_VERSION) {
 *     // abort,log,refuse to invoke other symbols
 *   }
 */
#define BAS_SOVEREIGN_C_ABI_HEADER_VERSION 1

/* ============================================================
 * Halt signal encoding (chapter 七百五十八 第一刀 / M2441)
 * ============================================================ */

/*
 * Compute the deterministic 32-byte opaque halt token for
 * (reason_code, timestamp_ms) per the v1 encoding:
 *
 *   token = SHA256("bas-sovereign-halt-v1"
 *                  || reason_code as int32_be
 *                  || timestamp_ms as int64_be)
 *
 * Use:L14 sovereign records the token in the audit chain to mark
 * a halt event in a replay-verifiable way that doesn't require
 * Swift or the full Rust verdict engine。
 *
 * Parameters:
 *   reason_code   — caller-defined halt code (e.g。 BR-001..BR-007
 *                   from the chapter 七百四十二 BR-bitfield convention)
 *   timestamp_ms  — UNIX epoch milliseconds when halt issued
 *   out_token     — caller-owned 32-byte writable buffer
 *
 * Returns:
 *    0 — success,32 bytes written to out_token
 *   -1 — out_token is NULL
 *
 * Reentrant:yes。 No global state。
 */
int32_t bas_sovereign_halt_signal_encode(
    int32_t reason_code,
    int64_t timestamp_ms,
    uint8_t* out_token
);

/* ============================================================
 * Integrity scan (chapter 七百五十八 第二刀 / M2442)
 * ============================================================ */

/*
 * ArtifactKind code values (passed as the trailing `kind: u8` byte
 * of each ArtifactClaim in the artifacts wire format)。
 *
 * Mapping to HardObservations bitfield (see out_hard_bits):
 *   kind 0 (modelOrPolicyArtifact) → BR-001 (bit 0,  0x0001)
 *   kind 1 (sovereignPolicyBundle) → BR-006 (bit 5,  0x0020)
 *   kind 2 (thoughtFoldOrCache)    → BR-002 (bit 1,  0x0002)
 *   kind 3 (runtimeImage)          → BR-007 (bit 6,  0x0040)
 */
#define BAS_ARTIFACT_KIND_MODEL_OR_POLICY      0
#define BAS_ARTIFACT_KIND_SOVEREIGN_POLICY     1
#define BAS_ARTIFACT_KIND_THOUGHT_FOLD_OR_CACHE 2
#define BAS_ARTIFACT_KIND_RUNTIME_IMAGE        3

/* HardObservations bit positions (chapter 七百四十二 convention)。 */
#define BAS_HARD_BIT_BR_001_ARTIFACT_SIGNATURE_INVALID 0x0001
#define BAS_HARD_BIT_BR_002_THOUGHT_FOLD_CHECKSUM      0x0002
#define BAS_HARD_BIT_BR_006_POLICY_BUNDLE_TAMPERED     0x0020
#define BAS_HARD_BIT_BR_007_UNAUTHORIZED_SELF_MUTATION 0x0040

/*
 * Pure function:given a list of artifact claims + a trusted
 * fingerprint map + an observed-self-mutation flag,produce the
 * 4-bit subset of HardObservations that the integrity sentinel
 * owns (BR-001 / BR-002 / BR-006 / BR-007)。
 *
 * Wire format for `artifacts_buf` (little-endian):
 *
 *   count : uint32
 *   per claim:
 *     id_len    : uint16
 *     id_bytes  : utf-8
 *     hash_len  : uint16
 *     hash_bytes: utf-8 (hex string,case-insensitive on read)
 *     kind      : uint8 (BAS_ARTIFACT_KIND_*)
 *
 * Wire format for `fingerprints_buf` (little-endian):
 *
 *   count : uint32
 *   per fingerprint:
 *     id_len    : uint16
 *     id_bytes  : utf-8
 *     hash_len  : uint16
 *     hash_bytes: utf-8 (hex string,lowercased on read)
 *
 * Behavior (mirrors BASSovereignIntegritySentinel.swift):
 *   1. Unknown artifact (no entry in trusted_fps for claim id) →
 *      claim FAILS。 Conservative because the sentinel cannot vouch
 *      for what it has no ground truth for。
 *   2. Trusted hash comparison is case-insensitive (both sides
 *      lowercased before compare)。
 *   3. observed_self_mutation flag OR's into BR-007 even if all
 *      runtime-image claims pass。
 *
 * Parameters:
 *   artifacts_buf,artifacts_len     — claims wire format + byte length
 *   fingerprints_buf,fingerprints_len — trust wire format + byte length
 *   observed_self_mutation           — 0 = clean,non-zero = flag set
 *   out_hard_bits                    — caller-owned writable uint16
 *
 * Returns:
 *    0 — success,*out_hard_bits written
 *   -1 — out_hard_bits is NULL,or non-zero buf with NULL pointer
 *   -2 — wire format parse failure (truncated buffer / non-UTF-8 /
 *        unknown kind code 4..255 / impossible length)
 *
 * Reentrant:yes。 No global state。
 */
int32_t bas_sovereign_integrity_scan(
    const uint8_t* artifacts_buf,
    int32_t artifacts_len,
    const uint8_t* fingerprints_buf,
    int32_t fingerprints_len,
    int32_t observed_self_mutation,
    uint16_t* out_hard_bits
);

/* ============================================================
 * Chain seal + verify (re-exports from bas-substrate-core,
 * forwarded so consumers don't need to link the sibling crate
 * separately;chapter 七百四十一 第二刀 / M2377 — chain primitives)
 * ============================================================ */

/*
 * Compute the next chain hash + canonical bytes for a single L14
 * audit entry。 Forwarder to bas_sovereign_seal_entry。
 *
 * Output canonical-bytes follows two-phase capacity discovery:
 *   1. Call with out_canonical=NULL,out_canonical_capacity=0 →
 *      returns required size (caller allocates this much)
 *   2. Call again with allocated buffer → returns same size,
 *      writes canonical bytes
 *
 * Returns the canonical-byte count required/written,or negative
 * on error (-1 if prior_hash32 or out_next_hash32 is NULL)。
 *
 * INTEROP CAVEAT (deep-audit rust LOW, 2026-07-13): the canonical bytes this
 * function emits are a SELF-CONTAINED Rust wire shape (prior_hash first) and are
 * NOT interoperable with the Swift `BASSovereignAuditLedger` canonicalBytes
 * encoding。 A chain SEALED by this C ABI must be VERIFIED only by the C
 * `bas_sovereign_verify_chain_c_abi` below (and vice-versa) — do NOT cross-verify
 * a C-sealed chain with the Swift ledger or a Swift-sealed chain with this C
 * verify;the encodings differ and cross-verification will FAIL。
 */
int32_t bas_sovereign_seal_entry_c_abi(
    const uint8_t* prior_hash32,
    const uint8_t* audit_id,    int32_t audit_id_len,
    const uint8_t* session_id,  int32_t session_id_len,
    const uint8_t* verdict_ref, int32_t verdict_ref_len,
    int64_t timestamp_ms,
    const uint8_t* payload,     int32_t payload_len,
    uint8_t* out_next_hash32,
    uint8_t* out_canonical,
    int32_t out_canonical_capacity
);

/*
 * Verify an L14 audit chain by replaying canonical-bytes entries
 * from initial32 through each entry and asserting the final hash
 * matches expected_final32。
 *
 * Wire format for entries_buffer (big-endian):
 *
 *   count: uint32_be
 *   per entry:
 *     entry_len: uint32_be
 *     entry_bytes: canonical-bytes buffer from seal_entry
 *
 * NOTE:entries_buffer_len MUST be ≥ 4 (to hold the count prefix
 * at minimum)。 Smaller buffer returns -1。
 *
 * Returns:
 *    1 — chain valid (replay produced expected_final32)
 *    0 — chain invalid (mismatch or malformed entry)
 *   -1 — null pointer or buffer too short
 *
 * Reentrant:yes。 No global state。
 */
int32_t bas_sovereign_verify_chain_c_abi(
    const uint8_t* initial32,
    const uint8_t* entries_buffer,
    int32_t entries_buffer_len,
    const uint8_t* expected_final32
);

/* ============================================================
 * Tamper-proof audit composite (chapter 七百五十八 第三刀 / M2443)
 * ============================================================ */

/*
 * Composite of bas_sovereign_verify_chain + bas_sovereign_integrity_scan
 * in a single call。 Detects mid-chain artifact mutations atomically
 * without requiring the consumer to handle two round-trips。
 *
 * Output `*out_tamper_mask` layout (uint64_t):
 *
 *   bits  0..15 — integrity hard_bits (same encoding as
 *                 bas_sovereign_integrity_scan output:
 *                 BAS_HARD_BIT_BR_001 / BR_002 / BR_006 / BR_007)
 *   bit  32     — chain mismatch flag
 *                 (1 when chain replay did NOT match expected;
 *                  0 when chain valid)
 *   bits 16..31,33..63 — reserved (zero on ABI v1)
 *
 * Output `*out_verification` is the raw chain replay return code:
 *
 *   1 — chain valid
 *   0 — chain invalid (mismatch or malformed entry)
 *  -1 — chain verify error (null pointer or buffer too short)
 *
 * Returns (function-level):
 *    0 — success,both outputs written
 *   -1 — null out_verification or out_tamper_mask
 *   -2 — integrity wire-format parse failure (outputs zeroed)
 *
 * Note:chain replay errors do NOT cause the function to return non-
 * zero — they're surfaced via `*out_verification` so the caller can
 * still act on integrity bits even when the chain itself failed。
 *
 * Reentrant:yes。 No global state。
 */
int32_t bas_sovereign_tamper_proof_audit(
    const uint8_t* initial_hash32,
    const uint8_t* entries_buffer,
    int32_t entries_buffer_len,
    const uint8_t* expected_final32,
    const uint8_t* artifacts_buf,
    int32_t artifacts_len,
    const uint8_t* fingerprints_buf,
    int32_t fingerprints_len,
    int32_t observed_self_mutation,
    int32_t* out_verification,
    uint64_t* out_tamper_mask
);

#ifdef __cplusplus
}
#endif

#endif /* BAS_SOVEREIGN_C_ABI_H */
