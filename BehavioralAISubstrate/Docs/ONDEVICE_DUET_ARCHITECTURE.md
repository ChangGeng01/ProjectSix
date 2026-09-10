# On-Device DUET — Integrated Architecture (Track G north-star)

Produced by the `duet-audit-and-architecture` workflow (2026-06-17): 7 adversarial auditors + 3 architects + synthesis.
Every aggressive claim traces to an AUDIT-PROVEN fact (addenda 23-28) or is tagged `[research]`. See addendum 28 for the audit verdict.

## Integrated system (decoder ⊕ Context Compiler ⊕ StateLake — 浑然一体)

# 浑然一体: The Closed-Loop Recurrent Reader — Decoder ⊕ Context Compiler ⊕ StateLake

> North-star, honesty-first. Every aggressive claim below is tagged `[PROVEN]`, `[buildable-now]`, `[needs-work]`, or `[research]`. The system rests on ONE structural fact the audit proves and the field ignores: **Mamba-3's 4-state recurrence collapses to a single 1st-order contractive step with the conv1d removed** (`mamba3_trainable.py:7-14`; `prev_t == cur_{t-1}` makes the rotated delay a state READ, not a buffer). That collapse is why a *fixed-shape* CoreAI state asset exists at all — which is why stateful-KV on-device decode exists. The whole loop is the maximal, honest exploitation of that one fact.

## 0. The one law that governs everything (the audit's most dangerous gap)
**A state is only ever loaded into the EXACT graph that produced it, and only within its valid fill window. Any mismatch is a hard, loud, fail-closed error — never a silent rehydrate.** This is mandated by two audit findings: (a) cross-version safety is FABRICATED/absent — a rehydrated state against mismatched weights is silent garbage with zero detection; (b) MAX_SEQ=256 is a SILENT cap — at step 256 the token is silently dropped (verified: no guard in `mla_step_fixed` or `BASCoreAIHybridDecodeSession.step`). The `binding_key` and `fill < max_seq` precondition are therefore mandatory schema fields, not optional metadata.

## 1. The three pillars are three views of ONE state ring
The **6 resident NDArrays** are the single shared object every pillar touches — `[angle_all, ssm_all, kprev_all, vprev_all, mla_kv, mla_fill]`, stacked angle-FIRST (the segmenter discipline, `[PROVEN]` 0 slot mismatches). There is no second representation and no cross-engine copy.

```
                         ┌──────────────────────── StateLake (Pillar 3) ────────────────────────┐
                         │  versioned .statelake artifact store: binding_key LAW · prefix DAG ·  │
                         │  hot/warm/cold tiers · ACL · checksum · expiry        [needs-work]     │
                         └───────────▲───────────────────────────────────────────────┬──────────┘
                                     │ route(corpus,query) -> ResumePlan              │ put(states)
                                     │ (ACL+binding gated; longest-prefix DAG match)  │
   QUERY ──┐                         │                                                │
           ▼                         │                                                │
  ┌─────────────────┐   miss/extend  │     ┌──────────────────────────────┐          │
  │  Router (P3 §8)  │───────────────┼────▶│ Context Compiler (Pillar 2)  │          │
  │  find, never     │   prefill the  │     │  tile-ladder pack · chunked  │          │
  │  FUSE (composition│  missing chunks│     │  scan (T>64) · prefix fork   │          │
  │  is KILLED)      │                │     │  [T=64 PROVEN / T>64 needs-work]│        │
  └────────┬─────────┘                │     └───────────────┬──────────────┘          │
           │ ResumePlan (node+delta)  │                     │ 6-state boundary         │
           ▼                          │                     ▼                          │
  ┌────────────────────────────────────────────────────────────────────────┐         │
  │  HANDOFF (the seam)  load_prefill: 4 Mamba stacked + MLA latents -> [0:fill]│       │
  │  [PROVEN] in-memory 31/32 vs fp32 (sole flip 0.001-margin near-tie)        │       │
  │  [needs-work] disk roundtrip of all 6 states; [HIGH] fp16 baseline crashes │       │
  └───────────────────────────────────┬────────────────────────────────────┘         │
                                       ▼                                               │
  ┌──────────────────────── Decode Backbone (Pillar 1) ─────────────────────┐         │
  │  二象 two SKUs on ONE asset family, sharing the 6 states:                 │         │
  │   SKU-A 灯  <=8L pure-Mamba, 100%-ANE [PROVEN ceiling], 112-160 tok/s     │         │
  │   SKU-B 炉  24L hybrid (20 Mamba + 4 MLA), GPU [PROVEN >8L=GPU], 21.6 t/s │         │
  │  decode[1,1] recurrent  ⊕  verify[1,K] MIMO-GEMM [PROVEN 2.2-3.3x]        │──put────┘
  │  self-speculation: A drafts K -> B verifies in one verify[1,K] [needs-work]│
  │  MAX_SEQ guard [must-fix] · fused on-device argmax [buildable-now]         │
  └──────────────────────────────────────────────────────────────────────────┘
```

## 2. How a query flows (the closed loop)
1. **Router (P3 §8)** receives `(corpus_id, principal, live_binding_hash, want_tok_range)`. It gates on ACL(RESUME) and `binding_hash == live` (the §0 LAW), then finds the deepest valid ancestor in the prefix DAG whose lineage is the longest prefix of the request. Output is a **cost-bearing ResumePlan** (node + exact token delta to replay) — it FINDS and EXTENDS, it NEVER FUSES two states (composition is KILLED).
2. **Miss / partial -> Context Compiler (P2)** prefills the missing chunk(s). A short suffix is one T=64 tile `[PROVEN]`; a long/new corpus is segmented on the fixed tile-ladder {64, 256, 1024} and run through `scan_chunked` `[needs-work]` — or the device-proven driver-loop fallback (nc separate T=64 prefill calls carrying the O(1) boundary state between them, exact by T-independence `[PROVEN]`).
3. **Handoff (the seam)** = `load_prefill`: 4 Mamba boundary states placed direct, MLA latents scattered into `mla_kv[:, 0:fill, :]` with `mla_fill=prompt_len`. This is the State-VALUE handoff, `[PROVEN]` 31/32 vs fp32 — NOT the disk contract.
4. **Decode Backbone (P1)** mutates all 6 states in place (`function.run` stateful-KV — the ONE CoreAI lever genuinely exploited). SKU-B (24L GPU) is the quality lane; SKU-A (<=8L ANE) is the battery/draft lane. At temp 0, SKU-A drafts K tokens and SKU-B verifies them in one `verify[1,K]` MIMO-GEMM `[needs-work]` (rewind-free; the conv-verify amortization is `[PROVEN]` 2.2-3.3x). Per step the MAX_SEQ guard `[must-fix]` and the fused on-device argmax head `[buildable-now]` keep the loop safe and fast.
5. **Persist -> StateLake `put`** writes the resulting state as a new DAG node (parent + token-delta edge), canonicalized (angle-wrap `[PROVEN]` lossless), int8 `[PROVEN]` floor (int4 rejected at write), keyed + checksummed. Forking a shared corpus into N continuations copies the O(1) Mamba trunk once per branch — the Mamba advantage a Transformer KV (O(ctx) per branch) cannot match.

## 3. The shared state-artifact contract (`.statelake`)
Two physical files because the audit `[PROVEN]` the hybrid cache is O(1)-Mamba + O(ctx)-MLA (split lets the cheap fixed trunk stay hot while the growing tail pages):
- `mamba.trunk` — 20 layers x {angle, ssm, kprev, vprev}, int8, FIXED-shape O(1) (~1.48 MB). The genuinely portable core; a pure-Mamba 8L SKU writes only this.
- `mla.tail` — 4 layers x `[fill, 128]` latents, int8, O(ctx) (only `fill` rows written, not `max_seq`).
- `header.json` — the **binding_key** {weight_hash, model_config, converter_version, angle_wrap_flag, state_dtype=int8, asset_id, state_order=angle-first}, plus `fill`, `max_seq`, `lineage{parent_sha, branch_tok_range}`, checksums {trunk_blake3, tail_blake3, state_fingerprint}, `perm{corpus_id, acl, expiry}`. Loaded fail-closed on every resume.

## 4. Where each PROVEN device-fact anchors the system
| Architectural claim | Anchoring PROVEN fact |
|---|---|
| Fixed-shape CoreAI state asset exists | Mamba 4-state -> 1st-order recurrence, conv1d removed (`mamba3_trainable.py:7-14`) |
| Growing KV becomes a fixed CoreAI state | MLA one-hot-write + offset-mask bit-exact 0.0 fp32 (`mamba3_hybrid_decode_deploy.py:38-55`) |
| Handoff/router-resume is sound | angle-first ordering 0 slot mismatches; fp32 seam 3.04e-6; in-memory 31/32 vs fp32 |
| Two SKUs (ANE lamp / GPU furnace) | 8-layer ANE ceiling sharp cliff (L8 clean / L9 92 errors); 24L = GPU reader |
| Self-speculation is the right shape | conv-verify 2.2x@K4 / 3.3x@K8, free decode<->verify switch on one resident asset |
| int8 portable State-Cache survives long ctx | Mamba contractivity (A=-softplus<0) -> quant error decays; int8 holds / int4 breaks |
| Prefix-fork beats Transformer KV | Mamba boundary 4-state is O(1) and T-independent (`mamba3_trainable.py:262`) |

## 5. The 颠覆/极致/优雅 thesis, bounded honestly
- **颠覆 (disruptive):** a transformer's prefix KV is O(prefix_len) and position-bound; a Mamba prefix is a single O(1) fixed-shape tensor that is the *complete* summary of the prefix — so a phone can hold a LIBRARY of pre-understood corpora and fork any of them near-free. **Honest bound:** the *hybrid* artifact carries an O(ctx) MLA tail (92% at 32k); the truly-O(1) library is the pure-Mamba 8L SKU. The library/persistence/cross-version layer is `[research]`/100% unbuilt today.
- **极致 (maximal exploitation):** stateful-KV is exploited; the headroom (named, tagged) is fused on-device argmax `[buildable-now]`, dynamic-fill windowed MLA `[needs-work]` (87% of MLA FLOPs are wasted on empty slots early — `[PROVEN]`), and ComputeStream CoreAI-internal pipelining `[needs-work]` (only the cross-framework attempt failed at rho=0.83).
- **优雅 (elegant):** one state, every aspect touches it — prefill writes it, decode/verify mutate it, StateLake serializes it, the router replays it forward. The conv1d removal IS the elegance; two SKUs are two ends of one loop; the audit's honesty is designed-in (margin-aware gate, defined context boundary, version-keyed cache).

## Roadmap

