# 3-bit weight quant — device A/B + quality verdict (2026-06-12, Tranche C)

Decode is bandwidth-bound qmv GEMV, so 3-bit reads ~25% fewer bytes/token than 4-bit. The local 3-bit
Llama-3.2-3B (`scripts/quantize-3bit.sh`, 1.3GB vs 1.8GB) was A/B'd paired-bracketed on device B
(`BAS_QUANT_AB=1`, single-model greedy, 6 mixed prompts).

## Speed: faster (direction clean, magnitude drift-confounded)

```
4bit-pre 3474ms → 3bit 2536ms → 4bit-post 5580ms   drift +60.6%  speedup(vs bracket)=1.79x
verdict=SPEED-INCONCLUSIVE-WITHIN-DRIFT
```
The +60.6% thermal slide inflates the raw ratio, but **3-bit (2536ms) beats even the COOLEST 4-bit
(pre 3474ms)** → 3-bit is genuinely faster (consistent with the cross-session smoke's ~+26% / active
1341MB vs 1724MB = −22% memory). Direction is clean; the exact magnitude needs a cold re-run.

## Quality: DEGRADES on reasoning + coherence — the gate FAILS for the core lane

Human side-by-side read of the 6 paired bodies:
| Q | type | 4-bit | 3-bit | 3-bit holds? |
|---|---|---|---|---|
| Q1 | factual (capital+landmarks) | correct | correct | ✅ |
| Q2 | explain (sky blue / Rayleigh) | correct | correct | ✅ |
| **Q3** | **reasoning trap ("all but 9 run away")** | **correct: 9** | **WRONG: 8, internally incoherent ("All of them"→"8")** | ❌ |
| Q4 | rhyming couplet | identical | identical | ✅ |
| **Q5** | summarize Romeo & Juliet | clean 3-sentence | **hallucinated system-context LEAK: "The Core tier of a behavioural AI substrate is engaged."** then summary | ❌ |
| Q6 | pros/cons remote work | fine | fine | ✅ |

**Two real degradations**: (Q3) 3-bit failed a reasoning puzzle 4-bit passed, with self-contradiction;
(Q5) 3-bit bled internal/system context into the output (a coherence break 4-bit never showed). Factual
+ generative held; **reasoning + coherence did not**.

## Verdict

**DECLINE 3-bit for the CORE / reasoning lane** — the speed/memory win does not survive the quality gate
(reasoning failure + context leak are exactly what a core lane must not do). 亏的不要: a faster model
that gets reasoning wrong is a net negative for core.

**Scout/fast-lane CANDIDATE (not promoted)**: factual Q1/Q2 held, so 3-bit MAY suit the scout/classify/
fast path (short factual, no deep reasoning) — but that needs its OWN eval (classification accuracy,
not these 6 prompts). Until then the `llama3_2_3B_3bit_local` catalog entry stays A/B-only / uncertified
/ not a default. The decode-elevation win that DID survive every gate is greedy speculative decoding
(A1, +34% device-confirmed, byte-identical) — that stands; 3-bit does not (for core).
