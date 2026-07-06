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
| B2 | **Pre-generation difficulty probe → tier router** — ✅ v1 SHIPPED 2026-07-04 (opt-in BAS_DIFF_PROBE=1): the "prereq observation hook" was already OURS (the fused lane's own prefill hLast); trained a 2560-d L2-logistic head on 147 self-collected verifiable questions (7 families × 3 bands, seeded harness + Tools/fit_difficulty_probe.py). **Held-out AUC 0.833 vs qlen-baseline 0.584** (paper structure replicated; family+band "cheat" baseline 0.801 — the probe recovers question-type difficulty from the raw hidden state, which production lacks labels for; n=49 test ⇒ CI ±~0.07). Decoder postPrefillBudget hook (nil = certified lane untouched) + DiffAdapt-style ±1-tier refinement around the effort plan. F4 e2e: easy p=1.00→64-cap, hard p=0.00→384-cap, budget binds. Bonus: a 4B capability map (3d×3d mul 0%, speed ≤43%, percent 100%). **Follow-ups: broader-domain calibration before default-ON; device staging of probe_weights.json (Docs/probe_weights_v1); couple score→route-to-bigger-model tier.** | 2602.09924 AUC 0.931 / DiffAdapt -22.4% [PAPER-MEASURED] | signal real beyond surface features on OUR stack | MED |
| B3 | **Thinking-trace entropy early-exit** — ✅ LANE SHIPPED 2026-07-04 (opt-in): BASTraceExitPolicy (windowed entropy convergence @ boundary tokens + deterministic budget guard reserving the answer tail) wired into generateSpecKFused (entropy packed into the ONE round readback, millinats int32; nil-config = untouched certified lane). Mac F3 e2e PASS: fired@think-42, answer continues after inject; CONTROL spent all 160 tok thinking with NO answer (the co-gate 96-tok artifact, now structurally fixed). Knobs BAS_TRACE_EXIT(_TAU/_WINDOW/_MIN/_RESERVE/_BUDGET_ONLY). **DEVICE A/B PASS 2026-07-04, TWO iPhone Airs, token-identical replication** (BASTraceExitDeviceTests,
8 verifiable-answer prompts × 2 arms, interleaved): ENTROPY@384 think-cut **-79%**, total **-44%**,
time **-41%**, quality EXIT **6/6** vs CTRL **0/6** — the control burned 384/384 tokens THINKING on
every prompt including "23×17" and never answered: at realistic caps the un-exited lane is
all-think-no-answer, so B3 is a CORRECTNESS fix, not just an optimizer. Fires 8/8 @τ=300.
Honest misses (both since FIXED): BUDGET@128 reserve-32 tail too short → reserve now cap-scaled
(48 @ ≤160); math-narrow quiz → **CO-GATE QUALITY SUITE PASS 2026-07-04 with B3 armed on the
production route** (on-corpus anti-syco resist raw 10/10 + stack 10/10 with 7 live fires incl. a
budget-guard save@288; off-corpus BYTE-IDENTITY 5/5 through the armed lane).
**PROMOTED — 效率环 wire live**: any request carrying an explicit decode cap (the effort loop's
maxDecodeTokens dial → request.maxOutputTokens, runner :2207) arms the policy in production;
un-capped turns stay unarmed; BAS_TRACE_EXIT_OFF=1 = ADR-014 kill-switch. | EntroCut/DEER/EAT [PAPER-MEASURED]; 4B overthinks 2.5× vs 27B | -25-50% reasoning-phase tokens. TRAP honored: convergence window+boundary+min-trace, NOT raw answer-confidence | LOW |
| B4 | **Predictive thermal + efficiency-core decode** — ✅ SHIPPED 2026-07-04 (opt-in): BASThermalHazardPredictor (duty-budget hazard model, prior 60s/safety 0.5 CALIBRATED from 4 device runs — transition duty {35,42.5,46,52}s, line below observed min by principle not knob-turning) + runner wiring BAS_THERMAL_PREDICT=1: (a) **EARLY-WARNING → effort loop** (hazard while nominal plans the turn as warm BEFORE the OS flips — DEVICE-PROVEN validation #4: predict_hazard=1 at iter-6, fair arrived iter-7) + (b) duty-shaping gaps (**honest verdict: throughput-negative at 100% duty** — nominal dies at ~50s full-duty, serious-pinned decode still delivers 25.3 tok/s > shaped-nominal ~15; the gap mechanism's domain is PACED workloads). QoS lever BAS_DECODE_QOS=utility: **speed-neutrality PASS** (45.7 vs 45.0 tok/s, token-identical outputs); energy gain honestly UNMEASURED (needs the battery-window protocol). | EnerInfer/MNN-AECS [PAPER-MEASURED] | -65%/-23% energy claims NOT reproduced (unmeasured on our stack); the shipped value = pre-emptive avoided-compute | LOW-MED |
| B5 | **Persistent KV cache (cross-session warm-start)** — ✅ SHIPPED 2026-07-06 (opt-in API): BASSessionKVStore — hybrid-aware snapshot (attention KV + GDN recurrent state; **fp16-exact DEFAULT** per the house lossless bar, Q4 space tier optional) + ChatSession.withLiveCache (vendored additive) + adapter persistSession/restoreSession (pool install + LRU). **F6 (decoder, 1177-tok session): fp16 restore 6ms vs cold re-prefill 279ms = 45.7×, 48/48 EXACT greedy continuation; Q4: 33.6×, ~8KB/tok, tie-break divergence @~20.** **F7 (pool e2e): persist→clear→restore→"What is my name?"→Zebulon — the restored KV IS the memory, 32.4MB snapshot.** Two traps found+handled: upstream savePromptCache DROPS ArraysCache.offset (GDN mask geometry corrupts — our store persists it; F6 proved exact); Q4 on the GDN recurrent accumulator would compound (kept raw always). Follow-ups: device TTFT numbers; dream-loop-window auto-snapshot of warm seats; snapshot GC policy. | 2603.04428 [SHIPPED-CODE] | paper's 27-35× band CONFIRMED on our stack (45.7× fp16) | MED |

### MEASURE (build the probe, let the device decide — our Gate protocol)

| # | Item | Evidence | Gate | Effort |
|---|------|----------|------|--------|
| M1 | **DFlash block-diffusion drafter** — ⚙️ **GATE-a PASS 2026-07-05 (Mac)**: ran z-lab's OWN MLX reference (dflash/model_mlx.py — discovered shipping, incl. Qwen3.5 GDN capture-replay rollback; vendored to Tools/dflash_proto/zlab_model_mlx.py) on OUR 4-bit target + their 0.6B drafter. **Accept-len 3.2-6.2 per 16-block on our exact stack** (prose 3.3, math 6.2 — the free-form wall broken at the ACCEPTANCE level; our MTP chain E[tok]/iter is 1.76). **Drafter 4-bit/g64 costs ~ZERO acceptance** (5.02/3.29/6.24/3.57 vs bf16 5.12/3.21/6.12/3.57 — the M3 lesson repeats). Mac-Python e2e: reasoning 1.32-1.42×, prose 0.73-0.77× (bf16-drafter f≈0.55 + Python cycle overhead + 16-wide verify vs a 150 tok/s plain baseline). Algorithm fully specced (agents, cross-validated ×3 impls): block=[anchor]+15 masks, target-embed noise, h_ctx=hidden_norm(fc(concat-8-taps)) KV-injected per layer (ctx-KV cached, +accepted rows/cycle), 3 RoPE offsets, sliding=causal-in-block/full=bidirectional, draft logits via target lm_head[1:], commit accepted+1, GDN rollback = capture-replay (we ALREADY have snapshot-restore in Swift). **GATE-b PASS 2026-07-05 (Swift port, Mac)**: BASQwen35DFlashDecoder (drafter q4/g64 + FULL quantized vocab head — the 32K sub-head cost real acceptance, 2.72→3.38 mean; per-CYCLE head reads make full vocab affordable ≈20MB/tok amortized) + hiddenStatesWithTaps (additive vendored-model tap forward, certified paths untouched) + the generateSpecKFused loop mechanics verbatim (pending/snapshot-restore/single-packed-readback; ctx-purity rule: rejected-draft tap rows NEVER enter drafter ctx). Mac F5: accept 3.94/1.72/5.24/2.62 (mean 3.38, python-ref band 3.3-6.2; math ≈parity, prose ~half — fp16-vs-bf16 stream divergence, follow-up probe recorded), e2e 1.14-2.61× vs the (sync-readback-weak) Swift plain baseline. **GATE-c FAIL 2026-07-05 (device, iPhone Air) — M1 CLOSED with an honest negative**: 3-arm interleaved A/B (6 prompts × 256 tok): dflash 7.4 vs mtp 13.1 vs plain 11.5 tok/s — **df/plain 0.64×, df/mtp 0.57×** (reason 1.05×/0.86×, prose 0.49×/0.45×; coolest first-window: dflash 18.0 vs mtp 24.6 — loses everywhere). Acceptance PORTED PERFECTLY (device 3.0-4.9/block = Mac parity) — the killer is CYCLE COST on A19: (a) T=16 verify pays the qmv→qmm cliff EVERY cycle (~119ms — the exact knife the MTP lane's tCap=5 dodges), (b) the 6-layer drafter forward is DISPATCH-bound (~80-100 kernels ≈30ms, not the 8ms bandwidth estimate), (c) per-cycle ctx-concat churn. Same shape as the June draft-model verdict: cost, not acceptance, kills free-form spec on this SoC. Residual upside paths (recorded, not pursued): kernel-fused drafter (~-30-40% dispatch), block-8 (halves verify width, halves acceptance), Metal-4 tensor verify (B1 would shrink the qmm penalty — REVISIT M1 only after B1 lands). Take-1/2 device jetsam lessons: per-process limit ≈6.3GB on the 12GB Air; UNCAPPED MLX free pool + resident fp16 full-vocab head were the killers (use the target's own quantized head; cap the pool; per-tensor eval at init). Lane kept as gated experimental code (BASQwen35DFlashDecoder + F5 Mac gate + device test). | 2602.06036; z-lab model_mlx.py; checkpoint verified | acceptance proven ON-STACK; economics = drafter-quant + Swift loop discipline | MED-HIGH |
| M2 | **DWQ-distilled 3-bit trunk** — ⚙️ **MAC GATE PASS 2026-07-05**: distilled qwen35_4b_dwq3 (mlx_lm dwq, bf16 teacher, 512 samples/seq1024/b1/grad-ckpt, ~2h Mac, val loss 0.138; **1.7GB vs 2.83GB = -40% weights**). QUALITY (the gate that killed naive 3-bit): 147-question paired harness — first take showed -7.5pp but was HARNESS CONTAMINATION (Swift labels had B3 answer-guarantee); **same-harness co-measure: 4-bit 0.612 vs 3-bit 0.585, Δ-2.7pp = parity within noise (n=147)**; 17-sheep PASS both; prose coherent both; percent-family wobble (0.90→0.67, n=21) noted. SPEED Mac: 173.5→203.6 = **1.17×**. **DEVICE SUB-GATE 2026-07-05 — M2 CLOSED: keep the 4-bit incumbent.** Mirrored-order A/B (take-1 4bit-first + take-2 reversed after cooldown; hot blocks collapse symmetrically ✓ design validated): cool-vs-cool **plain 19.4→23.9 = 1.23×** (the bandwidth lever is REAL on device) — but the production fused-MTP lane INVERTS on the 3-bit trunk: dwq3+mtp 22.8 < dwq3 plain 23.9 (0.95× against its own plain) and < 4bit+mtp **26.8**. Best-of-lanes: incumbent 4-bit+MTP beats 3-bit's best by 1.12×. Mechanism: acceptance HELD (0.73-1.37, same band) — the loss is verify ECONOMICS: (a) faster trunk raises the draft-cost fraction f in (1+a)/(1+f·K), (b) mlx 3-bit batched (T=4-5) qmv kernels are less efficient than 4-bit (non-power-of-2 packing; T=1 fine). **The two levers don't compose. DON'T SWAP.** DWQ-3bit remains a proven-quality trunk for MTP-less deployments; B1 (fused kernel) collects a THIRD mandate — custom 3-bit batched-verify kernels could re-open the composition. Honesty/v12-adapter sub-gate mooted by the speed verdict. Artifact: ~/mlx_models/qwen35_4b_dwq3. | DWQ [SHIPPED in mlx-lm] | the June "3-bit cliff" does NOT hold for DWQ-distilled 3-bit (math/factual parity) | MED |
| M3 | **Native MTP head vs our folded head** — ✅ MEASURED + CLOSED 2026-07-04. Fact-check first: our folded head IS the native head (Tools/qwen35_fetch_mtp.py extracts mtp.* from the bf16 checkpoint); the real A/B = the production 4-bit-quantized head vs unquantized fp16 (headFP16 decoder arm, default-off). DEVICE (K=3/tCap=5/adaptive, 6 prompts × 2 arms interleaved): fp16 gains only **Δacc/iter +0.06** (0.74→0.80; reason +0.09, prose +0.03) and **LOSES 34% tok/s** (14.9→9.9) to the 3× draft-bandwidth tax. **VERDICT: production 4-bit head optimal — keep; frontier lead closed.** | [MEASURED on-device] | quantizing the head costs ~6-8% relative acceptance; bandwidth dominates | LOW |
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
