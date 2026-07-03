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


## Addendum 2026-07-02 — the two open measure-firsts are now CLOSED with numbers (+ P0/P1 audit adjudicated)

- **Intra-turn candidate batching: CLOSED — NOT worth building.** Measured on the production adapter
  (`BASServingResidueMeasureTests.testCandidateConcurrencyVsSerial`, BAS_CANDIDATE_CONCURRENCY=1, real 4B
  generations validity-guarded): serial 2-gen 32.6s vs `async let` 2-gen 30.0s → **1.09×**, matching metric #17's
  pre-registered ≈1.0. Mechanism: `MLXOrganAdapter` is an actor and MLX's ModelContainer serializes `perform` —
  GPU work serializes regardless of task concurrency. Instrument note: the first attempt read 3ms/gen — invalid;
  root cause `draft()` throws `nonTrimmableCache` on Qwen3.5-GDN (trim-checked verifyCache vs MambaCache) and
  `try?` swallowed it. The GDN-safe generation path is `streamDraft`/`draftMultiTurn`. The same phantom invalidated
  the KV probe's fresh arm (BASKVReprefillCostProbe — now corrected with guards).
- **Event-log appendMany: CLOSED — CORRECTLY-AS-IS.** Measured (`testEventLogAppendsPerTurnWhenOptedIn`): an
  opted-in stub turn appends **0 events** — `runTurn` never writes the event log; the only writers are opt-in
  orchestration bridges (trace bridge / mutation emitter) off the turn path. Default path is 0 by construction
  (memoryEventLog default-nil). Batched append only becomes relevant if a host wires a high-frequency bridge and
  measures >100ms/turn.
- **P0/P1 "backend not modern" 10-point audit (2026-07-02) adjudicated** — descriptions ~13/14 accurate; conclusions
  ~9/10 rejected for THIS substrate: datacenter-assumption imports (fan-out/continuous-batching/paged-KV/adaptive-
  scheduler/batched-tokenizer at batch-1), 红线-7/ADR-014 design guarantees misread as staleness (V1-byte-equal V2,
  deterministic scheduler constants, `.default()==.nativeV2` already documented at BASTurnRuntimeEngine.swift:427 +
  Configuration:270), and re-litigation of already-measured verdicts (CoreAI doNotMigrate ✓ correctly cited by the
  audit; MiniLM `.cpuOnly` is deliberate — ANE/GPU fp16 NaN). The two genuine residues are the closures above.
  Do not re-open these without NEW measurements.
