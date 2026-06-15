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
