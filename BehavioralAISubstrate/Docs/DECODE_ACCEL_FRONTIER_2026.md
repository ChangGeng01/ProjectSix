# Decode-Acceleration Frontier (2026) — mapped to the A19 on-device batch-1 reality

> Web-grounded survey (2026-06-22), 7 technique families / 46 techniques, ranked by ability to break the
> **on-device A19/MLX batch-1 free-form ~38 tok/s wall WITHOUT quality loss**. Produced by the
> `decode-accel-frontier-research` workflow (7 parallel web-research lenses → synthesis). Companion to the
> decode-investigation ledger (`~/.claude/plans/sunny-yawning-dawn.md`, memory `draft-model-freeform-alpha`).

## The governing physics (read first)
On-device **batch-1** decode is **weight-bandwidth-bound**. A win must either **(a) read fewer bytes/token** or
**(b) emit more tokens/weight-sweep** — *and* avoid the Apple-GPU "extra tokens per forward aren't free" tax that
sank the 1B-draft (0.87×). Speculation's `(1+a·K)/(1+f·K)` is a **cost `f`** problem on Apple, not an acceptance
`a` problem. **Most datacenter "2–6×" numbers come from batched / idle-FLOP / offloaded regimes the A19 does not
have.** Every technique below is rated by *regime* (datacenter-batched vs gpu-single-stream vs on-device-capable).

The BAS ledger this maps against (already measured, on A19): 4-bit dense Llama-3.2-3B ≈ 38 tok/s = the floor;
ANE-overlap ρ=0.86 (dead); GPU 1B-draft free-form 0.87× (net loss); CoreAI/LiteRT kernels (slower / Gemma-locked);
affine-3bit + mixed_3_4 (quality rot); mxfp4 (lateral); KV-quant@2.1k (1.01× no-op); g128 (inconclusive);
Granite hybrid-Mamba + MoE (both slower on Apple-GPU batch-1). Shipped wins (repetitive-only): prompt-lookup 1.58×,
greedy spec-sibling 1.46×, cross-turn suffix 1.07–1.41×.

---

## ⚡ DEVICE-TESTED UPDATE (2026-06-22/23, A19) — both top recs RESOLVED, both negative
Verify-first (`BASBandwidthProbe`, BAS_BW_PROBE=1, pure-decode `rawTargetForwardsMs` on 4bit + 3bit) overturned the
optimistic framing below:
- **The "38 tok/s floor" was a chars/4 OVER-COUNT — exact 4-bit-3B decode = ~28 tok/s.**
- **Decode is BANDWIDTH-BOUND (assumption-free): 3bit 35.3 / 4bit 28.3 = 1.25× ≈ the 1.29× byte ratio**; achieved ~50 GB/s = ~72-75% of the 68.26 GB/s A19(Air) peak.
- **#1 fused Metal kernel ≈ DEAD (the "BUILD THIS" rec was WRONG).** MetalRT's 1.10-1.19× is M4 Max (546 GB/s, dispatch-bound). The A19's 68 GB/s bus is bandwidth-bound; the gap to *theoretical* peak is mostly unreachable memory-subsystem reality (bytes-scaling proves it), not recoverable dispatch overhead → kernel ceiling ~1.0-1.1×.
- **#2 quant: sub-4-bit is DEAD for a 3B (4/4 methods leak).** AWQ-3bit (body-3/embed-4) = best: ~1.25× faster, reasoning OK, but 1/6 system-prompt leak (3-bit body). DWQ-3bit (gradient distillation, strongest, distilled on AWQ) FAILED/REGRESSED (leak persists + 17-sheep flipped to 8). 4-bit (~28 tok/s) is the quality floor. Best available = **AWQ-3bit as an opt-in fast tier** (1.25×, documented 1/6 leak — a tradeoff, not lossless).
- **NOT universal:** the win is per-model + quality-fragile + size-dependent (3-bit rots a 3B; 7B+ absorbs it) and doesn't cover the default (Gemma-E4B).
- **FINAL:** no clean free-form speedup on the A19 Llama-3B — not drafters, not kernels, not quant. Past the bandwidth wall needs a bigger model (7B+) or different hardware.

---

## ① Most-promising wall-breakers (free-form, no quality loss) — ranked by EV
> ⚠️ Superseded by the DEVICE-TESTED UPDATE above — kept for the reasoning; #1 measured ~dead, #2 measured weakened.