- **Audit #4 (12-pt "unified modern stack", 2026-07-02) adjudicated: 0/11 actionable.** ~3 pts re-litigate this
  addendum (paged-KV/continuous-batching/unification at batch-1; SSMScan.metal probes whose own headers say "not to
  compete with vendor BLAS"; ModelExecutionProfile for a ~5-model batch-1 catalog); ~4 read the project's own
  honesty-notes back as findings (Package.swift scaffold block, registry "no V1 hot path consults yet", the
  documented quality-vs-throughput dual-endpoint election, the documented spec-re-prefill debt note); the rest were
  answered BEFORE the audit ran — esp. pt-11 memory-policy defaults: kvCacheBits/maxKVSize/enforceMemoryAdmission
  are documented ADR-014 output-changing opt-ins, and the on-device A/B ALREADY EXISTS
  (KV_LEVERS_DEVICE_VERDICT_2026-06-12: kvBits 4/8 = −7% tok/s for ~32 MB; maxKVSize neutral; admission gate =
  jetsam SAFETY not throughput). Optional hygiene noted: per-phase spans in TurnMetric; long-context kvBits re-run;
  E4B-factory admission default (host-policy). Same pin applies: no re-open without NEW measurements.

## ★ Addendum 2026-07-03 — the free-form wall HAS a lever after all: Qwen3.5's own MTP head (operator's catch)

The pin said "no re-open without NEW measurements" — this is that measurement. The operator asked "不是有 Qwen3.5
MTP 头吗?" and was RIGHT where four audits and the frontier sweep were wrong:
- **Qwen3.5-4B ships a 1-layer MTP (multi-token-prediction) head** (config `mtp_num_hidden_layers:1`; 15 tensors
  in the ORIGINAL Qwen repo — `mtp.fc` fusion + 1 gated-attention block + norms, shared embed/head). The
  mlx-community 4-bit conversion STRIPS it — which is why every MLX-stack measurement concluded "no cheap drafter
  exists". Fetched via per-tensor HTTP-Range (~240 MB, no 8 GB download): `Tools/qwen35_fetch_mtp.py`.
- **MEASURED acceptance (`Tools/qwen35_mtp_acceptance.py`, int8 shipped-form port, greedy self-trajectory):
  a = 0.674 over 95 steps — and 32/32 = 100% on the final natural-text stretch** (the low early region is the
  random golden prefix). Estimated speedup (K=1): (1+a)/(1+f) with f≈0.18-0.25 (MTP block ~0.11B + shared-head
  reuse vs the 4B trunk) → **~1.36-1.42× free-form, likely ~1.5×+ on natural text.**
- WHY the prior verdicts stay coherent: draft-MODEL spec was killed by COST (f≈0.33 for a 1B draft → 0.88× loss);
  MTP rewrites the cost term (f≈0.2) by reusing the trunk — the physics formula (1+a)/(1+f·K) was always the
  ruling, and MTP changes its inputs, not the law.
- Instrument archaeology (2 bugs caught by the discipline): first run read a=0.000 EXACTLY — not "low", broken:
  HF Qwen3-Next RMSNorms are ZERO-CENTERED (applied as 1+w; vLLM's fused kernel literally adds +1.0) while the
  mlx-baked main weights are plain — mixing conventions silently zeroed the head. Fix = (1+w) on all 7 MTP norms
  → 0.000 → 0.674.
- REMAINING to bank the win (not yet done): implement the MTP drafter in the live decode loop (MLX GPU lane
  and/or a 5th tiny CoreAI/ANE asset), measure END-TO-END wall-clock tok/s (the 1.42× is an estimate from a+f,
  not a measured wall-clock), and greedy byte-safety plumbing (same-vocab, argmax-verify — the existing spec
  machinery fits).

**Update 2026-07-03 — END-TO-END wall-clock MEASURED (`Tools/qwen35_mtp_wallclock.py`).** Built the real spec loop
on the verified int8 port: each iter = 1 MTP draft + ONE T=2 trunk forward with per-token GDN MID-state capture
(GDN can't rollback → on reject, adopt the mid state, no refeed). Result: **PLAIN 2.71 tok/s vs SPEC 4.38 tok/s =
1.61× wall-clock, live-loop a=0.82.** The estimate (1.42×) held — direction and magnitude both.
- MECHANISM (why CPU corroborates GPU): the T=2 batched forward is a GEMM that reads each weight matrix ONCE and
  reuses it for both rows → ~1 forward-cost for 2 tokens whether the bottleneck is CPU cache or GPU HBM bandwidth.
  Same weight-read-amortization that makes spec win on-device, so the CPU 1.61× is a real corroboration, not an
  artifact — but ABSOLUTE tok/s and the draft-cost ratio f still need the MLX-GPU lane (the CPU numbers are slow).
- HONEST CAVEATS (do not overclaim): (a) greedy-IDENTITY to the plain stream is by-construction (verify=argmax
  match) but NOT yet asserted equal token-for-token — a quick check is pending; (b) a=0.82 here is a short
  natural-text-dominated run (vs 0.674 over the 95-step cold-start); (c) production still needs the MLX-GPU lane +
  wiring into the vendored decode path — which is DECODE-RED-LINE-ADJACENT (byte-parity waiver territory), so it is
  a scoped decision, not a default. The lever is REAL and now wall-clock-corroborated; banking it on-device is the
  remaining (gated) step.

**Final update 2026-07-03 — PRODUCTION-PRECISION GPU number: 1.44× (84 → 120.6 tok/s). The lever is BANKED at the
bench level.** Full honest arc (`Tools/qwen35_mtp_gpu.py`, own mx port, correctness gate 5/5 = exact production
quantized math):
- CPU torch int8: 1.61× (mechanism proof; greedy-identity 40/40).
- GPU **fp16**: 0.86-0.91× LOSS — wrong precision + implementation artifact (isolated: T=2 trunk cost ×2.06 in the
  unfused fp16 path; head 2.8ms / MTP draft 3.4ms were cheap). Kept as the instrument lesson.
- GPU **4-bit (the ACTUAL main-model serving precision — operator's second catch: "主推是 Qwen3.5")**: plain 84.0
  tok/s → MTP-spec **120.6 tok/s = 1.44×**, live a=0.88, greedy-identity 64/64, matching the (1+a)/(1+f) estimate
  (1.42×). mx.quantized_matmul amortizes the T=2 step exactly as the bandwidth math predicts.
- STRATEGIC REFRAME (also the operator's point): the production Qwen3.5 lane has ZERO speculative decoding today
  (vendored spec fails closed on GDN `nonTrimmableCache`; the shipped 1.46× is the LLAMA lane). MTP is the ONLY
  spec candidate for the MAIN model — and it is now bench-proven at production precision with byte-safety.
- 5th CoreAI asset BUILT (`Tools/qwen35_mtp_to_coreai.py`): the MTP drafter as a 120.7MB int8 single-state
  `.aimodel` (zero-centered norms pre-folded; fidelity gate vs the torch reference passed) — ready for the ANE
  lane (draft cost there ≈ (MTP + head-GPU) vs ~100ms/token chain ⇒ est ~1.4×, unmeasured).
- REMAINING to ship: wire the K=1 MTP loop into the vendored Swift MLX path (2-token verify forward + GDN
  mid-state capture — the vendored spec machinery already does multi-token verify for Llama; the GDN mid-state
  needs the capture-not-rollback mechanism proven here). This is DECODE-RED-LINE territory: byte-parity waiver
  decision for the operator. The bench says the prize is ~1.4× on every free-form turn of the main model.

## ★★ Final 2026-07-03 — G3 DEVICE PASS: Qwen3.5-4B ≥20 tok/s on the iPhone Air (the operator's target, MET)

`BASQwen35MTPProbe` (BAS_QWEN35_MTP_PROBE=1), full inherited protocol (bracketed, cooldowns, identity+a gated):
- **plain-pre 19.3 → spec 22.4 → plain-post 19.3 tok/s** (drift band ±0%, thermal nominal throughout) = **1.16×,
  a=0.86, greedy-identity OK. VERDICT: 22.4 ≥ 20 → PASS.**
- THE point: the plain baseline (19.3) does NOT meet the 20 tok/s target — **the MTP lane is what puts the main
  model over the line**, exactly as the bandwidth archaeology predicted (plain ~20±, MTP = the amortization lever).
- Gate chain that got here: G1 Swift module fidelity 0.9931 → G2 Mac identity 48/48 (1.12×) → G3 device PASS.
  Zero vendored-kernel changes (3 additive accessors + a standalone opt-in decoder; snapshot-restore on MambaCache).
- HEADROOM (not yet taken): device ratio 1.16× vs the 1.44× 4-bit bench — the vendored T=2 forward path is the
  gap (same signature as the Mac-Swift 1.12×); a T=2 fast path could push ~27 tok/s. K=2 MTP is a further lever.
- WATCH: footprint 3268 MB with the fp16 MTP head — at the jetsam margin; int8-quantize the head (~-120 MB) before
  any default-ON cert. This G3 gate is NOT the ship cert (that needs the ≥50-prompt × 2-device × endurance protocol
  per SPEC_DECODE_CERT_RESULTS.md + the planner integration per MTP_LANDING_CHECKLIST.md §2).

## ★★ 30 tok/s campaign (2026-07-03) — 20 SMASHED (25.7), 30 NOT reachable by stacking spec (honest wall)

Pushed hard for 30 tok/s on the iPhone Air. Measured everything; the honest ceiling:
- **BEST (banked): K=1 MTP, 4-bit draft + carry-forward reject = 25.7 tok/s device** (plain-mean 20.3, bracketed,
  a=0.85, ADR-039 lossless). The T-cost isolation (Mac) reframed it: the vendored multi-token forward is ~FREE
  (T=1 14.9ms → T=4 16.6ms); the eater was the fp16 MTP draft (4.77ms/step) → 4-bit-quantized it + eliminated the
  reject refeed (carry-forward pending) → device 25.7.
- **K=2 chained MTP: DEVICE REGRESSION 23.6 < 25.7.** Chain acceptance is real (a1=0.944, a2|a1=1.00 on the
  golden self-trajectory ⇒ E[tok/iter]≈2.9), but on-device the per-iter cost (2 draft forwards + a T=3 verify +
  larger softmax) grew FASTER than the token yield (real-stream a=1.52 acc/iter ≈ 1.9 eff tok). Higher acceptance
  did NOT buy speed — the exact "acceptance≠speed" lesson from the 0.88× draft-model episode, re-confirmed.
- **compile(fixed-shape draft): REGRESSION** (Mac K=1 1.28→0.96×) — the full-buffer masked attention it needs for
  shape-stability is O(maxSeq) per draft, costing more than the graph-build it saves. Reverted.

**WHY 30 is a different problem, not more spec:** plain baseline ≈20 tok/s is the 4-bit bandwidth wall
(~2.3GB/step ÷ ~50GB/s). Realistic spec speedup on this trunk tops out ≈1.3× (K=1 measured; K=2 net-negative), so
spec alone ceils at ~26. To reach 30 the PLAIN baseline must rise to ~23-24 — that means **lifting bandwidth**, not
drafting: (a) mixed-precision quant (3.5-bit, sensitive layers protected — quality-gated, needs the fp16 ckpt +
device A/B; prior naive-3bit FAILED quality) or (b) the fused decode kernel (behind the decode red-line, operator
waiver). Both are baseline-lift decisions, not spec stacking. **25.7 × a ~1.15× baseline lift ≈ 30** — reachable,
but only by combining MTP with one baseline lever, which is the operator's next call.

## ★★★ 2026-07-03 — 30 tok/s MET: 30.1 on the iPhone Air, 满血 Qwen3.5-4B (1.48×)

`BASQwen35MTPProbe` bracketed protocol: **plain-pre 21.2 → spec 30.1 → plain-post 19.4 tok/s** (band ±9%, ratio
1.48× ≫ band), **a=0.85, serial-div@4 (ADR-039 lossless), thermal nominal, footprint 3023 MB.**

The final unlock (after compile-v2 and K=2 both REGRESSED on device and were reverted): re-deriving the iter
budget at DEVICE bandwidth exposed the real eater — **the draft's full-vocab head matmul (248K×2560 4-bit ≈
6.4 ms/draft at ~50 GB/s; only 0.94 ms on the Mac, which had masked it)**. Fixes, all QUALITY-NEUTRAL (满血):
1. **Draft SUB-HEAD**: drafts argmax over the FIRST 32K vocab rows (BPE id ≈ frequency order; 4-bit-quantized
   embed rows at init) → 6.4 → ~0.8 ms. A true-argmax outside 32K only makes that draft wrong → rejected →
   emissions remain FULL-vocab trunk argmaxes. Device acceptance UNCHANGED (a=0.85).
2. **GPU-resident single-sync iteration**: the draft token stays an MLXArray (embed lookup consumes the argmax
   array; verify input assembled by concatenation) — ONE gpu sync per iteration.
Journey: 20.3 plain → 22.4 (MTP v1) → 25.7 (4-bit draft + carry-forward reject) → **30.1** (sub-head +
single-sync). Trunk = production 4-bit checkpoint, untouched at every step; the quant lever (mixed-precision)
was DROPPED under the 满血 constraint and never used.

Caveats (unchanged class): 64-token arms, nominal-thermal cold protocol (sustained/thermal = ship-cert, not this
gate); maxSeq=192 campaign cap in the decoder (production needs a config); footprint 3023 MB (jetsam margin —
int8 the MTP block if more headroom needed); K=1 (K=2 measured net-negative on device, reverted).
