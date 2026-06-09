# MLX decode anatomy — measure-first (the efficiency gate)

> **Verdict: at the measured regime the turn is DECODE-BOUND.** Prefill is ~7-13% of MLX time; decode is
> ~88-93%, at a steady **~42.6 real tok/s**. So the efficiency lever is decode-side (faster/quantized model,
> KV-quant, speculative decode, or the decode-token cap) — NOT prefill (KV-reuse) at short-prompt scale. The
> chars/4 `est_tok_per_s` (47-59) **overstated** the real ~42.6 tok/s by 10-30% — measure-first caught it.

## Why this measurement

The decode is ~99% of a turn (M1.1), but we only logged a single `mlx_ms` + a chars/4 `est_tokens`, so the
prefill-vs-decode split was unknown and the throughput was an estimate. Phase-1 surfaced MLX's real
`GenerateCompletionInfo` (promptTime/generateTime + real token counts) through `BASOrganDraft.completionMetrics`
→ the runner's `📊 ch1025 mlx-decode` line. This is the gate for the decode-efficiency lever.

## On-device CAPTURED (2026-06-10, iPhone Air, iOS 27.0 beta, Gemma-3n-E2B, decode cap 96, short prompts ~65 tok)

```
mlx-decode iter=1 p=1 prefill_ms=184 decode_ms=2255 prompt_tokens=68 gen_tokens=96 prefill_tps=369.0 decode_tps=42.6
mlx-decode iter=1 p=2 prefill_ms=100 decode_ms=2252 prompt_tokens=59 gen_tokens=96 prefill_tps=590.7 decode_tps=42.6
mlx-decode iter=2 p=1 prefill_ms=102 decode_ms=709  prompt_tokens=63 gen_tokens=30 prefill_tps=619.3 decode_tps=42.3
mlx-decode iter=2 p=2 prefill_ms=154 decode_ms=2239 prompt_tokens=65 gen_tokens=96 prefill_tps=422.3 decode_tps=42.9
mlx-decode iter=3 p=1 prefill_ms=155 decode_ms=2237 prompt_tokens=65 gen_tokens=96 prefill_tps=419.0 decode_tps=42.9
mlx-decode iter=3 p=2 prefill_ms=155 decode_ms=2250 prompt_tokens=65 gen_tokens=96 prefill_tps=418.6 decode_tps=42.7
```

| metric | value |
|---|---|
| **real decode throughput** | **~42.6 tok/s** (42.3-42.9, extremely stable) |
| prefill | 100-184 ms; 369-619 tok/s (fast — prompts are short) |
| decode | ~2250 ms for 96 tokens; ~709 ms for 30 |
| **prefill share of MLX time** | **7-13%** (e.g. 184/(184+2255)=7.5%) |
| **decode share of MLX time** | **~88-93%** ⇒ DECODE-BOUND |
| chars/4 est_tok_per_s (the old log) | 43-59 — **overstated** the real ~42.6 by 10-30% |

## What this means for the lever (Phase-2 gate)

- **Decode-bound at the short-prompt regime** ⇒ the lever is decode-side:
  (a) **faster/quantized model** (Qwen/Llama/Gemma-E2B or a 3-bit quant — catalog already exposes
  alternatives; ~42.6 tok/s is the Gemma-3n-E2B baseline to beat);
  (b) **KV quantization** (`GenerateParameters.kvBits`, available in the vendor, unexposed in BAS);
  (c) **speculative decoding** (`SpeculativeTokenIterator` exists in the vendored MLX, unexposed — biggest
  potential ~2-3×, but a 2nd model's memory cost on 8 GB + heavy on-device cert);
  (d) the **decode-token cap** (WS2, already wired/tunable) — linear: at 42.6 tok/s, 96 tokens ≈ 2.25 s, so
  capping output directly cuts latency (at the cost of shorter answers).
- **Prefill (KV-reuse) is NOT the lever at this scale** — prefill is fast + a small share. It becomes relevant
  ONLY if prompts/context grow long (e.g. the fabric feed-forward enriched prompt, or long L8 retrieval
  context): at ~400-600 prefill tok/s, a ~2000-token context ≈ 3-5 s of prefill, which would then rival decode.
  So KV-reuse / prompt-shrink is a CONDITIONAL lever, gated on real prompt lengths — currently short.

## Cross-model decode tok/s (2026-06-10, iPhone Air, iOS 27 beta, same harness, decode cap 96)

The Phase-2 "faster model" lever measured BEFORE building anything — two passes: dense-3B "lateral" candidates,
then sub-2B "smaller" picks. The full tok/s ladder (4-bit, decode cap 96, short prompts):

| model | params | real decode tok/s | vs Gemma-3n-E2B | notes |
|---|---|---|---|---|
| **Llama-3.2-1B** | 1B | **~84.5** (84.1-84.8) | **1.98×** | the smaller-model win |
| **Qwen2.5-1.5B** | 1.5B | **~66.5** (66.2-66.8) | **1.56×** | — |
| **Gemma-3n-E2B** | ~2B-eff | **~42.6** | 1.0× (baseline) | current default; throughput-best ≥2B pick |
| Qwen2.5-3B | 3B | ~34.6 (34.2-34.7) | −19% | id + `<|im_end|>` confirmed on HW (incidental #2 cert) |
| Llama-3.2-3B | 3B | ~32.5 (32.3-32.7) | −24% | — |

**Finding 1 — the "faster model via Llama/Qwen-3B" lever is REFUTED:** both dense-3B alternatives decode
SLOWER than Gemma-3n-E2B (more parameters → more compute/token). Among ≥2B models, Gemma-3n-E2B is already the
throughput-best; Llama/Qwen-3B are stable-architecture fallbacks for the WEDGE class (ADR-038 §11.5), **not**
for speed.

**Finding 2 — the SMALLER-model lever is REAL + quantified:** decode tok/s scales ~inversely with parameter
count. **Llama-3.2-1B ≈ 2× the Gemma-3n-E2B baseline (84.5 vs 42.6); Qwen2.5-1.5B ≈ 1.56× (66.5).** The
tradeoff is QUALITY (a 1B/1.5B is weaker at reasoning) — so a smaller model fits **latency-sensitive
fast-path roles** (scout / classify / routing), keeping a ≥2B model for core reasoning. All decode-bound
(prefill ≤ ~13%; the smaller models prefill even faster, ~1000-1200 tok/s).

**Remaining levers (need building, not just measuring):** (a) **speculative decoding** (~2-3× WITHOUT a
quality drop — but a 2nd draft-model's memory on 8 GB + heavy vendored-MLX integration); (b) **KV
quantization** (`kvBits`, orthogonal — memory + modest speed). The decode-token cap (WS2) is a linear latency
lever already wired.

## Honesty bound (R1 / 亏的不要上)

n=1 device (iPhone Air, 8 GB), iOS 27.0 beta, **short prompts (~65 tok)**, decode cap 96, one 3-iter run per
model (5 models). The decode-bound verdict + tok/s ladder are for THIS regime; a long-prompt/long-context
workload could shift toward prefill-bound (measure again before assuming), and tok/s are throughput only —
QUALITY was not measured (a 1B is faster AND weaker; the smaller-model lever is a latency-vs-quality trade, not
a free win). The cross-model loads incidentally exercised the opt-in catalog ids on hardware (all 5 loaded
clean) but that is not an endurance/quality cert. No decode lever is wired yet — that's the next
operator-steered fork, and any throughput claim will be on-device-certified, never inferred.
