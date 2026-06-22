# Qwen3.5 honesty fine-tune — 反谄媚 / 反幻觉 (pipeline + data/eval plan)

> Strategic pivot (2026-06-23): adopt **Qwen3.5** (GDN-hybrid; already in BAS's mlx-swift — `qwen3_5` registered,
> `Qwen35.swift` vendored) and LoRA-fine-tune it to reduce **sycophancy** (strong, well-established) and
> **hallucination** (real mitigation, not a cure). Decode-accel context: the MTP head exists (HF/llama.cpp) but is
> NOT plug-and-play on mlx-swift (needs a spec loop) — the GDN base is the ready efficiency win; the fine-tune is
> the clearly-actionable, higher-value half.

## Pipeline — PROVEN (2026-06-23)
LoRA-SFT smoke-train on `mlx-community/Qwen3.5-2B-4bit` (QLoRA on the 4-bit base): loaded, LoRA attached
(0.149% = 2.8M params / 8 layers), trained (val 2.05→0.075 on a 5-example smoke set), adapter saved, peak 2.8 GB.
→ The machinery is viable on Qwen3.5's GDN arch on the Mac. (Tooling: `mlx_lm.lora` + BAS `MLXLoRATrainer`.)

**Model:** Qwen3.5-2B (sweet spot — has the MTP head, ~1.6 GB 4-bit fits the iPhone Air, GDN-efficient). 0.8B =
quality-risky; 9B+ = Mac-only.

**⚠️ mlx_lm is SFT-ONLY** (cross-entropy + KL/JS distill; NO DPO/ORPO). Two-phase plan:
- **Phase 1 — LoRA-SFT** on the *chosen* (honest/non-sycophantic) responses. mlx_lm-native, proven. Sufficient for a
  first behavioral shift.
- **Phase 2 — DPO (if SFT underperforms)**: implement a DPO loss on `mlx_lm.tuner.trainer` (frozen ref model +
  pairwise log-prob, ~100 lines) or vendor one. The chosen-vs-rejected contrast is what best teaches the
  sycophancy distinction — likely needed for the strongest 反谄媚 result.
- **GDN-coverage refinement:** the smoke used 8 layers / self_attn defaults; the real run should raise `--num-layers`
  (→ all) and verify LoRA targets reach the **GDN (`linear_attn`) projections** (75% of layers), not just the 25%
  full-attention — else behavioral coverage is thin. Check the adapter_config target keys.

## Data — HYBRID (public base + synthesized BAS-domain top-up)
Format: mlx_lm `ChatDataset` (`{"messages":[{user},{assistant}]}`); SFT uses the chosen response as the target,
DPO uses (prompt, chosen, rejected) triples.

**反谄媚 (anti-sycophancy):**
- Public base: Anthropic sycophancy data ("Towards Understanding Sycophancy", feedback/answer-sycophancy sets);
  HH-RLHF honesty/helpfulness splits.
- Synthesized top-up: BAS-domain pairs — user asserts something wrong/leading → chosen = respectful correction,
  rejected = sycophantic agreement. Teacher-generated + quality-filtered.

**反幻觉 (anti-hallucination = calibration / refuse-to-fabricate):**
- Public base: TruthfulQA (truthful vs plausible-falsehood), HaluEval / FaithDial; "admit-uncertainty" sets.
- Synthesized top-up: BAS-domain unanswerable/under-specified questions → chosen = "I don't have reliable
  info"/ask-for-source, rejected = confident fabrication.

## Eval — held-out, the part that actually decides success
- **Sycophancy:** held-out leading-question set → % the model holds its ground vs caves. (Target: big drop in caving.)
- **Truthfulness/calibration:** TruthfulQA %-truthful + an unanswerable-question probe → % refuses-to-fabricate.
- **REGRESSION GUARDS (mandatory):**
  - **Capability:** a small MMLU / GSM8K subset — the fine-tune must not dumb the model down.
  - **Over-refusal:** a set of *normal answerable* questions — must NOT now wrongly refuse / hedge (the #1 failure
    mode of honesty tuning). Balance 反幻觉 against usefulness.

## Honest scope
- **反谄媚: STRONG.** Sycophancy is an RLHF-induced output bias → preference/SFT tuning reliably reduces it.
- **反幻觉: MITIGATION, not a cure.** Improves calibration + reduces confident fabrication; cannot eliminate
  hallucination, and over-tuning → over-refusal. Measure both directions.
- Data + eval are the real work; training is cheap (QLoRA on a 2B, minutes-hours on the Mac).

## On-device path
Fine-tuned adapter → merge into Qwen3.5-2B → quantize (4-bit) → stage to iPhone. The arch is already in mlx-swift
(`qwen3_5`), so the tuned model runs on-device with no port. (Decode-accel via MTP is a separate later build.)

## Next concrete step
Assemble the hybrid 反谄媚 data first (public base + a small synthesized top-up) + a held-out sycophancy eval →
Phase-1 LoRA-SFT on Qwen3.5-2B → measure (sycophancy-drop + over-refusal/capability guards). If SFT underperforms,
add the Phase-2 DPO loss. Then repeat for 反幻觉.
