# THE PLAN — Mamba-3 standalone ANE decoder backbone (2026-06-15)

**Goal:** a capable, fast, low-power on-device decoder = **Mamba-3 (+ sliding-window attention) running standalone
on the A19 ANE**, as the main generation backbone (NOT a spec-decode draft).

## DONE — proven on-device this session (the engine is de-risked)
- Mamba-3 (SSD + data-dependent RoPE + MIMO) compiles + decodes on the A19 ANE: **int8 50.9 / int4 90–140 tok/s**,
  ~70–90 MB, the **angle-first state-order** fix (ssm-first SIGSEGVs).
- **Chunked-GEMM verify/prefill** mechanism: 2.2× (K=4) / 3.3× (K=8) cheaper than sequential, scales with K;
  decode↔chunk **mode-switch is free** (one asset, two functions, shared state).
- Architecture decided: **Mamba-3 backbone + SWA** (a few sliding-window-attention layers for recall; both halves
  fixed/bounded state → O(1)/token, constant memory, fits the cap).

## THE GAP = WEIGHTS (the #1 problem)
No trained Mamba-3 checkpoint exists (kernels-only release). Random weights = garbage. **Distillation fills this
gap** — it is the (off-device, one-time) step that gives the ANE backbone its brain. The distilled student IS the
Mamba-3 that runs on the ANE; distillation is not a separate model.

## PLAN (the steps)
1. **Decide teacher + student size** (the one open call):
   - Teacher — `Gemma-4-E4B` (strongest, multilingual/multimodal breadth; but 256K vocab → 2× lm-head → slower ANE
     student + harder novel-arch distill) **OR** `Llama-3.1-8B` (Llamba's proven MOHAWK teacher) / `Qwen2.5-7B`
     (128K–150K vocab → faster student, text-focused). Teaching runs on a training GPU — E4B's on-device jetsam is
     irrelevant for teaching.
   - Student — ANE-shaped **Mamba-3 (+SWA)**, ~1–3B, depth under the per-asset compile ceiling (1B/16L proven;
     3B needs a fit check), int4. Fastest first cut: **warm-start from Llamba-1B/3B** (Mamba-2 ⊂ Mamba-3).
2. **Distill (GPU, one-time):** warm-start init OR pure-logit / MOHAWK → trained Mamba-3 student weights.
3. **Convert int4 → CoreAI `.aimodel`** (engine proven; `Tools/mamba3_full_ane.py` recipe).
4. **Prefill:** chunked-conv bucketed (mechanism proven). The remaining hard technical piece = a TRUE parallel SSD
   chunked scan on ANE for long prompts (my chunked impl unrolls the scan → blows the compile ceiling at large
   blocks; recurrent-prefill is the slow fallback).
5. **Validate on A19:** quality vs teacher, decode + prefill tok/s, fit (< 3376 MB), long-session endurance.

## GATES / open decisions
- Teacher + student size (step 1) — the call that unblocks execution.
- Prefill parallel-scan on ANE (step 4) — the one unsolved technical piece (decode is the easy/proven half).
- Distillation quality (does the ANE-shaped student stay capable enough).

## NOT doing (closed)
- Spec-decode / Saguaro (Mamba-as-draft) — structurally dead on this SoC (ρ=0.83 overlap + recurrent rewind).
  The Asymmetric-Duo (Mamba-as-target) chunked-verify is banked as a *future* accelerator, but the standalone
  backbone is the priority and needs no draft.
- Running E4B directly on the A19 (jetsams at 4314 MB) — it is the TEACHER, not the deployed model.
