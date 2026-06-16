# Universal Self-Speculative Decode — Probe Results

Program: a universal LLM speculative decoder (any LLM, token-identical under greedy verify, no per-target draft
pairing), two tracks — **A** prompt-lookup (model-free n-gram draft) and **B** CoreAI/ANE draft (squeeze the
otherwise-idle ANE). Doctrine: probe-first, 实测胜出才晋升, token-identical under greedy verify (ADR-039), zero
auto-promotion.

> **Terminology (audit fix):** below, "byte_identical = N/N" / "byte-identical" denote **token-sequence identity**
> — the probe (`BASPromptLookupProbe`) compares the spec decoder's emitted token IDs to the baseline's
> (`specTokens == baseTokens`). This is the ADR-039-safe property (every emitted token is the target's greedy
> argmax). It is NOT a claim about detokenized TEXT bytes: equal tokens through the same tokenizer give equal text,
> but exact text byte-equality to the production streaming detokenizer was not separately measured.

---

## Track D — EAGLE feature-head (2026-06-14, Mac MLX self-distillation) — pipeline works; first cut drafts ~1 token

EAGLE drafts at the FEATURE level: a small head predicts the next penultimate feature `f_{t+1}` from `(f_t,
e_{t+1})`; the target's own lm-head maps `f_hat` → token. Vendor patch exposes features/embed/lm-head (byte-identical).
`Tools/eagle_train_head.py` self-distills (run the 4bit-3B greedy, capture `(f_t, token)` sequences), trains a
residual head `f_{t+1} ≈ f_t + MLP(concat(f_t, e_{t+1}))` (smooth-L1 feature + 0.1·CE), measures held-out acceptance.

| metric (held-out, 12 seqs) | value |
|---|---|
| teacher-forced 1-step accept (head sees the TRUE `f_t`) | **1.000** |
| **AUTOREGRESSIVE accept** (head feeds back its OWN `f_hat` — the real decode signal) | **0.503** |
| **mean accepted draft length** | **1.01 / 4** |

**Verdict — pipeline works end-to-end, but the first cut drafts only ~1 token (not EAGLE's SOTA 3–4×).** The
teacher-forced (1.0) vs autoregressive (0.5) gap is the diagnosis: the head's PREDICTED features **drift** after one
step, and a pointwise residual MLP cannot model "given the draft so far, predict the next feature" (no attention over
the sequence). EAGLE's real head is a **transformer decoder layer** (attends to the draft) trained on **~68K samples**;
this cut is a simple MLP on **52 self-gen sequences / 8 epochs** → undertrained + under-architected. Byte-identity holds
regardless (the target verify); only the speedup is limited. The honest levers: (i) a proper transformer-layer head,
(ii) ~100× more training data, (iii) train against the head's OWN autoregressive features (reduce drift). Each is a
real ML investment — not a marathon-tail task. The pipeline (patch + self-distill + honest held-out/autoregressive
eval) is the reusable foundation.

## Track B3 — Core ML 3B TARGET backend (2026-06-14, A19) — DECLINED: quality↔memory jointly unsatisfiable

The "rewrite the decode backend on Core ML, same target quality, max throughput" bet. Probe-first Phase 0 gate:
convert Llama-3.2-3B → stateful Core ML (head_dim 128) at int4 AND int8 (`Tools/llama_target_to_coreml.py`, torch
fidelity 24/24), measure on the A19 (`BASANETargetProbe`, BAS_ANE_TARGET_PROBE).

| 3B quant | size | fidelity vs HF greedy | memory | throughput | gate |
|---|---|---|---|---|---|
| int4 | 1.7 GB | **6/24** (coherent but divergent — lossy) | fits | — | ❌ quality NO-GO (not "same target quality") |
| int8 | 3.2 GB | **24/24** (faithful) | **JETSAM on the 3.2 GB compile/load** (probe printed only START at 12 MB, then SIGKILL) | never reached | ❌ memory NO-GO |

**Verdict — DECLINED. The conventional "move the 3B target to Core ML" is jointly unsatisfiable on the A19:** the
only faithful quant (int8, 24/24) is 3.2 GB and the app is jetsam-killed compiling/loading it against the 3376 MB
cap; the only fitting quant (int4) is 6/24 — not "same target quality". Throughput was never even measured — and
per the int8 1B's ~31 tok/s (already < the MLX 3B's 38.3), a 3B Core ML decode would have failed (b) too. This
confirms the plan's risks #1 (Core ML decode < MLX) + #2 (quality↔memory tension). **The Core ML backend rewrite
is the wrong bet on this device; the SSD program's universal win remains Track A (prompt-lookup).** The phase-1/2
backend was correctly NOT built.

## Track C — tree-structured prompt-lookup (2026-06-14, iPhone A19) — CORRECT byte-identical, but marginal over linear

The aggressive, training-free successor to linear prompt-lookup: propose a TREE of n-gram continuations (branch
where the matched suffix recurred with different next tokens), verify the whole tree in ONE target forward via a
custom tree attention mask + per-depth RoPE (vendor patch `Docs/patches/spec-decode-tree-mask.diff`, byte-identical
default), accept the longest root-to-leaf path that is the target's greedy argmax, trim-all + replay the path.

| workload | mean_path | max_path | **vs_linear** | token_identical |
|---|---|---|---|---|
| rag-quote | 3.50 | 4 | 0.63× | YES |
| json-structured | 1.05 | 4 | 0.79× | YES |
| code-repeat | 1.26 | 4 | 0.78× | YES |
| verify-claim | 0.54 | 4 | 0.86× | YES |
| control-freeform | 0.03 | 2 | 0.89× | YES |

**Verdict — the scheme is CORRECT (token_identical 5/5: vendor mask patch + per-depth RoPE + tree walk + trim/replay
all byte-exact) but a NET LOSS over the shipped linear lane (mean 0.76×).** The tree finds deep paths (rag
mean_path 3.5) yet loses because it does ~2× the forward work/round (the S≈9 tree forward vs linear's 5, PLUS a
second "replay" forward for the cache), and the marginal acceptance gain over the ALREADY-strong linear
prompt-lookup doesn't pay for it. **Insight:** tree-spec wins in the literature (SpecInfer/Medusa) because there the
draft is often wrong; prompt-lookup's linear n-gram draft is already high-precision on repetitive content, so
branching adds little. The tree machinery is a correct, reusable foundation — its real payoff is a MODEL draft with
uncertain branches (EAGLE). Two further levers if revisited: a cache-GATHER vendor patch to drop the replay forward,
and deeper/wider trees on more-divergent content. Not pursued for prompt-lookup (marginal); carried to EAGLE.

---

## Track B0 — ANE-placement feasibility gate (2026-06-14, **Mac M-series ANE**)

