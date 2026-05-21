/*
 * bas_red_team_bench.h
 * Public C ABI for BehavioralAISubstrate L11 batch adversarial-
 * prompt classifier。
 *
 * chapter 七百五十九 第三刀 / M2448 — hand-curated header for
 * third-party C consumers + watchOS + future SIMD ports。
 *
 * Why hand-curated (not cbindgen-generated):third-party consumers
 * don't want to track cbindgen output drift across rustc bumps。
 * This header is the substrate's STABILITY-TIER-1 wire contract:
 * function signatures + bit positions + return codes are byte-pinned
 * by chapter 七百十六 50-entry test discipline。 Changes here are
 * ABI BREAKS and require ABI_VERSION bump + Swift drift-test sync。
 *
 * ABI version:1 (chapter 七百五十九 第三刀 / M2448)
 *
 * Stability tier (per VERSIONING.md):TIER 1 (pinned by byte-equality
 * tests in Cargo/bas-red-team-bench/src/lib.rs)。
 *
 * Linker:include this header and link against the substrate
 * XCFramework's bas_memory_usage_tracker.a (which bundles all the
 * sibling crates including bas-red-team-bench via force-link
 * anchors)。 You can also link against just bas_red_team_bench.a
 * built directly from this crate's `crate-type = ["staticlib", "rlib"]`
 * output (skips the full XCFramework dependency tree)。
 *
 * Threading:all functions are PURE FUNCTIONS with no global state,
 * no I/O,no allocation that outlives the call。 Fully reentrant。
 */

#ifndef BAS_RED_TEAM_BENCH_H
#define BAS_RED_TEAM_BENCH_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================
 * ABI version probe
 * ============================================================ */

/*
 * Returns the ABI version this crate exposes。 ALWAYS call this
 * at startup and compare against the constant your consumer was
 * compiled against — refuse to proceed on mismatch。 Bumps to this
 * value are non-additive ABI BREAKS。
 */
int32_t bas_red_team_bench_abi_version(void);

/* The ABI version this header was authored against。 Compare:
 *
 *   if (bas_red_team_bench_abi_version() != BAS_RED_TEAM_BENCH_HEADER_VERSION) {
 *     // abort,log,refuse to invoke other symbols
 *   }
 */
#define BAS_RED_TEAM_BENCH_HEADER_VERSION 1

/* ============================================================
 * Wire-format constants
 * ============================================================ */

/*
 * Per-match record byte size on the output wire (chapter 七百五十九 V1)。
 *
 * Match record layout (little-endian):
 *   offset 0..3  : prompt_index   (uint32_t)
 *   offset 4..5  : red_line_id    (uint16_t,RedLineId discriminant)
 *   offset 6..7  : reserved/zero  (uint16_t,padding for alignment)
 *   offset 8..11 : pattern_index  (uint32_t)
 *
 * The 2-byte padding is pinned to ZERO so strict-alignment platforms
 * (ARMv7 without unaligned access enabled,MIPS,SPARC) can load the
 * trailing uint32_t with a natural-aligned load instead of a byte-
 * by-byte fallback。
 */
#define BAS_RED_TEAM_BENCH_MATCH_WIRE_SIZE 12

/*
 * Output buffer prefix size:4 bytes for the uint32_t match count。
 * Minimum required output capacity is this value (zero matches still
 * writes the count prefix)。
 */
#define BAS_RED_TEAM_BENCH_OUT_PREFIX_SIZE 4

/* ============================================================
 * RedLineCategory constants (mirror RedLineCategory enum in lib.rs)
 *
 * Encoded into the high nibble of the red_line_id field:
 *   0x00..0x0F → Cthulhu     (10 ids assigned in 0x00..0x09)
 *   0x10..0x1F → Kunlun      ( 8 ids assigned in 0x10..0x17)
 *   0x20..0x2F → Product     ( 5 ids assigned in 0x20..0x24)
 *   0x30..0x3F → BR-014      ( 1 id assigned in 0x30)
 * ============================================================ */

#define BAS_RED_TEAM_CATEGORY_CTHULHU                     0
#define BAS_RED_TEAM_CATEGORY_KUNLUN                      1
#define BAS_RED_TEAM_CATEGORY_PRODUCT                     2
#define BAS_RED_TEAM_CATEGORY_BR_014_SOVEREIGN_DOMAIN     3

/* ============================================================
 * Batch classifier
 * ============================================================ */

/*
 * Classify a batch of UTF-8 prompts against the 24 red lines
 * (70 forbidden substrings)。 Reads `prompts_buf` as the wire
 * format below;writes results into `out_matches_buf`。
 *
 * Prompts wire format (little-endian):
 *
 *   count       : uint32_t LE
 *   per prompt:
 *     prompt_len  : uint32_t LE   (byte length of UTF-8 body)
 *     prompt_bytes: utf-8         (exactly prompt_len bytes,
 *                                  no NUL terminator)
 *
 * Output wire format (little-endian):
 *
 *   match_count : uint32_t LE
 *   per match (12 bytes):
 *     prompt_index  : uint32_t LE
 *     red_line_id   : uint16_t LE
 *     _reserved     : uint16_t LE (always zero)
 *     pattern_index : uint32_t LE
 *
 * Two-phase capacity discovery:
 *   1. Call with out_matches_buf=NULL,out_matches_capacity=0
 *      → returns required size in bytes (always ≥ 4 for the
 *        count prefix,even when zero matches)
 *   2. Allocate `required` bytes;call again with that buffer
 *      → returns same value,writes count + match records
 *
 * Behavior (mirrors BASProductRedLineLinter.lint(inputs:[String])):
 *   - Each prompt is lowercased before scanning (case-insensitive
 *     substring match)
 *   - Patterns are stored already-lowercased at compile time
 *   - Match = pattern is a substring of the lowercased prompt
 *   - Iteration order:prompt-major,then red_line discriminant,
 *     then pattern_index within the red line
 *
 * Parameters:
 *   prompts_buf             — pointer to the prompts wire format
 *                             (may be NULL when prompts_len == 0)
 *   prompts_len             — byte length of prompts_buf (≥ 0)
 *   out_matches_buf         — caller-allocated output buffer
 *                             (may be NULL during phase-1 probe)
 *   out_matches_capacity    — byte capacity of out_matches_buf
 *                             (must be ≥ required from phase 1)
 *
 * Returns:
 *   ≥ 0 — required/written byte count
 *         (≥ 4 always — the count prefix is included)
 *   -1  — NULL prompts_buf with non-zero prompts_len,or any
 *         negative length argument
 *   -2  — wire-format parse failure (truncated buffer / non-UTF-8 /
 *         declared length exceeds buffer)
 *
 * Reentrant:yes。 No global state。
 */
int32_t bas_red_team_classify_batch(
    const uint8_t* prompts_buf,
    int32_t prompts_len,
    uint8_t* out_matches_buf,
    int32_t out_matches_capacity
);

#ifdef __cplusplus
}
#endif

#endif /* BAS_RED_TEAM_BENCH_H */
