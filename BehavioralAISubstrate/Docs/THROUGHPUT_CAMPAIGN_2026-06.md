# Decode / serving throughput campaign — outcome + decisions (2026-06-30)

Outcome of verifying a 9-point decode/serving/RAG audit and measuring the real throughput levers for **fixed
Qwen3.5-4B-4bit, on-device, single-user (batch-1), Apple-only sovereign, iPhone-8GB**. Every description was
verified against the code; the priority order was re-derived from measurement.

## The decisive measurement (reframes everything)

Per-turn latency is **~15 s and GENERATION-dominated, not prefill.** Proof (`BASKVReprefillCostProbe`, discarded as
an instrument but this signal is valid): in a growing multi-turn conversation, turns that add only a *short* message
(KV reused) still take ~15 s each — identical to the big-context turn. If prefill drove latency the short turns
would be fast; they aren't. The ~15 s is the model **thinking** (~500 tokens).

**Consequence:** the audit's serving-layer levers (KV cache, batching, scheduler, routing) operate on a small
fraction of per-turn time. Throughput is bound by GENERATION cost, not serving overhead.

## Per-lever disposition (verified + measured)

| Lever (audit #) | Verdict | Gate | Ready-to-run plan |
|---|---|---|---|
| Serving plumbing — KV/batch/scheduler/route (#1-4) | **BOUNDED** | generation-dominance (measured) | not the throughput lever; skip unless TTFT on long convos becomes a product goal |
| Fewer tokens — think-budget | **WALLED** | no cheap difficulty signal (measured dead this session: thinking-gate arithmetic-only, surprise/length/confidence all failed) | needs a real question-difficulty oracle; unsolved |
| **Fused Metal decode kernel** | **THE clean lever (~15-20%, no quality cost)** | **红线 (decode kernels)** | requires an explicit red-line waiver; a byte-parity-safe design can be scoped on request (greedy-identical output guard + parity test vs the vendored path) BEFORE any edit |
| Mixed-precision quant | **MODEST + quality-risky + infra-blocked here** | no local fp16 ckpt (~8GB dl); speed needs A19 | recipe below |
| Cost/entropy decode gate (#1 real content) | **NEVER-WORSE SAFETY, not a throughput gain** | `_draftSpeculative` surfaces no accept stats (red-line-adjacent) + entropy premise CGR-yellow-flagged | measure entropy-separation first (free-form vs deterministic top-token bits); wire only if it separates |
| Intra-turn candidate batching (#2 residue) | **UNPROVEN on-device** | `generateCandidates` is serial (`QinaoLoop.swift:687`), but concurrent GPU calls may not parallelize (GPU-bound) | measure "does a TaskGroup / batched forward beat serial" before building |
| RAG reranker (#5) | **NOT A FIX — a feature** | only the identity stub exists; no learned/cross-encoder reranker (`BASVectorReranker.swift`, ADR-014 deliberate stub) | build a cross-encoder reranker (needs a model); dense-cosine rerank is redundant with vector topK |
| Remote adapter (#6), Apple FM provider (#7) | **MOOT** on a sovereign offline batch-1 project | — | see `CURRENCY_AUDIT_2026-06.md` |
| MPSGraph kernel (#8), CoreAI (#9) | **SKIP** | not the hot path / doNotMigrate | — |

## Ready-to-run: mixed-precision quant measure-first (when device + fp16 available)

Prior *naive* all-3-bit failed on quality (17-sheep reasoning flip + system-prompt leak) and thermal-inflated the
speed. Mixed-precision is the standard fix but shrinks the speed gain (only the layers dropped below 4-bit save
bandwidth → expect ~1.1-1.15× vs the current 4-bit, not the naive 1.3×).
1. Download an fp16/bf16 Qwen3.5-4B checkpoint (~8GB) — only 4-bit variants are local today.
2. `mlx_lm` (present in the finetune venv) mixed-precision quantize: sensitive layers (attn out / down_proj /
   first+last blocks) at 4-6 bit, the rest at 3-bit.
3. **Quality gate (Mac, device-independent):** re-run the prior failing cases (17-sheep reasoning, system-prompt
   leak) + a small correctness set. If quality drops like naive-3bit → quant lever is DEAD, stop.
4. **Speed gate (A19 only — Mac data is not representative):** tok/s vs the 4-bit baseline, watching thermal drift.
   Ship only if speed↑ AND quality held.

## Bottom line

**For this fixed-model, on-device, thinking-model config, throughput is largely maxed at the serving layer.** The
single biggest *clean* win is the fused decode kernel — and it is behind the project's own decode red-line. The
audit optimized the serving layer; the measured reality is throughput is generation-bound, so the real lever is
making each decoded token cheaper (a fused kernel — red-lined; or mixed-precision quant — modest + device-gated).
The honest recommendation if max throughput truly matters: reconsider the decode-kernel red-line **as a decision**,
with a byte-parity-safe design in front of you — not as a default. Nothing else on the list is a bigger, cleaner win.
