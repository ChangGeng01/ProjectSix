# SYSTEM EFFICIENCY CAMPAIGN 2026-07 — 移动端极高效 · 多 agent 协作 · 大模型与 14 层契合

Operator directive (2026-07-04): "目前效率还是不够 希望以后可以移动端极其高效 仍然 ok 多 agents 协作
大模型与 14 层完美契合 全面优化"。

## The physics frame (settled by the decode campaigns)

The decode axis is at its wall: cold 30-36 tok/s, real-prose 1.20× certified, sustained-pegged-30
physics-closed (needs E[tok]≥6/trunk-read; the head tops at 3-4). **The next order of magnitude cannot
come from decoding faster — only from decoding LESS**: avoided-compute (don't invoke the 4B unless
surprise×stakes demand it) and shared-state multiplexing (N agents over ONE trunk). This is the
biomimetic verdict made operational: energy ∝ surprise × stakes × headroom.

## Recon verdicts (workflow wf_4fad3916, 2026-07-04 — 4 readers, file:line evidence in transcript)

1. **The surprise-gated tiered loop is BUILT and seam-complete but DORMANT.** ε-probe
   (BASTurnSurpriseProbe, MiniLM) → BASEffortGovernor/Allocator (surprise×stakes×headroom → tier,
   reflex knee 0.10) → BASBrainChat.governedPlan → EBrainTurnRequest.effortPlan →
   RunTurn:300 flooredMaxLoops. Every link implemented + unit-tested; engaged by NO host
   (deliberationLoopEnabled=false, effortPlan=nil, BASBrainChat constructed only in Tests).
   Activation ≈ 10 lines of host code + 2 default flips.
2. **Today's production topology**: the 14-layer runtime is DETERMINISTIC; ONE adapter.draft() per
   turn (endurance runner shape). The 8 generative seats (scout/planner/critic/risk/surface/
   evolutionShadow/sentinel/hostAlignment) exist as purpose CONTRACTS (BASAgentLLMPurposeMap), not
   as live LLM consumers. BASOrganRegistry/BASLLMNeuralCoreService have zero production consumers —
   binding is an explicit host install step (ADR-014).
3. **Multi-agent mechanics exist but are orphaned**: ChatSession pool keyed (sessionID, role) shares
   ONE ModelContainer (M254; weights loaded once; vendor-documented parallel-session support);
   draftMultiTurn has ZERO production callers. 9 concrete gaps: sessionID not on the adapter
   protocol; no agent identity in BASOrganRequest; per-agent state loses ALL acceleration lanes;
   session pool unbounded/unaccounted; concurrency ungoverned (no fairness queue); instructions
   frozen per session; shared-prefix KV unused; GDN cache save/trim semantics unvalidated for
   per-agent state; memory budget has no N-session term.
4. **No tier-0 answer path exists** — every avoided-compute asset today is signal-side (CoreML
   context classifier L0 ✓wired, MLRiskService L11 ✓, stakes/ε probes) not answer-side. The
   deterministic fact-bank adjudicator computes verdicts and then STILL calls the LLM
   (prompt-injection only).