### #1 — Fused Metal decode kernel (MetalRT-class) — **BUILD THIS**
Replace MLX's general op-graph with a fused 4-bit-dequant→matvec kernel + per-token dispatch reduction. **Does not
speculate** (`a`/`K`/`f` never enter) — just makes each existing token cheaper. The *only* lossless free-form win in
all 46 that touches neither the model nor the acceptance term. Published 1.10–1.19× on M4 Max; A19 unpublished but
**likely more headroom** (smaller, more dispatch-bound GPU). Expected **38 → ~42–45 tok/s**, byte-identical, never
<1×. Risk = engineering, not physics. Source: [MetalRT](https://www.runanywhere.ai/blog/metalrt-fastest-llm-decode-engine-apple-silicon).

### #2 — Quality-recovered 3-bit (DWQ / AWQ / SpinQuant) — **RE-MEASURE THIS**
3-bit = ~1.3× less bandwidth = faster on every token incl. free-form. The prior 3-bit DROP was a **quality** failure
(17-sheep flip, sys-prompt leak), *not* speed (naive 3-bit was already ~1.3× faster). DWQ distills quant scales vs
the fp16 teacher; AWQ protects ~1% salient channels; SpinQuant learns an outlier-redistributing rotation — all aimed
at *exactly* the gap that rotted 3-bit. Pure bandwidth (immune to the spec wall). Ceiling ~1.3× → **~47–49 tok/s**,
and **stacks multiplicatively with #1**. Open risk (measurable in an afternoon vs known rot-prompts): does scale-
distillation hold a *3B*'s reasoning? Sources: [MLX DWQ](https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/LEARNED_QUANTS.md),
[AWQ 2306.00978](https://arxiv.org/abs/2306.00978), [SpinQuant 2405.16406](https://arxiv.org/abs/2405.16406).

### #3 — Self-speculative layer-skip (CLaSp/SWIFT) — **cheap probe, bet against**
Model drafts by skipping its own layers (fewer layers = less bandwidth), verifies with the full stack — the only
spec variant where drafting *reduces* bandwidth instead of adding `f`. Lossless greedy. But a 4-bit 3B has little
layer-redundancy → expected **0.9–1.3×, likely below thermal noise** (g128's fate). Sources:
[SWIFT 2410.06916](https://arxiv.org/abs/2410.06916), CLaSp (ACL 2025).

### #4 — Shared-trunk MTP head (Gemma-4-style), chain-only — **device probe, sober ceiling**
A trained head predicts next-K from the same trunk hidden state, sharing KV → far lower `f` + high `a` than a
separate draft (the only spec member that improves both). BUT the Apple "2.2×" is **batch 4–8 on a 26B MoE**, not
batch-1 3B → realistic batch-1 free-form **~1.1–1.4×**; **Gemma-locked** (no Llama-3.2-3B MTP head exists); tree
attention is blocked by MLX KVCache (chain-only). Sources:
[Gemma-4 MTP](https://blog.google/innovation-and-ai/technology/developers-tools/multi-token-prediction-gemma-4/),
[DeepSeek-V3 MTP 2412.19437](https://arxiv.org/abs/2412.19437).

---

## ② Radical / 暴力 bets (model-axis)

| Bet | On-device verdict | Source |
|---|---|---|
| **Diffusion parallel decode** (LLaDA / Dream / Fast-dLLM / TiDAR / Block-Diffusion) | The only *structural* escape (many tokens/forward, no draft/`a`/`f`) — but every fast number rides **spare compute**; A19 is bandwidth-bound with **no idle FLOPs** → K parallel tokens ≈ K× weight reads. The one on-device proof (llada.cpp 3.9×) used a **Qualcomm INT8 NPU with idle TOPS**, 8B not 3B. **WATCH**; re-open only if a small instruct **block-diffusion** ckpt ships, and test as a structured/code lane, not free-form. | [TiDAR 2511.08923](https://arxiv.org/abs/2511.08923), [Fast-dLLM 2505.22618](https://arxiv.org/abs/2505.22618), [on-device LLaDA 2606.13740](https://arxiv.org/html/2606.13740v1) |
| **Native ternary (BitNet b1.58)** | Cleanest physics (~40% of the bytes, quality baked in by training → no PTQ rot; a native 1.58-bit 3B → ~80–90 tok/s). But **(a)** no Apple Metal/MLX ternary GEMV kernel (bitnet.cpp is CPU-only ~34 tok/s, *below* 38); **(b)** can't convert Llama-3B (from-scratch pretrain); **(c)** existing 2B4T < 4-bit-3B quality. **WATCH (new-model bet).** | [BitNet b1.58 2504.12285](https://arxiv.org/abs/2504.12285) |
| **Distilled constant-state linear** (Mamba-3 MIMO / Gated DeltaNet / Llamba) | Dodges the spec wall, but its KV-elimination advantage **only pays at long context**; at short free-form the untuned MLX scan kernel eats it (= the Granite-H-slower result). Mamba-3 MIMO raises arithmetic intensity → Granite-H slowness is *partly* kernel immaturity. **BUILD only on a committed linear pivot** (pairs with the Qwen3.5-GDN-teacher + Mamba-3-convertibility memories) + a hand-written MLX batch-1 kernel — and the win is long-context, not short free-form. | [Mamba-3 2603.15569](https://arxiv.org/abs/2603.15569), [Llamba/MOHAWK 2502.14458](https://arxiv.org/html/2502.14458v1), [RWKV-7 2503.14456](https://arxiv.org/pdf/2503.14456) |
| **2-bit VQ** (VPTQ / QTIP / QuIP#) | Regime is right (>80% bandwidth at batch-1) but doubly blocked: a 3B is too small to absorb 2-bit + no Metal trellis/VQ kernel exists (lookup overhead = the KV-quant 1.01× trap). **Skip for 3B; reach for it only at 7B+.** | [QTIP 2406.11235](https://arxiv.org/pdf/2406.11235) |

---

## ③ Pure datacenter hype — will NOT transfer to A19 batch-1
- **EAGLE-3 / HASS "3–6.5×"** → directly measured on Apple **1.05×** (M3 Ultra, 4-bit 8B); the tree is blocked by MLX KVCache. The Gate-2b 0.87× class. ([2503.01840](https://arxiv.org/pdf/2503.01840), [MLX discussion 890](https://github.com/ml-explore/mlx-lm/discussions/890))
- **Medusa/Hydra "2.2–3.6×"** → need cheap tree attention MLX lacks; default typical-acceptance is *lossy*.
- **Sequoia/SpecExec "4–6 tok/s"** → exist *only* under offload (PCIe/disk slack); A19 unified memory has none.
- **MLA / KIVI / KV-eviction "2.4–10.6×"** → cut **KV bandwidth only**, never **weight bandwidth (~85% at 2k ctx)** → hard ceiling **~1.07×** at short context (= why KV-quant@2.1k was 1.01×). KIVI's headline is "4× larger *batch*" (nonexistent at batch-1).
- **Diffusion datacenter** (Mercury 2 1009 tok/s, Gemini Diffusion 1479) → Blackwell + batched; transfers zero tok/s.
- **Lookahead / CLLM / Jacobi** → trade FLOPs for steps; free on idle-FLOP GPUs, a bandwidth wall on A19 (≤1×).
- **ANE decode (Orion)** → single-stream decode is dispatch-bound; ANE (170 tok/s) *loses to CPU* (283) on small models. Confirms ρ=0.86. ([Orion 2603.06728](https://arxiv.org/html/2603.06728v1))
- **FlashDecoding++ "4.86×"** → NVIDIA softmax-sync; real decode gain ~1.14×, already captured by a good Metal qmv (#1).

---

## ④ Single highest-EV next experiment for BAS
**Build a fused 4-bit dequant→matvec Metal decode kernel + per-token dispatch reduction (MetalRT-class), benchmarked
head-to-head vs the mlx-lm 4-bit Llama-3.2-3B floor on A19, free-form greedy.** It is the only lossless/free-form/
no-new-model win in all 46; physics is *for* it on A19; **never <1×**; and it's the multiplier base for the #2 quant
lever (a fused 3-bit qmv makes 3-bit *fast on Apple GPU*, which naive affine-3-bit was not).
- **Phase A (week 1):** fused 4-bit qmv; A19 free-form tok/s vs floor + **byte-identity assertion** + **thermal-controlled** runs (cooldown between measurements, report steady-state). Gate: **≥1.10× sustained, byte-identical**.
- **Phase B (if A passes):** re-run **DWQ/AWQ-3bit quality A/B vs the known rot prompts** (17-sheep, sys-prompt-leak) on the new fused-3bit kernel. Gate: **rot prompts pass + ≥1.25×**. If 3-bit still rots, keep the Phase-A win and stop.

**Bottom line:** exactly **one** ship-this-quarter lossless free-form win (a better Metal kernel, ~42–45 tok/s);
exactly **one** lever that stacks to ~47–49 (quality-recovered 3-bit, gated on whether scale-distillation holds a
3B). Everything promising 2–6× is either a different model (diffusion/BitNet/linear — real physics, but from-scratch
pretrain + a Metal kernel that doesn't exist + a quality step-down) or a regime A19 structurally lacks. The wall is
bandwidth; the only free way through is bytes-per-token, and the only free version of *that* is the kernel.

---

## Appendix — all 46 techniques (by family)
Columns: technique · year · regime · training · brute · maturity · on-A19 fit (abbrev). Full data: the
`decode-accel-frontier-research` workflow result.

### Speculative decoding
| Technique | Year | Regime | Maturity |
|---|---|---|---|
| EAGLE-3 (training-time test, multi-layer feature fusion) | 2025 | gpu-single-stream | production |
| HASS (Harmonized Self-Speculation) | 2025 | gpu-single-stream | paper+code |
| Medusa / Hydra (parallel draft heads) | 2024 | gpu-single-stream | paper+code |
| Tree / Sequoia / SpecExec (large draft trees, offload) | 2024 | gpu-single-stream | paper+code |
| Self-speculative / layer-skip (SWIFT, CLaSp, LayerSkip) | 2024-25 | gpu-single-stream | paper+code |
| SpecDecode-Bench reality check | 2026 | datacenter-batched | paper+code |

### MTP + parallel
| Technique | Year | Regime | Maturity |
|---|---|---|---|
| Native MTP head (DeepSeek-V3 / Gemma-4 MTP) | 2024-26 | on-device-capable | production |
| Lookahead decoding (Jacobi + n-gram) | 2024 | gpu-single-stream | paper+code |
| Consistency-LLM (CLLM) + Jacobi Forcing | 2024-26 | unknown | paper+code |
| Blockwise parallel / block verification | 2025-26 | datacenter-batched | paper-only |

### Diffusion / non-AR
| Technique | Year | Regime | Maturity |
|---|---|---|---|
| On-device masked-diffusion (llada.cpp / Mobile-NPU, Dream-7B) | 2026 | on-device-capable | paper+code |
| TiDAR (diffusion-draft + AR-verify, one forward) | 2025 | gpu-single-stream | paper+code |
| Block Diffusion (BD3-LM / Fast-dLLM v2) | 2025 | gpu-single-stream | paper+code |
| Fast-dLLM (training-free KV + confidence parallel unmask) | 2025 | datacenter-batched | paper+code |
| Mercury 2 / Gemini Diffusion (closed) | 2026 | datacenter-batched | production |
| DiffuCoder (Apple masked-diffusion code) | 2025 | unknown | paper+code |

### Aggressive quant
| Technique | Year | Regime | Maturity |
|---|---|---|---|
| MLX DWQ (distilled weight quant, 3/4-bit) | 2025-26 | on-device-capable | production |
| MLX AWQ (W4A16) | 2023/25 | on-device-capable | production |
| SpinQuant (learned rotations, W4A8KV4) | 2024 | on-device-capable | paper+code |
| BitNet b1.58 (native ternary, from-scratch) | 2024-25 | on-device-capable | production |
| VPTQ (vector PTQ, <2-bit) | 2024 | gpu-single-stream | paper+code |
| QTIP / QuIP# (trellis-coded 2-bit) | 2024 | gpu-single-stream | paper+code |

### KV / attention
| Technique | Year | Regime | Maturity |
|---|---|---|---|
| MLA (Multi-head Latent Attention) | 2024-25 | datacenter-batched | production |
| TransMLA (post-hoc GQA→MLA) | 2025 | datacenter-batched | paper+code |
| KIVI / KVQuant (2-bit KV) | 2024 | datacenter-batched | paper+code |
| CLA / cross-layer KV sharing (YOCO, LCKV) | 2024-25 | datacenter-batched | paper+code |
| KV eviction (SnapKV / H2O / StreamingLLM) | 2023-25 | gpu-single-stream | paper+code |

### Linear / sub-quadratic
| Technique | Year | Regime | Maturity |
|---|---|---|---|
| RWKV-7 "Goose" / G1 (native linear, no KV) | 2025 | on-device-capable | production |
| Llamba (Transformer→Mamba-2 distill, MOHAWK) | 2025 | datacenter-batched | paper+code |
| Mamba-3 (inference-first SSM, MIMO) | 2026 | gpu-single-stream | paper-only |
| Gated DeltaNet (DeltaProduct / Kimi-Linear) | 2025 | datacenter-batched | paper+code |
| Hybrid Mamba-2/Transformer (Bamba, Granite-4, Jamba) | 2024-25 | datacenter-batched | production |

### Kernel / systems / on-device
| Technique | Year | Regime | Maturity |
|---|---|---|---|
| MetalRT fused Metal decode engine | 2026 | on-device-capable | production |
| FLUTE (flexible LUT-quant GEMV, 3-4 bit) | 2024 | gpu-single-stream | paper+code |
| MTP draft-heads + verify_qmv small-M Metal kernel | 2026 | gpu-single-stream | paper+code |
| FlashDecoding++ (async-softmax + flat-GEMM) | 2024 | gpu-single-stream | paper+code |
| BitNet b1.58 + bitnet.cpp kernels | 2025 | on-device-capable | paper+code |
| ANE decode offload (Orion characterization) | 2026 | on-device-capable | paper+code |
