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

## Honesty bound (R1 / 亏的不要上)

n=1 device (iPhone Air, 8 GB), iOS 27.0 beta, Gemma-3n-E2B, **short prompts (~65 tok)**, decode cap 96, one
3-iter run. The decode-bound verdict is for THIS regime; a long-prompt/long-context workload could shift toward
prefill-bound (measure again before assuming). Cross-model tok/s (Qwen/Llama) not yet captured (those models
are opt-in/uncertified + need a first-launch download). No decode lever is built yet — that's the next
operator-steered fork, and any throughput claim will be on-device-certified, never inferred.
