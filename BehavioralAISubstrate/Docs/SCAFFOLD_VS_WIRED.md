# Agent Fabric Arc — Scaffold vs Wired Inventory

**Authority**: ch 996 / M3685 — gap closure synthesis
**Source-of-truth**: this document supersedes per-chapter claims about
"genuinely wired" vs "scaffold" status for every public API shipped
in arc ch 953-995.9。

## Background — why this doc exists

Across 14 N-pass review rounds (956.11 → 995.9), the cascade caught
**same-class orphan / dead-code bugs for 6 consecutive rounds**
(R10-R15)。 The pattern:

1. New API shipped
2. Test verifies compile-time signature (API exists)
3. Test passes
4. N-pass review catches that API has NO internal consumer — only the
   test reads it
5. Fix-of-fix attempt adds another layer
6. Next round catches the same class one layer deeper

The pattern proves the substrate has **structural pressure toward
"looks complete but does nothing" APIs**。 This document is the
explicit honest inventory:every public API shipped in the arc,
classified by whether it has internal substrate consumers vs is
host-observable scaffold。

## Status legend

- ✅ **WIRED** — has 2+ internal `Sources/` consumers that BRANCH on
  the value。 Removing the API would break dispatch/merge/apply/
  graph paths。
- 🪜 **SCAFFOLD** — substrate STORES + SURFACES the value but does
  NOT branch on it。 The API is a host-observable signal for SDK
  consumers (host apps) to read + branch on themselves。 Removing
  the API would not change substrate behavior。
- 💀 **DEAD** — emitted/set by no source path AND read by no source
  path。 Reserved for future use OR genuine cruft to be removed in
  a future arc。

Audit method: `grep -rn "<API>" Sources/` followed by manual review
of each hit to distinguish declaration / writer / reader / branch site。
Run at ch 996 close on HEAD `e7b918f3e`+。

## Inventory

### Core dispatcher API (Phase 0-2, ch 953-962)

All WIRED — the dispatcher consumes every field of these types
internally at apply / merge / emit time。

| API | Status | Notes |
|---|---|---|
| `BASAgentSpec` | ✅ WIRED | agentMap lookup + writeDomains gate |
| `BASAgentDelta` | ✅ WIRED | every field consumed at apply |
| `BASAgentTurnInput` | ✅ WIRED | every field threaded to a seat |
| `BASAgentTurnRoster` | ✅ WIRED | per-slot guard at dispatch |
| `BASAgentMergeResult` | ✅ WIRED | applier loops over accepted |
| `BASSharedStateGraph` | ✅ WIRED | core write path |
| `BASAgentTraceEvent` | ✅ WIRED | logged + flushed |
| `BASAgentObservation` | ✅ WIRED (ch 1006) | Pre-ch-1006 doctrine claim「L14 audit reads」was inaccurate — grep proved NO substrate consumer。 Now `BASAgentObservationAuditEmitter.{signalRefs, observationFromAnnotator}` provides canonical producer + serializer for the L14 audit ledger。 Closes a mislabeled-DEAD-as-SCAFFOLD gap。 |

### Seat input/output DTOs (Phase 1-3, ch 957-965)

All WIRED — each seat's input/output is consumed by its emit fn。

| Seat input | Status |
|---|---|
| `BASScoutInput` | ✅ WIRED |
| `BASPlannerCandidate` | ✅ WIRED |
| `BASRiskInput` | ✅ WIRED |
| `BASSurfaceInput` | ✅ WIRED |
| `BASMemorySeatInput` | ✅ WIRED |
| `BASCriticSeatInput` | ✅ WIRED |
| `BASHostAlignmentInput` | ✅ WIRED |
| `BASSovereignSentinelInput` | ✅ WIRED |
| `BASEvolutionShadowInput` | ✅ WIRED |

### Cross-module integration adapters (ch 983-994.7)

