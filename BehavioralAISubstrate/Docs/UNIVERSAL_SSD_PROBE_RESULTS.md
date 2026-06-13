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
