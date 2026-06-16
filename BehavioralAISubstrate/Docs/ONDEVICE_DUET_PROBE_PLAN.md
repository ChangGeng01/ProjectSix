# On-Device DUET Probe — Build Plan (Track G)

Produced by the `ondevice-duet-design` workflow (8 agents: 5 readers + 2 adversarial verifiers + synthesis), 2026-06-17.
Takes the host-verified hybrid DUET (addendum 22) onto the iPhone Air A19 / iOS-27 CoreAI 0.4.0.

## Mamba-3 DUET on-device probe — concrete build+probe plan

### TL;DR
The host has proven the full 24L hybrid DUET (20 Mamba-3 + 4 MLA) hands off a **token-identical int8 1.75MB State-Cache** (addendum 22). Two things gate the device port, and they are NOT equal in risk:

1. **The co-load wall is real and proven** — but the DUET's asymmetry (one-shot prefill, hot decode loop) makes the *sequential-load + state-via-disk* escape nearly free.
2. **Prefill convertibility is genuinely unproven and is the #1 risk** — the "already confirmed" claim is a refuted placeholder. Settle it with a 1-hour single-layer GPU probe BEFORE building anything else.

### Co-load strategy: state-via-disk (B), sequenced as the benign half of (A)
Proven facts: 2nd `AIModel.load` → SIGSEGV (Track E:553); multi-function single asset → SIGABRT because compile is per-asset (Track E:557). Both assets can never co-reside.

The DUET escapes this cheaply because **prefill is one-shot, not per-token**:
- Prefill: load GPU asset → run `[1,T]` prompt → serialize int8 1.75MB State-Cache to Documents → **release + deinit**.
- Decode: load own GPU asset ONCE → read State-Cache ONCE → run the full per-token loop with **no reload, no further disk I/O**.

One disk round-trip (~10–50ms) amortized over 128+ tokens = negligible. The generic "(A) is a 0.3× loss" warning does not apply — that assumed per-token reload, which we do not do.

### Prefill-converts: REAL RISK (smallest experiment first)
`prefill_state` (mamba3_trainable.py:205) and MLA `forward_seq` (mamba3_mla.py:52) use ops decode never touches: `torch.cumsum`, `scan_chunked` (O(C²) segsum, [T,T]), `softmax`+`triu` over `[h,T,T]`. These are the exact dynamic-shape/large-intermediate ops that trip the CoreAI 0.4.0 segmenter. Prefill is meant for **GPU** (sidesteps the ANE segmenter) but GPU export of these ops is unverified.

**Settle it in STEP 1–2**: export ONE `Lyr.prefill_state` + ONE `MLABlock.forward_seq` (fp16, fixed [1,T=64], GPU) and run on A19; compare boundary state to host (< 1e-2). ~1 hour. If it faults → fall back to a per-token `step_ref` warm-up prefill (proven, slower, acceptable for prefill-once).

### Reuse vs build
- **Build new**: the DUET converter (two separate assets) + `BASCoreAIHybridPrefillSession`/`BASCoreAIHybridDecodeSession`. `BASCoreAIMamba3DualSession` is the wrong shape (single-asset 2-function, 2-state pure-Mamba) — not reusable.
- **Reuse**: `mamba3_deploy.py` decode converter (angle-first separate 4-state) as the decode base; `llama_to_coreai_split.py:500-536` state-handoff export pattern; the `BASCoreAIMamba3DualProbe` harness skeleton + the BAS_COREAI_DUAL_PROBE launch-hook pattern (BASEnduranceAppRunner.swift:359); the **angle-FIRST** registration discipline verbatim.

### Ordered steps (smallest de-risk first)
0. Host regression gate: re-run `mamba3_duet_handoff.py` + `test_hybrid_duet.py` → confirm int8 100% token-identical (the comparison ceiling).
1. **`Tools/mamba3_prefill_probe.py`** — export 1 Mamba `prefill_state` + 1 MLA `forward_seq` (fp16, GPU, [1,64]); host-verify export.
2. **Device GPU prefill gate** — `BASCoreAIPrefillProbe` + tiny session; run L1 assets on A19, compare state < 1e-2. **DECISION GATE.**
3. **`mamba3_hybrid_prefill_deploy.py`** — full 24L `HybridM.prefill` → GPU asset; host 24/24 first.
4. **`mamba3_hybrid_decode_deploy.py`** — 24L decode; MLA growing cache as fixed `[MAX_SEQ,128]` + fill-offset; host 24/24.
5. **State-Cache contract** — int8 serialize (`cache_serialize_state_hybrid`) → disk → Swift read; Python-write→Swift-read parity check.
6. **Swift DUET sessions + sequential orchestration** — prefill fully deinits before decode loads; new BAS_COREAI_DUET_PROBE hook.
7. **Device E2E gate** — fixed-seed weights matched to host; assert no co-load SIGSEGV + decode argmax token-identical to host; report latency/tok/s/MB/seam-ms.
8. **Real-checkpoint quality pass** — re-run with distilled 24L student (downstream of cloud distill); promotion gate to a production lane.

### Open risks → fallbacks
- Prefill GPU export faults → per-token `step_ref` warm-up prefill.
- MLA growing cache vs fixed-shape state → pre-allocate `[MAX_SEQ,128]` + offset + masked read (proven in split converter).
- Lazy deinit → 2nd load SIGSEGVs → force release + footprint-drop confirm; escalate to XPC prefill-process (one-time IPC, no per-token).
- 24L GPU decode too slow (~73 tok/s) → stays a research probe if it loses to Track A (1.58×).
- int8 cross-language state corruption → STEP 5 parity check catches it; fp16 cache (3.5MB) fallback.
- Asset-size wall → int8 is already the floor; size-check 24L int8 main.mlirb in STEP 3.
- No placement readback → report inferred (compile-failure proxy), as docs already do honestly.

### Key files
- Converters to extend: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools/mamba3_deploy.py` (decode base), `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools/llama_to_coreai_split.py` (handoff export pattern).
- Host DUET (source of truth): `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools/mamba3_hybrid.py`, `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools/mamba3_mla.py`, `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools/mamba3_duet_handoff.py`, `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tools/mamba3_trainable.py`.
- Swift harness skeleton to clone: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAppleAdapters/BASCoreAIMamba3DualSession.swift`, `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/Sources/App/BASCoreAIMamba3DualProbe.swift`.
- Launch hook: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/DeviceTestApp/Sources/App/BASEnduranceAppRunner.swift:359`.
- Co-load + addendum 22 evidence: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Docs/UNIVERSAL_SSD_PROBE_RESULTS.md` (lines 545-566, 1520-1545).