# Gemma-4-E2B comprehensive on-device development (2026-06-15)

Operator-elected: develop Gemma-4-E2B as the main on-device model **at its real 42.6 tok/s decode** — NOT chase an
unreachable 100+ decode (a 2–3B model's decode is memory-bandwidth-bound on the A19; 100+ is the *prefill* number,
600+ tok/s). Gemma-4-E2B = **Gemma-3n-E2B** (the MatFormer/PLE "effective-2B" nano model; `mlx-community/gemma-4-e2b-it-4bit`).

## Measured on the A19 (iPhone Air, n=1, iOS-27 beta)
| metric | value |
|---|---|
| **decode** | **42.6 tok/s** (42.3–42.9 across 9 prompts; memory-bandwidth-bound = the honest ceiling) |
| **prefill** | **600+ tok/s** (short prompts; 170–617 by length) |
| **peak mem** | **2593 MB** under the 3376 MB jetsam cap (~365–783 MB headroom) |
| cold load | 67 s (first load) |
| wedge | mitigated stable 30/30, cache plateau ≈512 MB cacheLimit (ADR-038) |

## Where E2B sits — the strongest-fast-that-fits default (with an honest quality floor)
Three models fit the A19 cap: E2B, Llama-3.2-3B, Qwen2.5-3B.
- **SPEED:** E2B **42.6** > Llama-3.2-3B 38.3 > Qwen2.5-3B ~34–40. E2B is the fastest.
- **MEMORY:** E2B 2593 MB (comfortable headroom) < the 3Bs (run hot against the wall; the next rung **E4B JETSAMS at load** on this device class — which is *why* E2B is the survivor default).
- **QUALITY (the trade):** E2B is the **floor** — MMLU ~60.1 vs Llama ~63 (−3) vs Qwen2.5 ~65.6 (−5.5); trails on math/code. It's ~5B-raw / ~2B-**effective** (PLE offloads per-layer embeddings to CPU; E2B is a MatFormer slice of E4B) → behaves like a 2B-class dense net, "faster-but-weaker."
- **UNIQUE:** native **multimodal** (text/image/audio/video) + **140 languages** — the dense 3Bs have neither.

**Verdict:** E2B = the **speed / footprint / multimodal / multilingual** default. Qwen2.5-3B = the **quality-under-cap**
alternative (~10–20% slower decode). Llama-3.2-3B = the middle (true-3B quality + a curated draft pairing).

## Acceleration reality (the deciding asymmetry)
- **Greedy spec-decode: STRUCTURALLY UNAVAILABLE for E2B.** The catalog has no same-family Gemma smaller than E2B
  (`recommendedDraft(E2B)=nil`; E2B *is* the draft for E4B). The 2–3× draft-spec lane that accelerates Llama/Qwen/E4B
  can never apply here. 42.6 is the decode ceiling — do not promise more from a decode accelerator.
- **Prompt-lookup (model-free n-gram): the ONE decode lever — but PROBE-ONLY / UNWIRED in production today.**
  Measured ~**1.58× mean on repetitive** lanes (rag-quote 2.05×, json 1.58×, verify-claim 1.23×) → ~67 tok/s on those
  turns; **−8% on free-form** (must lane-gate OFF there — adaptive-K does NOT fix it; the cost is the propose() scan).
- **KV-quant @4-bit: SHIPPED-AND-WIRED but default-OFF.** Halves the KV cache (headroom for long sessions). NOT
  byte-equal (changes decode numerics) → needs a quality A/B before any default flip.

## Boundary table row
| model | params | quality | A19 fit | base decode | accelerated | prefill |
|---|---|---|---|---|---|---|
| **Gemma-4-E2B** (Gemma-3n-E2B, MLX 4-bit) | ~5B raw / ~2B eff (MatFormer+PLE) | MMLU ~60.1 (floor; <Llama 63, <Qwen 65.6); +native multimodal +140 lang | 2593 MB / 3376 cap (~365–783 MB headroom); load 67 s | **42.6 tok/s** (bandwidth-bound) | draft-spec ✗ (no draft); prompt-lookup repetitive ~1.58×→~67 (rag 2.05×→87, json→67, verify→52), free-form −8%; KV-q@4 halves KV | 600+ tok/s |

## Prioritized development TODO
1. **[P1 — highest value] Wire prompt-lookup into the production repetitive lane** (today PROBE-ONLY → zero production
   acceleration). The decoder/gate/EOS-superset already exist (`MLXOrganAdapter+PromptLookup.swift:111`); only the
   ROUTING is missing — a protocol-typed adapter can't reach the extension-only `respondPromptLookup`. Add an optional
   default-impl `respond(_:lane:)` to `BASOrganAdapter`; MLX override consults `shouldUsePromptLookup` and dispatches;
   `brain.process()` maps purpose→lane with `elect = BASDecodeLanePolicy.promptLookupEligible(for: purpose)` host-side
   (true only for .factual/.deterministic). Byte/token-identical under greedy, fail-closed. **Effort: medium (1–2 d).**
   Unlocks 42.6→~67 tok/s on rag/json/verify turns.
2. **[P2] Lane-gate strictly to repetitive purposes** (never free-form: −8%). Reuse `promptLookupEligible` (already
   returns false for .creative/.scoutDefault). Folded into P1. **亏的不要.**
3. **[P3] KV-quant default for long sessions** — run the on-device throughput+memory+**quality** A/B at BAS_KV_BITS=4;
   if quality holds, default `kvCacheBits:4` for long/endurance sessions. Code is wired; the cost is the A/B. **Low-med.**
4. **[P4] Harden the ADR-038 wedge mitigation as ship default + add a memory-pressure watchdog** (the 512 MB cacheLimit
   was mitigated, not root-fixed; ~365 MB worst-case headroom). **Low + med.**
5. **[P5] Streaming prompt-lookup variant** (the shipped one is non-streaming + drops per-turn metrics — a UX gap on the
   accelerated turns). Fast-follow. **Med-high (2–3 d).**
6. **[P6] Lock E2B as the device-gated default + honest model card** (E2B = speed/footprint/multimodal default, NOT
   quality leader; Qwen2.5-3B is the quality-under-cap alternative). **Low.**

## Honest bounds
n=1 device, iOS-27 beta (every number is one iPhone Air). NO draft-spec for E2B (structural, not a config gap).
Prompt-lookup helps ONLY repetitive output AND is unwired today — the 42.6→67 only materializes after P1. KV-quant is
not byte-equal (quality A/B pending). Quality MMLU figures are third-party aggregated (directionally robust: −3 vs
Llama, −5.5 vs Qwen). The wedge is mitigated, not root-fixed → ship E2B-only + watchdog.

## Ship recommendation
Ship E2B as the on-device default **conditionally + with the watchdog**, under the elected framing (real 42.6, no
100+ chase). Sequence: **(1) land the prompt-lookup wiring behind the repetitive gate [P1+P2 — the single
highest-value change]**, (2) KV-quant A/B → default for long sessions if quality holds, (3) fast-follow streaming
prompt-lookup. Do NOT default-on prompt-lookup for free-form. Position honestly in the model card; Qwen2.5-3B is the
documented quality alternative when the product needs top English reasoning/math/code under the cap.
