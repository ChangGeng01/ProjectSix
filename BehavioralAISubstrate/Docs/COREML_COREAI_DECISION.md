# CoreML vs Core AI — decision record (canonical pointer)

**Q: has CoreML been converted to Core AI? → No — deliberately. It is NOT an unfinished migration.**

The conclusion was scattered across `COREAI_RUNCERT_BACKLOG.md` + `CURRENCY_AUDIT_2026-06.md` (P4) +
`THROUGHPUT_CAMPAIGN_2026-06.md` (P9); this is the single canonical record. Do not re-litigate without new
evidence (see "When to revisit").

## Verdict

Production small models **stay on CoreML.** The CoreML→Core AI migration was **measured and rejected**
(`coreai-migration-gate recommendation=doNotMigrate`, GATE CLOSED 2026-06-11).

Evidence (T1.1 campaign, n=112 samples × 2 iPhone Airs, fully paired):
- **PARITY MET** — Core AI output equals CoreML: 112/112 agree, `max_mae = 0.000001`.
- **LATENCY LOSS** — Core AI `0.71 ms` vs CoreML `0.14 ms` (~5× slower, paired).
- **MEMORY LOSS** — Core AI ~2.6× heavier (standalone single-model runs).

⇒ Core AI is *correct* but ~5× slower + heavier on these small models. Converting would be a pure regression.
"New framework" ≠ "faster" — the canonical example in this repo.

## What actually runs on what (verified)

| Surface | State |
|---|---|
| **CoreML (production)** | `Sources/BASAppleAdapters/Resources/MiniLM.mlmodelc` (embedding) + PhaseB context-classifier `.mlpackage` (coremltools). Shipped. |
| **Core AI shipped assets** | **none** (no `.mlprogram` / CoreAI asset in the tree). |
| **Core AI code — kind 1: the cert instrument** | `BASCoreAIShadowComparison` — observe-only; records logits-MAE + latency to an immutable `BASShadowTrialFeedbackLedger`. This is the harness that *produced* the doNotMigrate evidence, not a production path. |
| **Core AI code — kind 2: unrelated research** | `BASCoreAIMamba3Session` / `BASCoreAIDecodeSession` / `BASCoreAIHybridDecodeSession` etc. — **Mamba-3 / Llama on-ANE LLM-decode** experiments (accelerating the big-model decode backbone). NOT a conversion of the small CoreML models. |

So the Core AI code in the repo is (1) the shadow-cert that rejected migration and (2) a separate LLM-decode
research thread — neither is "CoreML converted to Core AI."

## Separate question: can the MAIN model (Qwen3.5-4B) be converted to Core AI/ANE?

Asked 2026-06-30; distinct from the small-model question above. **Verdict: 能转,但不该转 — technically
FEASIBLE-WITH-WORK, but it's a speed *regression*, so no.** (Verified against the project's own CoreAI/Mamba
conversion work; a feasibility workflow cross-checked every claim + caught an invented latency number in its own
drafts.)

**CAN IT — feasible with net-new work + an OS-bug gate.** Qwen3.5-4B text backbone = 32 layers (24 GatedDeltaNet
+ 8 full-attn, `full_attention_interval:4`, hidden 2560). The GDN ops (`exp`/`softplus`/`sigmoid`/broadcast-mul/
`sum`/`where`/`stacked`, `GatedDelta.swift:172-267`) are a strict **subset of the already-proven Mamba-3 Core AI op
set** (`Tools/mamba3_to_coreai.py`); the 8 full-attn layers are Llama-style, already converted. No unsupported op.
Blockers, worst first:
- **⛔ rdar 177354777** — Apple's own seed doc: "linear-attention LLMs may crash," **explicitly names Qwen3.5/3.6**
  (`Docs/COREAI_IOS27_REFERENCE.md:195`). An OS-seed crash for exactly this architecture; you don't control it.
- 32 layers → **≥3 chained assets** (12+12+8; ANE per-asset ceiling 12, 16→SIGABRT). Existing split converter is
  homogeneous-Llama-only → needs a GDN+FA hybrid rewrite. No tool targets GDN today.
- **No fp16/bf16 checkpoint local** (only 4-bit) → ~8GB download + unvalidated dequant/re-quant (export needs
  unquantized source; int4/int8 mandatory under the ~2GB single-asset wall).
- `MLX.where` in the GDN state write re-hits the broadcasting_mul fidelity bug (guard known, must re-verify);
  large GDN state (64 value-heads × 128 × 192 ≈ 1.57M elem/layer × 24) is heavy to plumb across 3 assets.
- **Estimate: weeks, gated on an Apple OS bug.**

**SHOULD IT — NO, it's a speed regression.**
- ANE decode is **~3.7× slower than GPU** at this scale (measured: Core AI GPU-pipelined 181 tok/s vs ANE
  static-shape 49 tok/s, `COREAI_IOS27_REFERENCE.md:146`). ANE has no native matmul (Conv1×1, ~⅓ GEMM efficiency)
  → a **power** win, not a throughput win.
- The **doNotMigrate reasoning transfers and worsens**: the gate killed a byte-perfect small candidate for being
  4-6× slower + memory-heavy; a larger 4B on the same engine is strictly worse (bigger state, 3 assets, more host
  round-trips).
- **Fights two committed decisions**: 4B is Mac-only, 2B is the on-device Qwen line (`QWEN35_HONESTY_FINETUNE.md`);
  distill-necessity already ruled "ANE as the iPhone MAIN backbone = NO."
- **The one scenario it'd make sense**: NOT foreground decode — power-budgeted **background/concurrent drafting**
  (run on ANE to free the GPU / cut watts on a thermally-throttled iPhone Air in long sessions), accepting the
  ~3.7× lower tok/s. Energy-per-token is the only axis ANE beats GPU. Even then it's build-and-measure (rdar crash
  + ρ=0.83 ANE∥GPU bandwidth contention), not a slam dunk.

## When to revisit

Re-run the migration gate (not before) if any of: a materially faster Core AI runtime ships (new iOS SDK), the
small models are re-architected, or a new device class changes the latency/memory profile. Judge by the same
paired campaign (parity + latency + memory floors), not by "Core AI is newer."

## Cross-references
- Evidence: `Docs/COREAI_RUNCERT_BACKLOG.md` (the T1.1 campaign)
- Currency context: `Docs/CURRENCY_AUDIT_2026-06.md` (P4/P5)
- Throughput context: `Docs/THROUGHPUT_CAMPAIGN_2026-06.md` (P9)
