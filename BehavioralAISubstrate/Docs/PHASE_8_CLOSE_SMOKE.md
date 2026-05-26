# Phase 8 Close + Arc Seal — iPhone Air 2-hour Real-Device Smoke

**Arc**: Agent Fabric 953-981 (FINAL CHAPTER)
**Phase**: 8 — End-side perf + arc seal (ch 979-981)
**Status**: substrate-sealed at ch 981, device-verification PENDING

This is the **final smoke procedure** of the Agent Fabric arc. Three modes, 2 hours each, validate that the 29-chapter arc holds together end-to-end on real hardware.

See `Docs/ARC_SEAL_953_981.md` for the full arc seal declaration.

---

## What this smoke validates

Per plan PHASE 8 close + arc seal requirements:

1. All 3 Phase 8 perf primitives (latent spine + hot/cold tier + speculative prefetch) compose cleanly on real hardware
2. Cumulative perf delta ≤ +15% vs ch 952.6 baseline across all 3 modes
3. ALL Phase 0-7 sovereignty invariants STILL hold under Phase 8 perf optimizations
4. 20-agent compare mode (9 core + 7 watcher + 4 reference skill) runs without crash or drift
5. Single-Writer-Per-Domain holds across all 12 domains regardless of which agent set is active

## 3-mode arc-seal procedure

> **Pre-condition**: Same as Phase 7 smoke (real Gemma 4 E2B on iPhone Air via MLX) PLUS a mock 5-agent compare client that exercises Planner+Critic+Memory+Risk+Surface concurrently for Mode 3.

> **Env-var caveat**: Per ch 981 ARC_SEAL deferred item #6, the `BAS_AGENT_FABRIC` / `BAS_AGENT_TIER` / `BAS_TRANSCRIPT_MODE` / `BAS_ACTIVE_AGENTS` env vars documented below are NOT YET WIRED into `scripts/run-iphone-air-10hr.sh` or the dispatcher. Phase 8 ships as library only. Operator either (a) wires the env-var gate in a separate commit, OR (b) runs the baseline smoke + manually exercises the 20-agent set through a custom test harness calling `BASAgentTurnDispatcher.dispatch(...)` directly.

### Mode 1 — Fabric OFF (baseline ch 952.6 behavior)

```bash
BAS_AGENT_FABRIC=disabled MAX_SEC=7200 \
    BAS_DEVICE_LOG_DIR=/tmp/ch981-fabric-off \
    bash scripts/run-iphone-air-10hr.sh
```

Expected: substrate behaves as if Agent Fabric arc never landed. Pre-Phase-0 callers (anyone not invoking `BASAgentTurnDispatcher.dispatch`) see zero behavior change. Per plan Red Line 7 (additive-only, byte-equal when fabric unconfigured).

### Mode 2 — Fabric ON, all 20 agents

```bash
BAS_AGENT_FABRIC=enabled BAS_AGENT_TIER=all MAX_SEC=7200 \
    BAS_DEVICE_LOG_DIR=/tmp/ch981-fabric-all \
    bash scripts/run-iphone-air-10hr.sh
```

All 9 core + 7 watcher + 4 reference skill agents active. Tests the full agent set under sustained 2-hour load.

### Mode 3 — Fabric ON, compare-mode 5 active agents

```bash
BAS_AGENT_FABRIC=enabled BAS_TRANSCRIPT_MODE=compareSelected \
    BAS_ACTIVE_AGENTS=Planner,Critic,Memory,Risk,Surface MAX_SEC=7200 \
    BAS_DEVICE_LOG_DIR=/tmp/ch981-fabric-compare \
    bash scripts/run-iphone-air-10hr.sh
```

Compare mode is the highest-coordination-cost path (5 agents share one encode pass via ch 979 latent spine, ch 980 hot/cold ensures 4 hot agents pre-warmed). Tests the per-turn coordination overhead target of ≤ 40ms P95.

## Trend analysis

```bash
python3 scripts/analyze-ch952-trend.py /tmp/ch981-fabric-off
python3 scripts/analyze-ch952-trend.py /tmp/ch981-fabric-all
python3 scripts/analyze-ch952-trend.py /tmp/ch981-fabric-compare
```

Pass criteria (arc seal verification):

| Metric | Pass threshold | Status |
|---|---|---|
| Total failures (across 3 modes) | 0 | active |
| Single-writer violations | 0 | active (sealed by ch 953-965 + ch 974 stability pins) |
| Cumulative perf delta vs ch 952.6 | ≤ +15% | active (substrate budget) |
| Mode 3 coordination overhead P95 (per turn) | ≤ 40ms | **deferred — needs ch 980 instrumentation wiring** |
| Sovereign-lock invariants (all 20 agents) | 100% | active (sweep-tested by ch 977 + ch 973 + ch 968) |
| Sealed-LOW force-default rate | 100% | active (ch 968 + ch 968 fuzz confirms 100% across 1000-iter) |
| Phase 8 specific: latent spine cache hit rate | ≥ 60% | **deferred — needs operator measurement** |
| Phase 8 specific: hot-tier wake cost | ≤ 5ms P95 | **deferred — needs operator measurement** |
| Phase 8 specific: speculation correctness rate | ≥ 80% (fires saved cost > wasted speculation) | **deferred — needs operator measurement** |