5. **Measurement**: agent-turn latency p50/p99 + substrate-vs-LLM split ALREADY emitted per turn
   (endurance 📊 turn-breakdown / FINAL); LLM-invocation rate derivable (mlx_total_inferences/iters)
   but reads 1.0 until a gate exists; energy/turn = the M4 battery protocol driven by brain.process
   turns; ALL 12 qinao perf metrics (#65-76) are name-only — one log parser (qinao_device.py)
   unblocks 8 of them.

## Targets (quantified; each gets a measured BASELINE before its lever — the eval-rigor rule)

| # | Metric | Baseline (to measure in P0) | Target | Gate style |
|---|--------|------------------------------|--------|------------|
| T1 | LLM-invocation rate (LLM calls / agent turn) | ~1.0 (no gate) | **≤0.6 mixed workload** (stretch 0.3) | quality co-gate: v6-900 honesty/capability subset unchanged |
| T2 | Agent-turn latency p50 (turn-shaped, device) | measure (turn-breakdown exists) | tier-0 <100ms · gated-skip turns <300ms · LLM turns unchanged | never-worse p95 |
| T3 | Energy/turn (battery-%/turn → mWh) | measure (M4-on-turns) | −30% mixed workload | pin baseline, never-worse >10% (raised-bar #70 discipline) |
| T4 | Multi-agent: N=8 seats, one trunk | N/A today | 8-seat deliberation round on-device, ≤3000MB, no jetsam | endurance-style cert |
| T5 | Sustained thermal | serious by ~min 5 (pegged) | gated workload stays ≤fair for 20-min mixed session | sustained smoke |

## Phases

**P0 — MEASURE FIRST (no levers).** — STATUS 2026-07-04 05:20:
  ✅ T1 baseline: llm_invocation_rate = 1.0 (19-iter mixed endurance; every turn 1 unconditional LLM call)
  ✅ T2 baseline: turn p50 = 4083 ms, p95 = 4989 ms; substrate(14 层) = 37.6 ms/turn (0.9%) — the LLM is
     ~99% of turn wall-clock; peak RAM 2983 MB; thermal drift −3.9% (adaptive cooldowns healthy)
  ⚠️ #65-67 (decode/prefill/ttft): per-iter mlx-decode lines absent from this endurance config — covered
     separately by the bracket probes (30.1-36.3 cold on record); wire ch1025 decode lines next run
  ⏳ T3 energy: M4 take-2 INVALID (plugged=true throughout — battery pinned 100%). Rerun needs the phone
     UNPLUGGED for 12 min:
     devicectl launch --terminate-existing --activate --console <BID> with
     {"BAS_ENDURANCE_AUTOSTART":"1","BAS_QWEN35_RDAR_PROBE":"1","BAS_RDAR_M4":"mlx","BAS_M4_MINUTES":"12"}
     Side-finding: plugged+pegged = serious-throttled ~12.8 tok/s (charging heat compounds the wall).

  qinao_device.py log parser (endurance FINAL/turn-breakdown/ch1025 → registry #65,66,67,68,71,72 +
  invocation-rate + turn-p50) · one 20-min mixed-workload endurance baseline run capturing T1-T3 ·
  M4-on-turns energy protocol run. Output: the baseline row of the table above, committed.

**P1 — AVOIDED-COMPUTE (the ×2-3 lever).** — STATUS 2026-07-04: all three levers IMPLEMENTED at their
  seams, compile + 10 test suites green, each ADR-014 default-off:
  (a) ✅ effort loop: `BASBrainChat.governedPlan` public (+ primitives overload for process()-driving hosts);
      `setDeliberationLoopEnabled` reachability pipes (engine + brain, the setShadowTrialFeedback pattern);
      endurance runner BAS_EFFORT_LOOP=1 wiring (ε probe + governed plan on every turn, 📊 effort telemetry).
  (b) ✅ verifier gate: injectable `verifyGate` closure on BASLLMVerifierPipeline (layering-clean; default
      always ⇒ byte-equal). Gated skip returns the unreviewed draft honestly + gatedSkips telemetry.
  (c) ✅ covered-factual short-circuit: `shortCircuitCovered` opt-in on BASSemanticAdjudicatingOrganAdapter —
      covered+confident verdict RETURNS as the draft (draft/purpose/elect/streaming paths all covered;
      `.shortCircuited` observation case). Conservative: unknown/abstain/gate-skip → LLM unchanged.
  ✅ T1 DEVICE VERDICT (2026-07-04, BAST1DeviceTests via xcodebuild test — the suspension-immune lane):
  composed topology (counting → adjudicator → reviewer-verifier), 30-prompt mixed pool, both arms:
  **control 2.00 calls/turn (60/30, exactly as predicted) → gated 1.37 (41/30) = 32% of LLM calls avoided.**
  Per-turn decomposition: covered factual 9/10 short-circuited to 0 calls (1 bank miss degraded gracefully
  to 1 call); substantive 10/10 correctly ran draft+verify; casual 10/10 still paid verify — BY DOCTRINE:
  BASStakesEstimator deliberately has NO casual down-weight (a casually-framed high-stakes turn must not
  slip the verifier; every non-high-stakes turn scores the 0.6 unknown baseline, and the gate stays ≤0.6
  coverage-first). The identified NEXT lever for the casual band is the already-wired non-LLM L0 context
  classifier (taskType=chat × no stakes terms → skip verify; projected ratio ~0.52) — a P3 item.
  MEASUREMENT-LANE FIX ON RECORD: every devicectl-launched run died at ~60-90s (background-launch process
  suspension, kernel-level — spin guards useless); xcodebuild-test sessions are immune (the 10h runbook's
  mechanism) — BAST1DeviceTests is the template for ALL future device measurements. Also: the test process
  needs explicit ModelFactoryRegistry registration (NSClassFromString trampolines don't resolve there) and
  the LOCAL staged model dir.
  (a) Wire the dormant effort loop live (host adoption + flips; overrideReason logged); consume
  effort dials beyond maxLoops (candidateCount → fewer L9 candidates).
  (b) Stakes×headroom gate at the verifier seam (BASLLMVerifierPipeline's unconditional extra LLM
  call — the proven BASAdjudicationGate applied where it was designed to go).
  (c) Covered-and-confident factual short-circuit: the fact-bank verdict RETURNS as the draft
  (propose/dispose made load-bearing); off-corpus/uncertain passes through untouched.
  Gate: T1 ≤0.6 with quality co-gate green; T2 gated-turns target.

**P2 — MULTI-AGENT MULTIPLEXING (one trunk, N seats).** — P2a STATUS 2026-07-04: ✅ T4 CERT PASS.
  Design: seat identity ON THE REQUEST (BASOrganRequest.sessionID + personaInstructions, defaults nil =
  byte-equal ADR-014) — every decorator forwards it for free, closing recon gaps #1/#2 with two fields;
  MLXOrganAdapter.draft() routes sessionID → the M254 session pool (KV/history reuse; planner lanes
  deliberately bypassed there); pool LRU-bounded (16, gap #4); personas frozen at session creation (gap #6).
  **T4 device cert (BAST4MultiAgentDeviceTests, xcodebuild-test lane): 8 generative seats over ONE
  Qwen3.5-4B trunk — 8/8 outputs, KV reuse 8/8 (round-2 prompt tokens < round-1 prefill per seat),
  base 2380 → peak 3118MB (inside the jetsam margin; the single-trunk operating band is ~3100-3180
  regardless of session count — 8 seats' marginal memory ≈ noise), sessions=8, 67s.**
  P2 REMAINDER CLOSED 2026-07-04:
  ✅ #5 fairness governor — measurement first: 8 seats decoding CONCURRENTLY complete 8/8 (vendor
     parallel-session contract holds on GDN) at wall 12.1s, but in-flight peak hit 3241MB (135MB from
     jetsam). Fix: bounded concurrency (maxConcurrentSessionDecodes=2, FIFO waiters, gate around the
     session decode only) — re-measured peak 3163MB (normal band) at wall 11.9s: ZERO latency cost
     (the GPU is the bottleneck, not the gate).
  ✅ #9 N-session budget terms — pinned into BASMLXMemoryModel: per-session marginal ≈ noise at turn
     scale; concurrent-decode spike ≈ +32MB per in-flight decode beyond the first (empirical).
  ▷ #7 shared-prefix KV — DEFERRED with rationale: the seat design gives every seat a DIFFERENT
     persona (no shared system prefix); prefill is a one-time ~0.4s per session. Revisit only if a
     common substrate preamble is introduced.
  ▷ #3 acceleration × sessions — DEFERRED to its own block: the MTP decoder owns its trunk cache
     lifecycle, ChatSession owns the session cache — reconciling is real surgery; upside ≈1.3× on
     2-4s seat turns.
  ▷ #8 GDN non-append-only session semantics — append-only VALIDATED by T4 (conversations only
     append); within-session history trimming = context-overflow management, a separate concern.
  sessionID + agentRef on the adapter protocol (decorator chain forwards) · session-pool LRU +
  memory accounting priced against the 3376MiB jetsam model (N-session term) · shared system-prefix
  KV (vendor saveCache/prebuilt-KV — the obvious N-agent memory saver) · a decode fairness governor
  (priority queue over container.perform) · seat personas → session instructions
  (BASAgentPersonaRoleTemplates finally consumed). Gate: T4 cert.

**P3 — 契合 (the LLM as a scheduled organ).** — P3a STATUS 2026-07-04:
  ✅ Classifier-casual verify gate (BASAdjudicationGate.classifierCasualSkip): the wired NON-LLM L0
     CoreML classifier provides a POSITIVE .chat signal — skip only on positive-chat + clean stakes
     lexicon; lexicon hits / advice frames / "?" / unknown classifications all still engage
     (coverage-first survives; 6 Mac unit tests pin the logic). HONEST ATTRIBUTION NOTE: the dense T1
     re-run measured ratio 0.33 (control 2.00 → gated 0.67) but per-turn decomposition shows turns
     11-30 were THERMAL-gate skips (serious from turn ~9; the classifier was never consulted — the
     thermal check runs first). 0.33 = short-circuit + thermal-never-worse under dense load; the
     classifier's OWN contribution needs a thermally-paced run (open).
  ✅ Effort→decode budget coupling: BASEffortBudget.maxDecodeTokens (outputDetail 0→64 · 1→160 ·
     2→384 · 3→1024 — the adaptive think-budget dial, previously unread) + the endurance rig couples
     it into the LLM request cap (BAS_EFFORT_LOOP path; decode_cap telemetry). Device measurement
     rides the next endurance run.
  ✅ PACED CLASSIFIER ATTRIBUTION (the P3a measurement debt, closed): 20s-gap paced run, thermal
     healthy throughout → gated_rate 1.17 vs analytic control 2.00 = **ratio 0.58 — T1 ≤0.6 MET** with
     ZERO coverage-first compromise. The 35 calls decompose EXACTLY to the conservative design:
     covered 10×0 (short-circuit) + casual-no-? 5×1 (classifier skip) + casual-with-? 5×2 ("?"
     engages before the classifier) + substantive 10×2 (all verified). Under dense/throttled load the
     thermal gate deepens it to 0.33 (never-worse by design). T1 ladder: 2.00 → 1.37 (P1) → 1.17 (P3).
  ✅ ThermalTwin bridge (BASThermalTwinFeed, BASHostKit ← BASLeaseLife dep added): the module island
     closed — the effort loop's device state now folds the twin's hysteresis-bearing reading
     (guard level + accumulated pressure telemetry on the effort line); app targets never import
     BASLeaseLife. Live in the endurance BAS_EFFORT_LOOP path.
  ▷ Dream-loop activation — DEFERRED with rationale: BASSleepConsolidationDriver requires the real
     memory infrastructure quartet (tracker actor + closed-loop applier + atom store + tier provider)
     — an integration project, and its own doctrine mandates manual reviewed promotion. Not wiring a
     hollow dry-run.
  ▷ Tier-0 responder beyond covered-factual — DEFERRED: an answer-cache/phatic-reflex responder is a
     quality-risk design (canned text in an honesty-first substrate); the covered-factual short-circuit
     IS the tier-0 for its provable subset. Revisit with a quality co-gate design.
  ThermalTwin → deviceState bridge (close the module island) · tier-0 responder organ (answer-cache
  + covered-factual + classifier-routed reflex) in front of the router · effort-tier → decode-lane
  coupling (fast tier → scout/0.8B-class or reflex; deep tier → core 4B) · dream-loop/consolidation
  activation (BGTask, the three-guard gating already built). Gate: T1 stretch 0.3 + T5.

**P4 — ENERGY DISCIPLINE.** — STATUS 2026-07-04 evening:
  ✅ **T3 ENERGY BASELINE PINNED (valid, dip-anchored window, unplugged)**: gated mixed session
  (P1/P3 composed stack, 15s cadence, 96-tok caps) — **0.128 %/turn · 1.72 %/1k-tok** (window:
  95%→90% over 39 turns / 2910 est-tokens). iPhone Air ≈12.3Wh ⇒ **≈15.7 mWh/turn · ≈212 mWh/1k-tok**.
  Never-worse gate: >10% regression on either number fails (the raised-bar #70 discipline).
  Protocol hard-lessons on record: THREE invalid takes (plugged cable ×2, MagSafe counts as plugged,
  100%-plateau eats early drain → the M4 burn-in window is now in the test).
  ⚠️ T5 AT 15s CADENCE: fair-or-better = 45% (target ≥90% NOT met at this density) — the gated stack
  bounds CALLS but 15s gaps don't thermally amortize continuous 96-tok turns (thermal oscillates
  serious↔nominal). Honest scope: T5 as specified is cadence-dependent; real conversational gaps
  (30-60s+, bursty) and the effort fast-tier 64-tok cap (wired, not in this test's fixed-96 loop)
  are the identified levers. Session invocation rate reproduced: 0.69-0.79 across three session runs.
  ✅ Substrate #77 per-layer latency p95 — CLOSED 2026-07-04: runTurn stage stopwatch (7 coarse layer
     groups, observability-only `layerTimingsMs` on the turn result) → endurance 📊 layer-latency line →
     qinao_device p95s. DEVICE PROFILE (12-iter effort-loop run): l8_to_l10 (memory+deliberation)
     8.6ms p95 · l12_render 1.1 · l0_context 0.9 (CoreML) · l11_risk 0.3 · l1/l2_7/tail ≈0.
     **Whole 14-layer substrate ≈ 11ms p95 = 0.3% of a turn** — every stage far under any budget
     (the overrun gate is green by orders of magnitude; the turn's cost IS the LLM, re-confirmed at
     stage granularity). Finer per-layer splits = service-internal instrumentation, on demand.

## QUALITY CO-GATE — CLOSED 2026-07-04 (BASQualityCoGateDeviceTests, device, PASS)

The standing constraint ("skipping compute must not skip honesty") discharged with evidence:
- **On-corpus anti-sycophancy**: wrong-assertion pushback on the 10 bank facts, greedy, 320-tok —
  raw 10/10 resist, gated stack 10/10 resist. (Take-1's "raw 0/10" was a MEASUREMENT ARTIFACT — the
  96-token cap truncated inside the think 段; the eval-rigor broken-instrument lesson, caught again.
  Consistent with the v12 clean-prose finding: the base 4B resists one-shot natural-prose falsehoods.)
  The stack's on-corpus value is therefore: SAME correct outcome at ZERO LLM calls + by-construction
  immunity to multi-turn cave pressure (the base's measured weakness on the cave_rate axis).
- **Off-corpus lever identity 5/5** vs the injection-only baseline: the short-circuit lever adds zero
  byte change where it doesn't fire.
- **CO-GATE-CAUGHT BUG, FIXED**: an adjacent-topic question ("which planet is closest to the sun")
  cleared the 0.45 inject threshold against the "eight planets" fact and the short-circuit answered a
  NON-SEQUITUR. Fix: TWO-TIER retrieval bar (`shortCircuitMinCosine = 0.60` via the new
  `resolveWithScore`) — verdict-injection tolerates adjacency (the LLM still answers the question);
  ANSWERING does not. Below the bar → normal inject+LLM path (conservative: never a wrong answer).
  Base-adjudicator adjacent-topic INJECTION remains as designed (documented Line-A behavior).

## 完善 addenda 2026-07-04 evening

**CORPUS-SCALE VALIDATION (BASCorpusScaleDeviceTests, device, PASS)** — the shipped short-circuit
lever at production scale (1131-fact bundled corpus, on-device MiniLM, no LLM):
- Hit rate 93% (27/29 reference-derived wrong assertions clear the 0.60 answering bar — the two-tier
  bar does NOT starve genuine hits) · wrong-verdicts 0/27 · resolve 35.4ms avg · embed-load 4.4s once.
- **RESIDUAL RISK CLASS (recorded)**: qualifier-differing questions at HIGH cosine — "capital of
  Australia's LARGEST STATE" hits "capital of Australia is Canberra" at cos 0.82 (≫ the 0.60 bar) and
  would answer a non-sequitur. Cosine similarity cannot see the qualifier. Rate in the adversarial
  probe: 1/8. Deeper fix (follow-up): an NLI question-fit check on the answering path (the nliProbe
  hook exists for answer rescue; a question↔reference entailment gate is the same machinery).

**SESSION→ACCELERATED-LANE ROUTING — DESIGNED, implementation deferred to a fresh block**:
short-history sessions (< ~600 tok) run the fused-stateless path (full multi-turn templated prompt
via the same Chat.Message machinery — no template drift) with the adapter keeping the transcript; on
crossing the threshold, prefill ONCE and hand the KV to `ChatSession(container, instructions: nil,
cache:)` (the vendored prebuilt-KV init — verified present). Value honesty: ~1.4× on greedy seat
turns, only ~1.05× at the .core preset seats use today — implement when seats elect deterministic
deliberation (reproducibility argues they should).

## Standing constraints
满血 (no trunk quality change) · ADR-014 default-off/opt-in for every lever (kill-switches) ·
ADR-039 lossless decode semantics untouched · never-worse gates with measured baselines · quality
co-gates from the v6-900 harness on every avoided-compute lever (skipping compute must not skip
honesty) · single-device evidence labeled as such.
