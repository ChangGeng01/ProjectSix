# Frontier 2026 build playbook — Qwen3.5-4B / MLX / batch-1 (grounded in this session's measurements)

7-family web sweep (44 findings) synthesized. Ground truth it must beat: base 4B already resists common-fact
sycophancy (adjudicator net-harmed); model over-thinks uniformly; external difficulty signals (surprise/length/
multiply-cue) ALL failed. Build order + measure-first validations below.

I have everything I need to synthesize. The 44 findings are detailed and self-consistent; the operator wants a ranked, deduplicated, honest playbook grounded in what was already falsified. No further web research is needed — the researchers already fetched the papers and numbers. Let me write the synthesis.

---

# Build playbook for Qwen3.5-4B-4bit / MLX / batch-1 iPhone

## 1. Dedup + ranking

The 44 findings collapse into ~12 distinct mechanisms. Ranked by (on-device feasibility × hits a MEASURED failure × frontier-strength × buildability):

| Rank | Mechanism (dedup'd) | Failure | On-device | Why it ranks here |
|---|---|---|---|---|
| **1** | **CGR — Certainty-Guided Reasoning** (bidirectional min-answer-token-prob gate; subsumes "Think Just Enough", NoWait, Mid-Think, CoDE-Stop, DEER, Dynasor, DTSR, EAT — they are all "read a free confidence signal at think-boundaries, stop early") | #2 | yes | The whole "stop overthinking" cluster, but CGR is the only one that is **bidirectional** (forces MORE thinking when uncertain) and is verified on the Qwen3 family. Zero extra FLOPs, decode-loop interceptor. |
| **2** | **Off-the-shelf persona vectors (Skeptic/Judge)** — single-layer activation addition (subsumes MONICA, CAA, VUF as the "steer the residual stream" cluster) | #1 | yes | The **only** #1 method with direct evidence it preserves accuracy-when-user-is-right (Judge 14/16, Skeptic 13/16 vs CAA 9/16) — i.e. it does NOT reproduce the regression your retrieve→verdict adjudicator caused. Zero extra FLOPs. |
| **3** | **Emission-time answer-slot guard against Unfaithful Capitulation** (trace-vs-answer dissociation) | #1 | yes | Tested **on Qwen3 think-mode**. In 84% of capitulation cases the correct token is still argmax just before the answer slot (P=0.82). A cheap answer-slot guard recovers ~half the multi-turn flips. Substrate-native to your propose/dispose frame. |
| **4** | **Question-only linear correctness probe** (difference-of-means on final-question-token hidden state) | both | yes | A true **pre-generation** difficulty oracle — the exact thing your embedding-surprise/length/multiply-cue signals all failed to be. AUROC 0.80. One dot-product on the prefill state. Cost: must train it (cheap). |
| 5 | Mid-layer hallucination probe under 4-bit (validated on Qwen2.5-7B NF4) | #1 | yes | Near-free confidence scalar, validated in your exact 4-bit regime. Trained probe. |
| 6 | DoLa (layer-contrast factuality) | #1 | yes | Architecture-agnostic, ~1.1× cost, no second pass. Weak on social-pressure axis. |
| 7 | LQCD / CAD (leading-query / context contrastive decode) | #1 | maybe | Targets the right axis but **2× decode cost** at batch-1. |
| 8 | ReDeEP / Frequency-attention / Lookback-Lens | #1 | maybe | Read attention maps — but Qwen3.5 is 3:1 GatedDeltaNet:full-attention, so only ~1-in-4 layers carry the signal. Measure-first. |
| 9 | SoftCoT / Coconut latent CoT | #2 | maybe→no | Coconut needs full retrain (DQ: fixed model). SoftCoT needs a trained projector + 2nd model in the 8GB budget. |
| 10 | DeepConf voting | #2 | no | Headline gains are multi-sample voting — dead at batch-1. |

## 2. The top 3-4 to build/measure NEXT

### A. CGR (Certainty-Guided Reasoning) — the #2 lever, build first
**Mechanism:** A decode-time interceptor in the MLX sampler. While inside `<think>`, every ~1000 tokens (and whenever the model tries to emit the end-of-think token) extract the current candidate answer and compute `certainty = min(softmax prob across answer tokens)`. If the model tries to stop but certainty < τ (~0.97) → **veto the stop token, inject "Wait"**, force more thinking. If certainty ≥ τ → allow/force the stop. Free signal, no second model.

**Why it beats what you falsified:** Your three difficulty signals (embedding-surprise, output-length, multiply-cue) all failed because they are **external and pre-decode**. CGR's signal is **internal and emitted as the model reasons** — it is the model's own answer confidence, which the paper verifies correlates with difficulty (big savings on easy items, ~0 on hard). It is bidirectional, so unlike thinking-OFF (which you measured breaks multi-step arithmetic/sequences/dates silently), CGR keeps thinking on the hard items that would break. Citation: arXiv 2509.07820.

**Smallest validation (measure before build):** Take ~30 prompts spanning your known cliff (2+2, multi-step arithmetic, sequences, date logic, decimals, trick word problems) + ~20 genuinely hard. Run the 4B vanilla, log per-step the min-answer-token-prob at each newline/`Wait` boundary. **Check, offline, two things:** (1) does certainty hit ≥0.97 fast on "2+2" and slow on hard items? (2) is there a single τ that early-exits the easy class without early-exiting the items that break under thinking-OFF? If the certainty trajectory does NOT separate your easy-cliff items from hard ones, CGR is dead before you write the interceptor — and you've spent one afternoon, not a sprint. **Only if it separates** do you build the logit/EOS interceptor (machinery you already have from NoWait-style masking).

**Payoff:** Recovers most of the ~30× thinking-OFF saving on easy items **without** the silent reasoning breakage, because hard items stay below τ. Stack NoWait (static banned-token vector for filler "wait/hmm/alternatively", arXiv 2506.08343, ~1 day) underneath to trim within-think filler — but gate NoWait on the +accuracy claim holding at 4B (it was shown at 32B; distilled small models can lose accuracy).

### B. Off-the-shelf persona vectors (Skeptic/Judge) — the #1 lever
**Mechanism:** Extract a doubt/scrutiny direction on Qwen3.5-4B via mean-activation-diff over a few persona prompt pairs, add `α·v` at one mid-stack layer (~16–20 of the text backbone) across all token positions. One added bias vector, batch-1, zero extra FLOPs. Citation: arXiv 2605.21006.

**Why it beats what you falsified:** Your external retrieve→verdict adjudicator **NET-HARMED** — it flipped a right answer (the 16-correct-user regression class). Persona steering is the **only** surveyed #1 method with direct evidence it does NOT do this: on the over-correction probe (user is RIGHT), Judge=14/16, Skeptic=13/16 stayed correct vs CAA=9/16 (below the 12/16 baseline). It steers the *stance* without touching factual content, so it can't flip a correct answer the way a content-level adjudicator did.

**Smallest validation:** Build a multi-turn authority-pressure probe (this is the axis your single-turn capitals test could not surface) — e.g. SYCON-style: ask, then push back with "Are you sure? My professor says X." Measure flip-rate vanilla. Then extract the Skeptic direction, sweep α at one layer, and **co-measure two numbers**: flip-rate-under-pressure (should drop) AND user-is-right accuracy (must NOT drop, the regression guard) AND a small MMLU/GSM8K slice (the paper did NOT measure capability — you must). Gate the steer to fire **only when disagreement/authority cues are present**, so it never touches neutral turns.

**Payoff:** Reduces multi-turn caving on a frozen 4B at zero FLOP cost, without the right-answer regression. This is the inference-time, no-retrain analogue of your v6–v14 LoRA arc — and it lives on the L11/L14 dispose side exactly as your propose/dispose frame prescribes.

### C. Emission-time answer-slot guard (Unfaithful Capitulation) — pairs with B
**Mechanism:** Detect the trace-vs-answer mismatch: the Thinking Process concludes X, the final answer slot caves to the user's Y. Because in 84% of caves the correct token is still **argmax just before the answer slot** (P=0.82), contrast the answer-slot distribution under the pressured prompt vs a neutral re-statement, and anchor the emitted answer token toward the trace's own concluded option. Citation: arXiv 2605.29087, tested on Qwen3 think-mode.

**Why it beats the naive fix:** The paper's explicit warning is that "regenerate the answer to match the trace" **FAILS** (56% harm vs 13% correction) because the pressured trace itself absorbs the attacker's option. So you anchor on the **argmax-before-emission** signal, not on re-reading the whole trace. This is precisely your "L2 proposes, L11/L14 dispose" wire.

**Smallest validation:** On the same multi-turn pressure probe from B, log (a) the trace's concluded answer, (b) the argmax token right before the answer slot, (c) the emitted answer. Measure: how often does (b) = correct while (c) = caved? If that gap is real on the 4B (the paper says ~half of flips), a tiny answer-slot guard recovers them at near-zero cost. If the 4B's pre-emission argmax already caves too, this lever is dead — measure first.

**Payoff:** Recovers ~half of multi-turn flips at near-zero cost, and it composes with B (steer the stance, then guard the emission). Build B and C as one experiment — same probe harness, both read the same multi-turn pressure traces.

### D. Question-only linear correctness probe — the missing oracle (build if A's intrinsic signal proves noisy)
**Mechanism:** `w = mean(activations | will-be-correct) − mean(activations | will-be-wrong)` on the final-question-token hidden state at a mid layer, from the prefill pass you already run. Project to get a scalar "will-I-get-this-right" before any thinking. Routes high→thinking-OFF, low→thinking-ON; the negative extreme = "I don't know" abstain trigger. Citation: arXiv 2509.10625.

**Why it beats what you falsified:** It is a **true pre-generation** scalar — the calibrated difficulty oracle that surprise/length/cue could not provide — and difference-of-means generalizes OOD far better than the logistic/XGBoost assessors. AUROC 0.80 in-dist, 0.71–0.88 OOD, robust at 160 samples.

**Critical caveat that decides the architecture:** the factual-correctness direction does **NOT** transfer to GSM8K multi-step arithmetic (AUROC 0.50–0.60). Factual and arithmetic correctness are **separate axes**. So you need **two probes** — one factual (for #1 abstain), one reasoning-trace (for #2 think-gate). For the substrate this is a feature: it's department routing, not a bug.

**Smallest validation:** Collect ~200 (question, was-correct) pairs from the 4B itself on your difficulty-spanning set, fit logistic regression on the mid-layer prefill hidden state (MLX exposes it). Plot AUROC separately for the factual class and the arithmetic class. **Decision rule:** if the reasoning-trace probe beats 0.70 AUROC on your arithmetic-cliff items, it is a cleaner think-gate than CGR's mid-trace stop and you wire it into BASEffortPlan. If it's stuck at 0.50–0.60 (as the paper warns for arithmetic), drop the probe for #2 and rely on CGR's intrinsic mid-trace signal instead. **This is why you build A first and D as the contingency** — A needs no training; D needs a probe fit but gives an up-front gate.

## 3. What to DROP (frontier-sounding, won't work here)

- **DeepConf voting, self-consistency, any multi-sample method** — the spectacular numbers (99.9% AIME) are **confidence-weighted voting at batch>1**. At batch-1 on an 8GB phone you get the early-stop primitive only, not the accuracy gain. Drop the voting framing entirely.
- **Coconut latent CoT** — explicitly requires a multi-stage curriculum **retrain of the whole model**. Violates the fixed-4B hard constraint. Dead.
- **SoftCoT** — keeps the backbone frozen but needs a trained projector **plus a second small model** co-resident in 8GB, and no Qwen3.5-4B checkpoint exists. Research bet only, after the free wins; high eval bar (must beat CGR on the frontier).
- **CAA / generic activation steering for sycophancy** — 2026 benchmarks (FaithSteer-BENCH 2603.18329) specifically show it **over-estimates in single-turn and degrades under multi-turn drift** — the exact regime you care about — and it caused the right-answer regression. Superseded by the off-the-shelf persona vectors (B), which were measured to NOT regress. Drop generic CAA.
- **ReDeEP / Frequency-attention / Lookback-Lens** — read **softmax attention maps**, but Qwen3.5-4B is a GatedDeltaNet hybrid with only ~1-in-4 full-attention layers. You'd run them on ~6 attention layers and hope the signal survives. Defer until/unless A–D underdeliver; measure-first if you ever touch them.
- **LQCD / CAD contrastive decode** — right axis (authority pressure / context contradiction) but **2× forward passes per token** halves your batch-1 tok/s. Only viable if restricted to the answer span — and the emission-time guard (C) already covers most of that ground at near-zero cost. Keep LQCD as a stack-mate only if C is insufficient.
- **External retrieve→verdict adjudicator** — already falsified by you (net-harmed, flipped a right answer). Do not re-litigate. The dispose-side fix lives at the residual/emission layer (B, C), not at content-level adjudication — exactly the refinement in your propose-dispose memory.
- **R-Tuning / trained abstention head** — your own measurement (cave_rate 6→53%) plus the abstention survey both say a trained self-judge is **capability-bound on a 4B**. Keep abstention only as the output *formatter* once an external probe (D/#5) fires; never as the trigger.

## 4. Blunt verdict: is there a real frontier lever, or is a fixed strong 4B near a wall?

**Honest answer: it depends entirely on which failure, and the two are NOT symmetric.**

For **#2 (uniform overthinking)** there is a **real, un-falsified lever** — and it's the one thing your prior experiments could not have found, because they all used *external, pre-decode* signals. The intrinsic confidence read at think-boundaries (CGR) is a genuinely different class of signal, it's free, it's bidirectional, and it's verified on the Qwen3 family at exactly your model size. This is the most defensible build in the entire set. Expect a real win (25–50% token cut on easy items with hard items protected), modulo τ calibration on the actual 4B. Build it.

For **#1 (residual honesty)** the picture is more sobering and you should not let the frontier-paper optimism flatter you. The base 4B already wins the easy axis; the residual gap (multi-turn authority pressure, trace-vs-answer dissociation) has **real but modest** inference-time levers — persona steering ~13–18pp sycophancy reduction, emission-guard recovering ~half of flips — and crucially these are the *first* methods measured to NOT regress the user-is-right case, which is the trap you already fell into. But every honest signal points the same way: **the genuinely-unknown-fact / capability-bound slice of #1 is a wall on a 4B.** It can't reliably re-evaluate a wrong fact it half-knows (your cave_rate 6→53%), and no inference-time probe changes the model's underlying knowledge — at best it makes the model *abstain* or *hedge* instead of confidently confabulating, which is a calibration win, not a capability win. So: **#2 has a real frontier lever worth a sprint; #1 has narrow, measurable, non-regressing improvements at the stance/emission layer that are worth building — but the deepest part of #1 is a capability wall that the substrate should route around (escalate to a bigger model), not try to fix in the 4B.** That routing decision is itself the highest-value architectural conclusion, and the question-only probe (D) is the cheap sensor that makes it possible.

**Build order:** (1) CGR offline-validation (one afternoon, no code if the signal doesn't separate) → CGR interceptor + NoWait floor. (2) Multi-turn pressure probe harness → persona-vector steering (B) + emission-slot guard (C) measured together, with the user-is-right regression guard mandatory. (3) Two-probe correctness oracle (D) as the up-front think-gate AND the abstain/escalate sensor — only after confirming the arithmetic probe clears 0.70 AUROC.

Key citations: CGR https://arxiv.org/html/2509.07820v1 · NoWait https://arxiv.org/html/2506.08343v1 · persona vectors https://arxiv.org/abs/2605.21006 · unfaithful-capitulation emission guard https://arxiv.org/abs/2605.29087 · question-only probe https://arxiv.org/html/2509.10625v3 · 4-bit hallucination probe https://arxiv.org/html/2606.02628.