1. PHASE 0 — Stop the bleeding (correctness + honesty, no new capability): land the MAX_SEQ silent-cap guard (must-fix 1), fix _zero_state device/dtype (must-fix 2), make the DUET comparison margin-aware + self-asserting + commit the device-log cert artifact (must-fix 3), and apply all OVERCLAIMED doc corrections (must-fix 9). Outcome: today's E2E becomes reproducible-from-repo and the docs stop overclaiming. No 一鸣惊人 claim before Phase 0 closes.
2. PHASE 1 — Certify the device fidelity that already exists: add the full-tensor elementwise max-rel-err readback to the prefill probe (must-fix 5), run MODE=ref HALF=1 to publish the fp16 HOSTREF and compare fp16-vs-fp16, run the autoregressive (argmax-fed-back) host+device comparison and PROMPT=64/CONT=192 high-occupancy MLA run (must-fix 8). Outcome: 'device reproduces host' becomes a defensible, elementwise, apples-to-apples, generation-aware claim.
3. PHASE 2 — The version-keyed state-artifact contract (the safety layer BEFORE persistence): implement the StateCacheArtifact header with the binding_key checked fail-closed on load (must-fix 4), then wire the actual disk serialize->file->deserialize of all 6 hybrid states and re-run the margin-aware comparison on the rehydrated-from-disk state (must-fix 10). Mechanism 5 (version key) MUST precede mechanism 4 (disk) or persistence ships a silent-corruption trap. Outcome: the in-process handoff becomes a trustworthy on-disk State-Cache.
4. PHASE 3 — Make prefill production-real for corpora: device-prove the T>64 scan_chunked path or ship the device-proven driver-loop fallback (must-fix 6); build the resumable-prefill asset (boundary state as both input and output) enabling intra-doc tile linking, prefix forking, incremental/streaming context; build the int8 prefill asset via the QuantLinear path to confirm the projected 0.5x. Outcome: the Context Compiler works on real documents, not 64-token toys.
5. PHASE 4 — The trained checkpoint + int8 certification gate: run the curriculum distillation (mamba3_cloud_distill TAU A/B), then re-confirm the int8 State-Cache floor on the distilled checkpoint with KL(int8||fp32) or greedy-verify acceptance (must-fix 7). Outcome: quality stops being unproven; int8 becomes a certified shippable precision, not a random-weight smoke test. This is the gate that turns 'plumbing demo' into 'usable reader.'
6. PHASE 5 — StateLake the database: 013_statelake.sql (state/edge/acl/binding tables), trunk/tail physical split, the prefix DAG with virtual nodes + copy-on-materialize replay (gated by the Phase-2 differential test), hot/warm tiering with explicit byte bookkeeping (never phys_footprint), model-version mass-invalidation + TTL expiry, the router find-path (ACL+binding+longest-prefix -> ResumePlan) and O(1) fork. Cross-corpus fuse rejected (composition KILLED). Outcome: the phone-resident library of pre-understood corpora, scoped honestly to short/medium context.
7. PHASE 6 — 极致压榨 performance headroom: fused GPU on-device argmax/top-k head (buildable-now, kills the per-token 128256-element CPU readback); dynamic-fill windowed MLA (needs-work, recovers the 87%-wasted-FLOP MLA drag); the SISO-vs-MIMO device A/B to MEASURE the MIMO arithmetic-intensity claim (must-fix 12); the 6-state dual-entrypoint self-speculation (<=8L ANE draft -> 24L GPU verify) with measured acceptance rate. Outcome: 21.6 -> 50+ tok/s and the MIMO/spec-decode wins move from projected to measured.
8. PHASE 7 — Research frontier (eyes-open, blocked-today): SSM-on-ANE / MLA-on-GPU intra-asset split (needs a learned low-rank D=128 residual bottleneck to give an ANE-legal boundary tensor, or a CoreAI fix); the learned MLA-latent compressor trained with decode-in-the-loop (the non-contractive cache makes compression error permanent); distributed/cloud chunk prefill shipping only the signed, keyed, checksummed artifact down to the phone. All gated on the version-keyed contract (Phase 2) and a trained checkpoint (Phase 4).

## Pillar — PILLAR 1 — Mamba-3 standalone DECODE backbone (极致压榨 CoreAI-0.4.0 / iOS-27 / A19): the closed-loop "二象 (two-aspect) recurrent reader" — one resident hybrid state, two compute SKUs (≤8L pure-ANE low-power / 24L GPU), MIMO conv-verify self-speculation, unified by an O(1)-Mamba + bounded-O(ctx)-MLA state ring.

# PILLAR 1 — The 二象 Recurrent Reader: a closed-loop Mamba-3 decode backbone for CoreAI-0.4.0 / A19

The design rests on ONE structural fact the audit proves and the rest of the field ignores: **Mamba-3's 4-state recurrence collapses to a single 1st-order contractive step with the conv1d removed** (`mamba3_trainable.py:7-14`). That collapse is what makes a *fixed-shape* CoreAI state asset possible, which is what makes stateful-KV on-device decode possible. Everything below is the maximal exploitation of that one fact, bounded honestly by what the audit found PROVEN vs FRAGILE vs FABRICATED.

The elegance (优雅) thesis: **one resident hybrid state, decoded two ways (recurrent `[1,1]` and conv-mode `[1,K]`), served two SKUs (≤8L pure-ANE / 24L GPU), persisted one way (int8 version-keyed) — a single closed loop where prefill→state→decode→verify→re-prefill all touch the same 6 NDArrays.**

---

## 1. The op-graph (decode step), and why it is the right one

Per Mamba-3 layer the decode step is (from `step_ref`, `mamba3_trainable.py:151-166`), all O(1), NO sequence buffer, NO conv1d:

```
new_angle = angle + dt·theta                      # RoPE phase accumulator (the ONLY growing scalar)
cos,sin   = cos(new_angle), sin(new_angle)
Brot,Crot = rope(B,cos,sin), rope(C,cos,sin)      # 2×2 real rotations (no complex dtype — audit-proven equiv)
cur       = einsum(x_mimo, Brot)    [H,P,N]        # MIMO outer-product → small GEMM
prev      = einsum(vprev, kprev)    [H,P,N]        # width-2 conv delay (the REMOVED conv1d, as a state read)
new_ssm   = α·ssm + β·prev + γ·cur                 # 1st-order, α=exp(dt·A)<0 → CONTRACTIVE
y         = einsum(Crot, new_ssm); y_out = einsum(y, mimo_o) + D·xin
```

Carried state = `(angle, ssm, kprev:=Brot, vprev:=x_mimo)` — 4 tensors, all T-independent shapes (audit cluster 7 PROVEN: 0 slot mismatches, fp32 seam 3e-6). The conv1d is gone because `kprev/vprev` are written *write-first* so `prev_t == cur_{t-1}` exactly — the audit's reproduced reformulation.

Per MLA layer the decode step is the fixed-buffer reformulation (`mamba3_hybrid_decode_deploy.py:38-55`), the lowering-safe pattern that makes a growing KV cache a fixed CoreAI state — **bit-exact vs the growing cache (audit cluster 3 finding 1: 0.0 fp32)**:

```
onehot = (arange(MAX_SEQ) == fill)                # NO dynamic index — the export-safe write
kv     = kv·(1-onehot) + c_t·onehot               # write latent at slot=fill
k,v    = k_up(kv), v_up(kv)                        # re-expand WHOLE buffer (the 87%-FLOP cost — §4)
scores = einsum(q,k)·scale; mask (idx≥fill+1)→-inf; a = softmax
fill' = fill + 1
```

**Resident state ring = 6 NDArrays**, stacked angle-FIRST (the segmenter discipline, `BASCoreAIHybridDecodeSession.swift:35`): `angle_all[20,H,N/2], ssm_all[20,H,P,N], kprev_all[20,H,R,N], vprev_all[20,H,P,R], mla_kv[4,MAX_SEQ,128], mla_fill[4,1]`. All mutated in place by `function.run` — **this is the ONE CoreAI lever (stateful-KV) the audit confirms is genuinely exploited**, and the spine of the loop.

---

## 2. The two SKUs — when to use which (the honest ANE-vs-GPU reality)

The audit is blunt (cluster 6 HIGH): **the 24L hybrid reader is a GPU reader, not an ANE decoder**; the only 100%-ANE artifact is ≤8 layers (addendum 10 sharp cliff: L8 clean, L9 = 92 errors). So I ship TWO SKUs, both real, selected by power/quality budget — not a fiction that 24L is ANE.

| | **SKU-A "灯 (lamp)" — ≤8L pure-Mamba-3, 100%-ANE** | **SKU-B "炉 (furnace)" — 24L hybrid, GPU** |
|---|---|---|
| Layers | ≤8 Mamba-3 (no MLA) | 20 Mamba-3 + 4 MLA @ L6/12/18/23 |
| Compute unit | 100%-ANE (addendum 10 PROVEN clean compile) | GPU (24L > 8L ceiling; co-load SIGSEGV avoided by sequential-load) |
| State | 4-state O(1) only (no MLA tail) | 6-state ring (O(1) Mamba + bounded O(ctx) MLA) |
| tok/s | 112–160 (warm, random-weight floor) | 21.6 unoptimized → target 50+ after §4 |
| Use when | battery-sensitive, short-context, draft lane | quality lane, RAG recall, dense token-mixing needed |

**The draft↔target pairing is the elegant part:** SKU-A is the *draft* and SKU-B is the *target* of a self-speculative loop (§5). They are not two products — they are two ends of one loop.

The dream SKU — **SSM-on-ANE / MLA-on-GPU intra-asset split** — is tagged `research` and the audit kills it cleanly: the D=1024 residual hidden cannot cross an ANE segment boundary (addendum 13), 2 co-resident assets SIGSEGV on ANE (Track E), and "fixed by asset-splitting" is FABRICATED (addendum 7). It only becomes buildable if a learned low-rank residual bottleneck (D=128) gives an ANE-legal boundary tensor, or CoreAI lifts the constraint. I name it because it IS the most elegant placement, but I do not pretend it ships.

---

## 3. The closed-loop internals (state ring, argmax, sampling)

The loop is `prefill → State-Cache → sequential-load → decode → (verify) → on-overflow re-prefill`, all over the same 6 NDArrays:

1. **Prefill** (`HybridM.prefill`): chunked-scan over the prompt → 5 stacked boundary states + MLA latents. Released after handoff (`pf=nil`) to dodge the GPU co-load. **Caveat (audit cluster 2 HIGH):** prefill is device-proven only at T=64 (scan_parallel); T>64 routes through scan_chunked which is host-equivalent (1e-13) but device-UNCONVERTED. The real-corpus path needs one T>64 chunked converter run before "production prefill" is true.
2. **Handoff** = in-memory 6-state copy → decode init (`load_prefill`, offset-mask puts prompt latents in `[0:prompt_len]`, fill=prompt_len). This is the State-VALUE handoff (PROVEN 31/32 vs fp32). It is NOT the disk contract — the audit (cluster 1/5) shows there is no disk roundtrip; "state-via-disk-style" is a misnomer to fix.
3. **Decode step** = `BASCoreAIHybridDecodeSession.step` advancing all 6 states in place.
4. **Argmax/sampling — the buildable-now win:** today argmax is a per-token full-vocab (128256) fp16 GPU→CPU readback (`argmaxF16`, lines 88-95) on the critical path — the audit names this as unexploited headroom. **Fuse a top-k+argmax tail into the exported graph** so the asset returns `next_token`+`topk_vals` instead of raw `logits`. Sampling (temp/top-p) then runs on the tiny top-k vector host-side. This removes a 128256-element copy every token.
5. **Overflow — the buildable-now safety fix:** the audit (cluster 3 finding 2 HIGH) proved at `fill==MAX_SEQ` the one-hot matches NO slot → the token is SILENTLY dropped and output corrupts to ~6e-2 with no NaN/crash. There is NO overflow handling anywhere. Add `assert fill < MAX_SEQ` (host) + emit `mla_fill` so the caller re-prefills (sliding the MLA window) before the cap. This converts an undetectable corruption into a defined boundary — a precondition for any real generation past 256 tokens.

---

## 4. 极致压榨 — pushing CoreAI-0.4.0 to its limit

The audit's gap analysis (cluster 6, "what are we NOT using"): of CoreAI's four advantages, only stateful-KV is used. The other three are the headroom:

