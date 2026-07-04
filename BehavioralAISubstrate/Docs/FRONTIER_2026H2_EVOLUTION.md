# FRONTIER 2026-H2 — Evolution Sweep (第四轮前沿扫荡)

**Date:** 2026-07-04 · **Method:** 6 parallel research agents (decode-accel / small-models / memory+sleep /
test-time-compute / Apple-platform / radical-futurist), ~100 web calls, every claim graded
[SHIPPED] / [PAPER-MEASURED] / [BLOG/HYPE], datacenter-batched numbers quarantined from batch-1 phone claims.
**Differential to:** DECODE_ACCEL_FRONTIER_2026.md, FRONTIER_2026_PLAYBOOK.md, biomimetic-brain (June 2026).
**Hard filter:** A19 batch-1 bandwidth-bound · 满血 lossless trunk · ADR-014 opt-in · spec speedup=(1+a)/(1+f·K).

**Conflict adjudicated by hand (2026-07-04):** agents disagreed on DFlash availability. Verified directly:
`z-lab/Qwen3.5-4B-DFlash` **EXISTS on HF** (0.6B drafter, target = our exact base, block 8/16, Apache-2.0,
40k-seq retrain) — but **mlx-lm ships NO spec lane** (README verified: zero mention of dflash/eagle/mtp;
official support = SGLang, vLLM PR pending). The "mlx-lm native dflash lane" claim was agent overclaim.

---

## Thesis check (4th consecutive sweep)

**"Efficient thinking = avoided-compute + bandwidth, not faster matmul" — REINFORCED again.**
Every loud 10-10,000× claim audited back to datacenter batching (d-Matrix), simulation on custom silicon
(Extropic), or discrete-GPU idle FLOPs (DiffusionGemma — Google's own page: unified-memory Apple Silicon
"may not see the same acceleration", quality below standard Gemma 4). The batch-1 free-form decode wall
STANDS everywhere; the frontier moved in exactly four places (BUILD/MEASURE below).

---

## VERDICTS

### BUILD (evidence sufficient, start when campaign slots open)

| # | Item | Evidence | Expected | Effort |
|---|------|----------|----------|--------|
| B1 | **Fused Metal 4 TensorOps decode kernel** (our owned lever, now with first-party scaffolding) | WWDC26-330: worked FlashAttention example, multi-plane INT4+scales tensors = MLX group-quant layout, cooperative tensors; iOS 27 adds FP4/FP8/INT2 [SHIPPED-API beta] | ~42-45 tok/s lossless (unchanged est.); also accelerates the compute-bound verify step of ANY spec lane → compounds with M1 | HIGH, risk LOW (physics-backed) |
| B2 | **Pre-generation difficulty probe → tier router** | Last-prompt-token hidden-state linear probe AUC **0.931** pre-generation (2602.09924); DiffAdapt ICLR-2026 **-22.4% tokens no fine-tune** [PAPER-MEASURED] | our probe→tier→maxDecodeTokens dial, now literature-validated; prereq = MLX observation hook (already flagged) | MED |
| B3 | **Thinking-trace entropy early-exit** | EntroCut (small-LRM-specific, **-40%** trace tokens), DEER (code released), EAT single-token signal [PAPER-MEASURED]; 4B overthinks 2.5× vs 27B | -25-50% reasoning-phase tokens, training-free decode-loop stop rule. TRAP: use convergence signals NOT answer-confidence (overconfidence fires early); `enable_thinking=False` is leaky | LOW |
| B4 | **Predictive thermal + efficiency-core decode** | EnerInfer 2606.23001: horizon thermal *prediction* pre-empts throttle, **-65% energy**; MNN-AECS: decode is memory-bound → efficiency cores, **-23% energy ~zero speed cost**, iOS-viable [PAPER-MEASURED] | upgrade our REACTIVE thermal-lease to PREDICTIVE; near-free energy win | LOW-MED |
| B5 | **Persistent Q4 KV cache (cross-session warm-start)** | "Agent Memory Below the Prompt" 2603.04428 + open code: KV→4-bit safetensors→disk, M4 warm TTFT **27-35×**, Q4 quality ≈lossless, survives reboot; in-paper iPhone projection ~1.7s@4K [SHIPPED-CODE, Apple-Silicon-measured] | extends session KV reuse across sessions; slots into dream-loop idle window; NOT learning — warm-start caching | MED |

### MEASURE (build the probe, let the device decide — our Gate protocol)