| API | Status | Sources/ branch sites |
|---|---|---|
| `BASAgentFabricAdapters.scoutInput(...)` | ✅ WIRED | turnInput consumer |
| `BASAgentFabricAdapters.plannerCandidates(...)` | ✅ WIRED | turnInput consumer |
| `BASAgentFabricAdapters.riskInput(...)` | ✅ WIRED | turnInput default-path consumer |
| `BASAgentFabricAdapters.surfaceInputObservationMode(...)` | ✅ WIRED | turnInput consumer |
| `BASAgentFabricAdapters.criticInput(...)` | ✅ WIRED | host pipeline calls |
| `BASAgentFabricAdapters.turnInput(...)` | ✅ WIRED | coordinator consumer |
| `BASAgentFabricAdapters.hostAlignmentInput(from:...)` | ✅ WIRED | pipeline → coordinator |
| `BASAgentFabricAdapters.enrichRiskInput(from:...)` | ✅ WIRED | full-turn adapter consumes |
| `BASAgentFabricAdapters.enrichCriticInput(from:...)` | ✅ WIRED | full-turn adapter consumes |
| `BASAgentFabricAdapters.candidateFrontierProjection(...)` | ✅ WIRED | full-turn adapter consumes |
| `BASAgentFabricAdapters.validateMCPInvocation(_:against:)` | ✅ WIRED (ch 1003) | `BASMCPInvocationAuditBridge.validateAndAppend(...)` is the canonical consumer — pipes the gate's auditRefs into the L14 ledger for both granted + rejected outcomes。 Pre-ch-1003 was tests-only。 |
| `BASSovereignWarrantAuditBridge.buildEntry(...)` | ✅ WIRED | appendToLedger consumer |
| `BASSovereignWarrantAuditBridge.appendToLedger(...)` | ✅ WIRED | pipeline consumer |
| `BASAgentTraceLogEventLogBridge.recordEvent(...)` | ✅ WIRED (ch 1004) | Per-event API now has a streaming consumer contract: `BASAgentTraceStreamingSink` protocol + `BASAgentTraceBufferingSink` reference impl + `recordEvent(_:streamingTo:)` overload。 Both flush (batch) + per-event-streaming remain first-class — hosts pick per architecture。 |
| `BASAgentTraceLogEventLogBridge.flush(forTurn:)` | ✅ WIRED | full-turn adapter consumer |
| `BASAgentTraceLogEventLogBridge.synthesizeEventLogEntry(...)` | ✅ WIRED | flush + recordEvent both consume |

### Host integration (ch 993-995.9)

| API | Status | Notes |
|---|---|---|
| `BASAgentFabricFullTurnAdapter.run(...)` | ✅ WIRED | host pipeline consumer + tests |
| `BASAgentFabricLiveInputs` | ✅ WIRED | all 12 fields flow to dispatcher chain |
| `BASAgentFabricFullTurnResult` | ✅ WIRED | pipeline reads .turnResult / .warrantAuditEntry / etc |
| `BASAgentFabricHostPipeline.runTurn(...)` | ✅ WIRED | DeviceTestApp + tests |
| `BASAgentFabricHostOutcome` | ✅ WIRED (ch 1014) | `BASAgentFabricHostOutcomeInspector.{summarize, category, isCleanRun}` provides canonical substrate-side consumer。 Pipeline now emits `diagnostics["inspector.category"]` per turn — the substrate is both PRODUCER and CONSUMER of the typed signal。 |
| `BASAgentFabricHostOutcome.activation` | ✅ WIRED (ch 1014) | Read by `BASAgentFabricHostOutcomeInspector.summarize(...)` (tier extracted into Summary.tier field) |
| `BASAgentFabricHostOutcome.fabricMode` | ✅ WIRED (ch 1014) | Read by `BASAgentFabricHostOutcomeInspector.category(...)` (nil mode → `fabric.run.unconfigured`) |

### Mode + gate scaffolds (ch 993-994)

| API | Status | Notes |
|---|---|---|
| `BASAgentFabricMode` enum | ✅ WIRED (ch 1007) | Substrate-side observer ships via `BASAgentFabricModeAuditEmitter`。 Mode flag now leaves a substrate-observable audit-ledger artifact per turn。 Substrate BEHAVIOR remains unchanged per ch 994 — the wire is observer-only。 |
| `BASAgentFabricMode.observationOnly` | ✅ WIRED (ch 1007) | Audited per turn with `observationOnly` verdictRef |
| `BASAgentFabricMode.authoritative` | ✅ WIRED (ch 1007) | Audited per turn with `authoritative` verdictRef — substrate's dispatcher / merge / apply output remains byte-equal between modes,but replay tooling can now distinguish。 Phase 9+ work flips actual coordinator branching;ch 1007 wires the observability。 |
| `BASAgentFabricGate.activationFromEnvironment(_:)` | ✅ WIRED | pipeline consumer + tests |
| `BASAgentFabricGate.Activation.fabricEnabled` | ✅ WIRED | pipeline guards on it |
| `BASAgentFabricGate.Tier.core` / `.all` | ✅ WIRED (ch 1008) | `BASAgentTierActivationValidator` detects tier ↔ activeAgents inconsistencies (e.g. `.core` + watcher name = mismatch)。 Host pipeline emits `gate.tierValidation` diagnostic per turn。 Full multi-chapter roster-filter wire (watcher + skill integration) is Phase 9+ — but this chapter ships real behavioral wire today。 |
| `BASAgentFabricGate.TranscriptMode.singleAgent` / `.compareAll` / `.compareSelected` | ✅ WIRED (ch 1009) | `BASAgentFabricTranscriptProjection.summarize(...)` produces a per-agent activity summary that GENUINELY varies by mode。 `.singleAgent` → nil (byte-equal old);`.compareAll` → full summary;`.compareSelected` → scoped summary。 Substantive output difference between modes。 Phase 9+ adds new `BASRenderFrame` variants on top of this projection。 |
| `BASAgentFabricGate.Activation.activeAgents` | ✅ WIRED (ch 1001) | CSV from env now drives optional-seat filtering in `BASAgentFabricHostPipeline`。 Memory / triScores / hostConstitution / sovereign / evolution seats are nil-filtered when `BAS_ACTIVE_AGENTS` is set + does not include their canonical role name。 Backward compat: empty CSV = no filter (preserves pre-ch-1001 behavior)。 |