- **(a) Dynamic-fill windowed MLA `[needs-work]`** — audit PROVES (cluster 3 finding 4) that k_up/v_up over the full MAX_SEQ=256 buffer is 87% of MLA FLOPs and ~267M wasted FLOPs/step early in decode, and *names it as the 21.6 tok/s drag*. Use CoreAI dynamic shapes (`resolvingDynamicDimensions`) to size MLA attention to actual `fill`. Risk: the codebase routed AROUND dynamic shapes (fixed buffer + one-hot) precisely because state is fixed-shape; dynamic state-path shapes are unverified on 0.4.0.
- **(b) ComputeStream CoreAI-INTERNAL pipelining `[needs-work]`** — audit (cluster 6) shows ComputeStream was only rejected for cross-framework CoreAI∥MLX, never tried internally. Overlap `prefill(corpus N+1) ∥ decode(corpus N)` on two ComputeStreams in one executor. Risk: the one overlap attempt measured ρ=0.83 (lost on A19 shared bandwidth) — intra-CoreAI may hit the same wall.
- **(c) On-device argmax `[buildable-now]`** — see §3.4, the cleanest immediate win.

The **stateful-KV vs per-token-loop** tension the prompt raises: CoreAI's stateful state IS already the right primitive (the 6 in-place NDArrays). The "naive serial per-token loop" is not the inefficiency — it is *correct* for autoregressive recurrence (each token depends on the prior). The real inefficiencies are the full-vocab readback (c) and the full-buffer MLA (a), not the loop itself.

---

## 5. Speculative / lookahead — the MIMO conv-verify self-loop

This is where Mamba-3's MIMO throughput becomes wall-clock-free. The audit PROVES (cluster 6) the conv-verify lane: ONE asset, TWO functions on the SAME resident state — `decode[1,1]` (recurrent) and `verify[1,K]` (multi-token GEMM) — with **device-measured 2.2x@K=4 / 3.3x@K=8 weight-amortization and a free decode↔verify switch** (`BASCoreAIMamba3DualSession.swift`). MIMO rank-R outer-products turn verify[1,K] into a GEMM that fills the memory-bound decode's idle compute.

