# Universal Self-Speculative Decode — Probe Results

Program: a universal LLM speculative decoder (any LLM, byte-identical, no per-target draft pairing), two tracks
— **A** prompt-lookup (model-free n-gram draft) and **B** CoreAI/ANE draft (squeeze the otherwise-idle ANE).
Doctrine: probe-first, 实测胜出才晋升, byte-identical under greedy verify (ADR-039), zero auto-promotion.

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

Next (refinement, not blocking): adaptive K (drop K when recent hit-rate is low → eliminates the −9% control
cost while keeping the repetitive wins); purpose-gated adoption (only the deterministic/factual/RAG lanes).

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
