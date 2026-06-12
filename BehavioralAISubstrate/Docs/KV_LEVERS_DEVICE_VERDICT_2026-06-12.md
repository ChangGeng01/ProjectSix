# KV decode levers — device A/B verdict (2026-06-12, 10h dual-device run)

The kvBits / maxKVSize decode levers landed this session (b37e94606 / 02d8efc66) were device-A/B'd in
the 10h dual-device sweep (`Docs/cert-logs/dual-device-20260612-034321/`, device A = Llama-3.2-3B,
COOLDOWN_BASE=20). **Verdict: DECLINE both as defaults at the measured regime — a clean negative result
that redirects the decode-efficiency effort to greedy speculative decode.**

## The data (device A, Llama-3.2-3B, active 1723.7 MB all phases)

| Phase | Knob | avg est_tok/s | cache MB | decodes |
|---|---|---|---|---|
| A1 | baseline | **39.4** | 700 | 272 |
| A2 | `kvBits=4` | **36.6** (−7%) | 668 | 225 |
| A3 | `kvBits=8` | **36.4** (−7%) | 668 | 180 |
| A4 | `maxKVSize=512` | **39.3** (≈) | 765 | 228 |

(est_tok/s = the chars/4 heuristic the runner logs — directional across phases, not an absolute token
count; the FINAL p50/p99 lines were lost to per-phase relaunches, but every per-decode line survived
and feeds the averages. Device B Gemma-E2B jetsam-churned from B2 on → no usable Gemma KV data.)

## Reading

1. **`kvBits` 4/8 made decode ~7% SLOWER, not faster** (39.4 → 36.6/36.4), and cut cache only ~32 MB
   (700 → 668). At the measured short-context regime (decode cap ~256), the KV cache is small relative
   to the weights, so the KV-read bandwidth saved is marginal — while the per-step quantize/dequantize
   overhead on the KV cache is real. Net loss. **DECLINE as default** (亏的不要); it changes decode
   numerics anyway (non-byte-equal, ADR-014) so it was opt-in regardless.
2. **`maxKVSize=512` was throughput-neutral** (39.3 ≈ 39.4) and saved no memory here — expected: it
   bounds long-context KV memory (RotatingKVCache eviction), which is irrelevant at short context. Its
   real value is long-session memory bounding, NOT decode speed — **unproven at the regime that
   matters; no decode benefit measured.**
3. **The real decode win is NOT the KV levers.** This redirects Tranche B → the certified greedy
   speculative decode (+31%, Tranche A) is the actual lever; the KV levers are at best a long-context
   memory tool, not a decode accelerator.

## Re-open triggers (the levers aren't dead, just not default-worthy here)

- **`kvBits`**: a LONG-CONTEXT regime (multi-thousand-token decode) where the KV cache is large relative
  to weights — there the KV bandwidth saving could outweigh the quant overhead. Re-A/B at long context
  before any default thought.
- **`maxKVSize`**: a genuine long-session memory-ceiling need (KV growth threatens jetsam) — its value
  is memory, not speed; promote on a memory A/B, never a throughput one.

Both stay wired, default-nil (byte-equal), opt-in via `BAS_KV_BITS` / `BAS_MAX_KV_SIZE`. No default flip.
The session's KV-lever work is preserved as an opt-in long-context tool with an honest device verdict —
the negative result IS the output.
