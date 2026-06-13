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

## Track A — prompt-lookup (n-gram) — IN PROGRESS
Drafter landed (`BASPromptLookupDrafter`, host-tested); decoder + probe next.