| # | Item | Evidence | Gate | Effort |
|---|------|----------|------|--------|
| M1 | **DFlash block-diffusion drafter on A19** — the ONE new mechanism attacking draft COST (16-token block per single forward vs autoregressive K) | Paper 2602.06036 >6× GPU lossless; LMSYS batch-1 B200 4B-class **2.2-3.3×**, accept-len 3.0-4.2 (crosses our a≈3 cost threshold from Gate-2b!); checkpoint **verified exists**; community M5-Max port claims 3.4× [unverified] | Port drafter forward to MLX (no mlx-lm lane exists — we write it; community dflash-mlx as starting point). Teacher-forced α on A19 FIRST, then kill-switch tok/s A/B, lossless via our rejection lane. Realistic A19 guess 1.3-2.0×; accept <1× outcome honestly | MED-HIGH (no training needed) |
| M2 | **DWQ-distilled 3-bit trunk** | DWQ SHIPPED in mlx-lm (4-bit DWQ ≈ old 6-8-bit quality); our June "3-bit cliff" verdict was about NAIVE group-quant [SHIPPED] | quality gates first (math/code + honesty axes + 17-sheep), then bracketed tok/s. ~1.2-1.35× IF quality holds. ⚠️ anti-syco adapter must stay ≥8-bit (v12 lesson) | MED |
| M3 | **Native MTP head vs our folded head** | Qwen3.5-4B checkpoint SHIPS ~785 `mtp.*` weight keys; standard quant discards them; community preserves bf16 via quant-ignore-list; llama.cpp merged native-MTP (PR #19493) [SHIPPED-WEIGHTS] | A/B acceptance α: native-bf16 head vs our folded head on device. Lane-QUALITY tweak, not a new speed regime (independent batch-1 runs: no net win) | LOW |
| M4 | **ANE sustained lane** ("ANE = power not speed" needs an "…except sustained" amendment) | iPhone 17 Pro 10-min continuous: MLX/GPU 48→**18** (38% retention) vs CoreML/ANE 33→**22** (67%) at ~half power; LiteRT-LM GPU 56→27 [MEASURED, rockyshikoku 2026-06] | measure OUR stack's 10-min sustained on the Air; if GPU sustained < ANE sustained, wire an ANE long-generation lane into ε→effort→thermal-lease | MED |
| M5 | **9B-class main organ feasibility** (correction: **iPhone Air = 12GB RAM**, not 8) | AFM-3 Core Advanced tier includes the Air; ecosystem consensus 7-13B 4-bit practical; `z-lab/Qwen3.5-9B-DFlash` also exists [MEASURED/VENDOR] | 9B-4bit ≈5GB + our substrate under jetsam (NO new entitlement — wired-memory discipline still ours). Directly serves "route factual-belief to a bigger model" | MED (evaluation), HIGH (migration) |

### WATCH (trigger events named; do nothing until they fire)

| Tech | Trigger | Then |
|------|---------|------|
| **Diffusion-on-ANE** (verdict refined: dead on Apple unified-memory GPU, ALIVE on idle-NPU — llada.cpp Snapdragon 3.9× quality-held; ANE is exactly such an idle engine) | any credible diffusion-LLM-on-ANE batch-1 measurement | prototype masked-block head on ANE vs MTP lane |
| **Small generative verifier ≤2B** (field converging on our propose/dispose; ThinkPRM/Generative-Verifiers/VeriBound) | released small-scale verifier checkpoint w/ selective-accuracy numbers | wire as L10/L14 dispose adjudicator vs honesty harness |
| **AFM-3 Core Advanced as bigger-model seat** (20B sparse, 1-4B active, IFP flash-streaming, ships Sept 2026, framework open to any provider via `LanguageModelExecutor`) | iOS 27 GA + independent capability data | prototype executor over BASOrgan; route factual-belief tier to it |
| **Phone-scale dense instruct hybrid ≤4B** (gap still open; datacenter closed: Nemotron-3-Nano 31.6B-A3.2B, Kimi-Linear-48B — usable as distill TEACHERS via our Mamba-3 route) | a ≤4B dense instruct hybrid, MLX-convertible | benchmark as L2 organ vs Qwen3.5 |
| **MLX-iOS NAX enablement** (Metal 4 API supports A19 NA today; MLX NAX = macOS 26.2+ M5 only) | MLX release notes enable NAX on iOS | adopt for prefill (2-3× TTFT, decode unaffected) |
| **mlx-lm PR #990** (native GDN MTP — our own snapshot-rollback technique, unmerged) | merge activity | adopt state-handling edge cases; consider upstreaming our adaptive-K + thermal tiering |
| **Rotation-quant in MLX** (PolarQuant-class "3-bit beats fp16" — paper-only) | an MLX rotation-quant landing | fold into M2 |
| **Ternary + linear-state convergence** (Ternary Mamba 2606.18114; BitNet still from-scratch + CPU-kernel-only) | native ternary ≥7B instruct + a non-CPU kernel path | reopen bandwidth-lever audit |
| **Titans/Atlas TTT shipped** (surprise-gated neural memory — architecturally kin to our ε-gate; not in any product) | edge numbers in a shipped product | evaluate vs StateLake |

### DEAD (confirmed again this sweep; do not revisit without new physics)

- **EAGLE-3 on small Apple batch-1** — 1.05× re-confirmed (M3 Ultra 8B, mlx-lm #890). Independent 2026 sweep: conventional drafters 1.06-1.18× free-form on Apple metal.
- **Naive/non-fused MTP on Metal** — llama.cpp #23752: **-11% to -28% net LOSS at every config** (validates exactly why our fused chain wins; upstream is behind our shipped lane).
- **Cross-family/UAG drafts** — net loss batch-1 re-confirmed (2604.16368).
- **KV-quant at our 1-4K lengths** — mlx #3404: **17.9× SLOWER** than native SDPA at 2K (Python dispatch dominates); long-context memory play only.
- **A19 "Neural Accelerators for LLM" narrative** — PREFILL-ONLY (Apple's own M5 data: decode delta 1.19-1.27× = bandwidth, not NA; llama.cpp: 2-3× prompt processing, "generation speed identical").
- **Multi-agent for capability** — 2604.02460: equal-token-budget single agent best-or-tied at every budget vs ALL MAS topologies ("MAS gains = compute effects, not architecture"). Our 8-seats-ONE-trunk validated; steal only quantized KV handoff (QKVShare 2.6× re-prefill avoidance, 3-bit KV near-lossless).
- **Speculative-CoT / draft reasoning** — 2nd model in RAM, wall-clock not total-token wins; same 0.88× wall.
- **Parallel self-consistency** — "losing its edge" (2511.00751); we run greedy single-trace.
- **HRM as breakthrough** — ARC Prize hidden-set audit: 32%/2% (from 41% claimed), hierarchy contributes ≈0, outer refinement loop is the whole effect, memorizes tasks; not a language model.
- **Extropic 10,000× / d-Matrix 10× / diffusion 4-6.4×** — simulation-on-custom-silicon / datacenter-batched / discrete-GPU. None pass the batch-1 unified-memory filter.
- **SEAL-style self-edit weights nightly** — measured catastrophic forgetting COMPOUNDS with edits; only behind a regression-gated admission (which is our eval-rigor doctrine, now citeable: GRASP/SkillAudit/"verifiability constraint" 2507.21046).
- **TTT layers as live memory** — +60-90%/token latency at 4 inner steps; fatal at the decode wall.
- **Cartridge composition dream** — independent per-doc cartridges COLLAPSE to 26% when mixed; joint training mandatory. (Cartridges per-corpus = StateLake-with-numbers: 38.6×mem/26.4×throughput/≈ICL — gate on the shelved product axis.)
- **Importing LoCoMo/LongMemEval 94s as our expectation** — GPT-5-mini-class ceilings; re-measure on the 4B (the crown-before-co-measuring trap).
- **Swapping the 4B base** — NOTHING beats Qwen3.5-4B-4bit on MLX-phone: no small Qwen3.6 (min 27B), no Phi-5, no Llama-4-mini, Gemma-4-E4B loses text/reasoning double-digit, Ministral-3 MLX decode 10-20× slow, Kimi-Linear 48B too big, Nemotron-Nano-4B GGUF-only + trails MMLU.

---

## Corrections to ground truth (repo-relevant)

1. **iPhone Air = 12GB RAM** (AFM Core Advanced tier device), not 8GB. 7-13B-4bit is ecosystem-consensus feasible. Jetsam/wired discipline unchanged (NO new entitlement in iOS 27 — searched three ways).
2. **Our MTP fused lane is AHEAD of upstream** — llama.cpp naive MTP is a net loss; mlx-lm's native-MTP PR (#990, our same GDN snapshot-rollback) sits unmerged. We additionally ship adaptive-K + thermal tiering + EMA persistence, which no upstream has.
3. **"ANE = power not speed"** amended: at 10-min sustained load ANE RETAINS 67% vs GPU 38% — sustained-marathon lane is an open measurement (M4).
4. **Sycophancy routing reinforced**: 2606.06306 — sub-7B instruct tuning can make factual sycophancy WORSE than base; size is the structural axis. Our anti-syco-LoRA-net-negative result is now the literature's expected outcome.

## Sleep-consolidation recipe (what the granted-path dream-loop should DO)

Field-validated pipeline for our three-guard windows, all [SHIPPED-CODE/PAPER-MEASURED]:
1. **Observer→Reflector text consolidation** (Mastra OM: LongMemEval 94.87 @GPT-5-mini ceiling, 10× token cut, NO vector DB) — the 4B condenses/supersedes session logs in the idle window.
2. **Surprise/forgetting-curve replay selection** (SuRe/FOREVER) over memory atoms — pure selection logic, energy∝surprise-aligned, no training.
3. **Q4 KV persistence** (B5) — snapshot warm session caches to disk in the same window.
NOT in the window: weight edits (SEAL forgetting), TTT (latency), cartridge training (joint-training trap, 8B-only validated).

## Priority order (when the user opens the next campaign)

**B3 → B4 → M3 → B2 → M1 → M2 → B5 → B1 → M4 → M5** — cheapest-first within
avoided-compute before bandwidth before new-mechanism; B1 last only because iOS 27 is beta and
it compounds with whatever M1 decides.
