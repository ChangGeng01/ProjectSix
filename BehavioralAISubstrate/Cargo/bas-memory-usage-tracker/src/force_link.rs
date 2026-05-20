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
    total
}

/// Returns the count of bundled crates (currently 9:the host
/// `bas-memory-usage-tracker` + 6 chapter-七百三 siblings +
/// `bas-tokenizer` added at chapter 七百二十二 第二刀 +
/// `bas-tribunal-court` added at chapter 七百四十 第二刀)。
/// Swift consumers use this for hygiene assertions in their
/// drift tests。
#[no_mangle]
pub extern "C" fn bas_substrate_bundle_crate_count() -> i32 {
    9
}
