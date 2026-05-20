// SPDX:internal
//
// force_link.rs — chapter 七百四 第一刀 / M2191
//
// Prevents the Rust linker from stripping the #[no_mangle]
// extern "C" ABI symbols contributed by the 6 sibling workspace
// crates。 When this top-level crate (bas-memory-usage-tracker)
// is compiled as a staticlib (.a)。 cargo + rustc only KEEP
// symbols that are referenced somewhere in the crate's own code
// — orphan `#[no_mangle]` functions can be dropped by LTO/
// dead-code elimination。
//
// The trick:expose one #[no_mangle] function that explicitly
// references one symbol from each sibling crate。 The linker
// sees a use-chain root → keeps all transitively referenced
// symbols。 The function itself is never called from Swift;
// existing for its side-effect on the static-archive symbol
// table。
//
// ## Why per-crate ABI version probes
//
// Each chapter-七百三 crate ships a `bas_<crate>_abi_version()`
// function that returns the crate's pinned ABI version。 They
// are the cheapest "anchors" to reference — pure constants,
// no allocator, no failure modes。

/// Sum of all sibling-crate ABI versions。 Forces the linker to
/// keep each crate's `extern "C"` symbol table linked into the
/// final staticlib。 Exposed under a stable name so Swift code
/// that wants to assert the bundled-crate set hasn't drifted
/// can read it via the bridge。
#[no_mangle]
pub extern "C" fn bas_substrate_bundle_abi_total() -> i32 {
    let mut total: i32 = 0;
    total = total.wrapping_add(
        bas_substrate_core::bas_substrate_core_abi_version());
    total = total.wrapping_add(
        bas_memory_atom_store::bas_mas_abi_version());
    total = total.wrapping_add(
        bas_retrieval_ranker::bas_ranker_abi_version());
    total = total.wrapping_add(
        bas_canonical_bytes::bas_canonical_bytes_abi_version());
    total = total.wrapping_add(
        bas_permit_policy::bas_permit_policy_abi_version());
    total = total.wrapping_add(
        bas_event_log_codec::bas_event_log_abi_version());
    total = total.wrapping_add(
        bas_runtime_frame::bas_runtime_frame_abi_version());
    // chapter 七百二十二 第二刀 / M2282 — fold the BPE
    // tokenizer's ABI version into the bundle total so a
    // future ABI bump shows up in BASRustCoreBridge drift
    // tests automatically。
    total = total.wrapping_add(
        bas_tokenizer::bas_tokenizer_abi_version());
    // chapter 七百三十九 第二刀 / M2367 — force-link the
    // L11 risk_plane C ABI exports so the staticlib
    // bundles them。 Cheapest anchor:invoke the pure
    // classifier with sentinel inputs (returns 0 → Answer
    // mode,no observable side-effect)。
    total = total.wrapping_add(
        bas_permit_policy::risk_plane
            ::bas_permit_policy_risk_band_to_next_mode(
                0, 0, 0));
    // chapter 七百四十 第二刀 / M2372 — force-link the L10
    // tribunal-court ABI version。 Cheapest anchor。
    total = total.wrapping_add(
        bas_tribunal_court::bas_tribunal_court_abi_version());
    // chapter 七百四十一 第二刀 / M2377 — force-link the L14
    // sovereign seal/verify entry points so the staticlib
    // bundles them。 Invoke with sentinel inputs (zero hash,
    // zero payload → produces a valid sealed hash;dropped
    // since we only need the symbol reference for the
    // linker)。 The capacity-discovery phase return value
    // (canonical bytes required size) is wrapped into the
    // running ABI total。
    let prior = [0u8; 32];
    let mut next = [0u8; 32];
    let needed = unsafe {
        bas_substrate_core::bas_sovereign_seal_entry(
            prior.as_ptr(),
            core::ptr::null(), 0,
            core::ptr::null(), 0,
            core::ptr::null(), 0,
            0,
            core::ptr::null(), 0,
            next.as_mut_ptr(),
            core::ptr::null_mut(), 0)
    };
    total = total.wrapping_add(needed);
    // chapter 七百四十二 第一刀 / M2381 — force-link the L14
    // verdict-decisions Rust port。 Invoke with all-clean
    // inputs (returns Pass rank 0,no observable effect)。
    let softs = [0.0_f64; 7];
    let verdict_rank = unsafe {
        bas_substrate_core::verdict_decisions
            ::bas_verdict_derive(
                0, softs.as_ptr(), 0, 1)
    };
    total = total.wrapping_add(verdict_rank);
    // chapter 七百四十三 第一刀 / M2386 — force-link the L14
    // token lifecycle decision。 Sentinel inputs:live
    // token (returns 0,no observable effect)。
    let token_status = bas_substrate_core::verdict_decisions
        ::bas_sovereign_token_lifecycle_status(
            100, 200, -1, 150);
    total = total.wrapping_add(token_status);
    // chapter 七百四十四 第二刀 / M2392 — force-link the L3
    // knowledge_graph_codec encode_node entry。 Sentinel
    // inputs:zero-length strings + capacity 0 → returns
    // required size (the codec's serialized minimum)。
    let nid = b"";
    let kr = b"";
    let lbl = b"";
    let kg_needed = unsafe {
        bas_event_log_codec::knowledge_graph_codec
            ::bas_kg_codec_encode_node(
                nid.as_ptr() as *const core::ffi::c_char, 0,
                kr.as_ptr() as *const core::ffi::c_char, 0,
                lbl.as_ptr() as *const core::ffi::c_char, 0,
                0,
                core::ptr::null(), -1,
                core::ptr::null_mut(), 0)
    };
    total = total.wrapping_add(kg_needed);
    // chapter 七百四十五 第一刀 / M2396 — force-link the L3
    // event extractor classifier。 Sentinel inputs (empty
    // action → returns 0 = None edge,no observable
    // side-effect)。
    let mut ek: i32 = 0;
    let mut ew: f64 = 0.0;
    let mut am: i32 = 0;
    let ext_rc = unsafe {
        bas_event_log_codec::event_extractor
            ::bas_event_extractor_classify(
                core::ptr::null(), 0,
                core::ptr::null(), 0,
                core::ptr::null(), 0,
                &mut ek, &mut ew, &mut am)
    };
    total = total.wrapping_add(ext_rc);
    // chapter 七百四十七 第一刀 / M2406 — force-link the L2
    // organ router select。 Sentinel inputs:tiny attention
    // workload under constrained power → returns 0 = Cpu
    // Reference (no observable side-effect)。
    let router_rc =
        bas_organ_router::bas_organ_router_select(
            0, 64, 0);
    total = total.wrapping_add(router_rc);
    // chapter 七百四十八 第一刀 / M2411 — force-link the L9
    // dream-loop batch-scoring kernel。 Sentinel inputs:
    // zero-size corpus → returns 0 (no indices written,
    // no observable side-effect)。
    let query: [f32; 1] = [0.0];
    let cands: [f32; 0] = [];
    let benefits: [f64; 0] = [];
    let costs: [f64; 0] = [];
    let mut out: [i32; 0] = [];
    let dl_rc = unsafe {
        bas_dream_loop::bas_dream_loop_batch_score(
            query.as_ptr(), 1,
            cands.as_ptr(), 0,
            benefits.as_ptr(),
            costs.as_ptr(),
            0,
            out.as_mut_ptr(), 0)
    };
    total = total.wrapping_add(dl_rc);
    // chapter 七百五十一 第二刀 / M2427 — force-link the L8
    // memory-atom-reducer admission-confidence tiebreak rule。
    // Sentinel inputs:existing 0.0 / new 0.0 / tiebreak=keep → 0
    // (no observable side-effect)。
    let reducer_rc =
        bas_memory_atom_store::reducer
            ::bas_atom_reducer_should_replace_admitted(
                0.0, 0.0, 1);
    total = total.wrapping_add(reducer_rc);
    // chapter 七百五十三 第二刀 / M2434 — force-link the
    // batched admission-tiebreak。 Sentinel:n=0,no writes。
    let existing: [f64; 0] = [];
    let new_arr: [f64; 0] = [];
    let mut out: [i32; 0] = [];
    let batched_rc = unsafe {
        bas_memory_atom_store::reducer
            ::bas_atom_reducer_batched_should_replace_admitted(
                existing.as_ptr(),
                new_arr.as_ptr(),
                0,
                1,
                out.as_mut_ptr())
    };
    total = total.wrapping_add(batched_rc);
    // chapter 七百五十八 第四刀 / M2444 — force-link the L14
    // sovereign-c-abi public wrapper crate's symbols so the
    // staticlib bundles them。 4 cheapest anchors:
    //   1. ABI version probe
    //   2. halt_signal_encode (sentinel inputs)
    //   3. integrity_scan (empty claims + empty trust → 0 bits)
    //   4. tamper_proof_audit (composite,exercises both paths)
    total = total.wrapping_add(
        bas_sovereign_c_abi::bas_sovereign_c_abi_version());
    let mut halt_token = [0u8; 32];
    let halt_rc = unsafe {
        bas_sovereign_c_abi::bas_sovereign_halt_signal_encode(
            0, 0, halt_token.as_mut_ptr())
    };
    total = total.wrapping_add(halt_rc);
    // integrity_scan with empty buffers → returns 0 + writes
    // 0 bits。 Buffers are non-null pointers to 4-byte
    // count-prefix zero buffers per the wire format。
    let empty_claims: [u8; 4] = [0, 0, 0, 0];
    let empty_trust: [u8; 4] = [0, 0, 0, 0];
    let mut hard_bits: u16 = 0;
    let integrity_rc = unsafe {
        bas_sovereign_c_abi::bas_sovereign_integrity_scan(
            empty_claims.as_ptr(), empty_claims.len() as i32,
            empty_trust.as_ptr(),  empty_trust.len() as i32,
            0,
            &mut hard_bits)
    };
    total = total.wrapping_add(integrity_rc);
    // tamper_proof_audit with empty chain (4-byte BE count=0)
    // + matching initial==expected (both all-zero) → chain
    // valid (1) + clean composite (0)。
    let init32 = [0u8; 32];
    let expected32 = [0u8; 32];
    let entries_buf: [u8; 4] = [0, 0, 0, 0];  // BE count=0
    let mut verification: i32 = 0;
    let mut tamper_mask: u64 = 0;
    let tamper_rc = unsafe {
        bas_sovereign_c_abi::bas_sovereign_tamper_proof_audit(
            init32.as_ptr(),
            entries_buf.as_ptr(), entries_buf.len() as i32,
            expected32.as_ptr(),
            empty_claims.as_ptr(), empty_claims.len() as i32,
            empty_trust.as_ptr(),  empty_trust.len() as i32,
            0,
            &mut verification, &mut tamper_mask)
    };
    total = total.wrapping_add(tamper_rc);
    // chapter 七百五十九 第三刀 / M2448 — force-link the L11
    // red-team-bench batch classifier symbols。 Two cheapest
    // anchors:
    //   1. ABI version probe (constant return,zero side-effect)
    //   2. classify_batch with empty prompts wire (4-byte count=0
    //      prefix) + null output buffer → returns 4 = required
    //      prefix size for empty match list,no observable side-
    //      effect since out_matches_buf is null
    total = total.wrapping_add(
        bas_red_team_bench::bas_red_team_bench_abi_version());
    let empty_prompts: [u8; 4] = [0, 0, 0, 0]; // u32 LE count=0
    let red_team_rc = unsafe {
        bas_red_team_bench::bas_red_team_classify_batch(
            empty_prompts.as_ptr(), empty_prompts.len() as i32,
            core::ptr::null_mut(), 0)
    };
    total = total.wrapping_add(red_team_rc);
    // chapter 七百六十 第三刀 / M2453 — force-link the L11
    // typed integrity-sentinel crate symbols。 Two cheapest
    // anchors:
    //   1. ABI version probe (constant return,zero side-effect)
    //   2. sentinel_scan with empty claims + empty fingerprints
    //      (4-byte count=0 prefix on each) + null out buffer →
    //      returns 8 = required prefix size for empty report,
    //      no observable side-effect since out_report_buf is null
    total = total.wrapping_add(
        bas_integrity_sentinel::bas_integrity_sentinel_abi_version());
    let empty_claims: [u8; 4] = [0, 0, 0, 0]; // u32 LE count=0
    let empty_fps: [u8; 4]    = [0, 0, 0, 0]; // u32 LE count=0
    let sentinel_rc = unsafe {
        bas_integrity_sentinel::bas_integrity_sentinel_scan(
            empty_claims.as_ptr(), empty_claims.len() as i32,
            empty_fps.as_ptr(),    empty_fps.len() as i32,
            0,
            core::ptr::null_mut(), 0)
    };
    total = total.wrapping_add(sentinel_rc);
    total
}

/// Returns the count of bundled crates。 Swift consumers use this
/// for hygiene assertions in their drift tests (chapter 七百四 /
/// 七百五 `BASChapter704PerformanceBenchTests.testRustBundleManifest`
/// + `BASChapter705IntegrationTests.testChapter705AbiBundleVersionsMatch`,
/// both converted to `>= count` floor assertions in chapter
/// 七百五十七 第三刀 so growth doesn't break the gate)。
///
/// History:
///   - 9 = post-chapter-七百四十 (host + 6 七百三 siblings + tokenizer + tribunal-court)
///   - 13 = chapter 七百五十八 第四刀 / M2444 (+sovereign-c-abi,
///         AND backfill organ-router from chapter 七百四十七 + dream-loop
///         from chapter 七百四十八 that were added as deps but not
///         counted in the static return)
///   - 14 = chapter 七百五十九 第三刀 / M2448 (+red-team-bench)
///   - 15 = chapter 七百六十 第三刀 / M2453 (+integrity-sentinel)
#[no_mangle]
pub extern "C" fn bas_substrate_bundle_crate_count() -> i32 {
    15
}