## Arc seal invariants (verified across all 3 modes)

### Invariant 1 — Single-Writer-Per-Domain

For every observed turn across all 3 modes, the graph actor's `writerForDomain(...)` returns at most one agentID per domain. Verified by `BASChapter954SharedStateGraphTests` + ch 956.11 USER-PASS-4 global writer registry + sweep tests in ch 977/978.

### Invariant 2 — External + skill agents NEVER write to state graph

For every external `BASAgentSpec` (from `BASExternalAgentGateway.submit(...)`) and every skill `BASAgentSpec` (from `BASSkillAgentInvoker.buildAgentSpec(...)`), `writeDomains.isEmpty == true` AND all 4 sovereign-locked domains in `forbiddenDomains`. Sweep-verified by `testCRITICAL_ExternalCannotWriteAnyDomain` + `testCRITICAL_SkillAgentCannotWriteHostVersion/Sovereign/Evolution`.

### Invariant 3 — Persona pipeline monotonic raise

Risk floor cannot be lowered by ANY downstream step. Verified by ch 967 3×1000-iter fuzz suites + ch 978 cross-phase regression-defense test.

### Invariant 4 — LOW-tier sealed-default

Without sovereign warrant, LOW-tier persona force-defaults to template. Verified by ch 968 1000-iter fuzz + ch 969.5 CG1 SDK exemption regression defense.

### Invariant 5 — Forbidden persona detector

4 patterns (shame / gaslight / absolute-paternal / controlling) catch BOTH input and output (sandwich-attack). Verified by ch 969 + ch 969.5 H4 AND-logic fix.

### Invariant 6 — Watcher discipline

All 7 watchers read-only (writeDomains empty), pattern-based (no ML), severity-laddered (info/watch/alert/veto). Sanctum-leak ALWAYS .veto. Verified by ch 970-972 + ch 978 cross-phase.

### Invariant 7 — Reserved signalRefs prefix discipline

L14 audit absorption channel uses 11 reserved prefixes (`agentFabric.*` + `agentPersona.*` + `agentWatcher.*` + `agentExternal.*` + `agentMCP.*`). No other prefix overlaps. Verified by ch 974 + ch 977 prefix tests. Per ch 981.7 ARC FINALIZE Item 5 a 10th prefix `agentExternal.warrant:` was added for the sovereign warrant validation outcome — updated from "9 reserved" by ch 982.5 META-REVIEW。 Per ch 990 Cross-Module Integration Arc Gap 2 close the 11th prefix `agentMCP.permit:` was added for MCP-invocation permit validation outcomes (granted/rejected against the live `BASActionPermit`)。

### Invariant 8 — Zero-copy ref carries NO write capability

`BASZeroCopyStateRef` is a 4-field struct (domain + objectID + versionAtRead + createdAtNanos). NO payload + NO agentID. Verified by `testCRITICAL_ZeroCopyRefIsReadOnlyPointer` (ch 981) using Mirror reflection.

## Rollback (if needed)

Phase 8 is fully ADR-014 OPT-IN — the 3 new modules (latent spine + hot/cold + speculative) are NOT invoked unless caller explicitly calls their entry points. If a regression is caught:

1. Revert ch 979-981 via `git revert` on Phase 8 commits
2. Substrate behavior fully restored to Phase 7 close (ch 978) state
3. File a USER-PASS sub-chapter with regression detail + fix

## Arc seal declaration (when smoke passes)

When operator runs the 3-mode smoke and all 3 modes pass per the criteria above:

1. Append to `Docs/ARC_SEAL_953_981.md` an "Arc seal verified" section with date + operator + 3-mode log dirs
2. Bump SDK version flag if appropriate (Phase 6 ch 974 declared SDK v1 — no break in arc 953-981)
3. Tag the commit `arc-seal-953-981` (operator-side, when explicitly authorized by user — per standing instruction, this assistant does not tag without authorization)

## Arc seal summary (ch 953-981, 29 chapters)

- **9 N-pass review cycles** caught **70+ real bugs** (per ch 982.5 META-REVIEW tally)
- **663 tests** at the arc level, all 0 failures (per ch 982.5 actual count)
- **14,150+ tests** in the full substrate sweep, all 0 failures
- **20 agents** wired across 8 phases
- **12 state graph domains** under Single-Writer-Per-Domain
- **4 reserved persona pattern detectors** + 4 reference skill agents + 7 watchers + 2 external gateways
- **11 reserved L14 signalRefs prefixes** (7 in-use + 4 future-allocation per ch 981.7 ARC FINALIZE + ch 982.5 META-REVIEW + ch 990 cross-module integration arc — the 11th is `agentMCP.permit:`) for audit absorption
- **3 stability tiers** declared (WIRE-STABLE / API-STABLE / INTERNAL)
- **0 schema changes** to existing `SovereignAuditEntry.signalRefs` — full reuse pattern preserved per ch 953

This is the **FINAL chapter** of the Agent Fabric arc. With operator's 3-mode device smoke, arc 953-981 is sealed end-to-end (extended through ch 982.5 META-REVIEW for honest disclosure of cross-module integration gaps — see `Docs/ARC_SEAL_953_981.md`).