**The 二象 self-speculation `[needs-work]`:** SKU-A (≤8L pure-Mamba, 100%-ANE) drafts K tokens; SKU-B (24L hybrid, GPU) verifies them in one `verify[1,K]` call. Mamba-3 is rewind-free (the target only forward-scans, the audit's stated property), and the MLA fixed-buffer already accepts a K-token fill via the offset-mask. Greedy acceptance (argmax-equality at temp 0) makes this byte-identical to single-model decode. This extends the proven 2-state dual asset to the 6-state hybrid.

**Honest contradiction (audit cluster 6 FRAGILE):** the conv-verify win is random-weight, L=8, int4, speed-only; the end-to-end ~1.8x is PROJECTED not measured; MIMO-vs-SISO is never A/B-isolated on device. The acceptance rate of an 8L draft against a 24L target is UNMEASURED and is the genuine open risk. Self-speculation is the right architecture but its payoff is a hypothesis until a trained checkpoint exists.

---

## 6. What makes it 优雅 (the closed-loop / 浑然一体 claim)

- **One state, every aspect touches it.** Prefill writes the 6 NDArrays; decode mutates them; verify mutates them; the State-Cache serializes them; re-prefill on overflow rewrites the MLA half. There is no second representation, no cross-engine copy (audit-proven: switch is a function dispatch on a resident asset).
- **The conv1d removal IS the elegance.** Because `prev_t == cur_{t-1}`, the recurrent delay is a state read, not a buffer — so decode is genuinely O(1) and the asset is genuinely fixed-shape. The whole stack stands on this one collapse.
- **Two SKUs are two ends of one loop**, not two products — the ANE lamp drafts, the GPU furnace verifies.
- **The audit's honesty is designed-in.** The fidelity gate is margin-aware (so an fp16 near-tie flip is accepted, a real bug is not); the context cap is a defined boundary (not a silent drop); the State-Cache is version-keyed (so a stale state is rejected, not silently garbage).

---

## 7. The honest ledger (what is NOT 万无一失)

- **Quality is unproven everywhere.** No trained checkpoint exists; every tok/s is random-weight, best-of-3 warm, single prompt length (audit cluster 2/6). "A usable reader does NOT exist" until distillation + held-out eval lands.
- **int8 floor is a smoke test, not a certification** (audit cluster 4 HIGH): random-weight + argmax-agreement; trained near-ties untested. Blocking gate before shipping int8.
- **Disk persistence + version-keyed library is the FLAGSHIP and is 100% unbuilt** (audit cluster 5 FABRICATED cross-version safety). A rehydrated state against mismatched weights is silent garbage today. This is the single most dangerous gap the moment persistence ships, and the most valuable thing to build next.
- **fp16 host reference crashes** (`_zero_state` omits device/dtype, audit cluster 1/7 HIGH) — the apples-to-apples baseline the whole fidelity story should rest on has never run.

**Novel mechanisms:**
- [buildable-now] Fused GPU on-device argmax/top-k head: append a top-k+argmax tail to the exported graph so the asset returns next_token+topk_vals instead of raw logits, killing the per-token 128256-element fp16 GPU→CPU readback the audit (cluster 6 gap-analysis) names as a critical-path cost. Removes argmaxF16's full-vocab host scan (BASCoreAIHybridDecodeSession.swift:88-95). Sampling (temp/top-p) then runs on the tiny top-k vector.
- [buildable-now] Margin-aware self-asserting fidelity gate + typed/deviced _zero_state: the audit (cluster 1 HIGH, cluster 7 HIGH) shows the fp16 host ref CRASHES (mamba3_trainable.py:262 / mamba3_hybrid.py:54 omit device=/dtype=) so 31/32 is only-vs-fp32 and the Swift compare ignores already-computed margins. Infer device/dtype from embedding.weight, then accept a device flip ONLY where host fp32 margin < fp16-ULP threshold. Turns eyeballed 31/32 into a CI gate.
- [buildable-now] Silent-context-cap guard: the audit (cluster 3 finding 2 HIGH) proved at fill==MAX_SEQ the one-hot matches NO slot → token SILENTLY dropped, output corrupts to ~6e-2 with no NaN/crash, no overflow handling anywhere. Add host-side assert fill<MAX_SEQ in the Swift step + emit mla_fill so the caller re-prefills before the cap. Converts undetectable corruption into a defined boundary.
- [needs-work] The 二象 (two-aspect) single-asset dual SKU: ONE exported HybridM, TWO entrypoints sharing the 6 resident states — decode[1,1] (recurrent) and verify[1,K] (MIMO conv-mode GEMM) — extending the proven 2-state BASCoreAIMamba3DualSession to the full 6-state hybrid. Self-speculation: ≤8L pure-Mamba ANE SKU-A drafts K, 24L GPU SKU-B verifies in one verify[1,K] (rewind-free; target only forward-scans). The MLA fixed-buffer already supports K-token fill via the offset-mask.
- [needs-work] Dynamic-fill windowed MLA: the audit (cluster 3 finding 4 PROVEN) shows 87% of MLA FLOPs / ~267M wasted FLOPs/step go to k_up/v_up over empty MAX_SEQ slots early in decode, and names it the 21.6 tok/s drag. Use CoreAI dynamic shapes (resolvingDynamicDimensions) to size MLA attention to actual fill instead of MAX_SEQ=256. Risk: CoreAI 0.4.0 dynamic-shape execution on the state path is unverified.
- [needs-work] ComputeStream CoreAI-INTERNAL pipelining: the audit (cluster 6 OVERCLAIMED) shows ComputeStream was only rejected cross-framework (CoreAI∥MLX), never tried internally. Overlap prefill(corpus N+1) ∥ decode(corpus N) on two ComputeStreams in one executor — the natural fit for the prefill-once-reuse-many library, currently strictly serial load→deinit→load. Risk: the one overlap attempt measured ρ=0.83 (lost on A19 shared bandwidth).
- [research] SSM-on-ANE / MLA-on-GPU intra-asset split: route the 20 contractive O(1) Mamba layers to ANE (in ≤8L groups) and the 4 O(ctx) MLA layers to GPU. BLOCKED today: D=1024 residual hidden can't cross an ANE segment boundary (addendum 13 PROVEN), 2 co-resident assets SIGSEGV on ANE (Track E), 'fixed by asset-splitting' is FABRICATED (addendum 7). Needs a learned low-rank D=128 residual bottleneck that IS an ANE-legal boundary tensor, or a CoreAI fix.
- [research] Disk-persisted, version-keyed State-Cache library: the audit (cluster 5 FABRICATED cross-version safety + HIGH no-persistence) shows the flagship library is 100% aspirational and a rehydrated state against mismatched weights is SILENT garbage. Bind every cached state to {weight-hash, model-config, converter-version, angle-wrap-flag, MAX_SEQ} and serialize all 6 states (incl. MLA latent + fill) to disk at the proven int8 floor. The genuine flagship, unbuilt.

**CoreAI/Mamba-3 advantages exploited:**
- Mamba-3 4-state→1st-order-recurrence collapse (mamba3_trainable.py:7-14): write-first kprev:=Brot/vprev:=x_mimo makes the rotated delay (prev_t==cur_{t-1}) a state read, REMOVING the conv1d — decode is a pure O(1) recurrent step. This is the structural reason a fixed-shape CoreAI state asset exists at all.
- CoreAI stateful-KV: the 6 resident NDArray states are mutated IN PLACE by function.run (BASCoreAIHybridDecodeSession.swift:71-83) — zero per-token state copy, zero recompile. The ONE of four CoreAI levers genuinely exploited, kept as the spine.
- Mamba-3 MIMO rank-R as arithmetic-intensity filler: SAME weights, two functions (decode[1,1]/verify[1,K]) on one resident asset (BASCoreAIMamba3DualSession.swift) — device-measured 2.2x@K4 / 3.3x@K8 weight-amortization (audit cluster 6 PROVEN). MIMO outer-products (mimo_x[H,P,R], mimo_o[H,R,P]) make verify[1,K] a GEMM filling memory-bound decode idle compute.
- Mamba contractivity (A=-softplus<0): the recurrent state is contractive so quant error DECAYS (audit cluster 5 / addendum 17 PROVEN + reproduced). This lets the Mamba half of the State-Cache survive int8 and long context — the cheap O(1) portable core.
- 8-layer pure-ANE compile envelope (audit cluster 6 / addendum 10 PROVEN sharp cliff): exploited as a real low-power SKU-A, not worked around — a ≤8L pure-Mamba-3 reader is 100%-ANE at 112-160 tok/s for the battery/draft lane.
- MLA fixed-buffer one-hot-write + offset-mask (mamba3_hybrid_decode_deploy.py:38-55): lowering-safe reformulation turning a growing KV cache into a fixed-shape CoreAI state — bit-exact vs growing cache (audit cluster 3 finding 1 PROVEN 0.0 fp32). Gives the SSM dense recall at ~16x smaller KV than full-MHA.

**⚠ Depends on audit-flagged-unproven:**
- The verify[1,K] conv-verify and the int8 State-Cache rest on RANDOM-weight + argmax-agreement evidence the audit flags as FRAGILE (cluster 4/6): a trained checkpoint's genuine semantic near-ties are exactly where int8 and a draft's acceptance could degrade, and that is UNTESTED. Self-speculation acceptance rate and the int8 floor are hypotheses until the distilled checkpoint exists.
- The SSM-on-ANE / MLA-on-GPU intra-asset split (research) directly needs the asset-split / segment-boundary capability the audit proved is DEVICE-REFUTED (cluster 6, addendum 13: D=1024 residual can't cross an ANE boundary; addendum 7: 'fixed by asset-splitting' is FABRICATED). Not buildable on CoreAI 0.4.0 without a residual-bottleneck redesign or a CoreAI fix.
- The disk-persisted version-keyed library (research) is the flagship the audit calls 100% aspirational (cluster 5 HIGH/FABRICATED): no persistence, no content-hash, no model-version key exist; a rehydrated state against mismatched weights is silent garbage today.
- ComputeStream CoreAI-internal pipelining (needs-work) was never tried; the only overlap attempt measured ρ=0.83 (LOSES on A19 shared bandwidth, audit cluster 6). Intra-CoreAI overlap may hit the same memory-bandwidth contention.
- Dynamic-fill windowed MLA (needs-work) assumes CoreAI 0.4.0 dynamic-shape execution the audit notes the codebase deliberately routed AROUND (fixed MAX_SEQ + one-hot precisely BECAUSE state is fixed-shape, cluster 6) — dynamic shapes on the state path are unverified.
- Every tok/s figure (21.6 hybrid GPU, 112-160 8L-ANE, 88-97 24L-GPU) is best-of-3 warm, random-weight, single prompt length; the audit (cluster 2) notes these are floors not steady-state p50/p95, and NO trained-checkpoint quality number exists anywhere (cluster 6: 'a usable reader does NOT exist').
- The prefill half is device-proven only at T=64 (scan_parallel); the real-corpus T>64 scan_chunked path is host-equivalent (1e-13) but device-UNCONVERTED/UNTESTED (audit cluster 2 HIGH) — so 'prefill→state' in the loop is not yet production-proven for long prompts.

## Pillar — PILLAR 2 — Hybrid-attention PREFILL as a "Context Compiler" (可缓存 cacheable · 可分块 chunkable · 可压缩 compressible · 可分布式 distributable · 可专用硬件加速 HW-acceleratable)

## Context Compiler — the framing

The hybrid prefill is not "a forward pass we tolerate before decode." It is a **compiler**: source = raw token stream of a corpus; intermediate representation = the per-layer boundary state (20 Mamba 4-states + 4 MLA latent caches); object file = a content-addressed, version-keyed, int8-quantized **State-Cache artifact**; linker = the prefill→decode seam (`load_prefill`) that links a compiled corpus into a live decode session. Like a real compiler it must be **cacheable** (don't recompile unchanged source), **separable/chunkable** (compile translation units independently), **compressible** (strip+pack the object), **distributable** (compile units in parallel, even off-device), and able to target **specialized hardware** (ANE for the ≤8L sub-graphs, GPU for the 24L whole).

The audit gives me an unusually clean foundation to build on and an unusually clear set of walls. The whole design is organized around ONE binding constraint the audit isolated (HIGH severity): **every device prefill run was T=64, which takes `scan_parallel`; the real-corpus T>64 path takes `scan_chunked`, a different op-graph that has NEVER been converted or run on device.** Pillar 2 is essentially "make the chunked path real on device, then build the compiler around it." Everything else (state, MLA buffer, int8 floor) is already host-proven and I lean on it.

---

## (1) CONTEXT PACKING — pack/segment/pad variable docs into the fixed-T prefill   `buildable-now`

**Grounded in:** CoreAI 0.4.0 is fixed-shape (every distinct T needs its own converted `.aimodel` — proven by the `_T64`-only asset inventory in `/tmp/draft_coreai`); the boundary 4-state is T-independent (`mamba3_trainable.py:262`, audit PROVEN); the input/token det-formulas are bit-identical Python↔Swift (audit PROVEN).

**Design — a fixed "tile ladder", not arbitrary T.** Compile a small *ladder* of prefill assets at power-of-two-ish tile sizes — e.g. T ∈ {64, 256, 1024} (and only those, because each is a separate compiled asset). A document of arbitrary length L is **segmented into tiles** along the ladder using a largest-tile-first greedy fill, then the tail is **right-padded to the next tile** and masked. Concretely:
- Pick the smallest ladder member ≥ remaining-length for the tail tile so padding waste is bounded by the *next-smaller* tile (≤ 1023 wasted positions worst case at the 1024 tile; far less if the ladder is denser).
- Padding is **causal-safe by construction**: the SSM scan and the MLA causal mask only ever look *backward*, so right-padding at the END of a tile cannot corrupt earlier positions — the boundary state is taken at the last *real* token index, not the padded end. This needs a "valid length" scalar input to the prefill asset so the boundary read is `state[valid_len-1]` not `state[T-1]` (today's converters hardcode `[-1]`; that is the one packing change — `prefill_state` returns `ssm_seq[-1]`, must become `ssm_seq[valid_len-1]` via a one-hot gather to stay lowering-safe, mirroring the MLA one-hot-write trick).
- **Inter-tile linking**: tiles within one document are NOT independent — tile k+1's prefill must start from tile k's boundary state. This is exactly PREFIX STATE REUSE (mechanism 3) applied intra-document: feed tile k's 4-state as the *initial* state of the tile k+1 prefill asset. This requires the prefill asset to accept an initial state (today it starts from zero) — a small converter change to register the boundary state as both an input and an output (a "resumable prefill" asset).

**Why a ladder beats one giant T:** a single T=8192 asset would (a) be a huge separate compile, (b) waste enormous padding on short docs, and (c) push the [T,T] scan intermediates past memory. A ladder of 3 tiles covers 64→∞ with ≤2 asset loads per doc and bounded waste. Tag: **buildable-now** for the fixed ladder + causal right-pad; the valid-length one-hot gather and resumable-prefill input are small, well-understood converter edits (the one-hot pattern is already proven in `mla_step_fixed`).

---

## (2) CHUNKED SCAN — the `scan_chunked` path for T>64, device-prove-able?   `needs-work` (THE binding gate)

**Grounded in:** `scan_chunked` (`mamba3_trainable.py:78-101`) is host-equivalent to `scan_parallel` at **1e-13 (fp64, T=512)** — audit PROVEN ("the algorithm is sound"). But the audit's HIGH finding: it is **torch-vs-torch only; never converted, never run on device.** `forward_seq`/`prefill_state` route to `scan_chunked` exactly when `T>64` (`:198`, `:219`).

**This is the single most important deliverable of Pillar 2.** Until one T>64 chunked-prefill asset runs on device and matches host, the "Context Compiler for real corpora" claim is unsupported — T=64 is a 64-token "document."

**The convertibility risk, concretely.** `scan_chunked` introduces ops the proven T=64 path never exercised on device: (a) `view(nc, C, H, ...)` reshapes that depend on `nc = ceil(T/C)` — a *data-independent* but T-derived shape, fine for fixed-shape export *as long as T is a compile-time constant* (it is — one asset per tile); (b) a **Python `for c in range(nc)` carry loop** (`:97-100`) that must unroll at export time (nc is constant per asset, so it unrolls — but it produces an nc-deep sequential dependency the GPU lowering must accept); (c) `torch.cat(outs)` over the unrolled chunks; (d) the `cijh,cjhps->cihps` chunk einsum. None are obviously fatal — they are the same *family* (`cumsum`/`masked_fill(-inf)`/`exp`/einsum) the prefill-probe already converted at T=64 (`mamba3_prefill_probe.py`, 2/2 convert) — but the unrolled carry loop is new and is exactly the kind of thing CoreAI 0.4.0 can choke on.

**Design / plan to de-risk in order:**
1. **Single-layer chunked convertibility gate** (extend `mamba3_prefill_probe.py`): export ONE `Lyr.prefill_state` at T=256 (forces `scan_chunked`, nc=4, C=64). Converter accepts → scaling is mechanical, same as the T=64 gate. Converter raises → we learn the exact blocking op in minutes (the prefill-probe already prints the failing op).
2. **Fallback already exists and is device-proven:** if the unrolled carry loop won't lower, **chunk the scan at the Swift driver level** — run nc separate T=64 prefill calls, carrying the boundary 4-state between them (this is mechanism 3 / mechanism 1's resumable-prefill asset, *reused*). This converts the "chunked scan" from an in-graph loop to a **driver loop over the already-proven T=64 asset** — strictly device-proven ops, at the cost of nc kernel launches. The audit-proven T-independence of the state (`:262`) is what makes this fallback exact.
3. **Host-fidelity gate before every convert** (the `eager-vs-exported-decomposed` check at `mamba3_hybrid_prefill_deploy.py:78-81`, audit PROVEN as a real elementwise CPU bound) — keep it, it catches decomposition bugs.
4. **Device numeric gate must be elementwise, not norm+head.** The audit's HIGH finding on the existing prefill device check: it compares only norm+sum+head[:4], which is permutation/sign-invariant and samples 0.006% of the tensor. **Add a full-tensor max-rel-err readback** (copy the whole device output, diff against a staged host tensor) — cheap and decisive, and the only way to certify the chunked path actually matches rather than coincidentally agreeing on norm.

Tag: **needs-work** — the host math is proven (1e-13); the device convert is unproven and is the gate; the driver-loop fallback makes the *capability* buildable-now even if the in-graph loop fails.

---

## (3) PREFIX STATE REUSE — Mamba's killer property   `buildable-now` (intra-doc) / `needs-work` (cross-query store)

**Grounded in:** the Mamba boundary 4-state is **O(1) and T-independent** (`:262`, PROVEN); the chunked-prefill→step_ref-decode seam is **fp32-exact, 3e-6, argmax 100%** (`mamba3_duet_handoff.py`, addendum, PROVEN); `run_ref(cont, init=state)` resumes from any boundary state (`mamba3_hybrid.py:70`).

**This is the architectural payoff that attention CANNOT replicate.** A transformer's prefix KV is O(prefix_len) and tied to absolute positions; a Mamba prefix's boundary state is a **single O(1) fixed-shape tensor** that is the *complete* summary of the prefix. So: compile a shared prefix ONCE, snapshot its boundary state, and **fork** it for every query that shares that prefix.

**Architecture — "compiled prefix + query suffix":**
- A corpus/system-prompt/document that is reused across many queries is compiled to a **prefix State-Cache** = its boundary state after prefill (Mamba 4-states are O(1); MLA latents are O(prefix_len) — see the honesty note below).
- Each incoming query loads the prefix State-Cache as the decode session's *initial* state (exactly `load_prefill`, already in `BASCoreAIDuetProbe.swift:84-89`), then prefills ONLY the query suffix (a tiny tile), then decodes. The expensive corpus prefill is amortized across all queries.
- **Forking is copy-not-mutate** (matches the immutability rule): the cached prefix state is never mutated; each query gets a *copy* into its decode session. The Mamba half is trivially forkable (small fixed tensors); the MLA half is a `[prefix_len, 128]` latent buffer that is also copy-forked.

**Honesty note grounded in the audit (MISLEADING finding on "O(1) portable"):** the *hybrid* prefix cache is **O(1)-Mamba + O(prefix_len)-MLA** (the 4 MLA layers cache one 128-wide latent per prefix token; at 32k prefix the MLA half is ~92% of the artifact). So prefix reuse is "16× smaller than a transformer KV prefix and the SSM half is free," NOT "O(1)." The truly-O(1) reuse is reserved for the **pure-Mamba 8L SKU** (no MLA) — which is also the only 100%-ANE artifact. Design implication: offer **two reuse tiers** — (a) hybrid prefix reuse (best quality, O(ctx) MLA tail, GPU) and (b) pure-Mamba prefix reuse (truly O(1), ANE-eligible, slightly weaker recall).

Tag: **buildable-now** for the fork-and-resume mechanism (the seam is proven, `load_prefill` exists). The cross-query *store* that holds many prefix caches is mechanism 5's job and is **needs-work** (no store exists today — audit FABRICATED/HIGH).

---

## (4) STATE HANDOFF — the prefill→decode seam, now proven in-memory   `buildable-now` to formalize / `needs-work` for disk

**Grounded in:** in-memory handoff is a Swift `[String:[Float16]]` dict copied via `copyF16` and fed into decode init (`BASCoreAIDuetProbe.swift:64-89`); the seam reproduces host fp32 monolithic at **31/32 argmax** (PROVEN-reproduced, sole flip a 0.001-margin near-tie). Audit HIGH findings: there is **NO disk roundtrip** ("state-via-disk-style" comment is misleading), and the apples-to-apples fp16 baseline **crashes** (`_zero_state` omits `device=`/`dtype=`).

**Formalize the handoff as a typed, versioned contract — the compiler's "object file format":**
```
StateCacheArtifact v1 {
  header:  { magic, format_version, model_id, weight_hash, config_hash,
             converter_version, angle_wrap_flag, precision(int8), tile_T,
             prefix_token_count, valid_len }
  layout:  ordered [angle_all, ssm_all, kprev_all, vprev_all, mla_kv, mla_fill]
           (EXACT stateNames order the decode descriptor declares — audit PROVEN
            angle-first ordering survives the convert with 0 slot mismatches)
  payload: int8 quantized tensors + per-tensor scales (symmetric per-tensor)
  trailer: checksum (mechanism 5)
}
```
**Three concrete fixes the audit demands before this ships:**
1. **Fix `_zero_state` device/dtype** (HIGH, in both `HybridM._zero_state` `mamba3_hybrid.py:54` and `M.run_ref` `:262`): infer `device=`/`dtype=` from `self.embedding.weight`. This unblocks the fp16/MPS host reference so the device fp16 output can be compared apples-to-apples instead of against fp32 (against which a faithful fp16 device is *expected* to flip near-ties).
2. **Margin-aware acceptance** (HIGH): the probe prints `DEV_CONT_ARGMAX` and a human eyeballs it. Bake the comparison in: the host already computes top1-top2 margins (`ref_e2e:163-164`); accept a flip *only* where the host margin is below an fp16 threshold, reject otherwise. Convert "print-and-eyeball" into an asserting gate.
3. **Disk serialize/deserialize of all 6 states** (the seam the audit says is "REMAINING"): write the `StateCacheArtifact` to disk and read it back, then run the SAME 31/32 (now margin-aware) comparison on the rehydrated-from-disk state. Today only the in-memory dict roundtrip exists.

Tag: **buildable-now** to formalize the in-memory contract and fix the two HIGH numeric gaps; **needs-work** for the actual disk roundtrip of the full hybrid 6-state (it has literally never been written to disk).

---

## (5) STATE CONSISTENCY CHECK — checksums + model-version match   `buildable-now` (and the audit's single most dangerous gap)

**Grounded in:** audit FABRICATED finding — "cross-model-version safety + state expiry/invalidation": *"NONE of it exists … A serialized recurrent state is silently invalid if reloaded against different weights (no key guards this) … This is the single most dangerous gap once persistence is built."* And the angle-wrap canonicalization (`cache_serialize_state`) is required for int8 long-context survival (PROVEN).

**This is the gate that must land BEFORE mechanism 4's disk persistence, not after.** A rehydrated recurrent state against mismatched weights produces **silent finite garbage** (exactly like the MAX_SEQ overflow: no NaN, no crash, undetectable by the caller). Design:

- **Binding key (header) checked on load, fail-closed:** `{weight_hash, config_hash, converter_version, angle_wrap_flag, precision, tile_T, model_id}`. `weight_hash` = hash of the actual checkpoint tensors used to build the prefill asset; `config_hash` = D/H/P/N/R/MLA-positions. On `load_prefill`, if any header field mismatches the *current* decode asset's embedded key → **refuse to load, re-prefill** (never silently resume). This is the project's own `content-hash-cache-pattern` skill applied to model state.
- **Integrity checksum (trailer):** a checksum over the int8 payload + scales, validated on read — catches disk corruption / truncated writes.
- **Canonicalization before checksum:** apply `cache_serialize_state` (angle-wrap to (-π,π]) BEFORE quantize+checksum so the stored bytes are canonical and reproducible (PROVEN lossless for the rotation; required for int8 to survive long prompts). This makes the checksum stable across runs.
- **Precision floor enforced in the header:** precision MUST be ≥ int8 (the proven floor set by the non-contractive MLA latent; int4 breaks at 88-89%). Reject int4 artifacts.
- **Expiry/invalidation:** a `model_id`+`weight_hash` change invalidates ALL prefix caches built against the old weights (an LRU/TTL store keyed on the binding key — the project's `BASEventSourcedMemoryAtomStore` governed-memory pattern is the natural host).

**Caveat carried forward (audit):** the int8 floor is proven only on **random-weight + argmax-agreement**, which is necessary-not-sufficient — a trained model's semantic near-ties are exactly where argmax punishes int8. So the consistency check must also gate on a **re-confirmation of the int8 floor on the distilled checkpoint** (a stricter metric: KL(int8‖fp32) or greedy-verify acceptance) before certifying int8 as the shippable artifact precision. Tag: **buildable-now** (the key/checksum/canonicalization are pure plumbing); the int8-floor-on-trained-checkpoint re-confirmation is **needs-work** (blocked on a trained checkpoint).

---

## (6) EVIDENCE COMPRESSOR — compress/distill a long context's state   `research` (with a buildable-now first step)

**Grounded in:** MLA *already* compresses KV ~16× (one 128-wide latent per token vs 2048-wide full KV — `mamba3_mla.py:28`); the Mamba 4-state is already an O(1) lossy learned summary of the whole prefix; int8 is the proven cache floor; the MLA latent is **non-contractive** (errors don't decay — `mamba3_mla.py:12-14`).

**Two layers of compression, one built, one research:**
- **Built-in (buildable-now):** the artifact format already compresses two ways — (a) MLA's down-projection (16× vs full KV), (b) int8 quant (2× vs fp16) with angle-wrap canonicalization making it survive long context. Ship these. The Mamba half is the ultimate compressor: a fixed O(1) tensor that summarizes an unbounded prefix.
- **Learned MLA-latent compressor (research):** the O(ctx) MLA latent tail is what bounds "library of corpora" density (92% of a 32k artifact). A learned compressor could shrink the MLA latent buffer — e.g. **strided/pooled latent eviction** (keep every k-th latent or attention-weighted-pool spans into fewer latents) or a small learned **latent autoencoder** that maps `[prefix_len,128] → [m,128]` with m≪prefix_len. CRITICAL constraint from the audit: because the MLA cache is **non-contractive**, any compression error is **permanent** (re-read by softmax every step), so a learned compressor must be trained with the downstream decode in the loop (distillation objective on the compressed-vs-full continuation), NOT a standalone reconstruction loss. This is genuinely **research** — it changes the model, needs a trained checkpoint, and the non-contractivity makes it risk-laden.
- **Relate to distillation:** the existing top-K KD harness (`mamba3_cloud_distill.py`, TAU=1) distills the *teacher* into the student; the evidence compressor would distill the *student's own long-context state* into a smaller state — a second, orthogonal distillation. Sequence them: ship int8+MLA-16× now, research the learned latent compressor after a trained checkpoint exists.

Tag: **research** for the learned compressor; **buildable-now** for the int8+MLA-16× already in the artifact.

---

## (7) MORE — my additions

### 7a. SILENT-CAP GUARD — close the MAX_SEQ=256 overflow trap   `buildable-now` (HIGH, must-fix before any production decode)
**Grounded in:** audit HIGH finding — at decode step 256 the one-hot write `(idx==fill)` matches NO slot, `c_t` is **silently dropped**, the mask masks nothing, output corrupts to ~6e-2 garbage with **no crash/NaN** — "a caller cannot even detect it." There is zero overflow handling anywhere. The "re-prefill on overflow fallback" the prompt premises **does not exist**.
**Design:** (a) host/driver assert `fill < MAX_SEQ` before each MLA step (fail-loud); (b) a defined overflow policy — the natural one for a Context Compiler is **re-compile**: when fill hits MAX_SEQ, snapshot the Mamba 4-states (O(1), carry forward exactly), evict/pool the MLA latents (mechanism 6), and continue. This is the *real* "re-prefill on overflow" the system needs — and it composes with PREFIX REUSE (the prefix state is already snapshotted). This is the highest-priority correctness fix in Pillar 2.

### 7b. DISTRIBUTED / PARALLEL CHUNK PREFILL   `needs-work`
**Grounded in:** chunked scan = independent intra-chunk matmuls + a thin inter-chunk carry (`scan_chunked` structure). The intra-chunk work (the `cijh,cjhps` einsum, 87%-class of the FLOPs) is **embarrassingly parallel across chunks**; only the carry loop is sequential.
**Design:** compile each tile/chunk's intra-chunk prefill independently (across GPU command buffers, or even off-device/cloud for very long corpora), then run the cheap O(nc) carry recurrence to stitch boundary states. For a phone-resident *library*, corpus compilation can even happen **on a companion device or cloud** and ship only the (int8, version-keyed, checksummed) artifact down — the artifact format (mechanism 4/5) is exactly the wire format. This is the "可分布式" pillar. Tag: needs-work (depends on chunked-scan device-proof; the cloud path depends on the version-key so a cloud-compiled artifact is trustable on-device).

### 7c. ANE-ACCELERATED CHUNK SUB-GRAPHS   `research`
**Grounded in:** audit PROVEN — a sharp **8-layer per-asset ANE ceiling** (L=8 → 0 compile errors/100%-ANE; L=9 → 92 errors/off-ANE), root-caused to the D=1024 residual hidden not being an ANE segment-boundary tensor (addendum 13). The shipped 24L reader is therefore honestly a **GPU** reader (audit MISLEADING finding: "stop framing the 24L as an ANE decoder").
**Design (research, eyes-open):** the pure-Mamba ≤8L SKU IS 100%-ANE-eligible. A Context Compiler could route the **pure-Mamba prefix-reuse tier** (mechanism 3b) to ANE for the chunk prefill, keeping the 24L hybrid on GPU. Honesty constraint the audit nails: there is **no positive ANE-fraction measurement possible** in CoreAI 0.4.0 (no compute-plan readback — addendum 16), so "ANE-accelerated" can only ever be a *negative* (no-compile-error) signal. And asset-splitting to dodge the 8L ceiling is **device-falsified** (2 assets → SIGSEGV; multi-process → residual-hidden can't cross the boundary). So ANE acceleration is restricted to genuinely ≤8L sub-graphs, never a split 24L. Tag: research.

### 7d. INCREMENTAL / STREAMING CONTEXT   `buildable-now`
**Grounded in:** T-independent state (`:262`) + resumable-prefill asset (mechanism 1/3).
**Design:** a streaming corpus (logs, a growing doc) is compiled **incrementally** — each new tile resumes from the running boundary state and updates the artifact in place (Mamba state replaced; MLA latents appended into the fixed buffer until the cap, then mechanism 7a kicks in). This is "可分块" extended over time. Tag: buildable-now (it's prefix reuse applied to a growing prefix).

### 7e. DEDUP OF REPEATED CHUNKS   `buildable-now`
**Grounded in:** the project's `content-hash-cache-pattern` skill; tiles are content-addressable.
**Design:** content-hash each *tile's input* (token ids + the incoming boundary-state hash, since a tile's output depends on both). Two documents sharing a boilerplate header/license/system-prompt prefix produce the **same tile hash for the shared prefix** → reuse the compiled tile's boundary state instead of recompiling. This is classic compiler object-file caching, and it makes the "library of pre-understood corpora" dense by sharing common prefixes. Caveat: dedup is only valid *within* a (weight_hash, config_hash, converter_version) cohort — the mechanism-5 binding key is the cache namespace. Tag: buildable-now (hash + the mechanism-5 key already define the namespace).

---

## End-to-end pipeline (the compiler)

```
RAW CORPUS ──segment(tile ladder, 7d dedup)──► TILES
   │                                              │
   │                              per-tile prefill (chunked scan, mech 2)
   │                              ├─ resumable: tile_k state ─► tile_{k+1}  (mech 1/3 intra-doc)
   │                              └─ parallel/distributed/cloud (mech 7b)
   ▼                                              ▼
BOUNDARY STATE (20 Mamba 4-state O(1)  +  4 MLA latent O(ctx))
   │
   ├─ canonicalize: angle-wrap (-π,π]  (PROVEN lossless)         (mech 5)
   ├─ compress: MLA 16× + int8 (+ research latent compressor)   (mech 6)
   ├─ key+checksum: {weight_hash,config_hash,converter_ver,...}  (mech 5)
   ▼
STATE-CACHE ARTIFACT  ──disk persist (mech 4 needs-work)──►  PHONE LIBRARY
   │                                                              │
   │   per query:  load(verify key+checksum) ─fail-closed re-compile (mech 5/7a)
   ▼                                                              ▼
DECODE SESSION  ◄── load_prefill (fork prefix, copy-not-mutate, mech 3) ◄── prefix artifact
   └─ teacher-forced/autoregressive decode, MAX_SEQ guard (mech 7a)
```

## Hardest-honesty summary (what this design must NOT pretend)
- "Device prefill works" today means **T=64 only** (scan_parallel). Mechanism 2 (chunked scan on device) is THE gate; until it (or its driver-loop fallback) passes an *elementwise* device numeric check, "Context Compiler for real corpora" is aspirational.
- The flagship persistence/library/cross-version layer is **~unbuilt** (audit HIGH/FABRICATED). Mechanisms 4 and 5 are net-new; mechanism 5 (version key) must land **before** mechanism 4 (disk) or persistence ships a silent-corruption trap.
- The "O(1) portable" pitch is true only for the **pure-Mamba SKU**; the hybrid artifact carries an O(ctx) MLA tail.
- int8 is proven only on random weights + argmax; re-confirm on the trained checkpoint before certifying.
- The 31/32 device match is vs fp32; fix `_zero_state` to get the apples-to-apples fp16 baseline, and make acceptance margin-aware.

**Novel mechanisms:**
- Fixed tile-ladder context packing (T in {64,256,1024}) with causal right-pad + valid-length one-hot boundary gather + resumable-prefill (initial-state input) for intra-doc tile linking — buildable-now (one-hot gather pattern already proven in mla_step_fixed)
- Driver-level chunked scan as the fallback for the in-graph carry loop: run nc separate device-proven T=64 prefill calls carrying the O(1) boundary state between them — converts 'chunked scan' from an unproven in-graph unrolled loop to strictly device-proven ops — buildable-now (state T-independence is PROVEN); in-graph scan_chunked convert is needs-work
- Compiled-prefix-fork: snapshot a shared prefix's boundary state once, copy-fork (immutable) it as the initial state for every query that shares the prefix — Mamba's killer reuse property attention cannot match — buildable-now (seam proven, load_prefill exists)
- Versioned StateCacheArtifact object-file format with a binding key {weight_hash,config_hash,converter_version,angle_wrap_flag,precision,tile_T} checked fail-closed on load — closes the audit's single most dangerous gap (silent garbage on weight mismatch) — buildable-now, MUST precede disk persistence
- Silent-cap guard + re-compile-on-overflow policy: fail-loud assert fill<MAX_SEQ, then snapshot Mamba O(1) state + pool MLA latents to continue past 256 — fixes the audit's HIGH silent-corruption trap that has zero handling today — buildable-now
- Content-hash tile dedup namespaced by the mechanism-5 binding key: shared boilerplate/system-prompt prefixes across documents reuse one compiled tile — buildable-now (project content-hash-cache-pattern skill)
- Learned MLA-latent compressor trained with the decode in the loop (NOT standalone reconstruction) because the MLA cache is non-contractive so compression error is permanent — research (changes model, needs trained checkpoint)
- Distributed/cloud chunk prefill shipping only the int8+keyed+checksummed artifact down to the phone — the artifact format is the wire format — needs-work (depends on chunked-scan device-proof + version key)
- ANE-routed pure-Mamba <=8L prefix-reuse tier alongside the GPU 24L hybrid tier — research (no positive ANE-fraction measurement possible in CoreAI 0.4.0; restricted to genuinely <=8L, asset-split is device-falsified)

**CoreAI/Mamba-3 advantages exploited:**
- Mamba-3 O(1) recurrent boundary state is T-independent (mamba3_trainable.py:262, audit PROVEN) — THE enabling property for prefix-state reuse: a whole prefix compiles to one fixed-shape tensor a transformer KV can never match (O(prefix_len) and position-bound)
- Mamba state contractivity (A=-softplus<0): quant/serialization errors DECAY not compound (addendum 17 PROVEN) — lets the Mamba half of the artifact survive int8 over long context
- MLA latent down-projection caches one 128-wide latent/token = ~16x smaller KV than full MHA (mamba3_mla.py:28) — the built-in evidence compressor for the dense-recall layers the SSM lacks
- CoreAI stateful KV / resident NDArray states (the ONE CoreAI lever the audit confirms is genuinely exploited) — the 6 resident decode states are mutated in place, which is what makes load_prefill (the prefix fork / state handoff) possible at all
- chunked-scan decomposes into embarrassingly-parallel intra-chunk matmuls + a thin O(nc) carry (scan_chunked structure) — the structural basis for distributed/parallel/cloud chunk prefill (可分布式)
- pure-Mamba <=8L sub-graphs are 100%-ANE-eligible (sharp 8-layer ceiling, addendum 10 PROVEN) — a real specialized-HW lane for the O(1) prefix-reuse tier, kept honest by the audit (24L hybrid is GPU, not ANE)
- MLA one-hot-write + offset-mask fixed-buffer is bit-exact vs growing cache (0.0 fp32, addendum 26 PROVEN) — the lowering-safe primitive reused for valid-length boundary gather in context packing

**⚠ Depends on audit-flagged-unproven:**
- Mechanism 2 (chunked scan on device) directly contradicts the audit's UNTESTED/HIGH status: every device prefill was T=64 (scan_parallel); scan_chunked is host-proven (1e-13) but NEVER converted or run on device — I tag it needs-work and provide a device-proven driver-loop fallback rather than claiming it works.
- Mechanism 4 (disk persistence of the full hybrid 6-state) contradicts the audit's HIGH 'NO disk roundtrip exists' finding — the current handoff is in-memory Swift dict only; I treat disk as net-new needs-work, not proven.
- Mechanisms 3/6 lean on the artifact being O(1)-portable, which the audit flags MISLEADING for the hybrid (MLA half is O(ctx), ~92% at 32k) — I explicitly split into a hybrid (O(ctx) MLA) tier and a pure-Mamba (true O(1)) tier rather than claiming O(1) for the flagship.
- Any int8-precision claim in mechanisms 4/5/6 rests on the audit's FRAGILE/HIGH finding that the int8 floor is proven only on random weights + coarse argmax; I gate certification on a trained-checkpoint re-confirmation, but until that lands the int8 floor is necessary-not-sufficient.
- The device numeric gate I require (full elementwise readback) implicitly concedes the audit's HIGH finding that the existing 'numerically exact rel-err<2e-4' prefill claim is a norm+sum+head[:4] match (permutation-invariant, 0.006% sampled) — so 'exact' is currently unproven elementwise on device.
- Mechanism 7c (ANE chunk acceleration) contradicts the route's 'ANE decode' framing the audit calls MISLEADING — the 24L hybrid is a GPU reader; ANE is restricted to genuinely <=8L pure-Mamba sub-graphs and even there only a negative (no-compile-error) signal exists, never a positive ANE-fraction measurement (CoreAI 0.4.0 has no compute-plan readback).
- The device 31/32 handoff fidelity that mechanism 4 builds on is, per the audit, vs fp32 with a human-eyeballed uncommitted comparison and the apples-to-apples fp16 baseline crashing — so 'handoff proven' is conditional on the _zero_state fix and margin-aware assert I list, not currently airtight.

## Pillar — PILLAR 3 — StateLake: the Mamba recurrent state as a lineage-aware, versioned, tiered neural-state DATABASE (State Market / State Router + StateLake)

# StateLake — a neural-state database for Mamba-3 hybrid recurrent state

> Audit posture: the only thing that exists today is one **in-process** Swift dict handoff (`BASCoreAIDuetProbe.swift` `handoff:[String:[Float16]]`) and the host-side serialize transform `cache_serialize_state_hybrid` (`mamba3_hybrid.py:88`). There is **NO** disk store, content-hash, version key, expiry, lineage, permissions, or tiering. The route's own self-audit says so verbatim. **Composition of states was KILLED** — I respect that and the router below NEVER fuses two states into a new SSM state. Everything here is new; each piece is tagged.

---

## 0. The one law that governs the whole system (the audit's most dangerous gap)

The audit (cluster 5, FABRICATED, HIGH): *"A serialized recurrent state is silently invalid if reloaded against different weights … the single most dangerous gap once persistence is built."* And cluster 3 (HIGH): MAX_SEQ=256 is a **silent** hard cap — at step 256 the new token is dropped and output corrupts with no crash/NaN.

**Law: a state is only ever loaded into the EXACT graph that produced it, and only within its valid fill window. Any mismatch is a hard, loud, fail-closed error — never a silent rehydrate.** This is the spine of the schema (the `binding_key` and `fill`/`max_seq` fields are mandatory, not optional metadata).

---

## 1. The STATE ARTIFACT format (`.statelake` bundle) — **buildable-now**

A state artifact is a directory bundle (mirrors the `.aimodel` convention already in the repo) holding the 6 resident states + a header. I deliberately separate the **O(1) Mamba trunk** from the **O(ctx) MLA tail** into two physical files, because the audit proved they have different growth and different invalidation behaviour (Mamba contractive/quant-decays; MLA non-contractive/quant-accumulates).

```
<sha>.statelake/
  header.json            # the binding key, lineage, fill, checksums (see §1.1)
  mamba.trunk            # 20 layers x {angle,ssm,kprev,vprev}, int8, FIXED-shape O(1)  (~1.48 MB)
  mla.tail               # 4 layers x [fill, D_LATENT] latents, int8, O(ctx)            (grows)
  manifest.sig           # optional Ed25519 over header.json (permissions, §4)
```

### 1.1 `header.json` schema (every field load-bearing)

```jsonc
{
  "schema": "statelake/1",
  "binding_key": {                       // THE LAW (§0). Load fails closed unless ALL match the runtime graph.
    "weight_hash":   "blake3:…",         // hash of the .aimodel weight tensors (NOT the random seed)
    "model_config":  "H16_P64_N64_R4_D1024_L24_MLA[6,12,18,23]_DC128",
    "converter_ver": "coreai_torch-0.4.0",
    "asset_id":      "Mamba3HybridDecode_L24_M256",
    "angle_wrap":    true,               // serialize wrapped angle to (-pi,pi] (mamba3_trainable.py:40)  PROVEN lossless
    "state_dtype":   "int8_pertensor_persym",   // int8 = the PROVEN floor; int4 REJECTED at write time
    "state_order":   ["angle","ssm","kprev","vprev","mla_kv","mla_fill"]  // angle FIRST (segmenter discipline, PROVEN)
  },
  "fill": 64,                            // valid MLA slots == prompt_len. HARD: fill <= max_seq (no silent overflow)
  "max_seq": 256,                        // the asset's fixed MLA buffer. Crossing it is a DEFINED error, not a drop
  "tok_count": 64,                       // tokens absorbed into this state (for the router + lineage)
  "lineage": { "parent_sha": "blake3:…", "branch_tok_range": [0,64], "op": "prefill" },
  "checksums": {                         // Pillar-2 consistency check (§5)
    "trunk_blake3": "…",
    "tail_blake3":  "…",
    "state_fingerprint": "…"             // cheap structural digest: per-layer L2 norm + ssm trace + angle hist (8 floats/layer)
  },
  "perm": { "corpus_id": "…", "acl_ref": "…", "expiry_utc": "…", "ttl_s": 604800 },
  "provenance": { "created_utc": "…", "host": "iPhone Air A19", "prefill_ms": 43, "tier_origin": "device" }
}
```

**Why two physical files (`mamba.trunk` / `mla.tail`):** the audit proved (cluster 5, MISLEADING) the hybrid cache is **O(1)-Mamba + O(ctx)-MLA**, with MLA at **92% of the artifact at 32k**. Splitting them lets the tier policy (§6) keep the cheap fixed-size trunk hot in RAM while paging the growing MLA tail to disk/cloud independently. It also lets a *pure-Mamba 8L SKU* (the genuinely O(1) artifact) write only `mamba.trunk` with an empty tail.

### 1.2 Serialization (the wire format) — **buildable-now**, reuses proven code

Reuse `cache_serialize_state_hybrid(state, quant)` exactly as-is — it already (a) wraps the angle (PROVEN lossless for cos/sin), and (b) takes an `int8` quant closure. The new code is only the *framing*:

- `mamba.trunk`: for each of the 20 Mamba layers, concatenate `[angle(512), ssm(65536), kprev(4096), vprev(4096)]` int8 + one fp32 per-tensor scale each → 74240 int8 + 4 scales/layer.
- `mla.tail`: for each of the 4 MLA layers, write `fill` rows of `[D_LATENT=128]` int8 + one scale. **Only `fill` rows are written** (not `max_seq`), so the on-disk tail is genuinely O(ctx), not O(256).
- Rehydrate is the inverse → exactly the tensors `HybridDecodeFixed.load_prefill(state, prompt_len)` consumes (`mamba3_hybrid_decode_deploy.py:89`). The `prompt_len` it needs == `header.fill`.

**Write-time guards (close the audit's silent traps):**
1. Reject `state_dtype:int4` at write — int4 is PROVEN-broken (cluster 4, 88% argmax / first divergence @tok6). int8 is the floor.
2. Assert `fill <= max_seq` at write AND at load. The Swift `BASCoreAIHybridDecodeSession.step` has *no* fill check (cluster 3, HIGH) — StateLake adds it as a precondition: a load with `fill==max_seq` is refused, a decode that would push `fill` past `max_seq` raises `StateLakeOverflow` (see §7 overflow policy) instead of silently dropping the token.

---

## 2. LINEAGE — the prefix DAG — **buildable-now (storage) / needs-work (the resume guarantee)**

A state is a **node**; its `parent_sha` + `branch_tok_range` is an **edge**. Because a prefill of `tokens[0:k]` is a deterministic prefix of `tokens[0:k+j]`, lineage forms a DAG where a child node's state is "parent's state advanced by the tokens in `branch_tok_range`."

```
root(∅) ──prefill[0:64]──▶ S_doc          (corpus "contract.pdf", fill=64)
                              ├─append[64:96]──▶ S_doc_qA   (user asked question A)
                              └─append[64:80]──▶ S_doc_qB   (user asked question B)
```

- **Edges store the token delta, not a re-derivation.** A child is materialized by loading the parent state and decoding `branch_tok_range` (cheap — Mamba is O(1) per token; the MLA tail just appends `len(range)` latent rows). This is the PROVEN `load_prefill → step` path, run forward.
- **The DAG lives in SQLite** (`edges` table, §3). Reconstructing any node = walk to the nearest **materialized** ancestor + replay the deltas. A node may be *virtual* (only its edge stored, replay on demand) or *materialized* (its `.statelake` bundle persisted) — a classic copy-on-materialize tree.
- **Audit guard:** the DAG ONLY ever does `parent → child by appending tokens`. It NEVER merges two siblings into a third state — that would be state composition, which the audit says was **KILLED**. The DAG is strictly a tree of prefixes (forking out, never joining in).

**`needs-work`:** the "child = parent advanced by delta" identity is asserted by the T-independent shape argument (cluster 5, PROVEN: zero-state has no T dim, `prefill_state` indexes `[-1]`). But the audit flags there is **NO differential test** (cache@P1 → decode-expecting-P2). The lineage replay correctness is exactly that test. **Gate L1: a `serialize@prompt=P1 → resume decode where monolithic ran prompt=P2` regression test must pass before virtual-node replay is trusted in production.**

---

## 3. On-disk layout & SQLite schema — **buildable-now**

`StateLake/` root (under app container, mirrors `/tmp/draft_coreai/`):

```
StateLake/
  catalog.sqlite              # the index/DAG/permissions/expiry — the brain
  hot/    <sha>.statelake      # RAM-backed tier mirror (mmap, evictable)
  warm/   <sha>.statelake      # device disk
  cold/   manifest only        # body in cloud (StateLake-cloud), header cached locally
```

```sql
-- the node table: one row per state artifact
CREATE TABLE state (
  sha            TEXT PRIMARY KEY,          -- blake3 of (binding_key || trunk || tail)  == content hash
  binding_hash   TEXT NOT NULL,             -- blake3(binding_key)  — the §0 LAW key; JOIN target for "can I load this?"
  corpus_id      TEXT NOT NULL,
  fill           INTEGER NOT NULL,
  max_seq        INTEGER NOT NULL,
  tok_count      INTEGER NOT NULL,
  tier           TEXT NOT NULL CHECK(tier IN ('hot','warm','cold')),
  bytes          INTEGER NOT NULL,
  trunk_blake3   TEXT NOT NULL,
  tail_blake3    TEXT NOT NULL,
  state_fp       BLOB NOT NULL,             -- 8-float/layer structural fingerprint (§5)
  created_utc    INTEGER NOT NULL,
  last_used_utc  INTEGER NOT NULL,          -- for LRU tiering
  expiry_utc     INTEGER,                   -- NULL = no TTL
  materialized   INTEGER NOT NULL DEFAULT 1 -- 0 = virtual (replay from parent)
);
CREATE TABLE edge (                         -- the lineage DAG (prefix tree)
  child_sha   TEXT NOT NULL REFERENCES state(sha) ON DELETE CASCADE,
  parent_sha  TEXT REFERENCES state(sha),   -- NULL = root prefill from zero-state
  tok_lo      INTEGER NOT NULL,
  tok_hi      INTEGER NOT NULL,
  op          TEXT NOT NULL CHECK(op IN ('prefill','append')),
  PRIMARY KEY (child_sha)
);
CREATE TABLE acl (                          -- permissions (§4)
  corpus_id   TEXT NOT NULL,
  principal   TEXT NOT NULL,                -- app/agent/user identity
  rights      INTEGER NOT NULL,             -- bitmask: READ=1 RESUME=2 FORK=4 EXPORT=8
  PRIMARY KEY (corpus_id, principal)
);
CREATE TABLE binding (                      -- model-version registry (§0 enforcement)
  binding_hash TEXT PRIMARY KEY,
  weight_hash  TEXT, model_config TEXT, converter_ver TEXT, asset_id TEXT,
  retired_utc  INTEGER                      -- set when a model version is superseded -> mass invalidation (§7)
);
CREATE INDEX idx_state_corpus ON state(corpus_id, binding_hash);
CREATE INDEX idx_state_lru    ON state(tier, last_used_utc);
CREATE INDEX idx_state_expiry ON state(expiry_utc) WHERE expiry_utc IS NOT NULL;
```

The repo already uses SQLite migrations (`009_sovereign_tokens.sql`, the `012_chapter_doctrine` KV doctrine), so a `013_statelake.sql` migration is the natural home and reuses the existing `BASSovereign` SQL plumbing patterns.

---

## 4. PERMISSIONS — per-corpus access — **buildable-now**

- Every artifact is bound to a `corpus_id`. The `acl` table is a per-`(corpus_id, principal)` rights bitmask: `READ | RESUME | FORK | EXPORT`.
- **RESUME** (load into a live decode) is the privileged right — a state that resumes the model can leak corpus content via generation, so it is stricter than READ (metadata-only).
- `manifest.sig` (Ed25519 over `header.json`) lets the **cold/cloud tier** be untrusted: a downloaded state is rejected unless its signature matches a key the device trusts AND the local `acl` grants RESUME. This reuses the `BASSovereign` token/TTL machinery the audit already found (`009_sovereign_tokens.sql`).
- **Audit-grounded reason permissions matter here specifically:** a rehydrated state against the WRONG corpus's weights is silent garbage (§0). ACL + binding_hash are the two independent gates: ACL says "you may", binding says "it will actually be correct."

---

## 5. CHECKSUMS — consistency check (from Pillar 2) — **buildable-now + one needs-work**

Three layers, cheapest-first:

1. **`binding_hash` match (mandatory, O(1)):** before any load, `JOIN binding` — refuse if the runtime graph's `binding_hash` differs. This is the §0 LAW and the single most important check. Cluster 5 proved its absence = silent corruption.
2. **`blake3` content integrity (O(bytes)):** `trunk_blake3`/`tail_blake3` detect bit-rot / truncated downloads on the cold tier.
3. **`state_fingerprint` semantic check (O(layers), 8 floats/layer):** per-layer `[L2(angle), L2(ssm), trace(ssm), L2(kprev), L2(vprev), L2(mla_latent), fill, angle_max]`. Computed at write, re-checked at load. Catches the failure the audit specifically warns about: a *structurally* valid but *semantically* wrong state.

**The audit's sharpest methodology lesson (cluster 2, HIGH):** L2 norm is **permutation/sign-invariant** — the auditor demonstrated rel-err 1.41 at identical norm. So the fingerprint is a *smoke screen, not a proof*. For the **load-time fidelity gate** we therefore do NOT rely on norm; we add (cluster 2 fix) an **elementwise max-rel-err readback**: when a state crosses a tier boundary (e.g. cold→hot), optionally re-decode 1 token from both the cached state and a freshly-replayed parent+delta and compare logits **elementwise** (the rigorous check that today only exists host-vs-host). Tagged **needs-work** because it requires the differential test harness from Gate L1.

---

## 6. TIERED STORAGE — StateLake hot/warm/cold — **buildable-now (hot/warm) / needs-work (cold)**

| Tier | Medium | What lives here | Eviction |
|------|--------|-----------------|----------|
| **hot** | RAM (mmap'd `.statelake`, or resident NDArray states mid-decode) | the active decode's 6 states + most-recently-used corpora trunks | LRU by `last_used_utc`; trunk (1.48 MB) stays, tail paged first |
| **warm** | device flash | all materialized corpora for this device/model version | TTL + LRU under a byte budget |
| **cold** | cloud (StateLake-cloud) | signed, encrypted artifacts; header cached locally | never auto-evicted; pulled on demand |

- **The trunk/tail split (§1) is what makes tiering pay off:** the O(1) trunk (1.48 MB int8) is cheap to keep hot for many corpora; the O(ctx) tail (17.9 MB @ 32k) is what you page. The audit's "16x-vs-Transformer-KV win is real" (cluster 5) is the budget headroom that makes a phone-resident *library* of dozens of small-context corpora plausible — but bounded by the MLA tail at long context (the audit's correction to the "O(1) library" overclaim, which I honor: the library density claim is scoped to short/medium context).
- **mmap honesty (cluster 1, FRAGILE):** the audit showed `phys_footprint` undercounts mmap'd clean pages, so "deinit released memory" was unproven. StateLake does NOT claim resident-memory accounting from `phys_footprint`; the hot-tier byte budget is tracked by **explicit bookkeeping** (sum of mapped artifact sizes), and eviction is by our own counter, not by trusting the OS footprint.
- **`needs-work`:** the cloud cold tier (signed transport, encryption at rest, the `manifest.sig` verification path) is unbuilt. Local hot/warm + SQLite catalog is buildable now.

---

## 7. EXPIRY / INVALIDATION — **buildable-now**

Two independent triggers, both fail-closed:

1. **Model-version change (the §0 LAW, mass-invalidation):** when a new `.aimodel` ships, its `binding_hash` differs. On app launch, StateLake computes the live `binding_hash`, looks it up in `binding`; if the active model's binding is new, **every state whose `binding_hash != live` is unloadable** — they are marked `retired_utc` and GC'd. This is the corruption-prevention the audit demanded. No state ever silently loads into a different model.
2. **TTL:** `expiry_utc` per corpus; a sweep on launch + on access drops expired nodes (CASCADE deletes their DAG subtree, since children depend on the parent's bytes). Reuses the `BASSovereign` token-TTL pattern (`009_sovereign_tokens.sql`).

**Overflow policy (closes cluster 3 HIGH — the silent MAX_SEQ cap):** a decode whose `fill` would reach `max_seq` does NOT drop the token. StateLake's resume API checks `fill < max_seq` each step and on the boundary executes a **defined** policy chosen at corpus-config time:
- `policy = "halt"` → raise `StateLakeOverflow` (loud).
- `policy = "reprefill"` → fork a fresh state from the corpus root with the recent window (the only legitimate "re-prefill on overflow" — which the audit confirmed does **not** exist today; this builds it explicitly).
- `policy = "evict_window"` → shift the MLA tail (drop oldest latents), explicitly logged as lossy. NEVER silent.

---

## 8. The ROUTER — given (query, corpus), find/compose the right cached state — **buildable-now (find) / KILLED (compose)**

The router answers: *"what is the cheapest way to get a decode-ready state for this corpus that is valid for the live model?"*

```
route(corpus_id, principal, live_binding_hash, want_tok_range) -> ResumePlan
  1. ACL gate:        require RESUME right for (corpus_id, principal)         -> else DENY
  2. Binding gate:    candidates = state WHERE corpus_id=? AND binding_hash=live  -> else MISS (must re-prefill)
  3. Prefix match:    pick the node whose lineage prefix is the LONGEST prefix of want_tok_range
                      (deepest valid ancestor in the DAG)  -> the "best cached state"
  4. Materialize:     if node.materialized -> load bundle (tier-promote cold->warm->hot)
                      else -> walk to nearest materialized ancestor + REPLAY edge deltas (decode the token delta)
  5. Resume:          load_prefill(state, fill); if want_tok_range extends past fill -> append-decode the remainder
  6. Verify:          binding match (§5.1) + fingerprint (§5.3); optional elementwise gate on tier-cross (§5 needs-work)
```

- **"Find/compose" is strictly FIND + EXTEND, never FUSE.** The router's only "composition" is *prefix extension along the DAG* (load ancestor, decode forward) — which is just running the proven model forward. **It NEVER linearly combines or concatenates two independent SSM states**, because the audit says state composition was **KILLED**. I am explicit: any future "merge two corpora into one state" request is REJECTED by the router as an unsupported op.
- **Router output is a plan, not a guess:** it returns the node + the exact token delta to replay, so the caller knows the cost (O(delta) decode steps) before committing.

---

## 9. Public API (Swift, mirrors the existing session classes) — **buildable-now**

```swift
struct StateLake {
  // write a fresh prefill result as a node (after BASCoreAIPrefillSession produces the 6 states)
  func put(states: HybridStates, corpus: CorpusID, binding: BindingKey,
           fill: Int, lineage: Lineage) throws -> StateSha           // assert fill<=max_seq, dtype!=int4

  // the router entrypoint — returns a plan, does NOT mutate
  func route(corpus: CorpusID, principal: Principal,
             binding: BindingKey, want: TokRange) throws -> ResumePlan  // ACL + binding gated

  // materialize a plan into a live decode session (the proven load_prefill path)
  func resume(_ plan: ResumePlan) throws -> BASCoreAIHybridDecodeSession  // verifies §5; enforces §7 overflow

  // cheap fork: branch a node to append a different continuation (Mamba O(1) makes this near-free)
  func fork(from: StateSha, appending: TokRange) throws -> StateSha       // adds an edge; child virtual until used

  func invalidate(binding: BindingKey) throws    // model-version change -> mass retire (§7.1)
  func sweepExpired() throws                       // TTL (§7.2)
}
```

`fork` is the headline Mamba advantage (§ below): branching the same understood-document into N parallel continuations costs one O(1) trunk copy + a per-branch growing tail, vs a Transformer that must copy the entire O(ctx) KV per branch.

---

## 10. Build order (de-risked, each gated by an audit finding)

1. **`013_statelake.sql` + put/get of `mamba.trunk` only** (the genuinely O(1), PROVEN-fidelity pure-Mamba path; addendum 17 reproduced). int8, angle-wrapped, binding_hash enforced. **No MLA yet** — avoids the non-contractive risk on day 1.
2. **Disk roundtrip differential test (Gate L1)** — the test the audit says is missing: `serialize@P1 → resume@P2` elementwise logit compare. This is the gate that turns the structural argument into a guarantee.
3. **Add `mla.tail`** with the §7 overflow policy + the fill<max_seq assertion (closes cluster 3).
4. **Lineage DAG + fork** (virtual nodes + replay).
5. **Tiering hot/warm** (explicit byte bookkeeping, not phys_footprint).
6. **Cloud cold tier + signing** (needs-work).

**Novel mechanisms:**
- binding_key as a hard fail-closed LAW (weight_hash + model_config + converter_ver + asset_id + angle_wrap + state_dtype): a state can ONLY load into the exact graph that produced it; any mismatch is loud, never a silent rehydrate. Directly closes the audit's single most dangerous FABRICATED gap (cluster 5: mismatched weights = silent garbage). [buildable-now]
- Trunk/tail physical split of the artifact (mamba.trunk O(1) int8 + mla.tail O(ctx) int8, only `fill` rows written): turns the audit-PROVEN O(1)+O(ctx) structure into independent tiering/eviction units. [buildable-now]
- Prefix DAG with virtual nodes + copy-on-materialize replay: a child state = parent + token-delta, replayed by running the proven model forward, NEVER by fusing states (respects the KILLED composition verdict). Forking is O(1)-trunk-cheap. [buildable-now storage / needs-work resume-correctness guarantee]
- Defined overflow policy (halt | reprefill | evict_window) replacing the audit's SILENT MAX_SEQ=256 token-drop (cluster 3 HIGH): fill<max_seq is asserted every step; the boundary raises or re-prefills, never silently corrupts. [buildable-now]
- Three-tier checksum (binding_hash O(1) -> blake3 content -> 8-float/layer semantic fingerprint) with explicit acknowledgement that L2-norm is permutation/sign-invariant (auditor demonstrated rel-err 1.41 at equal norm) -> the real fidelity gate is an elementwise readback on tier-cross, not the norm. [buildable-now for hashes / needs-work for elementwise gate]
- Router returns a cost-bearing ResumePlan (node + exact token delta to replay) gated by ACL(RESUME) and binding_hash, where the ONLY 'composition' is prefix-extension along the DAG; cross-corpus state fusion is explicitly rejected. [buildable-now find / KILLED compose]
- StateLake-cloud cold tier with Ed25519-signed manifests so untrusted cloud-fetched states are refused unless signature + local ACL both pass — letting a phone pull a pre-understood corpus state it didn't compute. [needs-work / research]

**CoreAI/Mamba-3 advantages exploited:**
- Mamba O(1) state makes FORKING cheap: branching one understood corpus into N parallel continuations copies the fixed 1.48 MB int8 trunk once per branch (T-independent shapes, PROVEN: zero-state has no T dim, prefill_state indexes [-1]) — a Transformer would copy the full O(ctx) KV per branch. This is the DAG's economic justification.
- The hybrid's structural O(1)-Mamba + O(ctx)-MLA split (PROVEN in cluster 5) is exploited DIRECTLY by storing trunk and tail as separate physical files, so the cheap fixed trunk stays hot while the growing tail pages to warm/cold independently.
- int8 is treated as the PROVEN precision floor (cluster 4: int8 holds, int4 breaks at tok6) — the artifact format hard-rejects int4 at write time and the schema records state_dtype, so the database can never persist a precision the audit refuted.
- The angle-wrap (cache_serialize_state, mamba3_trainable.py:40, PROVEN lossless for cos/sin) is baked into the wire format as a mandatory binding-key flag — every stored Mamba angle is wrapped to (-pi,pi], which is what lets int8 survive long prompts.
- Reuses the device-PROVEN load_prefill -> step resume path (mamba3_hybrid_decode_deploy.py:89) as the router's materialize step — the router never invents a new resume mechanism, it replays the one path that reproduced the host monolithic 31/32.
- CoreAI stateful-KV (the ONE CoreAI feature the audit confirms is genuinely exploited) is the natural backing store for the hot tier's resident 6 NDArray states — StateLake is the persistence layer UNDER that runtime state, not a competing mechanism.

**⚠ Depends on audit-flagged-unproven:**
- The 'phone-resident LIBRARY of pre-understood corpora' density depends on the O(1) claim, but the audit (cluster 5 MISLEADING) proved the 24L hybrid flagship cache is O(1)-Mamba + O(ctx)-MLA (92% MLA at 32k). My design scopes the dense library to short/medium context and pages the MLA tail; truly O(1) density is only the pure-Mamba 8L SKU. The ambitious 'library of dozens of corpora' is honest only at modest context length.
- The cross-tier elementwise fidelity gate (§5) and the lineage replay correctness (§2 Gate L1) BOTH require the differential serialize@P1->resume@P2 test that the audit says does NOT exist yet — these pieces are needs-work, not buildable-now, until that harness lands.
- int8 as the persisted floor rests on argmax-agreement over RANDOM-weight models (cluster 4 HIGH: the int8 floor is UNCONFIRMED on a trained checkpoint). StateLake records state_dtype and can switch to fp16 trunk, but certifying int8 for the shipping (distilled) model is a blocking gate the audit flags and my design inherits.
- The cloud cold tier assumes a disk/transport roundtrip of the FULL hybrid state (6 states incl. MLA latent); the audit (cluster 1 OVERCLAIMED) notes the full-hybrid disk roundtrip was NEVER exercised — only an in-memory handoff and a Mamba-only fp32 disk test (addendum 17) exist. The cold-tier transport is research until a full-hybrid disk roundtrip is proven.
- fork()'s 'O(1) cheap branch' is true for the Mamba trunk but each branch still grows its own O(ctx) MLA tail; 'cheap' is relative to Transformer full-KV copy, not absolute — at long context a branch is not free.