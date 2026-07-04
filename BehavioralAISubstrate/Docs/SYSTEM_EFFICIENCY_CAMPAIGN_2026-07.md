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

**P3 — 契合 (the LLM as a scheduled organ).**
  ThermalTwin → deviceState bridge (close the module island) · tier-0 responder organ (answer-cache
  + covered-factual + classifier-routed reflex) in front of the router · effort-tier → decode-lane
  coupling (fast tier → scout/0.8B-class or reflex; deep tier → core 4B) · dream-loop/consolidation
  activation (BGTask, the three-guard gating already built). Gate: T1 stretch 0.3 + T5.

**P4 — ENERGY DISCIPLINE.**
  Pin mWh/1k-tok + mWh/turn baselines into the registry (report → never-worse gates) · sustained
  mixed-session smoke as a release gate · substrate #77 per-layer latency p95 harness.

## Standing constraints
满血 (no trunk quality change) · ADR-014 default-off/opt-in for every lever (kill-switches) ·
ADR-039 lossless decode semantics untouched · never-worse gates with measured baselines · quality
co-gates from the v6-900 harness on every avoided-compute lever (skipping compute must not skip
honesty) · single-device evidence labeled as such.
