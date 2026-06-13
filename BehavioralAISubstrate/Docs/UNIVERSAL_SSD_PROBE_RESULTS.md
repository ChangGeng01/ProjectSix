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