**Question (the operator's R1 challenge to my too-hasty "CoreAI can't decode"):** does a fp16 transformer at
DECODE shape (single-token GEMVs + lm_head) get its ops planned onto the Apple Neural Engine?

**Method:** `Tools/draft_llm_to_coreml.py` converts a synthetic Llama-1B-shaped decoder block (hidden 2048,
4 layers, 32 heads, intermediate 8192, vocab 32000, **seq=1 decode shape**) to a Core ML mlprogram at fp16 and
fp32 (raw torch, no transformers dep). `Tools/ane_compute_plan_probe.swift` walks `MLComputePlan` (per-op
preferred compute device) + an `MLModel.prediction` latency A/B across compute units.

**Result:**

| model | MLComputePlan placement | per-token latency (60 warm iters) |
|---|---|---|
| **fp16, `.all`** | **ops=140, ane=140** (100% ANE, ane_capable=140) | — |
| **fp16, `.cpuAndNeuralEngine`** | ops=140, ane=140 | — |
| **fp32, `.all`** | ops=138, **gpu=138**, ane_capable=0 | — |
| fp16 `.cpuOnly` | — | 7.16 ms |
| fp16 `.cpuAndGPU` | — | **1.85 ms** (GPU) |
| fp16 `.cpuAndNeuralEngine` (ANE) | — | 4.68 ms |
| fp16 `.all` (chose ANE) | — | 4.68 ms |

Numerical: fp16 `nan=False`, argmax matches torch (mae 1.8e-3) — the single-token decode shape avoids the
fp16-attention overflow that NaN'd the MiniLM embedder (long-seq softmax).

**Verdict — my prior "CoreAI can't do LLM decode" was FALSE; the operator was right.**
- **Placement door is WIDE OPEN:** a fp16 transformer decoder gets **100% of its ops on the ANE**. The earlier
  "0 ANE ops" (`ANE_UTILIZATION_FINDINGS.md`) was on tiny **fp32 classify/embed heads** — exactly the
  precision+shape the planner rejects. Precision is the lever: fp16 → ANE, fp32 → GPU.
- **Speed caution:** on the Mac the ANE is ~**2.5× slower per single-token forward** than the GPU (4.68 vs
  1.85 ms). So the ANE is NOT a faster *standalone* decoder here — the per-inference overhead hurts
  autoregressive single-token decode. The spec-decode value is the ANE drafting **in parallel on idle
  hardware** while the GPU runs the verify (a slower-but-GPU-free draft), or a stateful KV path keeping the
  ANE warm.

**Honest scope / not yet answered:** (1) synthetic random-weight block, not a real 4-bit model (Core ML
int4-on-ANE is its own question); (2) 4 layers, not the full 16 (full model ≈ 4× latency); (3) no KV-cache yet
(B1) — single-token without attention-over-history.

### B0 on the REAL iPhone A19 (`BASANEDraftProbe`, BAS_ANE_DRAFT_PROBE=1) — STRONGER than the Mac

| model | A19 placement | A19 per-token latency |
|---|---|---|
| **fp16 `.all` / `.cpuAndNeuralEngine`** | **ops=140, ane=140** (100% ANE) | — |
| fp32 `.all` | ops=138, gpu=138, 0 ANE | — |
| fp16 `.cpuOnly` | — | 19.38 ms |
| fp16 `.cpuAndGPU` | — | 10.98 ms (GPU) |
| **fp16 `.cpuAndNeuralEngine` (ANE)** | — | **10.51 ms** |
| fp16 `.all` (chose ANE) | — | 10.41 ms |

**A19 verdict:** the iPhone A19 confirms **100% ANE placement** AND the ANE latency (10.51 ms) is **competitive
with — marginally faster than — the GPU (10.98 ms)**. The Mac's 2.5× ANE penalty was a Mac-GPU artifact, NOT a
fundamental ANE limit. On the operator's target device the **ANE is a genuine decode lane**, so an ANE-draft
running in PARALLEL on idle hardware while the GPU verifies is a real "压榨 CoreAI" hybrid. **Green light for B1
(stateful ANE decode loop) → B2 (ANE-draft ∥ GPU-verify).** Remaining to measure: a real 4-bit model, the full
layer count, the stateful KV path, and the end-to-end hybrid speedup + byte-identity.

---

## Track A — universal prompt-lookup SSD (2026-06-14, iPhone Air, Llama-3.2-3B, ngram 1..3, K=4)

Model-free (`speculativeDecoding=.off`, no draft model) BAS-owned greedy verify loop (`BASPromptLookupDecoder`)
vs a null-drafter baseline (= pure single-model greedy), compared by direct TOKEN sequence (`BASPromptLookupProbe`).

| workload | tokens | hit_rate | mean_acc | spec_ms | base_ms | speedup | byte_identical |
|---|---|---|---|---|---|---|---|
| **rag-quote** (verbatim quote) | 47 | 0.82 | 3.27 | 993 | 1842 | **1.86×** | YES |
| **code-repeat** | 54 | 0.54 | 1.25 | 1580 | 2159 | **1.37×** | YES |
| **json-structured** | 200 | 0.41 | 0.98 | 5417 | 7251 | **1.34×** | YES |
| verify-claim | 200 | 0.26 | 0.52 | 9095 | 8978 | 0.99× | YES |
| control-freeform | 153 | 0.02 | 0.03 | 9425 | 8556 | **0.91×** | YES |

**FINAL: repetitive_mean_speedup = 1.39× · byte_identical = 5/5 · all_identical = YES.**

**Verdict — universal prompt-lookup SSD WORKS, byte-identical, helps the repetitive lanes:**
- **Byte-identity proven 5/5 on real device** — the BAS-owned loop is token-identical to single-model greedy
  (the ADR-039-safe property). The loop is correct.
- **Strong wins where output reuses input**: RAG-quote **1.86×** (the grounded/retrieval lane — accepts 3.27
  tokens/round), code/JSON 1.34–1.37×. These are exactly BAS's structured/extraction/RAG workloads.
- **Honest cost on non-repetitive output**: control free-form is **0.91× (−9%)** and verify-claim ~neutral
  (0.99×) — when nothing is accepted, the K+1-position verify forward costs slightly more than a single-token
  step. So prompt-lookup must be **GATED to repetitive lanes** (RAG/quote/structured/code), or use adaptive K
  (shrink K when hit-rate drops) to remove the free-form penalty. Promotion = gate-to-repetitive + the adaptive-K
  refinement; never an unconditional default (亏的不要 on free-form).

Next (refinement, not blocking): adaptive K (drop K when recent hit-rate is low — *hypothesized* to reduce the
−9% control cost; this was MEASURED in the refinement section below and **FALSIFIED** — adaptive-K lifts the
partial-repetition lanes instead, the free-form penalty needs lane-gating); purpose-gated adoption (only the
deterministic/factual/RAG lanes).

### Track A refinement — adaptive K (2026-06-14, iPhone Air, same model/prompts, `BAS_PL_ADAPTIVE=1`)

`effK = clamp(1, K, round(emaAccept)+1)`, `emaAccept = 0.6·emaAccept + 0.4·accepted_this_round` (floor 1 keeps
cheaply probing so re-entry into repetition is still caught). Re-measured A/B vs the SAME null-drafter baseline:

| workload | fixed-K speedup | **adaptive-K speedup** | hit_rate | mean_acc | byte_identical |
|---|---|---|---|---|---|
| **rag-quote** | 1.86× | **2.05×** | 0.78 | 2.92 | YES |
| **json-structured** | 1.34× | **1.58×** | 0.57 | 0.69 | YES |
| **code-repeat** | 1.37× | **1.46×** | 0.57 | 0.86 | YES |
| **verify-claim** | 0.99× (neutral) | **1.23×** | 0.49 | 0.43 | YES |
| control-freeform | 0.91× | 0.92× | 0.05 | 0.02 | YES |

**FINAL: repetitive_mean_speedup = 1.58× (was 1.39×) · byte_identical = 5/5 · all_identical = YES.**

**Verdict — adaptive-K is a clear net win, but NOT for the reason I hypothesized (honest correction):**
- **Hypothesis FALSIFIED:** I expected adaptive-K to remove the −9% free-form penalty by shrinking K. It did
  not (0.91×→0.92×, unchanged). On free-form the drafter almost never matches (hit_rate 0.05) → numDraft is
  *already* ~0 → the verify forward is *already* single-token, so K-width was never the free-form cost. The
  residual −8% is the per-round n-gram `propose()` scan, which adaptive-K doesn't touch. **The free-form penalty
  still requires lane-gating to eliminate (亏的不要 — never default-on for free-form); adaptive-K alone won't.**
- **What it actually bought (better than the hypothesis):** it lifts the **partial-repetition** lanes — it ramps
  K up during quote/reuse spans and down during novel spans, so semi-repetitive output stops paying for wasted
  verify width. **verify-claim went neutral→1.23× (a real BAS lane: factual verification with claim-quoting), and
  the repetitive mean rose 1.39×→1.58×.** Every repetitive lane improved; byte-identity held 5/5.
- **Net:** keep adaptive-K (it strictly dominates fixed-K on every measured lane and never regresses byte-identity),
  AND lane-gate prompt-lookup to repetitive/structured/RAG/verify lanes (the free-form −8% is gated off, not fixed).
  Promotion = adaptive-K on + lane-gated, never an unconditional default.

---

> ⚠️ **SUPERSEDED — read before the B1 / B1' / B1'' sections below.** Every DECLINE verdict in B1 / B1' / B1''
> was measured on the **Mac M-series planner only**. The iPhone A19 (the operator's target) **OVERTURNS all of
> them** — see **Track B2-GO** at the bottom: B1-class stateful KV decode AND B1''-class windowed decode both plan
> **100% onto the A19 ANE**. The "attention-over-history → GPU" conclusion in these sections is a **Mac cost-model
> artifact, NOT a Core ML structural wall**. The sections are kept verbatim for provenance; their standalone
> DECLINE verdicts are no longer true on target hardware.

## Track B1 — stateful Core ML KV-cache decode (2026-06-14, Mac) — TEMPERS B0

`Tools/draft_llm_stateful_to_coreml.py` converts a stateful decoder (iOS18 `ct.StateType` per-layer K/V caches,
`forward(hidden, position)` writing the new token's K/V at `position` + masked attention over the prefix). The
conversion SUCCEEDS. But `MLComputePlan` + an autoregressive `MLState` latency loop (`/tmp/statefulane.swift`):

| | placement | per-step latency (autoregressive, live KV state) |
|---|---|---|
| stateful fp16, `.all` | **ops=133, gpu=133** (100% GPU, **0 ANE**) | — |
| stateful fp16, ANE (`.cpuAndNeuralEngine`) | — | 4.67 ms |
| stateful fp16, GPU (`.cpuAndGPU`) | — | **2.40 ms** (GPU faster) |

**Verdict — the ANE-draft hybrid is NOT straightforwardly viable; B0's optimism doesn't carry to real decode.**
The STATELESS fp16 block lands 100% on the ANE (B0), but the STATEFUL KV-cache decode — what real autoregressive
decode requires — plans **entirely onto the GPU** (the dynamic position-indexed state write + the masked
attention over MAX_SEQ are ANE-incompatible ops that push the whole graph to GPU), and FORCING the ANE is
*slower* (4.67 vs 2.40 ms). So an "ANE draft" of a real (stateful) model would run on the GPU — contending with
the MLX verify, no parallelism win. **The naive ANE-draft ∥ GPU-verify hybrid (B2) is DECLINED on this evidence
(亏的不要 — measured, saved building it on a false premise).**

Honest scope / open: (1) the GPU fallback is driven by the dynamic-index state update + mask — an ANE-friendly
stateful formulation (fixed-window cache, no dynamic indexing, the patterns Apple's own on-device LLM Core ML
models use) MIGHT keep the matmuls on ANE; that is a deeper research problem, not solved by the naive approach.
(2) Mac planner; an A19 confirmation could differ but the dynamic-index ANE-incompatibility is structural (Core
ML lowering), not device-specific. **Net: B0 says the ANE runs stateless transformer MATMULS great; B1 says
real stateful DECODE goes to the GPU. The universal win that actually shipped this arc is Track A
(prompt-lookup, model-free, byte-identical, 1.39× on repetitive lanes).**

## Track B1' — ANE-FRIENDLY fixed-window stateful (2026-06-14, Mac) — the B1 open question, answered: STILL GPU

`Tools/draft_llm_fixedwindow_stateful_to_coreml.py` is exactly the salvage B1 pointed to: remove BOTH dynamic
ops B1 blamed — the position-indexed scatter write becomes an **elementwise one-hot select**
(`kc_new = kc·(1−oh) + k·oh`), the runtime causal mask becomes a **host-supplied additive bias** (no
`arange<=pos` compare) — the fixed-window pattern Apple's own on-device Core ML LLMs use. Per-layer state in
separate buffers (zero layer-dim indexing); state write-back via a STATIC full-slice assign (`buf[:] = …`).
Conversion SUCCEEDS. `Tools/fixedwindow_ane_probe.swift` (autoregressive, host-fed onehot+bias):

| | placement | per-step latency (autoregressive, live KV state) |
|---|---|---|
| fixed-window fp16, `.all` | **ops=197, gpu=197** (100% GPU, **0 ANE**) | — |
| fixed-window fp16, ANE (`.cpuAndNeuralEngine`) | — | 5.26 ms |
| fixed-window fp16, GPU (`.cpuAndGPU`) | — | **2.66 ms** (GPU faster) |

**Verdict — B1's "dynamic indexing was the cause" hypothesis is FALSIFIED; the GPU fallback is deeper.**
Removing the dynamic-index scatter + the runtime mask (the two ops B1 blamed) was **necessary but NOT
sufficient** — the fixed-window stateful graph STILL plans 100% onto the GPU, and forcing the ANE is still ~2×
slower. The structural barrier is the iOS18 **stateful (`MLState`) read-modify-write mechanism itself** being
GPU-bound under Core ML's current lowering, not any particular dynamic op. **So the ANE-friendly *stateful*
formulation is also DECLINED (亏的不要 — second negative, stronger than B1: even the Apple-style approach fails).**
The ONE door this leaves open is **stateless** decode (no `MLState`) — B1'' below.

## Track B1'' — STATELESS windowed-recompute (2026-06-14, Mac) — the last door, also GPU. Pattern resolved.

`Tools/draft_llm_stateless_window_to_coreml.py` removes state ENTIRELY: each step feeds the last W=64 token
hidden states as a fixed-shape `[1, W, H]` input + a STATIC baked causal mask, recomputing attention over the
window (O(W) per token, no `MLState`). B0 proved a stateless fp16 block lands 100% ANE, so this had a strong
prior. `Tools/stateless_window_ane_probe.swift`:

| | placement | per-draft-token latency (recompute over W=64) |
|---|---|---|
| stateless-window fp16, `.all` | **ops=145, gpu=145** (100% GPU, **0 ANE**) | — |
| stateless-window fp16, ANE (`.cpuAndNeuralEngine`) | — | 25.32 ms (= GPU → ANE units fell back to GPU) |
| stateless-window fp16, GPU (`.cpuAndGPU`) | — | 25.27 ms |

**Verdict — also GPU. The pattern is now RESOLVED, and it was never about state.** B0 (stateless) → ANE; this
(also stateless) → GPU. The ONLY structural difference is **seq=1 vs seq=W**: B0 is a single-token forward with
NO attention-over-history (1×1 attention); this attends over W positions (W×W scores + softmax over the W axis).

### B-track FINAL verdict (B0 + B1 + B1' + B1'' — four experiments, "严查"-grade)

> ⚠️ **SUPERSEDED by Track B2-GO (A19).** This Mac-only 4-experiment DECLINE was **OVERTURNED on the iPhone A19**:
> B1/B1' (stateful KV) and B1'' (windowed) all plan 100% onto the A19 ANE. The verdict below is the Mac result,
> kept for provenance — the "ANE can't do attention-over-history" conclusion is a Mac cost-model heuristic, not a
> structural Core ML wall. Read Track B2-GO for the corrected, device-grounded conclusion.

| formulation | state? | attention-over-history? | placement |
|---|---|---|---|
| **B0** stateless single-token | no | **no** (seq=1) | **100% ANE** ✓ |
| B1 stateful KV (dynamic index) | yes | yes | 100% GPU |
| B1' stateful KV (fixed-window elementwise) | yes | yes | 100% GPU |
| B1'' stateless windowed recompute | no | yes (seq=W) | 100% GPU |

**The lever is ATTENTION-OVER-HISTORY, not state.** Core ML's planner keeps single-token feed-forward matmuls
on the ANE (B0) but routes attention-over-multiple-positions to the GPU — whether the history lives in `MLState`
(B1/B1') or is recomputed statelessly (B1''). Autoregressive decode FUNDAMENTALLY needs attention-over-history
(a query token attending over the KV prefix). **Therefore a Core ML draft decoder runs on the GPU, contending
with the MLX/GPU verify — no idle-ANE parallelism, no "压榨 idle ANE" win. The ANE-draft ∥ GPU-verify hybrid (B2)
is DECLINED on thorough evidence (4 experiments).** This is the rigorous, measured answer to the operator's
"CoreAI 怎么可能不能参与 decode 严查": CoreAI/ANE *can* run transformer decode matmuls (B0, byte-real) — but NOT the
attention-over-history that real autoregressive decode requires, so it cannot be the speculative-draft engine.

**What "压榨 CoreAI" honestly means here:** the ANE's real strength is **stateless, batchable, attention-light
matmuls at fp16** (B0) — embedding / classification / rerank heads, not autoregressive decode. The universal
decode SPEEDUP that actually shipped is **Track A (prompt-lookup)**: model-free, byte-identical, 1.58×
repetitive, now production-wired (`respondPromptLookup`) + lane-gated. Track A doesn't touch the ANE, but it is
the real, on-device-proven win.

**Honest open (low probability of flipping):** Mac planner. B0 already showed A19 placement MATCHED the Mac
(both 100% ANE, stateless seq=1), so the attention-over-history→GPU routing — a Core ML lowering property — is
very likely identical on A19; an A19 re-run of B1/B1''  would confirm (not overturn) the wall. Untested:
int4-weight ANE attention, and whether a future Core ML release lowers attention-over-history to the ANE.

> ⚠️ **The bracketed paragraph above was WRONG — the A19 OVERTURNED it. See "Track B2-GO" below. I predicted
> "low probability of flipping"; the device flipped it. 实测胜出, again.**

## Track B2-GO — the A19 OVERTURNS the Mac decline: stateful KV decode runs 100% on the ANE (2026-06-14)

The "剩余部分" step the operator pushed for — the A19 confirmation I expected to *confirm* the wall — **overturned
it.** `BASANEDraftProbe` (extended) walked `MLComputePlan` for all three formulations on the **real iPhone A19**,
side-by-side, same device:

| formulation | seq / state | **Mac M-series** placement | **iPhone A19** placement | A19 latency (ANE vs GPU) |
|---|---|---|---|---|
| **B0** single-token † | seq=1, no state | ane=140 (ANE) | **ane=140 (ANE)** | 10.40 vs 10.95 ms |
| **B1''** stateless window | seq=64, no state | gpu=145 (**GPU**) | **ane=145 (ANE)** | **10.64** vs 13.83 ms/tok |
| **B1'** fixed-window stateful | seq=1 + KV state | gpu=197 (**GPU**) | **ane=197 (ANE)** | **11.13** vs 11.56 ms/step |

**Both `ane_capable` counts are identical Mac↔A19 (145, 197) — the ops were ALWAYS ANE-capable; only the planner's
*preferred* device differs.** The Mac M-series cost model routes attention-over-history to the GPU; the A19 keeps
it on the ANE. To pin the Mac heuristic, a single self-attention block was swept by seq length (Mac, fp16,
`Tools/ane_arch_probe_convert.py` + `generic_placement_probe.swift`, fanned out via the `ane-boundary-map` workflow):

| arch (Mac) | mlp | mlp_pool:64 | attn:1 | attn:4 | attn:16 | attn:64 | attn:128 | attn:256 |
|---|---|---|---|---|---|---|---|---|
| placement | ane=15 | ane=16 | ane=37 | ane=38 | **ane=38** | **gpu=38** | gpu=38 | gpu=38 |

The Mac flips attention ANE→GPU **between seq=16 and seq=64** (a length-cost heuristic); attention-LIGHT heads
(MLP, mean-pooled MLP) stay 100% ANE at any length. **The A19 does not flip at all** — seq=64 AND stateful KV
both stay 100% ANE.

**Corrected verdict — the "attention-over-history → GPU wall" is a Mac-M-series artifact, NOT structural. On the
A19 (the operator's target), a real Core ML draft decoder — INCLUDING a stateful KV-cache autoregressive loop —
plans 100% onto the ANE, at latency ≤ the GPU.** So the **ANE-draft ∥ GPU-verify hybrid (B2) is VIABLE on target
hardware** — the naive/fixed-window DECLINEs above were Mac-bound and are **OVERTURNED**. My earlier "DECLINED on
4 experiments" was wrong because 3 of the 4 were Mac-only; the operator's instinct ("CoreAI 怎么可能不能参与
decode") is vindicated a SECOND time, on the decisive device.

**Honest scope — B2 is GREEN to BUILD, not yet PROVEN to win** (亏的不要 still binds the eventual ship):
- Placement viability ≠ a measured speedup. The hybrid (ANE Core ML draft running ∥ the MLX/GPU verify, end-to-end,
  with `byte_identical` under greedy argmax verify) is **unbuilt and unmeasured** — that is the next experiment.
- Synthetic random-weight blocks (placement is weight-independent; real draft ACCEPTANCE/quality is unmeasured —
  needs a real small same-family model converted to Core ML).
- A19 ANE per-token ≈ 10–11 ms; whether a parallel ANE draft actually beats serial GPU decode depends on the MLX
  verify rate + the draft acceptance length — the real end-to-end A/B, not yet run.
- The universal win that ALREADY shipped remains Track A (prompt-lookup, token-identical, 1.58× repetitive,
  production-wired). B2 is now a green-lit build, no longer a declined dead-end.

† The B0 A19 row here (10.40 / 10.95 ms) is a FRESH run; the earlier B0-A19 table (§"B0 on the REAL iPhone A19")
logged 10.51 / 10.98 ms from a different run. Both agree within run-to-run variance; neither is authoritative over
the other — treat ±0.5 ms as noise.

### B2 real-draft (Llama-3.2-1B) — int8 is the working ANE draft: 65% A19-ANE, fidelity 24/24 (2026-06-14)

The B2-GO synthetic results said stateful KV decode A19-ANE-places. The next gate was a REAL same-family draft.
`Tools/llama_draft_to_coreml.py` loads real Llama-3.2-1B-Instruct weights (un-gated mirror, pinned revision; same
Llama-3.2 tokenizer as the 3B target → draft token ids are valid target ids) into a stateful Core ML module
(host-fed exact llama3 RoPE, GQA 8→32, tied embeddings, the fixed-window static-slice KV write).

**Conversion + fidelity:** the torch module is **token-identical to HF greedy 24/24** (fp32 gate); the converter
re-validates the shipped Core ML model through the same loop via `Tools/check_draft_fidelity.py` (audit fix — the
fp32 gate alone doesn't certify the quantized artifact). The full measured matrix (size × A19 placement × fidelity):

| draft | size | Mac `ane_capable` | **A19 placement** | fidelity vs HF greedy |
|---|---|---|---|---|
| LlamaDraft1B **fp16** | 2.3 GB | 0 / 1205 | ops=1205 **ane=0** gpu=1203 (size-rejected) | **24/24** |
| LlamaDraft1B **int4** | 0.66 GB | 1087 / 1208 | ops=1208 **ane=784** gpu=422 (**65% ANE**) | 2/24 (lossy) |
| LlamaDraft1B **int8** | 1.2 GB | 1087 / 1208 | ops=1208 **ane=784** gpu=422 (**65% ANE**) | **24/24** ✓ |

**The size↔fidelity tension, resolved: int8 is the working B2 draft.**
- **Size is the ANE gate.** The fp16 2.3 GB model is `ane_capable=0` for EVERY op on BOTH Mac and A19 (a
  per-op diagnostic `Tools/placement_diag_probe.swift` showed even mul/add/matmul incapable) — a **model-level
  size rejection**, NOT the cost heuristic. Quantizing under the limit restores capability (int4 AND int8 both →
  `ane_capable=1087`).
- **On the A19 the quantized draft places 65% on the ANE** (784/1208 ops), vs 0% for fp16. It is a **partition**,
  not a full takeover — ~422 ops (embedding gather over 128k, dequant, GQA repeat, the big lm_head) stay on GPU.
  So a hybrid runs the *majority* of the draft on the otherwise-idle ANE in parallel with the GPU verify — a real
  but **partial** "压榨 CoreAI".
- **int4 is too lossy; int8 keeps fidelity.** int4 greedy-diverges from its own fp32 (2/24 — coherent text, but an
  early argmax flips and cascades), which would tank acceptance. int8 is **token-identical (24/24)** AND the same
  size-class-fits-ANE, so **int8 is the draft to carry forward**.

**Net — B2 is GREEN and the draft is identified (int8).** Established this arc: the ANE *can* run a real LLM decode
draft on the A19 (65% placement, fidelity-preserving int8). The end-to-end hybrid was then BUILT + MEASURED ↓.

### B2 END-TO-END hybrid — built + measured (2026-06-14): CERTIFIED CORRECT, but a net loss as built

`BASCoreMLDraftSession` (Core ML int8 1B draft, stateful KV, host-fed RoPE/one-hot/bias) + `BASCoreMLDraftDecoder`
(TARGET verify/accept/trim VERBATIM from `BASPromptLookupDecoder` → byte-identity inherited; + the draft KV
RESYNC: K+1 propose forwards so every proposal's K/V is written, then 1 commit forward for the correction) +
`BASANESpecHybridProbe` (`BAS_ANE_SPEC_PROBE`). Design de-risked by a 3-agent panel.

On-device A/B (iPhone A19, K=4, spec vs the SAME decoder at K=0 = pure greedy):

| target | draft units | workload | mean_acc /4 | hit_rate | speedup | token_identical | peak |
|---|---|---|---|---|---|---|---|
| 1B-4bit | GPU | rag-quote | **3.88** | 0.97 | 0.70× | YES | 1097 MB |
| 1B-4bit | ANE | rag-quote | 3.88 | 0.97 | 0.73× | YES | 1285 MB |
| **3B-4bit** | GPU | rag-quote | **4.00** (perfect) | 1.00 | 0.89× | YES | **2253 MB** |
| 3B-4bit | GPU | code-repeat | 3.00 | 0.75 | 0.82× | YES | — |
| 3B-4bit | GPU | control | 1.88 | 0.49 | 0.70× | YES | — |

**CERTIFIED CORRECT:** token_identical=3/3 every config (the draft only proposes; the target argmax is
authoritative — ADR-039 holds with a real Core ML draft). Acceptance up to **4.00/4** (3B target, rag-quote:
the int8 1B draft predicts the 3B argmax perfectly on verbatim quote) — this certifies the draft KV RESYNC (a
broken cache stays byte-identical but collapses acceptance to ~0; it didn't). **Memory fits**: 3B + int8 draft =
2253 MB < 3376 cap — the int8 draft adds only ~14–30 MB resident (clean-page mmap), so the "won't co-reside"
fear was wrong.

**But speedup < 1 everywhere (0.70×–0.89×) — net loss as built (亏的不要 → DON'T ship). Precise diagnosis:**
1. **Draft not cheap enough** — the int8 1B forward is ~0.68× the 3B-4bit target forward (int8 dequant overhead
   eats the size win); break-even for the K+2-forwards/round scheme needs draft < ~0.58× target.
2. **No ANE offload at execution** — `.all` fails the executable plan (Core ML **error -14**, mixed ANE/GPU
   partition); `.cpuAndNeuralEngine` runs but the int8 stateful ANE per-forward is comparable-to-SLOWER than GPU
   (consistent with B0/B1) — the ANE is not the free/fast hardware the thesis assumed.
3. **Serial loop** — propose-then-verify puts the draft cost on the critical path. The win needs the draft to run
   ∥ the GPU verify (overlap round r+1 propose with round r verify) — the deferred "v2" — so the draft is hidden.

### Honest re-measurement (fair baseline, no draft prefill) — the conventional 1B-draft hybrid is a 3× SLOWDOWN

The 0.70–0.89× above was a MEASUREMENT ARTIFACT: the K=0 baseline wrongly paid the draft prefill too (canDraft
ran regardless of K). With the baseline fixed to pure target greedy (no draft work) + a warmup + a long workload:

| workload | mean_acc | **speedup (fair)** | ane/gpu |
|---|---|---|---|
| rag-quote | 4.00 | **0.20×** | 3.06 |
| code-repeat | 3.00 | 0.35× | 3.38 |
| long-quote | 3.79 | 0.40× | 4.33 |
| control | 2.26 | 0.39× | 2.29 |
| **mean** | — | **0.34×** | — |

**The honest end-to-end is a ~3× SLOWDOWN.** Two structural causes: (1) the draft prefill is O(promptLen)
**sequential** forwards (a seq=1 Core ML stateful model CANNOT batch-prefill the prompt the way the MLX target
does in ONE forward) — ~4000 ms draft prefill for a 50-token prompt vs the target's ~64 ms batched prefill; (2)
even the LOOP loses on most lanes — K+2=6 draft forwards × ~0.72× verify ≈ 4.3× verify cost/round, MORE than the
~4 tokens it saves. The 1B draft is too expensive and there are too many forwards/round.

**Verdict — the conventional separate-1B-draft hybrid is DECLINED DEFINITIVELY (亏的不要): a measured 0.34× net
loss that loses badly to Track A (prompt-lookup, 1.58×).** It is certified-correct (token-identical 4/4) but
structurally the wrong design. The fix requires the AGGRESSIVE frontier, not tuning: (i) FEWER draft forwards/round
(tree/Medusa heads propose K in ONE forward), (ii) a much CHEAPER draft (EAGLE: a 1-layer head on the target's
hidden state, ~0.1× the target, trained → high acceptance, no separate-model prefill), (iii) batched draft prefill.
The conventional hybrid is a certified-correct FOUNDATION (the verify/accept/RESYNC machinery is reusable) but a
mediocre design; the next arc is tree-structured speculation (training-free, builds on the Track A win) and/or an
ANE-resident EAGLE head (SOTA, training-based).

**Verdict — the "压榨 CoreAI" hybrid is BUILT, byte-identical, and CERTIFIED, but does NOT win on the A19 as built.**
The negative is MEASURED, not assumed. Two evidence-gated paths to a win (next arc): (a) a genuinely CHEAPER draft
(4-bit, not int8, or sub-1B same-tokenizer) to get draft < 0.58× target; (b) TRUE ANE∥GPU overlap so the draft
leaves the critical path. Until one lands, the shipped universal decode win remains **Track A (prompt-lookup,
token-identical, 1.58× repetitive, production-wired)** — and the B2 mechanism is a certified, correct foundation
the next arc builds on, not a dead end.

---

## Track E — Saguaro (SSD) on iOS-27 **CoreAI** — Phase-0 capability gate (2026-06-14, iPhone Air A19)

The NEW `import CoreAI` framework (`AIModel`/`InferenceFunction`/`NDArray`/`ComputeStream`), distinct from the `MLModel`
Core ML of B0–B2. Goal: a universal speculative-speculative decoder (Saguaro, arxiv 2603.03251) on CoreAI. This is the
Phase-0 *capability* gate (toolchain + runtime + Swift + on-device compile/throughput). Full build plan:
`Docs/COREAI_SAGUARO_INTEGRATION_PLAN.md`.

**GREEN (host + Swift):**
- **Toolchain** — `coreai-torch 0.4.0` converts a stateful Llama-3.2-1B decoder → `.aimodel` with a real fused KV `state`
  (`read_handle`/`write_handle`; one mutated buffer → one CoreAI state → one Swift `insert`, sidestepping the 32-way
  `~Escapable` borrow problem). **torch fidelity 24/24** vs HF greedy.
- **Host runtime** — the `.aimodel` loads + runs on `coreai.runtime`; KV state persists across calls (toy + tiny + 1B).
- **Swift** — `BASCoreAIDecodeSession` (stateful decode driver: prefill/step/propose/commit/reset; `run(inputs:states:)`
  with the fused KV via an `inout` helper) **compiles under the real Xcode-27 / iPhoneOS27 SDK** and runs on the A19 far
  enough to load + attempt the model.

**Fidelity bug — localized then FIXED:** the converted `.aimodel` was 0/24 on greedy. First bisection misattributed it to
the `attn·vr` matmul; deeper bisection proved the matmul is **faithful** (MAE 1.3e-8) and the real fault is the **one-hot
KV write** — `coreai_torch 0.4.0`'s `broadcasting_mul` mis-lowers the double-broadcast `v*oh` (v `[1,n_kv,1,hd]` size-1
seq × oh `[1,1,MAX_SEQ,1]` size-1 head), **zeroing every kv-head beyond head 0**. Fix: a `torch.where` select
(→ `broadcasting_where`) for the write — **full 1B `.aimodel` → 24/24**, strictly cheaper. (Applied to
`Tools/llama_to_coreai.py`; reused identically in the multi-position verify scatter.)

**RED on-device (gate (a) — the decisive device finding, fp16 AND int8):** the 1B decode graph **fails to compile/load
on ALL THREE A19 backends at BOTH precisions** in CoreAI 0.4.0 beta:

| model | `.cpuOnly` (BNNS) | `.gpu` | `.neuralEngine` (aned) |
|---|---|---|---|
| **fp16 1B** (2.3 GB) | `BNNSCompileError.compilationFailed` | SIGABRT (load) | OOM `std::bad_alloc` → SIGABRT |
| **int8 1B** (1.24 GB, 24/24 host) | `BNNSCompileError.compilationFailed` | SIGABRT (load) | **SIGABRT (compile)** |
| **tiny** (2-layer, vocab 320) | ✅ compiles + loads (Δ17 MB) | — | — |

int8 weight-quant (verified: `coreai_torch._compression` → `(Int8, …)` storage, 1.24 GB, **host fidelity 24/24**) was the
chosen P0.5 unblock — and it **did NOT clear any backend** (still crashes/fails all three). A tiny model compiles + loads
fine. **So the wall is beta-compiler ROBUSTNESS on the 16-layer / 128k-vocab graph, NOT size/quantization** — halving the
bytes changed nothing. (The uncatchable `std::bad_alloc`/SIGABRT crashes happen in `AIModel.load`→compile, before any
Swift decode code runs — not our bug; the fp16-input/state/logits dtype is correct.)

**Verdict — CoreAI is the rigorous substrate (strictly more than Core ML: stateful KV + first-class `ComputeStream`
concurrency + async `encode`/`AsyncValue` zero-copy + dynamic shapes); the HOST toolchain + fidelity are SOLVED (24/24
fp16 AND int8); the Swift integration compiles + runs on-target — BUT the on-device throughput gate (G3) is BLOCKED by the
iOS-27 CoreAI 0.4.0 BETA COMPILERS: all three backends crash/fail on a 1B-class LLM decode graph at both fp16 and int8,
while small models compile fine.** This is a beta-toolchain maturity wall, not a design or memory failure — a legitimate
**DECLINE-for-now (亏的不要)**: the on-device path is blocked upstream, not by us. Concrete paths when revisited: a future
CoreAI/`aned` beta that compiles the graph; **heavy layer-split** multi-function assets (each chunk under the beta's
robustness limit); or a **much smaller target** (sub-1B draft / Gemma-3n-E2B). The shipped universal decode win remains
**Track A (prompt-lookup, byte-identical, 1.58× repetitive, production-wired)**. The CoreAI foundation (fixed converter +
int8 + Swift session + the full Saguaro plan in `COREAI_SAGUARO_INTEGRATION_PLAN.md`) is ready for the moment the beta
compilers mature — evidence-gated (G0 ✅ done; G1–G3 pending an on-device compile).

### Track E AUDIT (堵死原因) — the "DECLINE" above was PREMATURE; root cause found, ANE decode WORKS (2026-06-14)

The operator challenged the "beta-compiler robustness wall" conclusion ("全面 audit 堵死原因"). The audit **falsified it.**
On-device bisection (real Llama-1B dims, random weights, fp16, ANE, `BAS_COREAI_UNITS=ane`):

| variant | layers | vocab | compiled size | ANE | tok/s |
|---|---|---|---|---|---|
| L1  | 1  | 128256 | 0.60 GB | ✅ compiles + decodes | **78.5** (2× MLX) |
| L8  | 8  | 128256 | 1.40 GB | ✅ | 36.0 |
| **L12** | 12 | 128256 | **1.99 GB** | ✅ | 27.0 |
| L16 | 16 | 4096   | **1.83 GB** | ✗ SIGABRT | — |
| L16 | 16 | 128256 (fp16/int8) | 2.3 / 1.15 GB | ✗ | — |

**Root cause: a per-asset LAYER-COUNT (op-count / graph-depth) ceiling in the iOS-27 CoreAI 0.4.0 ANE compiler at ~12–15
transformer layers — NOT memory, NOT disk, NOT the 128k-vocab op, NOT byte-size.** Decisive evidence: **L12 @ 1.99 GB
compiles but L16 @ 1.83 GB does not — bigger passes, smaller fails ⇒ it tracks layer count, not bytes.** Disk ruled out
(int8 still SIGABRTs on a clean 245 GB-free container); the 128k-vocab op ruled out (L1 compiles it fine, 78.5 tok/s);
memory ruled out (L12 peak 2.3 GB < 3248 cap). The standard 16-layer Llama-3.2-1B sits **just over** the limit.

**Two corrections to the record:** (1) **ANE CoreAI decode genuinely works and is fast** — my "fundamental wall" framing
was wrong. (2) The fix is **layer-split**, now a CONCRETE, validated path (not a vague "when the beta matures"): split the
16-layer 1B into ≤12-layer chunks (e.g. 8+8) as separate `.aimodel` functions, drive sequentially through one KV frontier
→ the full 1B compiles + runs on the ANE today. Throughput note: standalone full-16 extrapolates to ~22 tok/s (random
weights, full 128k lm_head every step — wasteful for a draft; optimizable), but Saguaro's value is ANE-draft ∥ GPU-verify
overlap, not standalone tok/s. **Gate (a) is GREEN for ≤12 layers; the 1B needs layer-split. Not a decline — a measured,
fixable per-asset limit.** (GPU/BNNS not re-tested at low layer counts — may share the same limit or differ; ANE is the bet
and it works.)

### Track E AUDIT cont. — layer-split DEVICE result: the full 1B does NOT run on the ANE (the per-asset cap can't be split around)

The "layer-split → full 1B on the ANE today" hope above was itself too optimistic on the DEVICE side (HOST was 24/24). Built
+ measured the 8+8 split end-to-end and it CORRECTS that:
- **Converter** (`Tools/llama_to_coreai_split.py`): 16-layer 1B → N chunks; chained **HOST fidelity 24/24** (the cross-chunk
  hidden hand-off must be fp32 — all-fp16 is 0/24, the layer-boundary residual has outliers fp16-rounding flips). ✅ host
- **Swift** `BASCoreAILayerSplitSession`: pipes the fp32 hidden chunk→chunk; typechecks; chunk0 alone LOADS + RUNS on device. ✅
- **DEVICE — every on-ANE form of the full 16-layer 1B FAILS:**
  - 2 SEPARATE 8-layer assets → **SIGSEGV (signal 11) at the 2nd `AIModel.load`** (the device CoreAI runtime won't hold two
    separately-loaded AIModels in one process).
  - 1 MULTI-FUNCTION asset (stage0+stage1, host 24/24, unique kv0/kv1 states) → **SIGABRT (signal 6)**. DECISIVE: loading
    **stage0 ALONE** (8 layers) from the mfn asset on a clean cache ALSO SIGABRTs → **the ANE compiles the WHOLE ASSET
    (16 layers) when any function loads — the compile is PER-ASSET, not per-function.**

**Corrected conclusion: the ANE compile ceiling is PER-ASSET (~12–15 layers) and CANNOT be split around on-device** —
multi-function shares one asset graph (per-asset compile = 16 layers = over limit), and separate assets can't co-load (2nd
`AIModel.load` SIGSEGV). So **the full 16-layer Llama-3.2-1B does NOT run on the A19 ANE in CoreAI 0.4.0 beta.** What DOES
work, and fast: any **≤12-layer SINGLE-function asset** (L8 36 tok/s, L12 27 tok/s). **Practical CoreAI/Saguaro-on-ANE path: a
≤12-layer DRAFT** (truncate/distill the 1B to ≤12 layers — a quality cost; or a naturally ≤12-layer model), NOT the full
16-layer 1B. The host toolchain + fidelity (fp16+int8 24/24) + the Swift split machinery are all built and ready; the
on-device ceiling is purely the beta ANE compiler's per-asset layer cap. (Plus a 3rd, larger lever if ever needed:
multi-PROCESS — `AIModelCache(appGroup:)` + XPC so each asset is in its own process — explicitly OUT of scope here.)

### Track E AUDIT cont. — real-weight ≤12-layer ANE decode PROVEN end-to-end (engineering ✅; but truncation ≠ usable draft)

To close the loop, built a REAL-weight **12-layer truncated Llama-3.2-1B** (embed + layers 0–11 + final_norm + tied lm_head,
fp16, `Tools/llama_to_coreai_12L.py`) and ran it on the A19 via the single-model `BASCoreAIDecodeSession` (`BAS_COREAI_LAYERS=12`):
- **DEVICE (ANE): compiles + decodes END-TO-END — 27.5 tok/s, peak 2.25 GB, real token ids.** The first real-weight CoreAI
  ANE decode of a 1B-class LLM on-target. Matches the L12 random-weight (27 tok/s) → confirms the engineering with real weights.
- **Conversion is FAITHFUL** (fp16-torch vs fp16-`.aimodel`: logit corr 0.997, teacher-forced argmax 22/24).
- **BUT the truncated model is a DEGENERATE LM** (free-running greedy 1/24, repetition-collapse; near-tied logits make argmax
  precision-unstable — even fp32-torch vs fp16-torch disagree). Dropping 4 of 16 layers wrecks coherence. So a truncated-12L
  is *runnable + faithful* but *useless as a generator or a high-acceptance draft*.

**Final CoreAI-ANE picture:** the **engineering is GREEN** — a real ≤12-layer LLM decodes on the A19 ANE end-to-end (27.5
tok/s), byte-faithful, < cap. The **blocker is the model**: the per-asset ≤~12-layer ANE ceiling (a) excludes the full
16-layer 1B (can't split around it — per-asset compile + 2nd-AIModel SIGSEGV) and (b) truncating to fit yields garbage. A
USABLE CoreAI-ANE draft therefore needs a **properly-trained ≤12-layer model (distillation, not truncation)** OR the beta to
lift the per-asset layer cap. Everything host-side + the Swift drivers are built + committed; the device path works for any
≤12-layer asset the moment a good ≤12-layer model exists.

### Track E AUDIT — 🎯 USABLE ≤12-layer Llama-3 model RUNS ON THE A19 ANE (the win)

Found + ran a real one. Surveyed ≤12-layer decoder LLMs (verified layer counts from HF configs; modern small models trend
DEEP — Llama-3.2-1B=16, SmolLM2=30, Qwen2.5-0.5B=24 — so ≤12 is rare). Coherence-tested the Llama-3-tokenizer candidates via
HF greedy:
- `Axcel7766/...-drafter-500m` (12L, purpose-built drafter) → **degenerate** (emits `<|end_of_text|>` immediately, HF-confirmed).
- `foss22/vikhr-...-depth-pruned` (10L, raw prune) → **garbage** (repetition/random tokens).
- **`TheGardener/KD-llama-0.8b-shortened-epoch-1st-ver1` (9L, depth-prune + knowledge-DISTILLATION, vocab 128256) → COHERENT**:
  "The capital of France is" → *"the city of Paris, the capital of France…"*. KD recovery is what makes the difference.

Converted KD-9L → fp16 `.aimodel` (`Tools/llama_to_coreai.py` is arch-parametric; 9 layers, hidden 2048, 32 heads / 8 KV,
head_dim 64, vocab 128256, 1.62 GB) with REAL llama3 RoPE tables. **DEVICE (A19 ANE, single-model `BASCoreAIDecodeSession`,
`BAS_COREAI_LAYERS=9`): compiles + decodes END-TO-END — 33.6 tok/s, peak 1.83 GB, real token ids.**

**This is the first real, USABLE, coherent ≤12-layer Llama-3-tokenizer model running on the A19 ANE** — and because it uses
the Llama-3 tokenizer it is a **valid speculative-decode DRAFT for a Llama-3.2-3B target** (draft ids are valid target ids).
Coherence is host-proven (torch); conversion is faithful (same converter as the 24/24 fp16/int8 builds); the ANE runs it at
33.6 tok/s. **CoreAI ANE decode of a usable LLM is no longer hypothetical — it works today with a KD'd ≤12-layer model.** Open
next-level work (bigger scope): measure draft **acceptance rate vs the Llama-3.2-3B** + wire the full Saguaro two-stream loop
(the ANE-draft ∥ GPU/MLX-verify overlap, gate G2); and an end-to-end on-device coherence capture (real prompt → decoded text
from the ANE) to complement the host-side coherence proof.

### Track E — 🐍 Mamba-2 (SSD) / Llamba-1B FAITHFUL on CoreAI — full-depth recurrent draft, host 24/24 (2026-06-15)

The ≤12-layer transformer ceiling forces either truncation (degenerate) or a scarce KD'd shallow model. **Mamba-2 sidesteps
the premise:** O(1)/token decode, a FIXED-size recurrent state (no KV growth, no MAX_SEQ window, **no softmax-over-history** —
the exact op the B-track showed the ANE planner routes off-engine), no RoPE/onehot/bias. Model: **`cartesia-ai/Llamba-1B`**
(16-layer "discrete Mamba-2", Llama-3 tokenizer vocab 128256, **distilled from Llama-3.1-8B** → a valid Llama-3.2-3B draft).

**Converter `Tools/llamba_to_coreai.py`** → stateful fp16 `.aimodel` (2.81 GB) with **TWO fused fp16 states** (the per-layer
conv/ssm slots differ in shape so they can't share one rectangle like the transformer KV, but 2 ≪ 32 → two `MutableViews.insert`
via a 2-`inout` helper): `conv_all [16,6144,4]` (rolling causal-conv window) + `ssm_all [16,32,64,64]` (SSM state), ~4.9 MB total;
input `input_id` int32 `[1,1]`, output `logits` fp16 `[1,128256]`; function `main`; positionless `step(token)`.

**FIDELITY — GREEN end-to-end (the operator's top-priority question):**
- **GATE 1** (torch): the exact stateful module that gets exported = **24/24 token-identical** vs an INDEPENDENT fp32 sequential
  selective-scan reference (built from mamba_ssm's documented `selective_state_update_ref` math, real Cartesia weights) + coherent.
- **GATE 2** (the saved fp16 `.aimodel`, CoreAI host / ODIE executor) = **24/24** vs the torch ref + coherent
  (`"The capital of France is" → " Paris. However, the capital of France is not Paris…"`).
- **Mamba-2 lowered through coreai_torch 0.4.0 cleanly — NO fidelity bug.** Unlike the transformer (whose `broadcasting_mul`
  size-1×size-1 double-broadcast zeroed GQA heads, needing the `torch.where` fix), Mamba's conv (`cat+sum`) and SSM
  (explicit-shape muls) have no double-broadcast → converted right the first time. fp16 is faithful for greedy.

**COMPILE-CERT — GREEN:** `Sources/BASAppleAdapters/BASCoreAIMambaSession.swift` (2-fused-state driver, argmax fp16) +
`measureMamba` path in `BASCoreAIDecodeProbe.swift` (`BAS_COREAI_MAMBA=1`, no RoPE, states via `BAS_COREAI_MAMBA_CONV/_SSM`)
both **compiled against the iOS-27 SDK** (`** BUILD SUCCEEDED **`, BASDeviceTestApp for device).

**OPEN — Q1 device run (the decisive question), BLOCKED on device connectivity:** does a **16-layer RECURRENT** Mamba-2 clear
the per-asset ANE layer-count/op-graph ceiling that SIGABRT'd the 16-layer *transformer*? Mamba layers carry no attention/softmax/KV
→ far fewer/simpler ops/layer, so the per-asset budget is plausibly under the ceiling even at full depth — but that is a device
MEASUREMENT, not a claim. App built + 2.6 GB asset ready; run: stage `Llamba1B_fp16.aimodel` → Documents, launch
`BAS_ENDURANCE_AUTOSTART=1 BAS_COREAI_DECODE_PROBE=1 BAS_COREAI_MAMBA=1 BAS_COREAI_UNITS=ane,gpu,cpu`. If 16-layer Mamba clears
the ceiling it would be the first **full-depth** model on the A19 ANE decode lane.

**TTT-Linear evaluated as the alternative expressive-state RNN — DECLINED for now (source-verified, adversarially checked):**
no usable checkpoint (every `Test-Time-Training/ttt-*` HF repo is gated JAX *training-state* artifacts, HTTP 401, no weights;
tokenizer **Llama-2 / vocab 32000**, not Llama-3 → a faithful draft needs a from-scratch Llama-3 distillation, weeks–months);
**24 layers** (vs Llamba's 16) and a heavier per-layer op graph (batch-1 decode is ALWAYS the primal path → per-token `f×f`
outer-product einsum + a 2nd `W1_grad` cache + LayerNorm-fwd/bwd) → *worse* against the ANE ceiling, not better; its only real
edge (>16k long-context) is moot for a short greedy phone draft. The inner "gradient step" is NOT a torch.export blocker
(no autograd, shape-bounded scan — it IS a delta-rule fast-weight recurrence, arXiv 2602.21204), so it remains a cheap *future*
insurance probe (convert one random-weight TTT layer), but not a reason to delay the Mamba ship.

**Probe ladder (what to run; Q1/Q4 need no TTT and settle the Mamba path):** Q1 = the device-ceiling run above (hours, gates all);
**Q4 = Llamba-1B's real acceptance α vs the Llama-3.2-3B target (~1 day, NO device) — the genuinely open risk: we have 24/24
token-identity vs the fp32 REFERENCE but ZERO acceptance data vs the actual 3B TARGET;** Q2 = convert 1 random-weight TTT layer
(future insurance); Q3 = binary-search TTT layer count for SIGABRT (only if Q2 passes); Q5 = from-scratch Llama-3 TTT distillation
(the multi-week disqualifier). Verdict flips to TTT only if a Llama-3-distilled vocab-128256 TTT checkpoint appears, OR Q1 fails
AND Q4 shows Llamba's α is capped by fixed-state forgetting (and even then the first move is a shallower re-distilled Llamba).

### Track E — ✅ Q4 acceptance: Llamba-1B is a STRONG draft for Llama-3.2-3B (host, 2026-06-15) — but the speedup now hinges on draft-SPEED + overlap

Ran the genuinely-open measurement (greedy spec-decode, `Tools` host harness `llamba_q4_acceptance.py`): the faithful fp32
`LlambaDecode` draft (exact recurrent-state snapshot/restore on partial accept) proposing K=4/round, verified against **bf16
`unsloth/Llama-3.2-3B-Instruct` (MPS)** over a 24-prompt battery (factual/narrative/code/instruction), 64 tokens each.

**Result: block efficiency τ = 3.298 tokens / target-forward** (K+1=5 ceiling); overall draft acceptance **0.797**; mean accepted
2.30/4 + bonus. Per-position acceptance **RISES** with depth — d0 0.778, d1 0.784, d2 0.811, d3 0.839 (1573 committed / 477 target
forwards) → the draft does NOT degrade as the block lengthens, so K>4 has headroom — confirmed by the τ(K) sweep below.
Stable across the battery (3.27–3.42). **This validates Llamba as a high-quality draft and FALSIFIES the one condition that
would reopen TTT** (α capped by fixed-state forgetting): Mamba's fixed state is not the bottleneck for this draft/target pair.

**HONEST framing — quality ✅ ≠ guaranteed wall-clock win.** Spec-decode speedup = τ / (K·(t_draft/t_target) + 1) for the
SEQUENTIAL schedule. The catch for THIS pair: the ANE draft is NOT much faster than the MLX 3B target (KD-9L transformer was 33.6
tok/s vs the target's 38.3 tok/s) — so a sequential draft→verify schedule can NET-LOSE even at τ=3.3 (a win needs draft ≳1.7× the
target's per-token speed). **This is exactly why Saguaro's premise is the concurrent OVERLAP** (ANE-draft ∥ GPU/MLX-verify): with
overlap the draft block is hidden behind the verify, and throughput → τ × target-rate (≈ up to 3.3 × 38.3 ≈ 126 tok/s ideal). So
the two REMAINING gates for an actual win are now sharp: **(Q1) does 16-layer Mamba run on the ANE + at what tok/s** (draft speed),
and **(overlap gate, plan Phase-0.4) does ANE∥GPU actually overlap on the A19** (Core ML's was 0.34× — CoreAI ComputeStream +
zero-copy is the bet). τ=3.3 is the necessary green light on draft quality; draft-speed + overlap decide the throughput.
Caveats on the number: bf16 target = architectural upper bound (production MLX 4-bit slightly lower); free-form continuation
(chat-templated may differ).

**τ(K) sweep (`llamba_q4_ksweep.py`, same target/battery) — τ rises monotonically but saturates:**
K=2 → 2.440, K=4 → 3.298, K=6 → 3.892, K=8 → 4.310, K=12 → 4.762 (marginal τ/added-K step: +0.43, +0.30, +0.21, +0.11). Per-token
accept-rate falls as the block lengthens (0.72 → 0.31) but never collapses. **Under overlap you want K≈8–12 (τ≈4.3–4.8 → ~4–5
committed tokens per 3B forward);** the optimal K is draft-speed-dependent (the draft must emit the K-block within the verify
window). Next (operationally exact): re-measure vs the production MLX 4-bit 3B target + chat-templated prompts.

### Track E — Q2: TTT-Linear DOES convert through coreai_torch (future-insurance probe, 2026-06-15)

Ran the cheap checkpoint-free convertibility probe (`Tools/ttt_linear_q2.py`): a structurally-faithful single-step TTT-Linear
layer (in-proj→Q/K/V, inner LayerNorm-L2 loss, MANUAL LayerNorm-backward gradient, the `f×f` OUTER-PRODUCT einsum `hi,hj->hij`
fast-weight update, predict-with-updated-W, SiLU gate; `W1` as a fused mutated CoreAI state). **Verdict: ✅ CONVERTS + host 16/16
vs torch.** The novel/"scary" ops (outer-product einsum + LN-backward) export and lower fine — they were NEVER the blocker. The
ONLY obstacle was `aten.var.correction` (from `.var()`/`F.layer_norm`), which coreai_torch 0.4.0 can't lower → fixed by writing
variance as `((x-mu)**2).mean()` (the same trick the Mamba rmsnorm used). **So the conversion-risk axis against TTT is RESOLVED:
the toolchain will not be the obstacle if/when a Llama-3-distilled TTT checkpoint ever appears.** (Caveat: the 16/16 is on a
degenerate random-weight constant argmax — proves the path runs end-to-end + is self-consistent, not strong numerics.) This does
NOT change the ship-now verdict: TTT remains dominated by Mamba purely on **(1) no usable Llama-3-vocab checkpoint** (weeks–months
to distill one) and **(2) 24 layers + heavier op-graph vs the ~12-layer ANE ceiling** (device-unverified) — and Q4 already showed
we don't NEED TTT (Llamba α=0.80 is strong). Net: TTT is now convertibility-cleared *future insurance*, not a ship-now contender.

### Track E — 🎯 DEVICE VERDICT (real iPhone Air A19, 2026-06-15): Mamba-on-ANE is a WIN, Saguaro spec-decode DECLINES

The full serial Saguaro stack was built (compile-cert iOS-27, host-tested 8/8, adversarially reviewed), then measured on a
real A19. Three device gates:

**Q1 — does 16-layer Mamba run on the A19 ANE? ✅ GREEN (a genuine first).** The fp16 2.6 GB Mamba `.aimodel` `std::bad_alloc`-
crashes on LOAD on BOTH ane AND gpu — the CoreAI-0.4.0 beta **~2 GB asset-size limit** (same wall as the 2.3 GB fp16 transformer;
NOT the layer ceiling, never loads). **int8-quant → 1.41 GB (`Tools/llamba_int8.py`, reuses the transformer's QuantLinear/QuantEmbed
`constexpr_blockwise_shift_scale`) clears the size wall, and then 16-layer int8 Mamba LOADS + DECODES on the A19 ANE: 39.24 tok/s,
peak 77 MB (Δ53 MB resident — mmap CLEAN PAGES), gpu 39.74 tok/s.** So **16 RECURRENT Mamba layers CLEAR the per-asset ANE compile
ceiling the 16-layer TRANSFORMER SIGABRT'd — the first FULL-DEPTH model on the A19 ANE decode lane.** Co-residency is free: the MLX
3B (1846 MB) + the int8 Mamba draft = **Δ9 MB**, peak 2143 MB ≪ 3248 cap (the litert mmap bet pays).

**Serial Saguaro — ❌ 0.10–0.24× (loses badly).** byte-identity HOLDS on every workload (the loop is CORRECT on device), acceptance
is real (code mean_acc 3.2/4, factual 1.86/4, narrative 0.37/4), BUT `draft_ms` is **5–7× `target_ms`**. The int8 Mamba is 39 tok/s
standalone, yet in the loop the draft dominates — because **Mamba's recurrent rewind re-runs the accepted tokens every commit**
(a recurrent state can't KEEP partial-accept writes the way a KV cache does), so the draft does ~2.5× the committed tokens in
forwards. The very thing that made Mamba FIT the ANE (recurrent state, no KV) makes its spec-decode rewind expensive. (The snapshot/
restore deep-clone scalar loop adds more; fixable via bulk memcpy, but doesn't change the verdict.)

**Overlap ρ — ❌ 0.83 < 1 (the decisive gate, FALSIFIED).** Raw ANE-draft ∥ GPU-target concurrency (no rewind, the BEST case):
target 299 ms→**482 ms (+61%)**, draft 827 ms→**1359 ms (+64%)** when run concurrently → concurrent wall 1359 > serial 1126 →
**ρ=0.83. ANE and GPU CONTEND for memory bandwidth; running them together is a NET LOSS.** Much better than Core ML's 0.34×, but
still < 1: **the Saguaro overlap premise — hide the draft behind the verify — does NOT hold on the A19's shared-bandwidth SoC.**

**VERDICT: Saguaro two-stream spec-decode DECLINES on the A19 (亏的不要, evidence-backed).** The decline is STRUCTURAL, not a bug:
(a) the ANE draft isn't faster than the GPU target → serial can't win; (b) ANE+GPU contend for bandwidth (ρ=0.83) → overlap can't
win either. This holds for ANY ANE-draft ∥ GPU-target pairing on this SoC, not just Mamba (a transformer KV-draft would avoid the
rewind cost but still hits draft≈target speed + ρ<1). **What IS banked: (1) Mamba-on-ANE — the first full-depth model on the A19 ANE
decode lane, 39 tok/s, tiny footprint, byte-identity (a real, reusable capability for a STANDALONE small-model ANE lane, just not
for spec-decode); (2) the whole Saguaro stack is built, correct, byte-identical, default-OFF — ready if the SoC bandwidth economics
ever change.** Device run-book: stage assets via `devicectl device copy to --domain-type appDataContainer`; launch with `devicectl
device process launch --environment-variables '{...}'` (JSON, NOT --environment); app com.changgeng.basdevicetest on the A19.

---

## Track F — Mamba-3 weights-free ANE probe (2026-06-15): host GREEN, CPU runs, **ANE compiler SIGSEGVs**

> **⚠️ SUPERSEDED by Track G.** This track's conclusion — "Mamba-3 does NOT compile on the A19 ANE (SIGSEGV)" —
> was FALSIFIED: the crash was NOT an op-graph limit but a state-registration-ORDER bug. With the 2 states
> registered angle-first, the SSD+RoPE+MIMO graph compiles + decodes on the ANE (Track G). Read Track G's audit
> correction for the honest scope of what runs.

The "upgrade to Mamba-3" gate. The study (memory `mamba3-coreai-convertibility.md`) predicted Mamba-3 converts + lands
on the A19 ANE "as cleanly as Mamba-2". A weights-free probe (random weights at the Llamba-1B config — L=16, d=2048,
H=32, P=64, N=64, MIMO R=4 — int8) was built to test the OP-graph compile + speed, no checkpoint/training. Driver:
`Tools/mamba3_to_coreai.py` (+ ablations), `Sources/BASAppleAdapters/BASCoreAIMamba3Session.swift`,
`DeviceTestApp/.../BASCoreAIMamba3Probe.swift` (`BAS_COREAI_MAMBA3_PROBE=1`).

**Host convertibility — ✅ GREEN (prediction confirmed).** The full Mamba-3 step — real 2×2-rotation / data-dependent
RoPE, trapezoidal 3-term recurrence, AND the MIMO rank-R einsums (`hpr,hrn->hpn`) — lowered through coreai_torch 0.4.0
first try, no unsupported-op error. L=16 int8 = **1.04 GB** (under the ~2 GB beta load wall). Host CoreAI runtime
loads + runs it (3 steps OK).

**On-device CPU — ✅ runs.** Flat single-state L=16 int8 loads in 1.85 s and decodes at **23.1 tok/s, 56 MB peak** on
the A19 CPU. The op-graph is valid silicon.

**On-device ANE — ❌ compiler SIGSEGVs (the prediction FALSIFIED for the ANE lane).** `AIModel(contentsOf:options:
ane)` crashes with **signal 11** during compile/segmentation — for EVERY variant tried: 4 properly-shaped states,
1 flat fused state, 2 properly-shaped states, AND op-ablations `norope` / `nomimo` / `plain` (a bare SSD step with
no rotation, no MIMO, no RMSNorm). So the ANE crash is **NOT the Mamba-3 ops** — it persists in a minimal SSD step —
while the structurally-similar, PROVEN Llamba Mamba-2 int8 kernel ANE-compiles (Track E, 39 tok/s). ⇒ a beta-ANE-
compiler limitation on this hand-written-from-scratch op formulation, not a Mamba-3 fundamental. (The concurrent
boot smoke suite is ruled out: it completes before the crash and CPU runs of the same asset never crash.)

**Secondary converter bug — CoreAI multi-state segmenter ordering.** Models carrying >1 properly-shaped mutable state
in a "wrong" relative order fail (CPU clean error / ANE SIGSEGV): *"order of token outputs does not match order of
handle inputs … Failed to rewrite module using segmenter"*. The device segmenter pairs state INPUTS by graph
first-use with state OUTPUTS by registration; when a layer reads a later-registered state first (here `angle` read
before `ssm` for the RoPE), they mismatch. Llamba's conv→ssm order dodged it; a single flat state dodges it (one
state, no ordering) — which is why the flat variant is the one that CPU-runs. Source-order reordering does NOT fix it
(torch.export reorders by data-dependency). The robust converter fix is a single flat state OR matching the exact
proven Llamba kernel's state read/write order.

**VERDICT: Mamba-3 is convertible (host + CPU proven) but does NOT compile on the A19 ANE in the current beta toolchain.**
Combined with the study's hard gate (NO instruct checkpoint exists — kernels-only release), the "upgrade to Mamba-3"
decision is **NOT NOW, evidence-backed (亏的不要)**: the only on-device lane it currently runs is CPU at 23 tok/s,
BELOW the banked Mamba-2 ANE 39 tok/s. Mamba-3 stays a real FUTURE upgrade for the tiny-ANE lane (half-state @ equal
quality + ANE-friendly arithmetic intensity, convertibility proven) — actionable when BOTH (a) a checkpoint is
released and (b) the ANE compile is unblocked (either a newer toolchain, or porting the step to the exact op
formulation the proven Llamba Mamba-2 kernel uses rather than a from-scratch graph).

---

## Track G — Mamba-3 RUNS ON THE A19 ANE (2026-06-15): Track F's "ANE SIGSEGV" was a STATE-ORDER bug, now fixed

> **AUDIT CORRECTION (R1, 2026-06-15 — read first).** The "FASTER than Mamba-2, blocked ONLY on a checkpoint"
> framing below is OVERSTATED on three confirmed counts: (1) the graph that runs at 50.9 tok/s
> (`Tools/mamba3_full_ane.py`) is **Mamba-2 SSD + data-dependent RoPE + MIMO rank-R — NOT the trapezoidal 3-term
> recurrence** (it discards the learned A, hardcodes A=−1, Euler 2-term). The faithful trapezoid
> (`Tools/mamba3_to_coreai.py`) has ZERO on-device decode measurement — **trapezoid-on-ANE is UNPROVEN.** (2) The
> 50.9 > 39 comparison is **mixer-only (no per-block MLP) vs the full hybrid Mamba-2** — the missing MLP, not MIMO,
> is the leading explanation; NOT a like-for-like win. (3) Random weights → ZERO quality/acceptance signal. WHAT
> GENUINELY BANKS: the SSD+RoPE+MIMO op-graph compiles + decodes on the A19 ANE (50.9 tok/s / 84 MB, L=16, int8),
> and the **angle-first state-order fix is real + reproducible** (correctly overturning Track F's op-crash
> diagnosis). Honest claim: "an SSD+RoPE+MIMO graph runs on the A19 ANE; angle-first is the ANE-compile fix; the
> faithful Mamba-3 trapezoid, a real checkpoint, and a fair MLP-included speed A/B all remain to do."

**Reversal of Track F (R1 — new measurement overrides).** Track F concluded the A19 ANE compiler SIGSEGVs on the
Mamba-3 op-graph. A full op-bisection (workflow `mamba3-ane-crash-localize` + on-device ladder) FALSIFIED that: the
crash was never an op — it was the carried-STATE LAYOUT + registration ORDER.

**The bisection (each a device run):**
- **1 properly-shaped state** (ssm_all [L,H,P,N]), op-for-op the proven Llamba SSD step (RMSNorm, A=-1, pre-divide
  x by dt, broadcast outer via view) → **✅ ANE compiles + runs, 145.8 tok/s (L=2)**. So the SSD math, norm, dt/A,
  and the rank-0 select are ALL exonerated (they're byte-identical to or simpler than the shipped Llamba kernel;
  the broadcasting_mul precedent is a fidelity bug, not a crash).
- **Flat single fused state** [L,S] with op-for-op Llamba body → ❌ ANE SIGSEGV. The heterogeneous slice/reshape
  (`row[0:o1].reshape(...)`) is an ANE-compiler crasher → do NOT flat-pack states.
- **2 properly-shaped states, ssm-FIRST** (ssm_all, angle_all) → ❌ ANE SIGSEGV.
- **2 properly-shaped states, angle-FIRST** (angle_all, ssm_all) WITH full data-dependent RoPE rotation + MIMO
  rank-R einsums → **✅ ANE compiles + runs**. The 2nd-state registration ORDER is the whole story: put the
  smaller RoPE/angle state FIRST (mirroring how the proven Llamba kernel registers conv before ssm). ssm-first
  trips the coreai_torch/ANE segmenter; angle-first threads correctly.

**Headline (full Mamba-3, data-dependent RoPE + MIMO R=4, int8, L=16, A19 ANE):**
| | load (1-time compile) | decode tok/s | peak MB |
|---|---|---|---|
| **Mamba-3 (RoPE+MIMO, angle-first 2-state)** | ~10.0 s | **50.9** | **84** |
| Mamba-2 banked (Llamba, Track E) | — | 39 | 77 |

Mamba-3 is **FASTER than Mamba-2 on the ANE** (50.9 vs 39 tok/s) at comparable footprint — exactly the paper's
promise (MIMO fills idle memory-bound decode compute; the trapezoid/no-conv step is lighter). CAVEAT: this probe
is mixer-only (no per-block MLP) + random weights, so the absolute tok/s is not a perfect apples-to-apples vs the
hybrid Llamba; a real instruct checkpoint with the MLP would be somewhat slower. But the decisive facts hold:
**the full Mamba-3 op-graph (rotation + MIMO) compiles and decodes on the A19 ANE at competitive speed + tiny
footprint.** (CPU still errors on the 2-state with "order of token outputs…" for BOTH orders — a CPU-backend
segmenter quirk, irrelevant to the ANE deployment lane.)

**VERDICT FLIP — Mamba-3 ANE convertibility + speed = GREEN. The upgrade is blocked ONLY on a checkpoint.** Track F's
"NOT NOW, toolchain-blocked" is corrected: there is NO toolchain blocker once states are registered angle-first.
When a Mamba-3 instruct checkpoint ships (or we train/distill one — the sole remaining gate, kernels-only release),
it is a **drop-in, faster-than-Mamba-2 ANE draft / standalone tiny-model** for the banked ANE decode lane. Converter:
`Tools/mamba3_full_ane.py` (the working angle-first full Mamba-3); `Tools/mamba3_1state.py` (the localizing control);
driver `BASCoreAIMamba3Session` (generic 1-or-2 state) + `BASCoreAIMamba3Probe` (`BAS_COREAI_MAMBA3_PROBE=1`,
`BAS_COREAI_MAMBA3_STATES="16,32,32;16,32,64,64"`).

### Track G addendum — standalone Mamba-on-ANE decode SPEED ENVELOPE (2026-06-15)

How fast can the standalone Mamba-on-ANE decode lane go on the A19? Swept layer depth × quant (angle-first
SSD+RoPE+MIMO, random weights, **mixer-only/no-MLP** — the SPEED CEILING, not a usable model). All on the A19 ANE,
96 decode steps:

| quant | L=8 | L=10 | L=12 | L=16 |
|---|---|---|---|---|
| **int8** | 79.6 (69 MB) | 70.0 (78 MB) | 62.0 (83 MB) | 50.9 (84 MB) |
| **int4** | **140.7** (72 MB) | — | **107.6** (85 MB) | 89.9 (93 MB) |

Levers (decode is memory-bandwidth-bound; the 128k-vocab tied-head is a large fixed per-step read): **int4 ≈ 1.77×
over int8** (50.9→89.9 at L=16, asset 991→496 MB); **fewer layers** raises tok/s ~linearly (~0.93 ms/layer + ~4.8 ms
fixed). Targets: **75 tok/s** = int8 L≈9 OR int4 L=16 (89.9, full depth); **100 tok/s** = int4 L=12 (107.6) OR int4
L≈14 (near-full depth). HONEST BOUND (R1): random-weight + mixer-only = the op-graph speed ceiling; a real instruct
model (with the per-block MLP + trained weights) at the same (depth, quant) would be somewhat slower, and int4 costs
quality vs int8 — so a *usable* 100-tok/s standalone model = land this (depth × int4 × MLP) point with a real
checkpoint/distillation. What's proven: the A19 ANE can DECODE a Mamba SSD+RoPE+MIMO graph at 90–140 tok/s.

### Track G addendum 2 — Asymmetric Duo: Mamba-3-as-TARGET + chunked-GEMM verify on ANE (2026-06-15)

The operator's "Asymmetric Duo" reframing — Mamba-3 as the spec-decode TARGET (not draft), tiny transformer as the
GPU draft — escapes every wall that killed Saguaro, and each escape is now DEVICE-MEASURED. One Mamba-3 .aimodel
with TWO functions sharing state: `decode[1,1]` (recurrent) + `verify[1,K]` (chunked-GEMM: in_proj/out_proj/lm-head
batched `[K,d]×W` so weights are read ONCE, amortized over K; SSM recurrence a cheap per-token scan). A19 ANE, int4,
L=8 (`Tools/mamba3_dual_ane.py`, `BASCoreAIMamba3DualSession`, `BASCoreAIMamba3DualProbe`, BAS_COREAI_DUAL_PROBE=1):

| metric | K=4 | K=8 |
|---|---|---|
| decode[1,1] | 7.35 ms (136 tok/s) | 7.30 ms (137 tok/s) |
| verify[1,K] per token | 3.34 ms | **2.22 ms** |
| **verify-vs-K-sequential-decodes** | **2.20× cheaper** | **3.29× cheaper** |
| decode↔verify switch overhead | +1.86 ms | −0.07 ms (≈ free) |
| peak MB | 603 | 595 |

KEY RESULTS (measured): (1) the `[1,K]` conv-mode verify graph COMPILES + runs on the A19 ANE (one-time ~18–30 s
compile). (2) The decode↔verify SWITCH is FREE — one asset, two functions, shared fused state → a function
dispatch, no recompile/reload/state-copy. (3) The UNROLLED verify (K separate `[1,d]` steps) is 1.01× (no win — it
re-reads weights K times); the CHUNKED-GEMM verify (batched `[K,d]×W`) amortizes the weight read over K → 2.2×
(K=4) / 3.3× (K=8) cheaper than K sequential decodes, SCALING with K. This is the enabler that flips spec-decode
from loss to win on this lane: at τ≈4.3 (α=0.8) the verify-bound effective ceiling is ~244 tok/s, ~1.8× over bare
137. WHY it beats Saguaro: Mamba-3-as-target has NO draft-rewind (the target only forward-scans), and the
cross-engine payload is K tokens (bytes) not states → no ρ=0.83 bandwidth contention. R1 HONEST: the 2–3× verify
amortization + free switch + 137 decode are MEASURED; the ~1.8× end-to-end win is PROJECTED, contingent on
(a) a draft cheap enough to not exceed the verify time (Lookahead/n-gram or a 2-layer tiny transformer),
(b) the draft's real α (τ assumed from α=0.8), and (c) a trained Mamba-3 target checkpoint (random weights here =
speed only). Net: the kernel/architecture is validated; the remaining work is TRAINING, not the SoC walls.

### Track G addendum 3 — int4 acceptance de-risk: does int4 quantization crater the SSD draft? NO (2026-06-15)

THE GATE. The grafting-recipe go/no-go made the whole Mamba-3-on-ANE direction hinge on one cheap measurement:
*int4 is mandatory on ANE (fp16 hits the ~2 GB asset-load wall), so does int4 quantization destroy an SSD decoder's
quality?* Measured on the EXISTING trained Mamba-2 (Llamba-1B), as a fidelity proxy = acceptance vs Llama-3.2-3B,
same harness as the fp32 baseline (K=4, N_GEN=64, 24 prompts). Method = naive **post-training** per-output-channel
symmetric int4 fake-quant (qmax=7) on all 80 draft `nn.Linear` + the embedding; conv/D/norms stay fp16. NO QAT.

| config | block-eff τ (tok / target-fwd) | accept-rate α | accepted draft tok/round |
|---|---|---|---|
| fp32 baseline | 3.298 | 0.797 | 2.30 / 4 |
| **int4 PTQ (this de-risk)** | **2.462** | **0.644** | **1.462 / 4** |
| Δ | −0.836 (−25% rel) | −0.153 (−19% rel) | −0.84 |

VERDICT — **int4 did NOT crater (branch B, greenlight).** PTQ costs ~15 pts of agreement and ~25% of block
efficiency, but the draft still tracks the target 64% of the time and τ=2.46 keeps spec-decode net-positive (still
~2.46 tok per target forward vs 1 bare). No collapse. Since this is **PTQ** (the pessimistic floor), QAT is expected
to claw back a large fraction of the 0.153 gap (typical recovery 50–80% → projected α≈0.70–0.76).

WHAT THIS DECIDES vs DOESN'T (R1 honest):
- **Decides:** int4 is a viable quantization for an SSD ANE decoder → the int4-on-ANE direction is NOT killed; the
  **standalone int4 Mamba-2 (Llamba-1B) ANE decoder is greenlit**, with QAT-int4 as the next concrete step to recover
  the PTQ loss. This is the cheap, near-certain win — now de-risked.
- **Does NOT decide:** whether Mamba-3's new features (data-dependent rotation, MIMO rank-R, trapezoidal recurrence)
  pay enough over a QAT-int4 Mamba-2 baseline to justify the multi-week graft. That gate (G2/G3 ablation) is STILL
  UNMEASURED and STILL the expensive question. This de-risk only confirmed int4 won't slam the door shut on either
  Mamba-2 OR Mamba-3 — it did not open the Mamba-3-specific door.

Net route: ship QAT-int4 Mamba-2 ANE decoder first (near-certain); the Mamba-3 graft stays a gated upgrade whose
justifying measurement is not yet taken.

### Track G addendum 4 — "is the Mamba-3 graft worth it?" GATE (b) RESOLVED: NO-GO (2026-06-15)

Gate (b) = does Mamba-3 pay over a QAT-int4 Mamba-2 baseline? Tested via a research+adversarial-verify workflow
(73 agents: 4 evidence lenses → 2 skeptics per load-bearing claim → synthesis). Hard constraint: NO trained
Mamba-3 checkpoint exists, so α_Mamba3 cannot be measured — the verdict BOUNDS the expected lift Δarch from the
paper's own iso-param ablations + distillation/spec-decode literature, adversarially verified. 31 of 34 claims
were refuted/weakened by skeptics; the verdict held at the defensible floor anyway.

INT8 ANCHOR (measured, same harness): int8 α=0.803 / τ=3.314 ≈ LOSSLESS vs fp32 (0.797/3.298). ⇒ the entire
int4 PTQ drop (→0.644) is int4-rounding, NOT model fragility → QAT-int4 has large recovery headroom; AND the 1B
ceiling (~0.80) is NOT quantization-limited → it is a SIZE/capacity ceiling.

VERDICT — **NO-GO. Ship QAT-int4 Mamba-2; do NOT start the multi-week Mamba-2→Mamba-3 graft.** The chain:

| term | value | basis |
|---|---|---|
| Δarch_fp (Mamba-3 vs Mamba-2 @~1B, iso-param) | +0.7pp dn / −1.1% ppl (SISO) ; +1.9pp / −2.2% (MIMO) | paper Table 1 (arXiv 2603.15569 / OpenReview HwCvaJOiCj), VERIFIED iso-param/iso-data |
| → acceptance lift Δα_fp | **+0.005 to +0.02** | inference (paper has NO spec-decode/int4/acceptance result) |
| × workload discount (Lens B) | 2 of 3 win-regimes (state-tracking, long-ctx) OUT of our short-ctx regime; ppl→argmax sub-linear → stays at low end | literature |
| − size ceiling (Lens C) | ~80–85% capacity-bound at 1B-vs-3B; residual is MMLU(−8pp)/Lambada(−11.7pp) knowledge/recall an SSM swap can't fix | measured residual + distill lit |
| − Δquant_extra (Lens D) | ~[−2,+2] pts α, UNMEASURED, sign-open (new rotation on outlier-heavy/recurrence-amplified B/C path = credible negative tail) | inference (no SSM int4 lit touches Mamba-3 ops) |
| = **Δarch_deployed** | **≈ +0.005 to +0.02 α, with a ≤0 tail** | — |
| worth-it threshold | **≈ +0.05 α** | must beat the SAFE FALLBACK on the same knob |
| SAFE FALLBACK: QAT-int4 on existing Mamba-2 | projected **+0.056 to +0.116 α** recovery, zero architecture risk | 50–80% of PTQ gap |

Net: the graft's realistic lift is **2.5–10× below threshold and strictly dominated by QAT-int4 Mamba-2** — which
recovers MORE acceptance on the same knob with no checkpoint problem and none of the burned pitfalls (dt-cancel,
broadcasting_mul, fp16 2GB wall, multi-week unmeasurable train). The most expensive graft item (data-dependent
rotation/complex state) contributes ~0 to LM perplexity — its only verified win is synthetic state-tracking, which
is out-of-regime for short-context greedy decode vs a 3B teacher. Per 亏的不要, this is a legitimate evidence-backed
NO-GO. R1 honest: this is bounded fp-proxy inference, not a measured α_Mamba3 — but nothing measured supports a GO,
and the one acceptance pair we OWN (fp32 0.797 / int4 0.644, int8 0.803) says the binding levers are quantization
recovery + draft SIZE/distillation, not the SSM variant.

NEXT STEP (the route, decided): **ship QAT-int4 Mamba-2 (Llamba-1B)** — train the scoped QAT-int4 run to recover
the −0.153 PTQ loss (target α≈0.70–0.76), certify on the 24-prompt greedy harness + on-device. If MORE acceptance
is wanted after, spend it on Lens-C's high-leverage levers — re-distill the 1B draft directly to the Llama-3.2-3B
target (current Llamba-1B was distilled to a 1B-class teacher = fixable mismatch), an EAGLE-3-style objective,
and/or a 1.5–3B draft — NOT an architecture graft.

ONE cheap experiment that could flip it (days, no retrain): PTQ-graft ONLY the trapezoid + real-valued rotation
(RoPE-trick on B/C) onto the EXISTING Llamba-1B weights, run the same int4 PTQ, measure α vs the 0.644 int4
baseline. Directly measures the sign of Δquant_extra (the one genuinely-open term). Flat/down (mechanism-predicted)
= NO-GO confirmed decisively; a large rise = escalate to CONDITIONAL-GO. Reuses Tools/mamba3_full_ane.py.

### Track G addendum 6 — Qwen→Mamba-3 distillation: teacher SETTLED + plan re-scoped (2026-06-15)

Two reconciled, adversarially-verified workflows evaluating the operator's plan "distill a Mamba-3 ANE backbone
from Qwen3.5-0.8B": plan-eval (79 agents) + focused teacher-choice (64 agents). **VERDICT: plan AS WRITTEN =
NO-GO (wrong teacher); re-scoped = CONDITIONAL-GO.**

TEACHER (high confidence):
- **DECLINE Qwen3.5-0.8B** (the proposed teacher). config.json-confirmed: Gated-DeltaNet hybrid (18 linear-attn
  GDN + 6 softmax of 24 text layers, full_attention_interval=4) + 12-layer ViT → multimodal VLM, vocab 248320.
  NOT a dense transformer. Three disqualifiers: **(1) the GDN layers are NOT a gift** — the "linear-attention is
  closer to an SSM so easier" hypothesis is REFUTED for a diagonal student: MOHAWK Stage-1 is mixer-agnostic
  (Frobenius over any materialized mixer, so it doesn't *break*), but SSD duality holds for diagonal/scalar
  linear attention, NOT Gated DeltaNet. GDN's transition α(I−β·kkᵀ) is a data-dependent non-diagonal Householder
  (diagonal+rank-1), STRICTLY MORE expressive than the repo's diagonal-SSD student (A=−1). A less-expressive
  student matching a more-expressive target → Stage-1 residual WORSE not near-zero, with no clean GDN→diagonal
  warm-start. **(2)** multimodal: vision strip mandatory + unquantified early-fusion text tax (0.8B MMLU-Redux
  48.5 sits BELOW prior-gen text-only Qwen3-0.6B 51.26); no text-only checkpoint exists (−Base is also VLM).
  **(3)** 248320 head inflation vs the student's 128256 build.
- **RECOMMEND Llama-3.2-1B-Instruct** — the EXACT teacher Llamba was MOHAWK-distilled from (proven end-to-end at
  this scale), vocab 128256 MATCHES the repo student (mamba3_1state.py, llamba_to_coreai.py) → recipe UNCHANGED,
  Mamba-2→Mamba-3 warm-start intact, lowest-risk. **STRENGTH UPGRADE = Qwen3-1.7B-Base** (clean dense softmax,
  MMLU 62.6) if the 1B ceiling (Llamba-1B MMLU ~38) is too low; costs a 151936 head resize.

SCOPE (binding): a ~0.8–1B backbone + external SQLite memory is sufficient ONLY for a narrowly-scoped RAG-aware
grounded-QA reader, NOT a general assistant. Off-the-shelf small models are NET-HARMED by retrieval (injecting
context destroys 42–64% of known facts); only RAG-aware training (RAFT, woven into Stage-3) works — NOT bolt-on.
A general assistant needs 3–4B (Qwen3-4B dense), cutting ANE throughput + re-entering the capacity-bound regime.

MAMBA-3 vs MAMBA-2 (unchanged): arch gain tiny (+0.7pp SISO / +1.9pp MIMO iso-param) ≈ 10× smaller than int4 PTQ
loss → Mamba-3 is a THROUGHPUT play (MIMO weight-read amortization + conv1d removal), not a quality play. The
FAITHFUL trapezoid recurrence has ZERO on-ANE decode (all 90–140 tok/s numbers used the Mamba-2-equivalent A=−1
Euler shortcut, random weights, no MLP); 24-layer Mamba-3+MLP clearing the ~12–15 per-asset ceiling is unmeasured.
Mamba-2 retained as the safe student fallback.

RECIPE (Llama-3.2-1B teacher): MOHAWK unchanged from the proven Llamba run — Stage-1 Frobenius matrix-orientation,
Stage-2 hidden-state L2, Stage-3 weight-transfer + logit KD (~8–10B tokens) + RAFT RAG-aware objective; then QAT
(NOT PTQ) to int4/int6. Effort ~6–12 engineer-weeks to a shippable scoped-RAG-reader (GPU compute is cheap,
~100–135 H100-hr; cost is engineering: re-deriving Stage-1 for the rotated/MIMO/trapezoid mixer, the RAFT corpus,
QAT, the CoreAI runtime incl. the still-unsolved on-ANE parallel-scan PREFILL kernel, + bringing the faithful
trapezoid up on ANE).

CHEAPEST DE-RISKS (before any weeks-commit):
1. **(1–2 days, single GPU, NO training) Stage-1 Frobenius-residual bake-off** — materialize each teacher's
   per-layer mixing matrix, fit the diagonal Mamba-3 SSD, read the converged residual. 3 arms: Llama-3.2-1B /
   Qwen3-1.7B / Qwen3.5-0.8B (6 softmax + 18 GDN via chunkwise WY). Settles teacher choice + the GDN-gift
   hypothesis with a NUMBER. Rule: keep the hybrid only if its GDN residuals ≤ softmax; predicted higher.
2. **(3–5 days, 8×H100) surrogate** — MOHAWK-distill Qwen3-1.7B → ~1B MAMBA-2 (existing Llamba recipe), measure
   fp16 + INT4-QAT recovery + RAG-utilization. Answers: does a 2.1× teacher close the gap, does INT4-QAT survive
   at ~1B, can a RAG-aware small SSM use retrieval. GO to the full Mamba-3 build only if INT4-QAT MMLU ≥ ~85% of
   teacher AND oracle-context EM beats the off-the-shelf floor.

OPEN OPERATOR DECISIONS: (i) product scope (scoped-RAG-reader ~1B vs general-assistant 3–4B); (ii) is Mamba-2
acceptable as warm-start scaffold + de-risk surrogate (product stays pure Mamba-3) — the operator said "no
Mamba-2", but both the recommended teacher path AND both cheap de-risks lean on it.

### Track G addendum 7 — FAITHFUL trapezoid Mamba-3 RUNS ON THE A19 ANE (first-ever device decode) (2026-06-16)

The route's命门 is RESOLVED. Every prior on-ANE number (50.9 int8 / 90–140 int4) used the Mamba-2-equivalent
EULER shortcut (A=−1, dt-cancel). The FAITHFUL trapezoid (learned A=−softplus, the 3-term recurrence
α·ssm+β·prev+γ·cur, the rotated kprev/vprev delay, data-dependent RoPE, MIMO rank-R) had ZERO on-device decode.
Now measured on the iPhone Air A19, int8, via a NEW converter `Tools/mamba3_faithful_ane.py` + `BASCoreAIMamba3Session`
extended to 1–4 states (runStep3/runStep4, explicit inout). Random weights — op-graph compile + speed/footprint only.

| config (D=2048, mixer-only, 4 angle-first states) | result | tok/s | peak MB | load ms |
|---|---|---|---|---|
| **L=2**  | **clean full-ANE compile ✅** | **160.6** | 307 | 1944 |
| **L=16** | decodes, but 1 segment `ANECCompile() FAILED` → fallback | **51.8** (> Mamba-2 ref 39) | 88 | 9423 |

FINDINGS:
1. **The faithful trapezoid op-graph IS ANE-native** — L=2 compiles + decodes 100% on ANE, no error, 160.6 tok/s.
   The "complex state breaks ANE / needs a custom MIL pass" worry is moot (it's real 2×2 rotations by construction).
2. **The flat-state SIGSEGV is FIXED by 4 angle-first states.** The original faithful converter
   (`mamba3_to_coreai.py`) packed all carry-state into ONE flat `[L,148480]` tensor sliced per-layer → that
   flat-slice SIGSEGVs the ANE segmenter at LOAD (device-confirmed at L=2, both before AND after verifying the
   asset copied completely — R1 caught that `devicectl`'s recursive copy silently drops the 343MB `main.mlirb`).
   Re-architecting to 4 separate properly-shaped states (angle, ssm, kprev, vprev), registered/read/written
   angle-FIRST (the proven `mamba3_full_ane.py` pattern, extended 2→4) → loads clean. The "4 states hit the
   segmenter ordering bug" fear (the reason the original used the crashing flat-pack) did NOT materialize.
3. **At depth-16 in a SINGLE asset, one segment exceeds the per-asset ANE compile ceiling**
   (`_ANECompiler: ANECCompile() FAILED`) → falls back off-ANE, still decodes at 51.8 tok/s (> Mamba-2 39,
   peak 88MB, well under the 3376MB jetsam cap), but NOT 100%-ANE. This is a per-asset op-COUNT/depth ceiling
   (L=2 mixer-only is clean), NOT an op-incompatibility.
   ⚠️ **CORRECTION (2026-06-16 audit, R1):** the original text here claimed this is "fixed by ASSET-SPLITTING
   (proven pattern; split assets exist, e.g. LlamaDraft1B_split124)" — that was FABRICATED in two ways: (i)
   "split124" does not exist (the real converter default is `SPLITS=[8,8]` → `LlamaDraft1B_split88`,
   `llama_to_coreai_split.py:74`); (ii) it CONTRADICTS this repo's own Track E DEVICE record (§ above, lines
   ~545-566), which proves asset-split DOES NOT WORK on-device in CoreAI 0.4.0: 2 separate assets → SIGSEGV at
   2nd `AIModel.load`; multi-function asset → SIGABRT; the ANE compiles the WHOLE asset per-asset, so the
   per-asset cap CANNOT be split around. So "split fixes 100%-ANE" is DEVICE-FALSIFIED, not proven.

VERDICT — **the faithful Mamba-3 trapezoid OP-GRAPH is DEVICE-VIABLE** (the engine compiles + decodes on the A19
ANE). But "full-16-layer reader at 100%-ANE" is NOT solved: the per-asset compile ceiling (~12-15 Llama-layers,
likely FEWER for the heavier +MLP+gnorm Mamba-3 graph) is hit at L=16 and CANNOT be split around on-device
(Track E, device-proven). The only on-ANE-clean form is a **≤-ceiling SINGLE-function asset** (a shallower
reader). REMAINING (honest): (a) find the Mamba-3 per-asset ceiling via the L-ladder device probe (L2/4/8/10/12
.aimodels exist) — the exact depth where ANECCompile first fails for graph (b) is UNMEASURED; (b) decide whether
a ≤-ceiling-depth Mamba-3 (shallow + wide MIMO) is deep enough for quality; (c) weights/distillation.

### Track G addendum 8 — LOCAL DISTILLATION HARNESS + the ADVERSARIAL AUDIT correction (2026-06-16)

Built (committed) a local Granite-4.1-3b(dense) → Mamba-3 distillation + deploy pipeline on an M5 Max (torch-MPS):
`Tools/mamba3_trainable.py` (differentiable student, parity-gated to the per-token recurrence), the chunked-segsum
scan, Stage-3 logit-KD (`mamba3_distill.py`/`mamba3_poc_distill.py`), Stage-2+3 (`mamba3_mohawk.py`), the deploy
converter (`mamba3_deploy.py`), and `mamba3_parity_b.py`. A 26-agent adversarial audit (21/21 findings upheld)
then CORRECTED the session's own overstatements — recorded here so the claims don't outlive the evidence:

GENUINELY PROVEN: (1) **the L=16 training-NaN root cause + fix is the strongest result** — the segsum scan
`exp(diff)` over the FULL T×T decay matrix exponentiates the causally-invalid upper triangle (i<j, diff>0) →
exp(+)=inf; tril-zeroing leaves the inf so the BACKWARD is 0·inf=NaN; fix = `masked_fill(~tril, -inf)` BEFORE exp
(verified inf/NaN-safe). (2) PARITY-A is a real fp64 scan-reformulation gate (twin == per-token reference for the
trainable family) at **ssm ~1e-8 / logits ~5e-7 / argmax 24/24** — NOT the "~2e-15" the session narrated (that
figure is in no file; the only ~5e-14 is the unrelated scan-vs-scan check). It is train==inference for the
trainable family in fp64 ONLY — it is NOT bit-identity, NOT equality to this addendum's certified converter
(`mamba3_faithful_ane.py`, never numerically cross-checked), and says nothing about the int8/fp16 the device runs.
(3) the KD loop trains, CE 11.3→5.2 stably. (4) **PARITY-B (NEW, the audit's must-fix): the int8 deploy faithfully
reproduces the fp32 trained student — 98.3% argmax-agreement, logit max-err 0.76 (int4 = 91.5% → needs QAT).**

OVERSTATED / CORRECTED: "loop closed / trained student decodes on the A19" conflated THREE architecturally
distinct graphs — (a) the addendum-7 CERTIFIED asset = D=2048, mixer-only, **RANDOM weights** (op-graph/speed
only); (b) the TRAINED student = D=1024, **+MLP +gnorm**, 422M; (c) the first deploy = an int8 **8-of-16-layer
TRUNCATION** of (b), which is INCOHERENT (feeds an L=16-trained head a post-layer-7 residual → agrees with the
real student at ~chance; on-device `last_tok=574` is a truncation artifact, not the trained model). So the device
numbers (148.9 tok/s / 2457 ms / 62 MB) are a truncated + partial-off-ANE-fallback + int8 figure, NOT a valid
trained-model decode speed. FIXED: `mamba3_deploy.py` now refuses truncation; the coherent FULL L=16 trained
student (int8, PARITY-B-verified) was re-converted and MEASURED on the A19: **loads (3860 ms, 53 MB) + decodes
at 96.5 tok/s, peak 91 MB, last_tok=1176** — a VALID coherent trained-model number (vs the discredited
truncated 148.9). BUT one segment still hit `ANECCompile FAILED` → partial off-ANE fallback, so it is NOT
100%-ANE (the +MLP+gnorm op count pushes the per-asset compile ceiling).
⚠️ **CORRECTION (2026-06-16 audit, R1):** the original text claimed "→ asset-split is the remaining deploy step",
implying split would deliver 100%-ANE. That is FALSE — Track E (lines ~545-566) DEVICE-PROVED asset-split does NOT
work in CoreAI 0.4.0 (SIGSEGV on 2nd asset load / SIGABRT on multi-function; per-asset compile can't be split
around). The real remaining step is NOT split — it is finding the per-asset DEPTH ceiling for graph (b) (the
L-ladder probe; L=2 of graph (b) was NEVER measured, only the simpler L=2 mixer-only) and shipping a
≤-ceiling-depth SINGLE-asset reader. The certified-on-ANE claim covers (a) only. Quality is UNPROVEN: ~0.13M tokens (≈4–5 orders below the
~8–10B recipe), no RAG/RAFT objective, only top-1 argmax-agreement (~20%) on 8 wikitext seqs (a liveness signal,
likely dominated by high-frequency tokens, NOT a "mimics Granite" claim). Stage-2's null result is a recipe
artifact (joint, L2W=1.0, free 1024→2560 projection that launders the loss), not a verdict on hidden-alignment.

HONEST BOTTOM LINE: the plumbing runs end-to-end and the correctness gates (NaN-fix, PARITY-A, PARITY-B-int8)
hold, but **a usable distilled on-device Mamba-3 reader does NOT exist** — no single artifact is simultaneously
full-model AND 100%-on-ANE AND quality-measured. The route is de-risked at the plumbing/correctness level, not
demonstrated as a working reader. REMAINING: coherent-L16 on-device measure + asset-split (100%-ANE); a scale
run (cloud) with a real eval (held-out KL/perplexity + n-gram baseline + content-token agreement); RAFT; Stage-1
+ sequential MOHAWK; QAT-int4.

---

## Track G — Addendum 9: white-box MOHAWK COMPLETED (Stage-1 + sequential 1→2→3 + real metric) — staging is a SCALE lever, NULL locally

The prior addendum listed "Stage-1 + sequential MOHAWK" as REMAINING and flagged Stage-2's earlier null as a
recipe artifact (joint, free 1024→2560 projection). Both are now resolved. `Tools/mamba3_mohawk.py` was rewritten
into the CANONICAL sequential MOHAWK and validated against a fair baseline. This addendum records what is now
mechanically COMPLETE and what the local measurement actually says — kept separate, per doctrine.

WHAT IS NOW COMPLETE + CORRECT (the "名副其实" white-box pipeline):
- **Stage-1 (matrix orientation), NEW.** `MT.Lyr.attn_matrix(x)` materializes the student's per-head token-mixing
  matrix `A[t,s] = decay(t,s)·⟨C_rot_t, B_rot_s⟩` over s≤t (the SSD-core simplification — collapses the rank-R/per-P
  MIMO + trapezoid delay into the scalar mixing, the attention-relevant structure). Sanity-gated: finite + strictly
  causal (upper-triangle exactly 0). It is a SIGNED operator at init (⟨C,B⟩ unconstrained → ±50 scale, diagonal can
  be negative — this is correct, NOT softmax). Loss = **relative Frobenius** `‖S−T‖_F/‖T‖_F` per head (canonical;
  raw MSE is scale-broken: ±50 student vs O(1) row-stochastic teacher). Teacher attention via
  `attn_implementation="eager"`, GQA-grouped from H40→16. Measured: Stage-1 drives its loss 88→18 (orientation works).
- **Stage-2 (hidden align) — audit bug FIXED.** The free 1024→2560 projection that laundered the loss is replaced
  by a **FROZEN orthogonal** projection (init `nn.init.orthogonal_`, detached). Sequential (not joint). Stable
  (loss →1.16, no NaN).
- **Stage-3 (logit-KD).** KL(teacher‖student)/τ² + 0.1·CE, τ=2.
- **A REAL metric** (replaces the weak 8-seq argmax): held-out **KL + perplexity** on a FIXED deterministic held set
  (`chunks[:8]`, STEPS-independent so runs of different length are comparable — a confound I caught and fixed
  mid-experiment: `held=chunks[-8:]` had made the 80- and 240-step held sets DIFFERENT).
- **Hardened harness:** teacher in **bf16** (the INIT KL=nan was input-dependent **fp16** teacher instability on a
  specific chunk — bf16 has fp32 range, skip=0 after); nan-robust `evaluate()` (drops + counts non-finite chunks);
  a per-step `assert torch.isfinite(loss)` so any real training NaN fails loud (it never fired — Stage-1 backward is
  finite, 0 non-finite grads, max grad 2.5).

THE MEASURED VERDICT (Granite-4.1-3b bf16 teacher → 16L D=1024 student, M5 Max MPS, T=128, seed 0, identical held set):
| run | held-out KL ↓ | ppl ↓ | argmax-agree |
|-----|:---:|:---:|:---:|
| INIT (random student) | 9.064 | 126659 | 0.0% |
| **1→2→3** (80 steps each = 240 total) | 5.442 | 3472 | 14.0% |
| **Stage-3 ONLY** (240 steps, equal compute) | **5.226** | **2712** | **16.0%** |

At a FAIR comparison (equal total compute, identical held set) **Stage-3-only WINS on all three metrics**. At equal
*Stage-3* budget (80 vs 80) the full pipeline won on KL/ppl (5.145 vs 5.391 / 1430 vs 1789) — i.e. the pre-alignment
gives a better Stage-3 *starting point*, but the 160 steps it costs buy MORE if spent directly on Stage-3 at this
scale. 亏的不要: the staging does NOT beat Stage-3-only locally, and I do not claim it does.

WHY (two honest causes, both pointing the same way): (1) **scale** — MOHAWK's staged benefit amortizes over a long
Stage-3 / billions of tokens (Phi-Mamba, Llamba); a 240-step PoC never reaches the amortization regime. (2)
**dim-gap** — the student is deliberately NARROWER than the teacher (1024←2560, for the phone), so Stage-2's
cross-dim hidden alignment is fundamentally constrained: a frozen-random projection can't be optimal and a free one
launders the loss. The canonical MOHAWK references keep the student iso-width with the teacher, which this on-device
target cannot.

BOTTOM LINE (updates Addendum 8, does not overturn it): the white-box MOHAWK is now mechanically COMPLETE,
CORRECT, and audit-clean — every stage runs finite and demonstrably reduces its own loss, on a real KL/ppl metric.
But the staged curriculum is a **scale lever, null at local PoC scale**; for a narrower-than-teacher on-device
student, **Stage-3 logit-KD is the robust workhorse** and Stage-1/2 are optional, cloud-scale-only. This does NOT
change the Addendum-8 conclusion that a usable, quality-measured on-device reader still requires the scale run.

---

## Track G — Addendum 10: the trained Mamba-3 per-asset ANE ceiling is MEASURED = 8 layers (and my two root-cause hypotheses were REFUTED on-device)

Following Addendum 9's correction (both "split fixes it" and "even L=2 fails" were fabricated), the operator chose the
A19 L-ladder to actually MEASURE the per-asset ANE compile ceiling for the TRAINED graph (b) (+MLP+gnorm, D=1024,
int8). Built `scripts/run-mamba3-ane-ladder.sh` (stage `.aimodel` to Documents incl. the `main.mlirb` recursive-copy
fix; launch the `BAS_COREAI_MAMBA3_PROBE` with `.neuralEngine`; capture the DEVICE syslog via `idevicesyslog`).

KEY DETECTION FACTS (the prior "ANECCompile FAILED" verdicts rode on a fragile signal — confirmed): the real error
is `BASDeviceTestApp(ANECompiler) <Error>: Error: ANE cannot handle intermediate tensor type <private>` +
`Failed to create unit plist` — emitted to the device os_log (NOT the process stdout `--console` captures), and ONLY
on a FRESH compile (cached after first load: cache-busted with a new `SEED`). A partial fallback STILL loads + decodes
fast, so tok/s alone can't see it — only the syslog error count distinguishes 100%-ANE from fallback.

THE LADDER (trained graph, fresh compiles, A19):
| L | "ANE cannot handle" errors | tok/s | 100%-ANE |
|---|---|---|---|
| **8** | **0** | 112 | ✅ CLEAN |
| 9 | 92 | 147 | ❌ fallback |
| 10 | 102 | 131 | ❌ |
| 12 | 122 | 115 | ❌ |
| 16 | 83 | 94 | ❌ |

**The ceiling is EXACTLY 8 layers — a SHARP CLIFF (0 → 92 errors from one extra layer)**, i.e. a hard per-asset
program-capacity threshold, not a gradual size effect. An ≤8-layer single-asset Mamba-3 reader is **100%-ANE today**
(L=8: 0 errors, 112 tok/s, 67 MB peak). Track E's Llama ceiling was ~12-15; Mamba-3's is LOWER (8) because its
per-layer op count is higher (mixer + gnorm + SwiGLU MLP).

TWO ROOT-CAUSE HYPOTHESES BUILT + REFUTED ON-DEVICE (R1 — the data overruled my reasoning):
- **(refuted) "ANE SRAM working-set / state liveness"**: built `STATE_WRITE=inplace` (per-layer in-place state
  write, O(1) live state vs the stack-then-write O(L)). It was WORSE (162 vs 83 errors), not better → liveness is not it.
- **(refuted) "indexing the stacked `[L,...]` state buffer makes an int64 gather the ANE can't type"**: built
  `STATE_WRITE=separate` (4*L separate per-layer state buffers, ZERO `[L,...]` indexing). Still 162 errors → the
  state-buffer indexing is not it either.
- **(survives) per-asset DEPTH/capacity ceiling**: all three state-write patterns (stack/inplace/separate) fail
  identically at L≥9 and all are clean-equivalent below; L=8's identical per-layer OPS compile 100%-ANE. So the
  failure is depth-driven, NOT op-incompatibility, NOT the state plumbing. The exact redacted (`<private>`)
  intermediate type was not unmasked (would need device private-logging), but it is depth-triggered.
- **(refuted) "int8 quantization is part of the limit"**: built `FP16=1` (skip int8 quant — clean fp16, 539MB asset)
  at L=9. fp16-L9 = **92 errors, EXACTLY equal to int8-L9's 92**. Precision does NOT move the cliff → int8 is not the
  limiter; mixed-precision is not a lever. The ceiling is precision-independent AND state-pattern-independent → a pure
  per-asset op-graph DEPTH capacity limit at 9 layers.

PRODUCT CONSEQUENCE: the on-device pure-100%-ANE constraint for this graph is **≤ 8 layers** (split is dead per Track
E). The open question shifts from "does a 16-layer reader compile" to "is an 8-layer (wide-MIMO) Mamba-3 deep enough
for the narrow-RAG-reader quality bar" — and Mamba-3's MIMO (more capacity per layer) is exactly the lever that suits
a shallow+wide reader. NOTE: the L=9-16 decode tok/s (94-147) are PARTIAL-fallback + random-weight numbers, not
100%-ANE and not quality.

---

## Track G — Addendum 11: "全面修复" of the 16-layer question — single-asset 16L is a HARD WALL (every escape tested), 8 stands

The operator pushed: "16层真的不行吗 是不是忽略了什么". Right to push — addendum 10 proved 8 is the single-asset/
single-function ceiling but did NOT exhaust the escapes. This addendum tests them. A 4-agent research workflow grounded
the MECHANISM (Orion paper, arXiv 2603.06728: the ANE compiler bans the `concat` MIL op + has a ~119-compiles/process
limit; the error `ANE cannot handle intermediate tensor type` + `Failed to create unit plist` is the ANECompiler
failing to emit a segment ("unit") descriptor). The fit: ≤8 layers compiles as ONE ANE program (the offending tensor
stays fused/internal → 0 errors); at ≥9 the model exceeds one program, the compiler PARTITIONS, and every segment seam
materializes a banned-concat / un-typeable boundary intermediate → the 10×-per-layer error explosion.

ESCAPES TESTED ON-DEVICE (all fresh compiles, A19; the `LEAN_MLP` / `MAMBA_N,MAMBA_P` / `STATES_OVR` probe knobs are in
mamba3_deploy.py / mamba3_trainable.py / run-mamba3-ane-ladder.sh):
| variant @ L=16 | "ANE cannot handle" | verdict |
|---|---|---|
| full block | 83 | fallback |
| lean (drop SwiGLU MLP) | 130 | fallback → MLP NOT the culprit; the MIXER is |
| fp16 (skip int8) @ L=9 | 92 (= int8's 92) | fallback → precision-independent |
| stack / inplace / separate state-write | 83 / 162 / 162 | fallback → state-plumbing-independent |
| **shrunk N=32,P=32 (¼ SSD state)** | **162** | fallback → **per-layer SIZE is NOT the gate** |
| L=8 (every variant) | 0 | CLEAN 100%-ANE |

KEY new datum: shrinking the per-layer state made it WORSE (162), not better — so the cliff is **depth/segment-COUNT
bound, NOT per-layer-size/capacity bound**. This refutes the "shrink enough and 16 fits" hypothesis. Combined with the
MLP-ablation (mixer is the locus) and the segment-ceiling mechanism, the conclusion is:

**Single-asset 16-layer Mamba-3 is a genuine HARD WALL on the A19 ANE (CoreAI 0.4.0) — robust to precision, state-write
pattern, MLP presence, AND per-layer size. The ceiling is 8 layers, depth/segment-count-bound.** The ONLY un-refuted
path to a functional 16-layer 100%-ANE model is **multi-process** (2×8-layer assets in SEPARATE processes via XPC —
single-process 2-asset co-load SIGSEGVs per Track E). But multi-process adds per-token cross-process latency that would
erase the ANE speed win → a net-negative for a fast decoder (亏的不要). So **8 layers stands as the real on-device
constraint**; the cloud distill target is correctly fixed at 8. UNMASK NOTE: reading the exact redacted `<private>`
tensor type is not feasible on iOS (rejects non-Apple-signed logging profiles); the segment-ceiling mechanism is
established by the ablation pattern + the Orion constraints, not by unmasking.

---

## Track G — Addendum 12: the 100%-ANE ceiling is moot for a fast reader — 16 layers runs 97 tok/s all-GPU (clean)

After establishing single-asset 16L can't be LITERAL 100%-ANE (addendum 11), the cheap decisive question was skipped:
how fast does the 16-layer actually RUN, and is the ANE even the right backend? Measured the canonical 16-layer asset
across forced compute units in one probe run (`UNITS_OVR=ane,cpu,gpu`, A19):

| compute unit | compile | tok/s |
|---|---|---|
| ANE-preferred (`.neuralEngine`) | mostly-ANE + small fallback | 88.1 |
| **GPU (`.gpu`, forced)** | **CLEAN** | **97.3** |
| CPU (`.cpuOnly`, forced) | ERROR "Failed to rewrite module using segmenter" (CoreAI CPU-segmenter bug) | — |

KEY: the 16-layer 422M reader runs **88–97 tok/s, ~80 MB peak** on-device — and **forced-GPU (97, clean) is FASTER than
ANE-preferred (88, with the fallback).** So the "100%-ANE ceiling = 8 layers" (addenda 10/11) is REAL but only binds if
you demand *literal pure-ANE*. It does NOT bound a working fast reader: 16 layers (more quality) runs at 97 tok/s on the
CoreAI GPU backend, clean, tiny footprint. The ANE-purity goal matters only for (a) max power efficiency or (b) co-residency
with a separate GPU model; for a STANDALONE 422M narrow-RAG reader the GPU is free and faster.

CONSEQUENCE for the deploy/distill target: depth is a QUALITY-vs-POWER choice, not a hard wall:
- **8 layers** → literal 100%-ANE, 112 tok/s, lowest power (only if pure-ANE is a hard requirement).
- **16 layers (or deeper)** → 88 tok/s ANE-mostly / **97 tok/s clean GPU**, more quality, ~80 MB (no jetsam risk for 422M).

So the cloud distill is NOT forced to 8 layers. (Speeds are random-weight OP-GRAPH measurements — valid for the trained
model, same graph; numerics meaningless. CPU-only is a separate CoreAI segmenter bug, never a deploy path.)

---

## Track G — Addendum 13: the ROOT CAUSE found — the residual hidden can't cross an ANE boundary; multi-process 2×8 ALSO fails

Pursuing 100%-ANE-16 via the only un-refuted path (multi-process 2×8, per operator "继续尝试 100ane 最谨慎"), built
the split-half assets (deploy `SPLIT=head|tail`): HEAD = embed + 8 layers → boundary hidden [1,1024]; TAIL = hidden
[1,1024] → 8 layers + LM head → logits. Each is only 8 layers (the proven-clean depth). Device result:
| 8-layer variant | "ANE cannot handle" errors |
|---|---|
| full (input_id → logits) | **0** (clean) |
| HEAD (input_id → hidden) | **80** |
| TAIL (hidden → logits) | **82** |

ROOT CAUSE (unifies addenda 10/11/12): the un-typeable intermediate is the **D=1024 residual HIDDEN when it is
materialized at an ANE segment / model-I/O boundary.** `input_id` (int → embedding gather) and `logits` (matmul output)
are valid ANE boundary tensors; the raw residual activation is NOT (it fails as either input OR output — tail-input
fails too, and input_id is far smaller yet clean, so it is not a min-size issue but the residual tensor's type/role).
This explains the whole cliff: ≤8 layers compiles as ONE segment so the hidden is never a boundary (clean); ≥9 forces
partitioning so the hidden lands on a seam (fails); and an explicit 2×8 split makes the hidden an I/O (fails at 8).

CONSEQUENCE: **multi-process 2×8 does NOT escape the wall** — the cross-process boundary IS a residual-hidden I/O, which
fails to compile 100%-ANE (80 errors at 8 layers). So **100%-ANE is only achievable when the ENTIRE model is one ANE
segment = ≤8 layers; NO decomposition (depth-partition, single-process split, or multi-process) that materializes the
residual at a boundary can be 100%-ANE.** This is the definitive, mechanism-grounded answer to "can 16 layers be
100%-ANE": no. 16 layers runs fine at 97 tok/s (GPU, clean) / 88 (ANE-mostly) — that is the path for >8 layers.
(deploy SPLIT=head|tail knob added for this probe.)

---

## Track G — Addendum 14: full-power CoreAI depth-speed curve — no depth cap, ~linear, memory-trivial

"满血 CoreAI" reframe: stop forcing literal pure-ANE; let CoreAI orchestrate ANE+GPU+CPU (its design — ComputeStream +
stateful-KV + dynamic shapes). Then the 8-layer cap (literal pure-ANE only) DISSOLVES. Measured the depth-speed curve
(A19, random-weight op-graph speed — valid for the trained model, same graph; numerics meaningless):

| layers | ~params | ANE-preferred tok/s | GPU tok/s | peak MB |
|---|---|---|---|---|
| 8 (pure-ANE, single segment) | ~250M | 112 | — | 67 |
| 16 | ~420M | 88 | 97 | ~80 |
| 24 | ~600M | 73 | 74 | 80–118 |
| 32 | ~780M | 57 | 58 | 98–119 |

FINDINGS: (1) ~linear speed decay with depth — even 32 layers (~0.8B) = 57 tok/s, very usable. (2) ANE-preferred and
GPU CONVERGE as depth grows (16L 88-vs-97 → 32L 57-vs-58): deeper ⇒ more of the graph rides the GPU regardless, so the
two backends meet. (3) Memory is NEVER the limit (67–119 MB vs the 3376 MB jetsam cap) — at full power, depth is
SPEED-bound, not memory/compile-bound. Extrapolating: 48L≈38 tok/s, 64L (~1.5B)≈28 tok/s.

CONSEQUENCE: under full-power CoreAI the cloud-distill target depth is a free QUALITY-vs-tok/s choice (8/16/24/32+),
not a hard cap. Pure-ANE (≤8 layers, 112 tok/s, lowest power) remains the option ONLY if literal 100%-ANE is a hard
requirement (always-on / battery / co-residency with a separate GPU model). For a standalone quality reader, pick the
deepest depth that clears your tok/s floor (e.g. 24L @ 73 tok/s, or 32L @ 57). Speeds are op-graph (random-weight);
the trained model has the same graph → same speed.

---

## Track G — Addendum 15: AUDIT CORRECTION (万无一失) — what is MEASURED vs INFERRED in addenda 12/13/14

A 31-agent adversarial audit (26 candidates, 17 upheld) of the depth-speed curve found that addenda 12/13/14 overstate
ANE participation and compile-cleanliness. Corrections, so the cloud-target decision rests on honest evidence:

WHAT IS ACTUALLY MEASURED:
- **Decode WALL-CLOCK speed (tok/s) by depth** — random-weight op-graph, SINGLE-run, 4-warmup + 16-20 timed steps, ±~7%
  (16L was seen at 88 AND 94 across runs): 8L≈112, 16L≈88(ane-req)/97(gpu), 24L≈73/74, 32L≈57/58. The trend is ~linear;
  48L/64L are EXTRAPOLATION, not measured. Speed is graph-valid for the trained model (same graph), but is one short shot.
- **phys_footprint** 67-119 MB. NOTE: this EXCLUDES the int8 weights (~250-740 MB), which are mmap'd file-backed clean
  pages phys_footprint does not count. Jetsam pressure (dirty/resident) is low, but the weights are 250-740 MB on disk +
  mmap. "Memory never the limit" should read "resident footprint low; weights are 250-740 MB mmap'd."
- **ANECompile-FAILED error counts** (a NEGATIVE compile diagnostic, blind on cache hits): 8L=0 fresh, 16L≈83, 24L≈242,
  32L≈322; head(input_id→hidden)=82, tail(hidden→logits)=84 (addendum 13 said 80/82 — CORRECTED).

WHAT IS **NOT** MEASURED (the audit's core finding):
- **The actual ANE-vs-GPU compute SPLIT for ANY Mamba-3 `.aimodel` run.** There is NO per-op placement readback (the
  CoreAI session SETS `preferredComputeUnitKind:.neuralEngine` but never reads back what stuck; the only MLComputePlan/
  deviceUsage probes are CoreML/.mlpackage and never touch a `.aimodel`). So **every "ANE-mostly", "100%-ANE", and
  "GPU clean" claim is INFERRED from tok/s + compile-error-count, NOT a positive placement measurement.**
  - "8L = 100%-ANE" → honestly: "no fresh ANE-segment compile failure observed" (necessary, not sufficient).
  - "16L ANE-preferred 88 = ANE-mostly" → inferred; 83 segments failed so a large part is GPU regardless.
  - **"24L/32L ANE-preferred 73/57" → ~ALL GPU** (242/322 ANE-segment failures push the graph off-ANE; that is WHY
    ane-preferred≈gpu at depth). The "ANE-preferred" column for L>8 is fallback-contaminated and should be read as the
    GPU column. **For depth>8 the honest statement is: GPU-executed (CoreAI), ANE participation small/unverified.**
  - "GPU clean" → "loaded + ran, no load-time throw"; the harness has no GPU-side placement/fallback detector either.
- **Quality vs depth** — every run is RANDOM-WEIGHT, so the curve says NOTHING about whether a deeper model is BETTER.
  "more quality / deepest depth" is a capacity hypothesis; only the cloud distill establishes quality-vs-depth.

CORRECTED VERDICT for the cloud target: the depth→**speed** curve is roughly valid (≈ -linear, ±7%, single-run — RE-RUN
≥3 reps before final commit). At **depth>8 it is a GPU reader** (CoreAI GPU backend; ANE does not meaningfully
participate — confirmed by the rising ANE-segment-failure counts, exact split unmeasured). Literal ANE power-efficiency
is only mechanism-supported at **≤8 layers** (and even that is "no compile failure observed", not a positive ANE
measurement). Picking a depth (e.g. 24L≈73 tok/s) is a SPEED decision on a GPU-backed reader; its QUALITY is TBD by the
distill. TODO to actually certify ANE usage: implement the integration-plan-mandated `preferredComputeUnitKind` readback
(or a CoreAI-native placement probe) — until then, no `.aimodel` run is certified ANE-using.

---

## Track G — Addendum 16: ANE-placement readback (#2) is INFEASIBLE in CoreAI 0.4.0 — no compute-plan API exists

Investigated whether the actual per-op ANE-vs-GPU split for a Mamba-3 `.aimodel` run can be MEASURED (the audit-15
gap). Grepped the full beta framework interfaces (Xcode-beta iPhoneOS27 SDK): `CoreAIDelegates.swiftinterface` (122
lines) + `CoreAIRuntime.swiftinterface` (1425 lines). The complete compute-unit API surface is:
- `ComputeUnitKind` enum + `ComputeUnitKind.availableKinds` (the device's SUPPORTED units — a capability set).
- `SpecializationOptions(preferredComputeUnitKind:)` + `.allowedComputeUnitKinds` (what you REQUEST).
- `AIModel` / `InferenceFunction` / `InferenceFunctionDescriptor` (run/encode/ComputeStream; descriptor exposes
  state/input/output names + shapes) — **NO `computePlan`, `deviceUsage`, `computeDevice`, or actual-placement readback.**

CONCLUSION: **CoreAI 0.4.0 exposes the REQUEST side only; there is NO `MLComputePlan` analog.** A true per-op
ANE-vs-GPU placement readback (#2 as envisioned) is NOT implementable in this API. The integration plan's "read
`preferredComputeUnitKind` back to assert it stuck" only confirms the REQUESTED option (trivially what you set), NOT
what executed. So the actual ANE fraction for any `.aimodel` run is fundamentally not directly measurable here.

WHAT IS DONE INSTEAD: (1) `BASCoreAIMamba3Probe` now logs `ComputeUnitKind.availableKinds` (the mandated capability
gate — confirms the A19 offers `.neuralEngine`; takes effect on next app rebuild). (2) The placement PROXY is the
device-syslog **ANECompile-FAILED count** (already captured by `run-mamba3-ane-ladder.sh`): **0 ⇒ the model is fully
ANE-compilable** (necessary condition for 100%-ANE — no segment is forced off-ANE); **N>0 ⇒ N segments rejected by the
ANE compiler and forced to GPU/CPU** (e.g. 8L=0, 16L≈83, 24L≈242, 32L≈322). This is a NEGATIVE compile signal, not a
positive execution measurement, but it is the strongest available bound. A positive ANE-fraction measurement would
require a future CoreAI compute-plan API OR an energy probe (powermetrics ANE-active), which is not accessible from a
sandboxed on-device app. So: claims of ANE USAGE remain bounded by the compile-error proxy, never positively certified.

---

## Track G — Addendum 17: DUET state-cache fidelity kill-switch = GREEN (serialize→rehydrate is safe; error DECAYS, not compounds)

Route step 1 (2026-06-17): the cheapest kill-switch for the disruptive "State-Cache Reader" flagship — does a PREFILLED,
SERIALIZED, REHYDRATED recurrent state reproduce the monolithic continuation? Built `Tools/mamba3_state_fidelity.py`
(host, fp32 weights, no training). Isolates the ONE open variable = state serialization precision: BOTH prefill and
decode use the same per-token `step_ref` path (so chunked-vs-sequential is out of scope, already PARITY-A ~1e-8), weights
stay fp32 (weight-quant out of scope, already PARITY-B). Boundary 4-state (angle/ssm/kprev/vprev × 24 layers, ~3.6 MB
fp16) cached at fp32/fp16/int8, then continuation decoded from the rehydrated state vs a monolithic run.

RESULT (L=24, prompt=64, continuation 64/256/512 — IDENTICAL across all three lengths):
| cache precision | state rel-err | cont logit max-err | argmax agree | first divergence |
|---|---|---|---|---|
| fp32 (sanity) | 0 | 0 | 100% | none |
| **fp16** (deploy state) | 2.1e-4 | **8.4e-6** | **100%** | none/512 |
| **int8** (compressed cache) | 8.3e-3 | **8.6e-4** | **100%** | none/512 |

KEY: the logit-err is FLAT across 64→256→512 continuation tokens (does NOT grow) → the serialized-state perturbation
DECAYS, not compounds — a structural consequence of Mamba's contractive recurrence (A=−softplus ⇒ exp(neg) forgets the
initial error). This REFUTES the flagship's "error compounds geometrically" worry. So: **serializing the recurrent state
(even int8, ~1.7 MB) and resuming from it is fidelity-safe** → the prefill-once-reuse-many state cache is VIABLE, and the
cache can be int8 (half size). The flagship's #1 stated risk is CLEARED.

HONEST RESIDUALS: random weights + toy vocab (but the CONTINUOUS metrics are weight-independent — the robust evidence;
argmax-100% is consistent with the tiny logit-err). This isolated SERIALIZATION; the FULL DUET still needs the
chunked-scan prefill (`forward_seq`) to emit the decode-compatible 4-state (it exposes ssm+angle but not kprev/vprev —
the actual handoff-extraction engineering, low-risk per PARITY-A). MLA-KV handoff untested (read-only cached tensors →
trivial). ROUTE IMPLICATION: DUET serialization-robustness is ~free (no DUET-aware-retrain needed for it); the remaining
DUET piece is the chunked-prefill 4-state extraction, not state fidelity.

---

## Track G — Addendum 18: full-DUET handoff VERIFIED (chunked-prefill → decode-4-state parity + end-to-end fidelity)

The kill-switch (addendum 17) used step_ref for both paths (serialization only). This closes the ACTUAL DUET seam:
the CHUNKED-SCAN prefill (new `Lyr.prefill_state` / `M.prefill`) must emit the 4-state the per-token `step_ref` decode
resumes from. PARITY-A only covered ssm; `Tools/mamba3_duet_handoff.py` covers the FULL handoff (L=24, host, fp32 weights):

(A) chunked-prefill boundary 4-state vs step_ref-prefill 4-state — max rel-err over 24 layers:
    angle 7.8e-6 · ssm 9.5e-6 · **kprev 6.0e-6 · vprev 5.7e-6** (kprev/vprev/angle never tested before PARITY-A) → PASS.
(B) end-to-end (chunked-prefill → serialize → step_ref-decode) vs monolithic step_ref, cont=128:
    fp32 logit-err 3.7e-6 / fp16 7.7e-6 / int8 8.6e-4 — ALL 100% argmax, zero divergence.

So the DUET LEFT-HAND is sound: the parallel prefill produces the exact decode-compatible 4-state, and the
prefill→decode seam reproduces the monolithic continuation token-identically (even int8 cached). Combined with
addendum 17 (serialization safe + non-compounding), the WHOLE DUET handoff (prefill → state-cache → decode) is
host-verified. Code: `Lyr.prefill_state`, `M.prefill`, `M.run_ref(init=)`. REMAINING for the DUET: on-device (the
prefill .aimodel runs GPU — convertibility already confirmed) + the MLA-KV handoff (hybrid, once the MLA layer is built).

## Track G — Addendum 19: test battery P0-1 — the teacher top-K cache trained a DIFFERENT objective at TAU=2 (FIXED → TAU=1)

The route-evolution battery's #1 blast-radius test (`Tools/test_p0_1_topk_kd.py`, real Granite-4.1-3b, 12 RAFT HotpotQA
examples) falsifies the cloud cost model if it fails: the cached top-K KD must train the SAME objective as full-vocab KD,
else the cloud spends $ optimizing the wrong loss. Initial config (TAU=2, K=64) **FAILED** — top-64 captured only 0.32 of
the tempered mass, grad-cosine 0.91 (bar ≥0.98), loss-ratio 2.23 (bar [0.9,1.1]). Root cause: TAU=2 over a 100352-vocab
flattens the softmax so the top-64 logits miss 68% of the mass — the cache is structurally blind to the tail KD trains on.

TAU × K × method sweep (median over the 12 examples) located the fix:

| TAU | K | method | capt.mass | grad-cos | loss-ratio | verdict |
|----:|---:|--------:|----------:|---------:|-----------:|:--------|
| 1.0 | 64 | topk | 0.990 | 0.999 | 1.04 | **PASS** |
| 1.0 | 256 | topk | 0.996 | 1.000 | 1.02 | PASS |
| 1.5 | 1024 | topk | 0.896 | 0.997 | 1.14 | fail |
| 2.0 | 64 | topk | 0.319 | 0.910 | 2.23 | fail |
| 2.0 | 1024 | topk | 0.556 | 0.973 | 1.71 | fail |
| 1.0 | 64 | topk+TAIL | 0.990 | 1.000 | 0.98 | PASS |
| 2.0 | 64 | topk+TAIL | 0.319 | 0.999 | 0.69 | fail (scale) |

Findings: (1) **TAU=1, top-64 ≡ full-vocab KD** (captures 99%, grad-cos 0.999, loss-ratio 1.04) — the cache (top-K logits)
was always fine; the *temperature* was the bug. (2) TAU=2 is unrecoverable by K alone (even K=1024 → 0.556 mass). (3) The
lumped-TAIL bucket fixes the gradient DIRECTION at TAU=2 (cos 0.999) but not the loss SCALE (ratio 0.69) — so it is not a
substitute for the right temperature. **FIX APPLIED**: `mamba3_cloud_distill.py` default `TAU` 2.0 → 1.0 (valid for both
the full-vocab and cached top-K paths; the top-K path *requires* it). TAU=1 KD = match the teacher's native next-token
distribution, which is standard for LM distillation. The cloud cost model (cache top-K once, reuse) is now sound at TAU=1.

## Track G — Addendum 20: test battery P0-2/3/4 — int8 state-cache HOLDS to T=4096; angle-wrap is the free long-context hardening

The State-Cache Reader's binding spec is the cached 4-state's precision floor. Addendum 17/18 proved fp16/int8 fidelity at
cont=128 with PROMPT≤64. `Tools/test_p0_state_numeric.py` pushes prompts to 3968 tokens and sweeps precision × scope ×
angle-wrap (L=24, host, argmax-agree vs fp32 monolithic over a 128-token continuation):

| T (prompt) | max\|angle\| | 16b/all | 8b/all | 4b/all | 8b/ang | 8b/ang_wrap | 4b/ang_wrap | 8b/all_wrap | 4b/all_wrap |
|-----------:|----------:|--------:|-------:|-------:|-------:|------------:|------------:|------------:|------------:|
| 512 (384)  | 5.9 rad  | 100% | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| 1024 (896) | 12.5 rad | 100% | 100% | 99%  | 100% | 100% | 100% | 100% | 100% |
| 2048 (1920)| 24.2 rad | 100% | 100% | 99%  | 100% | 100% | 100% | 100% | 98%  |
| 4096 (3968)| 45.0 rad | 100% | 100% | 99%  | 100% | 100% | 100% | 100% | 99%  |

**Findings.** (1) **fp16 cache = 100% at every T** → safe regardless of prompt length (P0-4 PASS). (2) **int8 cache = 100%
at every T** → the int8 floor (addendum 17) HOLDS, now extended 64→3968 prompt tokens (P0-2/3 PASS). (3) The carried angle
is `new_angle = angle + dt*theta` UNWRAPPED, so `max|angle|` grows ~linearly: 5.9 → 45 rad over T=512→4096 (≈ 0.011 rad/tok).
int4/all dips to 99% — the angle quant is the culprit (`4b/ang_wrap` recovers to 100%). (4) **Angle-wrap is lossless**:
wrapping the cached angle to (-pi,pi] changes it only by whole multiples of 2π (measured 12.57 = 2·2π at T=1024), so the
fp32 decode is BYTE-IDENTICAL (wrapped==plain==ref 100%), while keeping the stored value O(1) instead of O(T).

**Decision (亏的不要).** int8 ≤4096 needs no change — but the angle grows linearly, so at T≈16k `max|angle|`≈180 rad would
make the int8 step (~1.4 rad) exceed the rotation and break the cache. The wrap costs nothing and removes that latent
long-context cliff, so it is now CANONICAL: `mamba3_trainable.cache_serialize_state(state)` wraps every layer's angle to
(-pi,pi] before quant — the required first step of State-Cache serialization. Caveat: argmax-agreement is coarse and this
is a random-init model; the int8 floor should be re-confirmed on the distilled checkpoint where logit competition is tighter.

## Track G — Addendum 21: MLA block BUILT + battery P0-12 — int8 is the hybrid's precision floor (the MLA cache, not Mamba, binds)

The hybrid's dense-coverage operator now exists: `Tools/mamba3_mla.py` (`MLABlock` + `MLAStack`). NoPE Multi-head Latent
Attention — caches one D_LATENT=128 latent/token (down-projected), re-expands to per-head k,v at compute → 16× smaller KV
than full MHA (2048 floats/tok). Mirrors the Mamba `Lyr` interface (pre-norm → residual → SwiGLU MLP → residual) so it drops
into the 24L hybrid at L6/12/18/23, with `forward_seq` (prefill, returns the latent cache) + `step` (decode over cached latents).

`Tools/test_p0_12_mla_kv.py` (4 MLA layers, prompt=512, cont=128, host):
- **(A) PARITY PASS**: `forward_seq` (prefill) == step-loop decode from empty cache — logit max-err 8.8e-6, argmax 100%.
- **(B) latent-cache quant floor** (argmax-agree vs fp32, 16× KV cut):

| cache | logit max-err | argmax all | first64 | last64 |
|------:|--------------:|-----------:|--------:|-------:|
| fp32  | 0          | 100% | 100% | 100% |
| fp16  | 3.0e-4     | 100% | 100% | 100% |
| int8  | 1.7e-2     | 99%  | 100% | 98%  |
| int4  | 2.5e-1     | 88%  | 89%  | 86%  |

**Findings.** (1) fp16/int8 MLA cache HOLD (100%/99%) at the 16× cut → the attention-path cache ships at int8. (2) **int4
BREAKS the MLA cache (88%)** — and this is the decisive contrast with the Mamba state, which held int4 at 99% (addendum 20).
(3) Mechanism = the MLA cache is **NON-CONTRACTIVE**: every cached latent is re-read by softmax every decode step, so a quant
error never decays (first64≈last64, no contraction recovery; cf. the Mamba state whose error DECAYS). softmax convexity bounds
the error but does not shrink it, so coarse int4 hurts ~4× more here than in the SSM. **Route consequence (亏的不要): the
hybrid's unified State-Cache precision floor is int8, set by the 4 MLA layers — not int4. The Mamba state could go int4, but a
single-precision cache must be int8 to keep the MLA layers faithful.** Unblocks: hybrid M wiring (20 Mamba + 4 MLA) + the full
two-state DUET handoff test.

## Track G — Addendum 22: HYBRID two-state DUET handoff VERIFIED — the full 24L route composes; int8 State-Cache = 1.75MB, token-identical

The integration test the whole route hinges on. Addendum 18 verified the Mamba-only DUET; addendum 21 built+verified the MLA
block alone. `Tools/mamba3_hybrid.py` (`HybridM` = 20 `MT.Lyr` + 4 `MLA.MLABlock` @ L6/12/18/23) + `Tools/test_hybrid_duet.py`
close the seam: does prefill→decode reproduce the monolithic decode when BOTH state types hand off at once, and survive a
single int8 State-Cache serialization? (24L, prompt=512, cont=128, host, argmax vs monolithic):

| config | logit max-err | argmax-agree | first-div |
|-------:|--------------:|-------------:|:----------|
| fp32 raw   | 3.7e-6 | 100% | none |
| fp32 wrap  | 3.6e-6 | 100% | none |
| int8 wrap  | 7.2e-4 | 100% | none |
| int8 nowrap| 7.7e-4 | 100% | none |
| int4 wrap  | 1.4e-2 | 98%  | tok 6 |

**Findings.** (1) **fp32 = exact (3.6e-6, zero divergence)** — the heterogeneous handoff composes: the Mamba 4-state
(`prefill_state`→`step_ref`) and the MLA latent cache (`forward_seq`→`step`) BOTH reproduce the monolithic continuation when
interleaved. (2) **int8 wrap = token-identical (100%, zero divergence)** — the shippable flagship State-Cache. (3) Cache size
= **1.75MB total** for a 512-tok prompt: **1.48MB Mamba (O(1), prompt-INDEPENDENT) + 0.26MB MLA latent (O(ctx))** — only the
small MLA part grows with context, so a phone-resident LIBRARY of pre-understood corpora at ~MB each is realistic. (4) int8
nowrap also 100% here (PROMPT=512 → angle ~6 rad, wrap is a no-op at this length; it pays off at >16k per addendum 20). (5)
int4 degrades to 98% (first div @ tok 6) — the MLA non-contractive floor (addendum 21) shows through the full hybrid → int8 confirmed.

**Route status:** the ENTIRE DUET path is now host-verified — Mamba-only (18), MLA block (21), and the hybrid two-state
handoff (22). The flagship "State-Cache Reader" rests on a token-identical int8 1.75MB handoff. REMAINING: on-device (prefill
.aimodel GPU + decode; the two-asset co-load risk P0-22 is device-gated) + cloud 24L distill (the quality gate, recipe now sound at TAU=1).

## Track G — Addendum 23: on-device DUET probe — design workflow + STEP 1 (prefill converts to CoreAI, host-level) = PASS

Operator chose the on-device path (take the host-verified hybrid DUET, addendum 22, onto the A19). An 8-agent design workflow
(5 readers + 2 adversarial verifiers + synthesis → `Docs/ONDEVICE_DUET_PROBE_PLAN.md`) settled the two claims that could sink it:
- **Co-load wall = device-PROVEN** (Track E: 2nd `AIModel.load` SIGSEGVs; a single multi-fn asset SIGABRTs — ANE compiles the
  WHOLE asset per-fn). Chosen escape = **state-via-disk handoff**: prefill runs ONCE → serializes the int8 1.75MB State-Cache →
  FULLY deinits → decode loads ONCE → reads the cache ONCE. One phase transition (not per-token), so the disk round-trip amortizes away.
- **"Prefill converts to CoreAI" was an unsupported PLACEHOLDER** (verifier: refuted as proven) — the #1 risk. Prefill is a
  structurally different graph from the device-proven decode (`step_ref`): it uses `cumsum`, `masked_fill(-inf)`+`exp` over a
  [T,T] segsum decay, big einsums, `cat`; MLA adds causal `softmax`+`triu` — the op family flagged as the likely converter blocker.

**STEP 1 (smallest de-risk) = PASS.** `Tools/mamba3_prefill_probe.py` exports ONE `MT.Lyr.prefill_state` and ONE
`MLA.MLABlock.forward_seq` (fp16, fixed T=64) through coreai_torch 0.4.0. **Both CONVERT** → `.aimodel` saved:
MambaPrefill emits the boundary 4-state (angle[16,32]/ssm[16,64,64]/kprev[16,4,64]/vprev[16,64,4]); MLAPrefill emits c_kv[64,128].
So `cumsum` + masked-exp-segsum + the einsums + MLA softmax+triu ALL have valid CoreAI lowerings — the prefill op-graph is
convertible. **Honest scope (R1): this is HOST conversion / op-lowering only.** It does NOT prove device GPU execution or numeric
fidelity — that is STEP 2 (load the L1 asset on the A19 GPU, run, compare the boundary state to host @ rel-err <1e-2), the real gate.
The placeholder is now replaced by evidence: scaling to the full 24L hybrid prefill asset (STEP 3) is mechanical IF STEP 2's device run holds.

## Track G — Addendum 24: on-device DUET STEP 2 — prefill RUNS on the A19 GPU + boundary state is NUMERICALLY EXACT vs host

STEP 1 proved host op-lowering; STEP 2 is the real device gate. Built `BASCoreAIPrefillSession` (no-state: feed [T,D], read
boundary-state OUTPUTS with empty MutableViews) + `BASCoreAIPrefillProbe` (BAS_COREAI_PREFILL_PROBE=1, GPU) + the launch hook;
`Tools/mamba3_prefill_probe.py` now emits a bit-reproducible input (`xs[i]=fp16((i%97-48)/480)`, mirrored in Swift) + HOSTREF
stats. Built via beta Xcode, staged the two L1 assets, ran on the iPhone Air A19 GPU:

| output | host norm | device norm | rel-err |
|-------:|----------:|------------:|--------:|
| Mamba.out_last | 19.1551 | 19.1546 | 3e-5 |
| Mamba.angle | 5.4372 | 5.4376 | 7e-5 |
| Mamba.ssm | 2.0846 | 2.0845 | 5e-5 |
| Mamba.kprev | 64.0016 | 64.0003 | 2e-5 |
| Mamba.vprev | 0.7422 | 0.7422 | <1e-4 |
| MLA.out_last | 7.1472 | 7.1477 | 7e-5 |
| MLA.c_kv | 59.4553 | 59.4553 | <1e-5 |

Head values agree to ~4 decimals. **Both prefill assets LOAD (load_ms 94/43) + RUN on the A19 GPU and produce the exact
decode-handoff state** — the #1 route risk ("does the chunked-segsum / MLA-softmax prefill run on device") is now DEVICE-PROVEN
cleared, not just host-convertible. Footprint tiny (49–86 MB). availableComputeKinds = [gpu, cpu, neuralEngine].

**Honest caveats (R1):** (1) `Mamba run_ms=2161` vs `MLA run_ms=205` — there is NO warmup in the probe, so the Mamba figure
almost certainly includes the one-time GPU shader compile; prefill compute latency must be re-measured with a warmup pass
before trusting a 20-layer prefill-time estimate (this is the next thing to check). (2) Single-layer, fp16, RANDOM weights —
numerics-correct is proven, end-to-end prefill latency at the full 24L is not. (3) GPU placement is inferred (no MLComputePlan
readback in 0.4.0); the asset ran + matched, which is the operative result. NEXT (STEP 3): scale to the full 24L hybrid prefill
converter — now mechanical and de-risked — then STEP 4-7 (decode asset, on-disk State-Cache contract, sequential-load orchestration, device E2E).

### Addendum 24 — latency caveat RESOLVED (warmup re-measure)
Added a warmup+timed loop to the probe (cold run vs 3 warm runs). The 2161 ms was a one-time process/GPU-stack init on the
FIRST CoreAI GPU op, NOT prefill compute. Per-layer at T=64, GPU, warm: **Mamba run_ms cold=17.1 / warm_best=4.6**; **MLA
cold=3.7 / warm_best=1.0** (load_ms 15/6). So the full 24L hybrid prefill projects to **~100 ms warm** (20×4.6 + 4×1.0) plus a
one-time ~2 s process warmup — the "prefill-once-reuse-many" flagship UX is comfortably fast. (Still single-layer/fp16/random
weights; the real 24L-single-asset number gets measured at STEP 3, but the compute is clearly not the bottleneck.)

## Track G — Addendum 25: on-device DUET STEP 3 — FULL 24L hybrid prefill RUNS on the A19 GPU, exact + fast (~43ms warm)

`Tools/mamba3_hybrid_prefill_deploy.py` exports `HybridM.prefill` (20 Mamba `prefill_state` + 4 MLA `forward_seq`) to ONE
.aimodel emitting 5 STACKED boundary tensors (angle_all/ssm_all/kprev_all/vprev_all + mla_all). HOST-fidelity gate (eager vs
exported-decomposed graph on CPU) = **0.0 rel-err** (no decomposition bug — the broadcasting_mul/torch.where class is clean
here). Asset = 862 MB fp16 (~430 MB int8, under the 2 GB wall). Built via beta Xcode, staged, ran on the iPhone Air A19 GPU
(probe "Hybrid" entry, T=64, hidden input):

| state | host norm | device norm | rel-err |
|------:|----------:|------------:|--------:|
| angle_all[20,16,32] | 48.7263 | 48.7275 | 2e-5 |
| ssm_all[20,16,64,64] | 6.4063 | 6.4056 | 1e-4 |
| kprev_all[20,16,4,64] | 286.2014 | 286.2173 | 6e-5 |
| vprev_all[20,16,64,4] | 3.6635 | 3.6636 | 3e-5 |
| mla_all[4,64,128] | 115.6250 | 115.6269 | 2e-5 |

**The entire prefill half of the DUET is device-proven at production depth.** load_ms=1962 (the 862 MB fp16 asset load — the
binding cost; int8 halves it), **run_ms cold=165.9 / warm_best=42.9** → the full 24-layer prefill computes in ~43 ms warm at
T=64, footprint 90→148 MB. For prefill-once-reuse-many, a ~2 s one-time load + ~43 ms compute per corpus is comfortable.
NEXT (STEP 4): the 24L DECODE asset — the harder piece (the 4 MLA layers' growing latent cache as a fixed [MAX_SEQ,128] buffer + fill-offset + masked attention; the 20 Mamba layers reuse the proven angle-first 4-state decode).

## Track G — Addendum 26: on-device DUET STEP 4 — 24L hybrid DECODE asset (MLA growing-cache → fixed buffer) host-exact + CONVERTS

The decode asset is the harder half: the 4 MLA layers' latent cache GROWS per token but CoreAI state is fixed-shape.
`Tools/mamba3_hybrid_decode_deploy.py` reformulates each MLA layer as a fixed `mla_kv[MAX_SEQ,128]` buffer + scalar `mla_fill`,
with a ONE-HOT write (`kv*(1-oh)+c_t*oh` at slot=fill — NOT dynamic indexing) and an offset MASK (slots ≥ fill+1 → -inf in
softmax). The 20 Mamba layers reuse the proven angle-first 4-state stacked decode.
- **STEP 4a host-equivalence = PASS**: the fixed-buffer hybrid decode vs monolithic `run_ref` over a 48-token continuation
  (24L, MAX_SEQ=256, prompt=64) → logit max-err **3.0e-6, 100% argmax**. The one-hot+mask reformulation is EXACT vs the
  growing-cache step — the hard algorithmic risk is retired in pure torch before any device work.
- **STEP 4b convert = PASS**: exports to `.aimodel` with **6 resident states** (angle_all/ssm_all/kprev_all/vprev_all/mla_kv/mla_fill,
  stacked — not 88 loose buffers), 891 MB fp16 (~445 MB int8). The one-hot `==`, offset `>=` masked_fill, and the scalar
  `mla_fill` mutation ALL lower through coreai_torch 0.4.0. (Caught + fixed one export blocker: scalar embedding index
  `ew[id.view(())]` emits `aten.item()`→unbacked symint; `F.embedding(...)` gathers cleanly — same fix DeployM already uses.)
NEXT (STEP 5/6/7): the on-disk State-Cache contract + the Swift hybrid decode session (6 states) + sequential-load orchestration
(prefill deinit BEFORE decode load, dodging the co-load SIGSEGV) → the device E2E: device decode == host monolithic continuation.

## Track G — Addendum 27: on-device DUET E2E (STEP 5/6/7) — the device DUET reproduces the host decode on the A19 ✅

The capstone. `BASCoreAIHybridDecodeSession` (6 resident states) + `BASCoreAIDuetProbe` (BAS_COREAI_DUET_PROBE) orchestrate
the full handoff in ONE process WITHOUT co-loading: load prefill → run the 64-token prompt → COPY the 5 boundary tensors into
Swift memory → **deinit the prefill AIModel** → build the 6 decode states (4 Mamba stacked direct + mla_kv = prompt latents
scattered into [0:64] + mla_fill=64) → **load the decode asset (2nd AIModel.load)** → teacher-forced decode of 32 cont tokens.
Both assets are the device-proven 24L converters; tokens are deterministic (`tok[i]=(i*17+5)%4096`, mirrored host↔Swift).

Device run (iPhone Air A19, GPU):
- prefill done footprint 148 MB → **prefill released footprint 91 MB** (the AIModel deinit drops resident memory)
- **decode loaded — NO co-load SIGSEGV** ✅ — the sequential-load escape (deinit-before-load) WORKS on device. This is the
  architectural bet the whole DUET rested on (Track E proved 2 co-resident assets SIGSEGV); it is now validated.
- 32 decode steps, 21.6 tok/s (unoptimized: cold, per-step Swift overhead, full MAX_SEQ=256 MLA attention even early).
- **DEV_CONT_ARGMAX matches the host monolithic 31/32**. The single difference is position 3 (host 1901, dev 1013) — whose
  fp32 top1−top2 **margin = 0.001** (a near-tie; pos-14 is an exact 0.0 tie yet matched; pos-0/1 at 0.003/0.002 matched).
  The fixed-buffer decode is fp32-exact vs monolithic (addendum 26, 3e-6), so the lone flip is the fp16-vs-fp32 boundary at a
  0.001-margin token, NOT a logic error.

**The entire on-device DUET is PROVEN end-to-end on the A19**: prefill (24L, exact, ~43 ms) → state-via-memory handoff →
sequential-load (dodges the co-load wall) → decode (24L hybrid, MLA growing-cache as fixed buffer) → output == host monolithic
to fp16 precision. STEP 1→7 complete. REMAINING: (a) persist the handoff to DISK (cross-launch State-Cache reuse — the flagship's
literal "prefill-once-reuse-many"; the in-memory handoff proves the contract); (b) decode tok/s optimization (warmup, windowed
MLA attention); (c) the cloud 24L distill (real weights → the quality gate). Host + device fidelity are GREEN end-to-end.

## Track G — Addendum 28: AUDIT (万无一失) — corrections to addenda 23-27 + the HONEST fp16 result (device == host-fp16 32/32)

A 10-agent adversarial audit (7 refute-auditors + 3 architects + synthesis) ruled the DUET work **NOT 万无一失 as worded**: the
engineering + host-numerics are trustworthy and reproduced, but several DEVICE-RESULT and FLAGSHIP claims were overstated.
Corrections (the underlying engineering is unchanged; the CLAIMS are downgraded to what is actually proven):

- **The headline is now HONEST and STRONGER.** addendum 27 compared device-fp16 vs host-**fp32** (31/32, "lone diff = fp16
  near-tie"). The audit found the code's OWN apples-to-apples baseline (`MODE=ref HALF=1`, fp16/MPS) CRASHED — `_zero_state`
  (mamba3_hybrid.py) and `M.run_ref` (mamba3_trainable.py) built `torch.zeros(...)` with no device=/dtype=. **FIXED** (inherit
  from `embedding.weight`). Re-run: **device fp16 == host-fp16 monolithic, 32/32 BYTE-IDENTICAL** (incl. position 3 → both 1013).
  So the seam is EXACT at matched precision; the 31/32 was purely the fp32→fp16 rounding at one 0.001-margin token. Cert log
  committed: `Docs/cert-logs/duet-e2e-*.log`.
- **"co-load SIGSEGV dodged" → "sequential-load works on GPU".** Track E's SIGSEGV was ANE-specific; the DUET runs on GPU and
  never attempted a co-load, so nothing was "dodged". The probe never re-demonstrates (or needs) the ANE co-load wall.
- **"state-via-disk handoff" → "in-memory STATE-VALUE handoff".** There is NO disk roundtrip — the handoff is a Swift
  `[String:[Float16]]` dict. Disk persistence remains UNBUILT (it is the flagship's remaining work, not a proven contract).
- **"reproduces the decode end-to-end" → "teacher-forced PER-STEP fidelity".** Both sides are teacher-forced (fed the ground-
  truth continuation); this is the correct fidelity test but CANNOT surface autoregressive error accumulation. Not a generation result.
- **MAX_SEQ=256 was a SILENT cap → now FAIL-LOUD.** `BASCoreAIHybridDecodeSession.step` tracks `written` and throws
  `.overflow` at `written == MAX_SEQ` (was: the one-hot write matches no slot, token silently dropped, output corrupts with no
  NaN). A defined overflow policy (re-prefill / evict-window) is still TODO, but the corruption is now trapped.
- **Random-weight + argmax caveat.** All device/host argmax-agreement is on RANDOM untrained weights (near-flat logits → 7/32
  positions have margin ≤0.01); the honest fidelity metric is the CONTINUOUS logit max-err (3e-6 fp32 seam, addendum 26). The
  int8 State-Cache floor (addenda 20-22) is a necessary-not-sufficient smoke test until re-confirmed on a DISTILLED checkpoint.
- **Scope/labels corrected.** Prefill is device-proven at 24 LAYERS, **T=64 (scan_parallel) only** — the real-corpus T>64
  `scan_chunked` path is host-equivalent (1e-13) but device-UNCONVERTED. The prefill device match is a **norm/sum/head[:4]**
  scalar match, not elementwise. "~430MB int8 prefill" is **PROJECTED** (no int8 prefill asset built). "O(1) portable" holds only
  for the pure-Mamba 8L SKU; the 24L hybrid is O(1)-Mamba + O(ctx)-MLA. The 24L hybrid decode is a **CoreAI-GPU** reader (the
  ≤8L single-asset is the only 100%-ANE form; asset-split device-refuted — already corrected in BASCoreAIMamba3Session.swift).

**Gated TODO (before any 一鸣惊人 claim — none shippable on random weights):** (1) elementwise device-vs-host readback (replace
norm/sum/head); (2) device-prove the T>64 scan_chunked prefill or ship the driver-loop fallback; (3) re-certify the int8 floor
on a distilled checkpoint with a KL/greedy-accept metric, not argmax; (4) autoregressive (feed-back) host-vs-device drift test +
CONT near MAX_SEQ; (5) actual disk serialize→file→deserialize of all 6 states + a fail-closed binding key {weight_hash, config,
converter_version, precision, max_seq}; (6) n>1 release/leak test; (7) SISO vs MIMO device A/B. **Bottom line: the host numerics
+ device PLUMBING are PROVEN; the product/persistence layer + a trained-checkpoint quality gate are the open work.**

## Track G — Addendum 29: 全面开发 — closed the scorecard's 2 BLOCKERS + built the 浑然一体 loop (StateLake + resumable prefill + Context Compiler), host

Acting on the coverage scorecard's build-order, three REAL host-verified modules turn the worst-scored pillars from prose into code:

- **STEP 3/4/11 — StateLake** (`Tools/mamba3_statelake.py`, neural-state DB): `binding_key` {weight_hash, arch-config,
  converter_version, precision, max_seq, angle_wrap} checked **FAIL-CLOSED** on load (the audit's #1 danger — gone); the
  `.statelake` disk bundle (header.json + int8 blobs + per-tensor scales + blake2b checksum); + the SQLite store with lineage
  DAG, fork, ACL, TTL/expiry, model-version mass-invalidation, hot-LRU/warm-disk tiering, and a Router (deepest valid
  ancestor; composition stays KILLED). Self-test PASS: **disk roundtrip int8 → rehydrated state reproduces the decode 100%**;
  binding-key rejects a stale key; fork/lineage/router/TTL/invalidate all green. → Pillar 3 (was ~5% prose) is now BUILT_HOST.
- **STEP 5 — resumable prefill** (`scan_parallel`/`scan_chunked` ssm-carry-in; `Lyr.prefill_state(init=)`; `MLABlock.forward_seq(kv_init=)`;
  `HybridM.prefill(init=)`): `prefill(suffix, init=prefill(prefix)) == prefill(prefix+suffix)` — boundary rel-err **5.5e-6**,
  decode argmax **100%**, no DUET regression. Mamba carries the O(1) 4-state, MLA carries the O(ctx) latent. → Context Compiler's
  PREFIX-STATE-REUSE / fork-and-extend / streaming-prefill are unblocked (were DESIGNED_ONLY).
- **STEP 7(basic)+integration — Context Compiler** (`Tools/mamba3_context_compiler.py`): `compile()` tiles a corpus + resume-prefills
  + stores every cumulative-prefix state with lineage; `serve()` ROUTEs to the deepest cached prefix → REUSEs → prefills only the
  suffix → HANDOFF → DECODE. Self-test PASS: a 112-tok query **reused 64 cached tok, prefilled 48, decode == from-scratch 100%**
  (57% of the prompt not re-computed). → the cross-cutting 浑然一体 (was ~35%, handoff-only) is now an EXECUTABLE closed loop (host).

**Honest scope:** all THREE are HOST builds. Still gated: (a) the Swift/device `.statelake` reader (the on-device half of persistence —
the host put/get + binding-key contract is proven and portable); (b) T>64 `scan_chunked` ON DEVICE (resumable prefill is host-exact;
device convert untested); (c) the trained-checkpoint quality gate (最强大 still unsubstantiated — every result is random-weight,
necessary-not-sufficient); (d) fused on-device argmax + verify[1,K] self-spec. NET coverage delta: Pillar 3 ~5%→~60% (host), Context
Compiler ~18%→~45%, 浑然一体 ~35%→~65%. The remaining gaps are device-port + the cloud distill (the one lever that makes 最强大 real).

## Track G — Addendum 30: 继续开发 — the HYBRID is now distillable; cloud 24L distill retargeted to the hybrid (the 最强大 prerequisite)

The coverage scorecard's #1 BLOCKER: every device/host result is RANDOM-WEIGHT, and the one trained checkpoint is a DIFFERENT
pure-Mamba L16 model — so 最强大 is unsubstantiated and the cloud distill trained the wrong arch. Fixed the prerequisite:
- **`HybridM.run_twin(tokens)`** — a parallel TRAINING forward (Mamba via `Lyr.forward_seq`, MLA via `MLABlock.forward_seq`,
  tied head), identical interface to `MT.M.run_twin`, so the distill + eval harness is arch-agnostic (verified: `eval_nll`
  uses `run_twin`; `HybridM(256,24).run_twin → [40,256]` with all 4 MLA layers).
- **`mamba3_cloud_distill.py ARCH=hybrid`** — builds `HybridM` (20 Mamba + 4 MLA) instead of `MT.M`; the loop (KD@TAU=1 +
  RAFT-CE, top-K cache, curriculum, atomic resume) is unchanged. The cloud run now produces the HYBRID checkpoint that feeds
  the device assets.
- **Trainability PROVEN** (`Tools/mamba3_distill_hybrid_smoke.py`, host overfit, L=8 incl. 1 MLA @ position 6): KD **2.05 → 0.027
  (99% drop)**, teacher-argmax agreement **0% → 100%**, MLA-layer `kv_down` gradient finite+nonzero, no NaN → the from-scratch
  MLA layers DO learn; gradients flow through MLA + Mamba end-to-end. The hybrid is distillable.

**Status:** the cloud distill is now READY to produce a trained 24L hybrid (`ARCH=hybrid LAYERS=24` on the RunPod kit). The
actual run needs the operator's cloud compute (cannot self-provision). Once it produces a checkpoint, wire it into
`mamba3_hybrid_{decode,prefill}_deploy.py` (replace `manual_seed(0)` with `load_state_dict`) → re-run the device DUET + the
int8 floor cert with a stricter-than-argmax metric → 最强大 becomes a measured number instead of prose. This is the last gate.

## Track G — Addendum 31: 选2/device-port — StateLake CROSS-LAUNCH persistence PROVEN on the A19 (disk .statelake → rehydrate → decode)

The device half of the StateLake (host put/get + binding-key proven in addendum 29). `BASStateLakeReader` (parse header.json,
**FAIL-CLOSED** binding-key check, **SHA256** payload verify, int8·scale / fp16 dequant → NDArrays) + `BASCoreAIStateLakeProbe`
(BAS_COREAI_STATELAKE_PROBE) + `Tools/mamba3_statelake_device_prep.py` (writes a device `.statelake` of the 6 decode-ready
states + the host ref). Ran on the iPhone Air A19 (GPU; cert log `Docs/cert-logs/statelake-*.log`):
- **(A) fail-closed = PASS** — a wrong binding-key is REJECTED on device ("artifact 446a… != expected dede… — refusing stale
  state"). The audit's #1 danger (silent garbage on mismatched weights) is now trapped ON DEVICE.
- **(B) load = PASS** — 6 states rehydrated from the 1.62 MB int8 `.statelake`, binding-key + SHA256 checksum both verified.
- **(C) decode = 30/32** vs the **fp32** host reference; the 2 diffs are positions 3 & 14 — the SAME known near-ties (pos 3
  fp32 margin 0.001, pos 14 an exact 0.0 tie). The int8 state survived the disk round-trip faithfully; the diffs are the
  fp16-device-vs-fp32-host boundary (per addendum 28, device==host-FP16 is exact), NOT a StateLake error.

**A host-serialized neural state rehydrates on the A19 (fail-closed + checksum-verified) and decodes** → the flagship
"prefill-once-reuse-many ACROSS LAUNCHES" is real on device, not just in-RAM/host. StateLake coverage: device-port done; the
.statelake format is the shared contract (host `mamba3_statelake.py` ⇄ device `BASStateLakeReader`). REMAINING (still gated):
the trained-checkpoint quality gate (cloud distill ARCH=hybrid) — every result here is still random-weight machinery.

## Track G — Addendum 32: 云前audit (pre-cloud) — 就差云吗 = NO; fixed 5 wasted-run BLOCKERS so the cloud output is usable

A 6-agent readiness audit answered 就差云吗 bluntly: **NO.** The trainer is correct (`mamba3_cloud_distill.py:117` derives
`vocab = tok.vocab_size` ≈ 100352 from Granite — NOT hardcoded), but the trained weights could not REACH the device — a cloud
run today would buy "a checkpoint nothing can deploy." Fixed the chain (host-side, no cloud/device needed; seam re-verified):
- **Checkpoint portability** (`save_ckpt`): now records `arch` / `vocab` / `mla_positions` so a converter rebuilds the SAME
  graph; **resume reads arch/vocab from the ckpt BEFORE building the student** (a hybrid ckpt no longer silently rebuilds as
  pure-Mamba → key mismatch).
- **Converters now LOAD the checkpoint** (were `manual_seed(0)` random): shared `HY.resolve_ckpt(default, layers)` → the
  **checkpoint is AUTHORITATIVE on vocab** (closes the 4096-vs-100352 mismatch), fail-closed on arch/layer mismatch; wired into
  `mamba3_hybrid_{prefill,decode}_deploy.py` + `mamba3_statelake_device_prep.py` (load into `m.m`/`m`, strict=False). No CKPT →
  the old random-weight 4096 op-graph probe (unchanged). `mamba3_deploy.py` CKPT is now env-overridable (the pure-Mamba path).
- **`runpod_distill.sh`**: now `export ARCH=hybrid` (was unset → silently pure-Mamba) + an `HF_TOKEN` gate (Granite may be
  gated → was failing only AFTER the expensive cache phase).
- **Seam re-verified** (host, pure-torch): a trained hybrid ckpt (the new metadata) → `resolve_ckpt` picks its vocab, loads into
  the converter, the **trained MLA weights land** (param allclose), and a wrong-arch ckpt is REJECTED. The cloud→device path is open.

**Verdict:** ready to launch AFTER these fixes (now landed). Launch = `ARCH=hybrid LAYERS=24` on the RunPod kit; post-run set
`CKPT=/workspace/ckpt/ckpt_latest.pt` for the converters + `mamba3_statelake_device_prep.py`, rebuild the assets, re-run the
device DUET/StateLake probes (binding-key fail-closed catches any vocab/arch mismatch). **Cost ≈ $50–200** on one A100/H100 80GB
spot (~20M-token PoC; teacher top-K cache built once). REMAINING NON-BLOCKING GAPS: (a) N_ROWS=20000 silently caps at the
HotpotQA val split ~7.4k (graceful; log the real count); (b) no torch-vs-on-device-ASSET quality gate on TRAINED weights — the
conversion-fidelity gates now run on the trained ckpt (decomposition exact) but the asset-vs-trained-model argmax compare is the
device probe (post-cloud). Training-time eval (RAFT E1/E2/E3 robustness) is wired + trustworthy.

## Track G — Addendum 33: 一次性 — ALL host-buildable 剩余部分 closed (StateMarket · 资料层 dedup · verify[1,K] · T>64 convert)

Closed every remaining HOST-buildable gap from the coverage scorecard + pre-cloud audit, each with a passing test:
- **StateMarket (竞争层)** (`mamba3_statelake.py`): states compete for the hot-tier budget by VALUE = (hits+1)·prompt_len /
  (size_mb·recency); `admit()` greedily fills the budget (high-value hot, rest→warm), `arbitrate()` picks the single most-
  valuable candidate (composition stays KILLED). Self-test PASS: budget≈2 states → hot1∈hot, cold∉hot, arbitrate→hot1.
  (+ `get()` records hits/last_used; schema gained hits/last_used/size_mb; `_valid` unpack widened.)
- **资料层 dedup** (`mamba3_context_compiler.py` + `StateLake.find_by_content`): cross-corpus content-addressed reuse — docB
  sharing docA's 64-tok prefix dedup-HITS the shared tile (1/2), not re-prefilled. The 资料层 cache (model-safe via binding-key).
- **verify[1,K] self-spec (二象, STEP 10)** (`test_verify_kstep.py`): the target's BATCHED verify of K tokens == K sequential
  step_ref decodes (logit max-err 2.1e-5, argmax 100%) → greedy speculative decode is BYTE-EXACT. The ≤8L-draft ∥ 24L-verify
  loop is algorithmically sound (verify[1,K] = `head(prefill(K, init=state))`, weight-independent; acceptance RATE needs trained models).
- **T>64 chunked-scan convert (STEP 6)** (`mamba3_prefill_probe.py PROBE_T=256`): the `scan_chunked` carry-loop + MLA
  attention BOTH convert to `.aimodel` at T=256 → real-corpus prefill is host-convertible (the audit's "Context Compiler is a
  64-token toy" gate clears at the convert level; the device RUN of the T=256 asset is the remaining confirmatory step).
- **N_ROWS** (audit GAP #7): non-issue — `cloud_distill.py:141` already logs the actual `train=`/`held=` counts post-split.

**就差什么了 (the IRREDUCIBLE remainder — none autonomously closeable):** (1) the **cloud distill RUN** — needs the operator's
RunPod compute; turnkey-ready (`ARCH=hybrid`, seam fixed, ~$50–200). (2) **trained-model quality** (最强大, int8-cert-on-trained,
the 语义层 evidence-compressor's VALUE) — all downstream of #1; cannot be measured on random weights. (3) **3 confirmatory device
RUNS** — T>64 prefill on-device, fused on-device argmax, verify[1,K] on-device — their CONVERTS/equivalences are host-proven;
the device runs confirm placement/perf. Every host MECHANISM of the three-pillar system is now built + verified; the spine is
device-proven. The product is mechanism-complete — it awaits a trained checkpoint (the cloud run) to become a model worth shipping.