### Audit + storage (ch 994.5-994.7)

| API | Status | Notes |
|---|---|---|
| `BASSovereignLedgerSQLiteStorage` v2 schema | ✅ WIRED | column persists + reads + migrates |
| `entry_schema_version` column | ✅ WIRED | per-entry value flows through canonical-bytes |
| `basSovereignAuditCanonicalBytes` v1 vs v1.1 separator-class | ✅ WIRED | both branches active |
| `BASSovereignAuditLedger` rotation/segments | ✅ WIRED | independent of this arc but stable |

### Reserved L14 prefixes (11 total)

| Prefix | Status |
|---|---|
| `agentFabric.activated:` | 💀 future-allocation |
| `agentFabric.merged:` | 💀 future-allocation |
| `agentPersona.applied:` | 💀 future-allocation |
| `agentPersona.clamped:` | 💀 future-allocation |
| `agentWatcher.flag:` | ✅ in-use (Phase 5) |
| `agentWatcher.count:` | ✅ in-use (Phase 5) |
| `agentExternal.proposal:` | ✅ in-use (Phase 7) |
| `agentExternal.tier:` | ✅ in-use (Phase 7) |
| `agentExternal.trust:` | ✅ in-use (Phase 7) |
| `agentExternal.warrant:` | ✅ in-use (ch 981.7+982+982.5+983+993) |
| `agentMCP.permit:` | ✅ in-use (ch 990) |

### DeltaType (ch 953 + ch 995.9 audit)

| Case | Status |
|---|---|
| `.add` | ✅ WIRED (Planner + EvolutionShadow emit) |
| `.replace` | ✅ WIRED (Surface + SovereignSentinel emit) |
| `.merge` | ✅ WIRED (Scout + Memory + Critic + Risk + HostAlign emit) |
| `.remove` | ✅ WIRED (tombstone path in applier) |
| `.annotate` | ✅ WIRED (ch 1002 — `BASTraceAnnotatorSeat` emits one `.annotate` delta per turn against the new `.traceAnnotation` domain;applier writes the payload via the existing payload-bearing branch)。 |

## Honest summary

**Total public APIs shipped in arc 953-995.9**: ~75 (including
adapters / bridges / DTOs / enums)。

**Status counts** (post-ch 1015 cascade consolidation):
- ✅ WIRED: ~68 (91%)
- 🪜 SCAFFOLD: ~4 (5%) — all genuinely multi-chapter Phase 9++
- 💀 DEAD / future-allocation: ~3 (4%)

## Cascade asymptote (Round-24 honest meta-assessment)

After 5 fix-rounds (ch 1000.5 / 1010.5 / 1010.6 / 1014.5 /
1014.6),Round-24 audit produced an HONEST meta-finding:

| Round | CRITICAL | Catch class |
|---|---|---|
| 19 (ch 1000.5) | 1 | ANE consult 4-way dup |
| 20 (ch 1010.5) | 3 | Confidence dup + 2 separator-injection |
| 21 (ch 1010.6) | 5 | 4 separators + sourceRefs `#` |
| 22 (ch 1014.5) | 2 | Sentinel dup + nil-result misclass |
| 23 (ch 1014.6) | 5 | Early-return + ShadowTrial seps + JSON-escape siblings + dead emitters + alias keys |
| **24 (this chapter)** | **1** | **Cascade-induced complexity (class h)** |

Round-24's lone CRITICAL was the cascade itself — unreachable
production code created BY a Round-23 fix。 The 3 HIGH items
were:
- HIGH-1: confidenceBand dup at 2 sites (Round-20-class
  recurrence)
- HIGH-2: inspector header doc lists 4 categories,actual is 5
  (Round-22-class deferred)
- HIGH-3: `fabric.run.no-result` category defensive but
  unreachable through `runTurn`

**Cascade health verdict (HONEST MODE)**:

