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
| `BASAgentObservation` | 🪜 SCAFFOLD | watcher hint surface;substrate doesn't branch but L14 audit reads |

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
| `BASAgentFabricAdapters.validateMCPInvocation(_:against:)` | 🪜 SCAFFOLD | tests-only consumers as of ch 996 — no host pipeline integration calls validate before MCP invocation;the result + audit ref is read only by ch 990 tests。 Will move to ✅ WIRED when a host calls `validateMCPInvocation` before an actual MCP tool dispatch。 |
| `BASSovereignWarrantAuditBridge.buildEntry(...)` | ✅ WIRED | appendToLedger consumer |
| `BASSovereignWarrantAuditBridge.appendToLedger(...)` | ✅ WIRED | pipeline consumer |
| `BASAgentTraceLogEventLogBridge.recordEvent(...)` | 🪜 SCAFFOLD | API ships;pipeline doesn't call per-event recordEvent — uses flush(forTurn:) instead。 Available for future per-event hosts。 |
| `BASAgentTraceLogEventLogBridge.flush(forTurn:)` | ✅ WIRED | full-turn adapter consumer |
| `BASAgentTraceLogEventLogBridge.synthesizeEventLogEntry(...)` | ✅ WIRED | flush + recordEvent both consume |

### Host integration (ch 993-995.9)

| API | Status | Notes |
|---|---|---|
| `BASAgentFabricFullTurnAdapter.run(...)` | ✅ WIRED | host pipeline consumer + tests |
| `BASAgentFabricLiveInputs` | ✅ WIRED | all 12 fields flow to dispatcher chain |
| `BASAgentFabricFullTurnResult` | ✅ WIRED | pipeline reads .turnResult / .warrantAuditEntry / etc |
| `BASAgentFabricHostPipeline.runTurn(...)` | ✅ WIRED | DeviceTestApp + tests |
| `BASAgentFabricHostOutcome` | 🪜 SCAFFOLD | typed activation + fabricMode fields read by no Sources/ consumer — host-observable SDK surface only。 Diagnostics dict similar (declared by pipeline,read by host code which lives outside this repo)。 |
| `BASAgentFabricHostOutcome.activation` | 🪜 SCAFFOLD | host-observable typed signal |
| `BASAgentFabricHostOutcome.fabricMode` | 🪜 SCAFFOLD | host-observable typed signal (per ch 994 mode scaffold doctrine) |

### Mode + gate scaffolds (ch 993-994)

| API | Status | Notes |
|---|---|---|
| `BASAgentFabricMode` enum | 🪜 SCAFFOLD | stored on runtime,surfaced in outcome,but NO Sources/ branches on it。 Substrate doesn't switch behavior between `.observationOnly` and `.authoritative`;host's downstream consumer (the code reading outcome.fabricMode) decides what to do with the result。 Per ch 994 + ch 995.9 explicit doctrine。 |
| `BASAgentFabricMode.observationOnly` | 🪜 SCAFFOLD | default value (back-compat) |
| `BASAgentFabricMode.authoritative` | 🪜 SCAFFOLD | host signal — substrate behavior byte-identical to `.observationOnly` |
| `BASAgentFabricGate.activationFromEnvironment(_:)` | ✅ WIRED | pipeline consumer + tests |
| `BASAgentFabricGate.Activation.fabricEnabled` | ✅ WIRED | pipeline guards on it |
| `BASAgentFabricGate.Tier.core` / `.all` | 🪜 SCAFFOLD | parsed into Activation,surfaced in diagnostics,but NO Sources/ branches on it for roster filtering。 Decorative env-var echo per ch 995.5 doctrine。 Full tier-filter behavioral wire deferred to phase 9+ scope (would require new dispatcher behavior)。 |
| `BASAgentFabricGate.TranscriptMode.singleAgent` / `.compareAll` / `.compareSelected` | 🪜 SCAFFOLD | same as Tier — parsed,surfaced,not branched on substrate-side |
| `BASAgentFabricGate.Activation.activeAgents` | 🪜 SCAFFOLD | CSV from env,surfaced in diagnostics,no roster filter |

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

**Status counts** (post-ch 1002):
- ✅ WIRED: ~52 (69%)
- 🪜 SCAFFOLD: ~20 (27%)
- 💀 DEAD / future-allocation: ~3 (4%)

**Change vs ch 996 inventory**:
- ch 998-1000.5 closed the chapter-500 ANE consultation gap (production
  Brain now reads + counts via `BASCognitiveBrain.recordANEConsultation`)。
- ch 1001 closed `BAS_ACTIVE_AGENTS` (decorative → genuine seat filter)。
- ch 1002 closed `.annotate` deltaType (DEAD → WIRED via TraceAnnotator
  + new `.traceAnnotation` domain)。
- ch 1003 closed `validateMCPInvocation` (SCAFFOLD → WIRED via
  `BASMCPInvocationAuditBridge` — granted + rejected both land in
  L14 ledger,mirroring ch 983 warrant-audit-bridge shape)。

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
5. **`recordEvent`** → host's per-event log consumer wires it
   into a streaming sink (currently only flush is used)。
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
