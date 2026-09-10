# Phase 5 Close — iPhone Air 30-minute Real-Device Smoke (Operator Procedure)

**Arc**: Agent Fabric 953-981
**Phase**: 5 — Watchers (ch 970-972)
**Status**: simulator-verified host-level CI passes (484 cumulative agent fabric arc tests, 0 failures) — device-verification PENDING
**Operator**: maintainer with physical iPhone Air

---

## What this smoke validates

Per plan PHASE 5 close requirements:

1. All 7 watcher agents emit cleanly under real-device load
2. Adversarial fuzz suite (known-bad inputs) triggers the right watchers
3. SignalRefs aggregate cleanly into L14 audit ledger (`agentWatcher.` prefix)
4. Watchers add < 2ms P95 overhead per turn (read-only, bounded)
5. Phase 5 cumulative perf delta ≤ +10% vs Phase 4 baseline (per plan)

## 7 watchers shipped (Phase 5)

| Watcher | Severity ladder | Detects |
|---|---|---|
| **Anomaly** | watch / alert | candidate-count surges, pressure surges, manipulation storms |
| **MemoryPollution** | watch / alert | duplicate arcs, fabrication-suspect recall, orphan conflicts |
| **HostDrift** | watch | untracked-axis touches, surface vs risk band mismatch |
| **Gaslight** | watch / alert / veto | 4 pattern categories (absolute / reality-denial / emotional-invalidation / trust-erosion) |
| **ToolInjection** | alert / veto | OWASP LLM Top 10 injection markers (system-override, role-elevation, output-leak, constraint-bypass) |
| **AxisDeviation** | alert / veto | coordinated boundary attacks (same host axis touched by ≥3 candidates) |
| **SanctumLeak** | veto (always) | sealed prefixes (`sealed:`, `deletion-manifest:`, `memory-seal:`, etc.) leaked into non-sealed channels |

## Pre-flight

```bash
cd /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate
swift build
swift test --filter "BASChapter97[012]" 2>&1 | grep "Executed [0-9]"  # 62 tests, 0 failures
```

## Smoke procedure (when host wires watchers)

> Same DH1 honesty caveat as Phase 4: the `BAS_WATCHERS_ENABLED` env var documented below is NOT YET WIRED into either `scripts/run-iphone-air-10hr.sh` or the dispatcher. Phase 5 ships as a library only. Operator must either (a) wait for Phase 6 SDK productization, or (b) wire the env-var gate manually in a separate commit before running the smoke.

### Baseline run (Phase 5 ships zero regression)

```bash
MAX_SEC=1800 \
    BAS_DEVICE_LOG_DIR=/tmp/ch972-phase5-baseline \
    bash scripts/run-iphone-air-10hr.sh
```

### Full watcher run (requires future env-var wiring)

```bash
# After wiring BAS_WATCHERS_ENABLED in ch 973+:
MAX_SEC=1800 \
    BAS_AGENT_FABRIC=enabled \
    BAS_WATCHERS_ENABLED=true \
    BAS_WATCHER_AUDIT_LEDGER=enabled \
    BAS_DEVICE_LOG_DIR=/tmp/ch972-phase5-full \
    bash scripts/run-iphone-air-10hr.sh
```

## Trend analysis

```bash
python3 scripts/analyze-ch952-trend.py /tmp/ch972-phase5-full
```

Pass criteria:

| Metric | Pass threshold | Status |
|---|---|---|
| Total failures | 0 | active |
| Phase 5 cumulative perf delta vs ch 952.6 baseline | ≤ +10% | active |
| Watcher overhead P95 per turn | ≤ 2ms | **deferred — instrumentation lands ch 973+** |
| Adversarial fuzz catch rate (known-bad inputs) | ≥ 95% | active (in-process tests confirm 100%) |
| Sanctum leak false-positive rate (clean prompts) | 0% | active (in-process tests confirm 0%) |
| SignalRefs format compliance (`agentWatcher.` prefix) | 100% | active (in-process tests confirm 100%) |

## Phase 5 invariants checked per iteration

### Invariant 1 — Watchers are read-only

For every watcher agent registered, assert `writeDomains.isEmpty == true`。 If any watcher's spec gains a write domain, that's an INV violation — emit a sovereign alert。

### Invariant 2 — Hints are not deltas

Watcher hints route through a separate audit channel (`BASWatcherAuditAggregate.signalRefs`), NOT through the merge engine。 Verify that no watcher hint ever lands in a `BASAgentDelta` writeObject call。

### Invariant 3 — SignalRefs prefix discipline

Every signal-ref pushed to the L14 audit ledger from watcher aggregation MUST start with `agentWatcher.flag:` or `agentWatcher.count:` per ch 953 SovereignAuditEntry absorption contract。

### Invariant 4 — Hint-ID uniqueness

All hints emitted in a single turn share a `seq` counter → all `hintID` strings are unique per turn。 The aggregator preserves this invariant across all 7 watchers。

## Adversarial fuzz suite (Phase 5 close discipline)

Per plan PHASE 5 close requirement, the test suite injects 5 known-bad inputs and asserts the right watchers fire:

| Attack | Expected veto-level watcher |
|---|---|
| Textbook gaslight (4/4 categories) | GaslightWatcher |
| Injection storm (3+ markers) | ToolInjectionWatcher |
| Sanctum leak (sealed prefix in planner) | SanctumLeakWatcher |
| Coordinated axis attack (6 candidates same axis) | AxisDeviationWatcher |
| Multi-vector (all 4 above simultaneously) | ≥ 3 distinct watchers |

All 5 attack scenarios pinned by `testCRITICAL_AdversarialFuzz_*` tests in `BASChapter972WatcherPhase5CloseTests`。

## Rollback (if needed)

Phase 5 is fully ADR-014 OPT-IN — watchers are NOT invoked unless caller explicitly calls `BASAgentWatcherDispatch.runPhase5(...)` or `BASAgentWatcherAggregator.runAll(...)`. The dispatcher in `BASAgentTurnDispatcher` is unchanged from Phase 4。 If a regression is caught in any watcher, revert commit(s) for ch 970-972 via `git revert` — substrate behavior fully restored without host-side code change。

## Phase 5 summary (ch 970 + 971 + 972)

| ch | Module | LOC (Sources) | Tests |
|---|---|---|---|
| 970 | BASAgentWatcher protocol + 3 watchers | ~580 | 21 |
| 971 | Gaslight + ToolInjection watchers | ~280 | 17 |
| 972 | AxisDeviation + SanctumLeak + L14 aggregator | ~410 | 24 |
| **Total** | | **~1270 LOC** | **62 tests** |

All 7 watchers shipped as pure functions, no actors, no I/O. Bounded by per-turn input size (no DoS surface). Pattern-based scoring (no ML) per ch 944 H2 — 100% replayable + auditable + explainable。

## Next phase gate

Phase 5 close is the gate to Phase 6 (SDK productization, ch 973-975)。 Phase 6 turns the substrate's library surface into a polished SDK for external consumers (Qinao runtime, 3rd-party hosts) — including the env-var gate, MCP/A2A adapters (deferred to Phase 7), and the sample host integration in DeviceTestApp。