- Genuine catches dwindling at non-bookkeeping pattern classes
- Pipeline grew from ~250 LOC at ch 995 to 765 LOC at ch 1014.6
  (+513 net over 9 sub-chapters)
- No prior fix REMOVED code;every fix ADDED
- Architectural elegance has degraded — pipeline reads as
  9 stratified geological layers,not as production code

**ch 1015 = CONSOLIDATION (subtractive)**:

- Extract canonical `BASTraceAnnotatorSeat.confidenceBandFor(_:)`
  + delete 2 duplicate private impls (-12 LOC,+6 LOC = net -6)
- Delete unreachable observation-projection `else` branch (-8 LOC)
- Fix 3 audit-bridge file headers + inspector header doc
  (no LOC change,doctrine-fix)
- First chapter in the cascade with NEGATIVE net LOC delta

**Round-25 recommendation**:

The cascade should NOT be a permanent ongoing process。 Per
Round-24 verdict,future rounds should:

1. **STOP extending diagnostics.** If a finding suggests a new
   diagnostic key,first ask:does any `Sources/` code branch on
   it? If no → write a test instead, not a diagnostic。
2. **CONSOLIDATE before extending.** Round-25 (if invoked)
   should continue subtractive work — refactor
   `BASAgentFabricHostPipeline.runTurn` (currently 406 lines)
   into 3-4 named helpers。 Move inline「Round-N fix」 comments
   into helper headers。
3. **Stop new prefixes.** `inspector.*`,`observation.*`,
   `watcher.*`,`gate.*` are not in any reserved-prefix
   registry。 Either add them or stop emitting new ones。
4. **Pivot to Phase 9++** instead of more cascade rounds。
   Tier-based ANE-dispatch arc + authoritative mode wire are
   the genuine next-arc work。

This is the HONEST asymptote signal。 Each round caught fewer
NEW pattern classes,more recurrences,more class-h cascade
complexity。 Round-24's 1 CRITICAL was complexity caused BY
Round-23 — the cascade is fighting itself。

**Change vs ch 996 inventory**:
- ch 998-1000.5 closed the chapter-500 ANE consultation gap (production
  Brain now reads + counts via `BASCognitiveBrain.recordANEConsultation`)。
- ch 1001 closed `BAS_ACTIVE_AGENTS` (decorative → genuine seat filter)。
- ch 1002 closed `.annotate` deltaType (DEAD → WIRED via TraceAnnotator
  + new `.traceAnnotation` domain)。
- ch 1003 closed `validateMCPInvocation` (SCAFFOLD → WIRED via
  `BASMCPInvocationAuditBridge` — granted + rejected both land in
  L14 ledger,mirroring ch 983 warrant-audit-bridge shape)。
- ch 1004 closed `recordEvent` streaming gap (SCAFFOLD → WIRED via
  `BASAgentTraceStreamingSink` protocol + `BASAgentTraceBufferingSink`
  reference impl + bridge `recordEvent(_:streamingTo:)` overload)。
- **ch 1012-1013 Phase 9+ Gate.Tier behavioral wire** —
  `BASAgentFabricWatcherCollector` (ch 1012) + pipeline integration
  (ch 1013) make `BAS_AGENT_TIER=all` GENUINELY change substrate
  output。 The「decorative」 label retired。
- **ch 1014「全面 一次性 gap closure」omnibus**:
  - HostOutcome.{type, activation, fabricMode} ✅ WIRED via
    `BASAgentFabricHostOutcomeInspector`
  - Honest `tierReadByExecutorInProduction = true` companion
    flag added alongside `consultedByExecutorInProduction = false`
    — captures the actually-true state machine without lying
    about substrate dispatch behavior
  - Round-21 LOW-1: ch 1006 summary JSON-escaped (defense-in-
    depth for downstream encoders)
  - Round-21 LOW-2: ch 1007 defense commentary disclosing
    ENUM-CONSTRAINED vs CALLER-SUPPLIED field discipline
- **「全面 收口 scaffold」arc (ch 1006-1010)** closed 4 more items:
  - ch 1006 — `BASAgentObservation` (mislabeled-DEAD-as-SCAFFOLD) via
    `BASAgentObservationAuditEmitter` for L14 audit signalRefs
  - ch 1007 — `BASAgentFabricMode` substrate-observability via
    `BASAgentFabricModeAuditEmitter`
  - ch 1008 — `Gate.Tier` validation wire via
    `BASAgentTierActivationValidator`
  - ch 1009 — `Gate.TranscriptMode` per-agent summary via
    `BASAgentFabricTranscriptProjection`

**Reading**: 2/3 of the arc is genuinely-wired internal substrate
infrastructure。 1/4 is host-observable scaffold (host SDK can
inspect + branch,substrate doesn't)。 Small remainder is reserved
for future allocation。

## Forward closure path

Future arcs may move SCAFFOLD APIs into WIRED by:
1. **`BASAgentFabricMode`** → wire `.authoritative` to actually
   drive coordinator output paths (replaces render frame /
   risk gate with fabric's deltas)。 Phase 9+ scope。
2. **`Gate.Tier`** → wire dispatcher to filter optional seats
   when `.core` selected (vs `.all` which would add watcher/
   skill agents to roster)。 Phase 9+ scope。
3. **`Gate.TranscriptMode`** → wire surface seat to emit
   per-agent transcripts when `.compareAll`/`.compareSelected`。
4. ~~**`validateMCPInvocation`** → host pipeline calls it before
   any actual MCP tool dispatch + appends audit ref to ledger。~~
   **CLOSED at ch 1003** — `BASMCPInvocationAuditBridge` ships
   `validateAndAppend(...)` (one-call validate + ledger append)
   and `appendToLedger(...)` (pre-validated batch append)。
   Mirrors the ch 983 `BASSovereignWarrantAuditBridge` shape。
   Granted AND rejected outcomes both land in the L14 ledger
   per ch 977 defense-in-depth doctrine。
5. ~~**`recordEvent`** → host's per-event log consumer wires it
   into a streaming sink (currently only flush is used)。~~
   **CLOSED at ch 1004** — `BASAgentTraceStreamingSink` protocol
   shipped + `BASAgentTraceBufferingSink` reference impl +
   `BASAgentTraceLogEventLogBridge.recordEvent(_:streamingTo:)`
   integration overload。 Hosts implementing Kafka publishers /
   websocket fanouts / observability streams now have a documented
   contract and a starting-point template。 Both `flush` (batch)
   and per-event-streaming paths remain first-class — substrate
   doesn't force one over the other。
6. ~~**`.annotate`** deltaType → future trace seat emits it。~~
   **CLOSED at ch 1002** — `BASTraceAnnotatorSeat` is that trace
   seat。 Writes against the new `.traceAnnotation` domain (also
   added at ch 1002)。 Production reads remain audit-only (no
   in-turn seat consumes,by design)。

These are explicitly post-arc-953-996 scope。 The substrate is
correct to ship the API surfaces NOW so future hosts can adopt
incrementally without API churn — but Round 12-14 reviewers
caught us claiming "wired" when we meant "shipped"。 This doc
fixes the claim。

## What ch 996 changed

- This file (`SCAFFOLD_VS_WIRED.md`) created。
- ARC_SEAL section "Cross-module integration arc closure summary"
  amended to point to this doc as authority。
- Source-file docstrings on the 🪜 SCAFFOLD APIs (BASAgentFabricMode
  + Gate.Tier + Gate.TranscriptMode + .annotate + HostOutcome.
  fabricMode/activation) annotated with explicit
  "SCAFFOLD per `Docs/SCAFFOLD_VS_WIRED.md`" tag so any future
  reviewer can find this taxonomy from the source side。
- No new public APIs added。 No behavioral change。 Genuine
  closure of the 6-round same-class cascade by making the
  scaffold/wired distinction EXPLICIT at the doctrine layer。

## What chapters 1001-1005 closed (the「全面 完成 scaffold」arc)

After ch 996 shipped the inventory,the user invoked a multi-
chapter scaffold-pruning sweep。 Each chapter took ONE forward-
closure item that was genuinely closable in a single-chapter
scope。 Each shipped with the same discipline:
  - additive only (red-line 7)
  - opt-in (ADR-014)
  - new tests pin the genuine wire
  - existing tests preserved byte-equal
  - doctrine row in this file flipped to ✅ WIRED

### ch 1001 — `BAS_ACTIVE_AGENTS` activeAgents filter

Pre-fix: env-var parsed into diagnostics, never affected behavior
(decorative since ch 993)。
Post-fix: `BASAgentFabricHostPipeline.runTurn` filters optional
seats (memory/triScores/hostConstitution/sovereign/evolution)
based on the activeAgents list。 Backward compat: empty CSV =
no filter (matches pre-ch-1001 behavior)。

### ch 1002 — `.annotate` deltaType WIRED via TraceAnnotatorSeat

Pre-fix: case shipped at ch 953,emitted by NO seat。
Post-fix: `BASTraceAnnotatorSeat` is the canonical emitter
(audit-only,writes against new `.traceAnnotation` domain)。
Applier's payload-bearing branch handles the write — no code
change needed in applier。

### ch 1003 — `validateMCPInvocation` SCAFFOLD → WIRED

Pre-fix: gate shipped at ch 990,auditRefs dead-letter (no
ledger consumer)。
Post-fix: `BASMCPInvocationAuditBridge.validateAndAppend(...)`
pipes both granted + rejected outcomes into L14 ledger,
mirroring ch 983 warrant-bridge shape verbatim。

### ch 1004 — `recordEvent` per-event streaming WIRED

Pre-fix: API shipped at ch 984,no documented protocol for
host streaming consumers。
Post-fix: `BASAgentTraceStreamingSink` protocol + 
`BASAgentTraceBufferingSink` reference impl + bridge
`recordEvent(_:streamingTo:)` overload。 Hosts now have a
contract + starting-point。 Both flush + per-event-stream
remain first-class。

### ch 1005 — Arc seal + remaining-scaffold honest pin

This chapter (the synthesis):
1. Closes the inventory drift caught at ch 1001-1004 (the
   activeAgents row was missed when ch 1001 shipped — same
   discipline failure ch 996 originally fixed,now caught
   end-to-end with a structural test)
2. Pins the REMAINING SCAFFOLDS as「correct as scaffold」by
   doctrine — each one is genuinely multi-chapter scope:
   - **`BASAgentFabricMode.authoritative`** — flipping behavior
     requires Phase 9+ work (replace coordinator output paths
     with fabric deltas)。 NOT closable in 1 chapter。
   - **`Gate.Tier.core`/`.all`** — needs watcher + skill agent
     integration into the pipeline first。 The 7 watchers + 4
     reference skill agents exist as substrate APIs but aren't
     wired into `BASAgentFabricHostPipeline`。 Until they are,
     `.core` and `.all` are behaviorally equivalent。 NOT
     closable in 1 chapter。
   - **`Gate.TranscriptMode`** — requires new `BASRenderFrame`
     variants for per-agent transcripts。 Architectural change。
     NOT closable in 1 chapter。
   - ~~**`BASAgentFabricHostOutcome.{activation,fabricMode}`** —
     host-observable SDK surface,read by code OUTSIDE this
     repo。 Substrate's job is to provide the typed signal;
     consumer's job is to branch on it。 CORRECT as scaffold
     from substrate's perspective — the substrate cannot
     reach into the host's code。~~
     **SUPERSEDED at ch 1014** — substrate now ships a canonical
     consumer (`BASAgentFabricHostOutcomeInspector`)。 The ch 1005
     doctrine of「substrate cannot reach into host code」 was
     true,but the substrate CAN ship its own reference reader。
     See updated rows at lines 108-110 for the WIRED status。
     Round-22 HIGH-4 audit caught this doc-self-contradiction
     and ch 1014.5 closes it。
   - **`consultedByExecutorInProduction = false`** — flipping
     this static-let to `true` requires actual tier-based
     dispatch (route through CoreML-on-ANE for `.aneNative`
     tier ops instead of MSL)。 Multi-chapter ANE-dispatch arc
     that the substrate ANE-consultation work (ch 998-1000.5)
     deliberately scoped OUT。 CORRECT as scaffold per
     chapter-500 invariant + ch 1000 honest-scope doctrine。
   - ~~**`BASAgentObservation`** — watcher hint surface;
     substrate doesn't branch but the L14 audit reads。 The
     genuine consumer (L14 audit ledger reader) lives in
     host code — same dynamic as host-observable signals。
     CORRECT as scaffold from substrate's perspective。~~
     **SUPERSEDED at ch 1006** — mislabeled-DEAD-as-SCAFFOLD;
     true status was 💀 DEAD (no substrate consumer)。 Closed
     by `BASAgentObservationAuditEmitter` ch 1006。 See row at
     line 61。
3. Adds structural test `BASChapter1005ScaffoldInventoryPin`
   that asserts: (a) `Docs/SCAFFOLD_VS_WIRED.md` and the
   source-file docstrings remain consistent;(b) the count
   of ✅ WIRED entries matches expected after this arc。

### What we explicitly DID NOT do

- No force-closing the remaining 🪜 SCAFFOLD items。 Each one
  was triaged honestly with explicit rationale。
- No silently flipping `consultedByExecutorInProduction` to
  `true` — that would lie about substrate behavior。
- No adding decorative dispatcher branches for `Gate.Tier`
  that don't actually filter anything — that would just
  shift the scaffold problem instead of closing it。

The 4 closures in this arc were the genuinely-closable items
identified by ch 996 forward-closure path。 The remaining items
are correctly multi-chapter scope。 Future arcs will close them
as their preconditions are met (watcher integration → tier wire;
authoritative-mode wire → coordinator branch refactor;tier-
based ANE dispatch → multi-chapter kernel arc)。

---

## ch 1025-1037 update — 最严苛 triage(2026-05-29)

This doc was last substantively updated at ch 1015。 A 2-agent
adversarial triage at ch 1037 (user mandate「全面 解决 scaffold/
backlog 最严苛 最诚实」) found THREE honesty debts in the sections
above,recorded here without rewriting history:

### Debt 1 — summary count self-contradicts its own tables
Line ~167 says「🪜 SCAFFOLD: ~4 (5%)」 but EVERY named row in the
inventory tables already reads ✅ WIRED — zero 🪜 rows remain in
the tables。 The genuinely-residual scaffolds live in PROSE only
(the「explicitly DID NOT do」 list),not the tables。 Honest
residual count is ~2 behavioral(`consultedByExecutorInProduction`,
`BASAgentFabricMode.authoritative`)+ ~3 DEAD reserved prefixes
(`agentFabric.activated:`,`agentPersona.applied:`,`.clamped:`),
NOT「4 SCAFFOLD」。

### Debt 2 — 「shipped ≠ wired」 reintroduced at the audit-emitter layer
ch 1006-1009 flipped `BASAgentObservation` / `BASAgentFabricMode` /
`Gate.Tier` / `Gate.TranscriptMode` to ✅ WIRED — but via
audit/observer/projection EMITTERS,which do NOT change dispatch
behavior。 `BASAgentFabricMode` runtime docstring itself says
`.observationOnly` and `.authoritative` 「produce byte-identical」
output。 The ✅ glyph reads stronger than the reality(observability-
wired,not behavior-wired)。 This is the exact pattern this doc was
created to stop — honest re-label: these are ✅ OBSERVABILITY-WIRED,
behavior-wired remains Phase 9+。

### Debt 3 — `agentFabric.merged:` mislabeled 💀 DEAD,actually Bucket-A
The triage proved the merge engine RUNS in the production dispatcher
(`BASAgentTurnDispatcher.swift:382`),`BASAgentMergeResult.
mergeReasonCodes` is a real per-turn field,and the watcher-aggregator
pattern(`BASAxisSanctumWatchersAggregator`)proves the emit shape。
So `agentFabric.merged:` is honestly-closable(add a merge-audit
emitter),NOT dead。 Triaged Bucket-A;ship when the audit-ledger
consumer is added。

### ch 1033 Mamba — now boot-probe exercised(device-verified)
`BASMetalBenchmarkHarness.runMambaScan` is exercised on-device by
`DeviceTestApp/.../BASMambaProbe.swift`(ch 1033,VERDICT all_ok=true,
cpu 370µs / gpu 452µs / speedup 0.82 at hiddenDim=8)。 The biomimetic
SSM layer was the top「NYI」 inventory line — now run on the A19。

### Honestly NOT closable(close-would-lie or external)
- `consultedByExecutorInProduction=false` → flipping = lie(ANE/
  thermal tier dispatch not routed;`tierReadByExecutorInProduction`
  companion already captures the true sub-state)。 ch 1026 needs
  5-axis perf at .nominal + red-line-7。
- `BASAgentFabricMode.authoritative` behavior wire → Phase 9+
  coordinator-branch refactor。
- ANE utilization% → iOS sandbox(private `H11ANE` entitlement)=
  WONTDO。
- 3 DEAD persona/activated prefixes → need the persona-resolver +
  watcher arcs wired into the turn pipeline first。

### OBSOLETE(mooted by ch 1025.4 in-app architecture)
`ch 1032 competing-xcodebuild lockout` + endurance `exit=65` items
were `xcodebuild test`-controller artifacts。 `devicectl device
process launch`(in-app endurance)has no test-bundle enumeration +
no shared test session,so these cannot recur on the now-default
path。 Retained only for the legacy `scripts/run-iphone-air-10hr.sh`
xcodebuild-test path。

---

## ch 1039+ — 循环/进化 引擎未点火(verified scaffold,→ ADR-018)

A ch 1037-1038 deep architecture study (3 layered Explore agents over
all 14 layers + 5 ignition-point feasibility spikes) verified a NEW
class of reserved-but-unfired interface: the substrate's **iterative-
loop + evolution engine**。 Recorded here as scaffold;designed in
`Docs/ADR_018_ITERATIVE_LOOP_AND_EVOLUTION.md`。

- **`loopCount` / `maxLoops` / `stepIndex`** — 🪜 SCAFFOLD (engine
  unfired)。 `runTurn()` is a single linear pass;`loopCount =
  max(1, stepIndex)` is pinned `== 1` by `BASEBrainSchemaCoreTests
  .swift:1743`。 The convergence telemetry (`BASConvergenceStoppingMode`,
  `uncertaintyLedger.confidenceFloor`, `evidenceDebts.debtWeight`,
  `candidateFrontier.frontierWidth`) + the `desiredLoopCount()`
  budget hook (`EBrainHostRuntime+LoopService.swift:115`) ALL exist
  — but nothing `repeat/while`s on them。 Ignition = ADR-018 Phase 1。
- **`ShadowTrialStateMachineCore` + `bas-shadow-trial` (Rust) +
  `bas-dream-loop` (Rust)** — 🪜 SCAFFOLD (real algorithms, feedback
  unwired)。 Pure trial-transition + batch-scoring kernels exist + are
  `@_silgen_name`-bound, but no cross-turn feedback consumes their
  output。 Ignition = ADR-018 Phase 2 (trial) + Phase 1 (dream-loop bias)。
- **`BASFeedbackEvent` → policy** — 🪜 SCAFFOLD (dead-ends at audit)。
  Field exists on the turn request, generates an UpdateTicket, but the
  ticket is never applied to future behavior。 Ignition = ADR-018
  Phase 4 — DANGEROUS, requires an L14 sovereign gate (a user could
  train the system badly)。
- **L13 version-tree branch/merge** — 🪜 SCAFFOLD (append-only)。
  `parentVersionID` (M110) exists but no branch/shadow-trial/merge。
  Ignition = ADR-018 Phase 5 — major multi-session arc。

Same doctrine as `consultedByExecutorInProduction=false` + fabric
`.observationOnly`:**reserved interface, behavior pending**。 None is
broken;the ignition is architectural wiring, opt-in + byte-equal-when-
off。 See ADR-018 for the unified deliberation-budget loop design +
phased red-line proofs。

### ch 1039 — P1 safe-slice partial ignition (deliberation-loop plumbing)

ADR-018 P1's full ignition (`runTurn` `repeat/while`) is a shared-
contract + hot-path refactor (MED-HIGH, 4-5 files) — see ADR-018 §7.1。
The ch 1039 safe slice landed the **plumbing + persistence bias** only,
NOT the running loop:

- **`BASLoopServicing.iterate(…:priorCandidateIDs:)`** — ✅ WIRED but
  🕯️ LATENT。 New 4-arg contract requirement + a default impl that
  forwards to the single-pass 3-arg `iterate`,so every existing
  conformer (`BASPlaceholderLoopService` + 7 test doubles + `StubLoop`)
  inherits it → byte-equal, zero edits。
- **`BASMLLoopService` persistence bias** — ✅ WIRED but 🕯️ LATENT。
  A candidate carried in `priorCandidateIDs` earns a bounded
  `priorPersistenceConfidenceBonus` (0.05,capped at 1.0);empty /
  unmatched prior set = byte-equal。 4 new tests in
  `BASMLLoopServiceTests` (empty-identity, unknown-id-identity,
  reinforce-by-exact-bonus, confidence-cap)。
- **LATENT because** `runTurn`
  (`EBrainRuntimeCoordinator+RunTurn.swift:172`) still calls the 3-arg
  form,so `priorCandidateIDs` is never non-empty in production until
  the repeat loop is wired。 The bias path is test-exercised but
  production-dormant。

Honesty boundary:this is real, tested, byte-equal code — NOT yet a
running loop。 `loopCount` is still `== 1`;the engine remains unfired。
The slice closes the contract gap so the loop chapter becomes a pure
control-flow change。 Verified:full sweep 14,648 tests / 0 failures
(includes the `loopCount==1` pin + the byte-equal red-line proofs)。

### ch 1039 (follow-up) — deliberation loop LANDED (opt-in, default OFF)

The plumbing above is now connected to a real running loop。
`BASEBrainRuntimeCoordinator.deliberationLoopEnabled` (default false)
gates a `runTurn` repeat that runs budget-driven refinement passes
(`min(maxLoops, stepIndex)`,prior-candidate-biased,terminal early-
exit) when ON。 Status flip:

- **loop engine** — was 🪜 SCAFFOLD ("`runTurn` is a single linear
  pass;nothing `repeat/while`s on the telemetry"),now ✅ WIRED but
  OPT-IN + 🕯️ dormant in production。 `makeWithDefaults` keeps the
  flag OFF and uses `BASMLLoopService` (stepIndex → 1),so
  `loopCount` is still 1 in production until explicitly opted in with
  a multi-loop service + budget。 Enabling it fires real refinement
  passes — the engine that **structurally could not run before**
  ch 1039 now can。
- byte-equal proof:full sweep 14,652 tests / 0 failures with the
  flag OFF (incl. `loopCount==1` pin,×2 `stepIndex==maxLoops`,
  canonical identity + byte-equality-proof sweeps)。

Honesty boundary:the loop is REAL + tested,but OFF by default。
Same doctrine as `agentFabric` / `.observationOnly`:reserved +
now-runnable,activation gated。 点3 (thermal → fewer loops) +
production activation remain follow-ups (see ADR-018 §7.2)。
