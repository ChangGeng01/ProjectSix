# Phase 4 Close — iPhone Air 30-minute Real-Device Smoke (Operator Procedure)

**Arc**: Agent Fabric 953-981
**Phase**: 4 — Persona Studio (ch 966-969)
**Status**: simulator-verified host-level CI passes (408 cumulative agent fabric arc tests, 0 failures) — device-verification PENDING
**Operator**: maintainer with physical iPhone Air

---

## What this smoke validates

Per plan PHASE 4 close requirements:

1. Persona Studio full pipeline (Resolve → Risk → Sovereign → Detector) under real-device load
2. Forbidden persona detector catches all 4 patterns in live turns
3. Sovereign clamp + LOW-tier force-default invariant holds
4. Monotonic-raise invariant preserved across full chain
5. Risk + Sovereign clamps add < 5ms P95 to turn latency
6. Compare-mode transcripts render correctly for `compareSelected` with 5 active agents
7. Phase 4 cumulative perf delta ≤ +5% vs Phase 3 baseline

## Pre-flight

```bash
cd /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate
git status   # clean tree
swift build  # green
swift test --filter "BASChapter9[56][0-9]" 2>&1 | grep "Executed [0-9]"  # 0 failures
```

## Run (3 modes per ch 969 transcript modes)

### Mode 1 — singleAgent baseline

```bash
MAX_SEC=1800 \
    BAS_AGENT_FABRIC=enabled \
    BAS_PERSONA_ENABLED=true \
    BAS_TRANSCRIPT_MODE=singleAgent \
    BAS_DEVICE_LOG_DIR=/tmp/ch969-phase4-single \
    bash scripts/run-iphone-air-10hr.sh
```

### Mode 2 — compareAll (all 9 core agents)

```bash
MAX_SEC=1800 \
    BAS_AGENT_FABRIC=enabled \
    BAS_PERSONA_ENABLED=true \
    BAS_TRANSCRIPT_MODE=compareAll \
    BAS_DEVICE_LOG_DIR=/tmp/ch969-phase4-all \
    bash scripts/run-iphone-air-10hr.sh
```

### Mode 3 — compareSelected (5 active agents)

```bash
MAX_SEC=1800 \
    BAS_AGENT_FABRIC=enabled \
    BAS_PERSONA_ENABLED=true \
    BAS_TRANSCRIPT_MODE=compareSelected \
    BAS_ACTIVE_AGENTS=Planner,Critic,Memory,Risk,Surface \
    BAS_DEVICE_LOG_DIR=/tmp/ch969-phase4-compare \
    bash scripts/run-iphone-air-10hr.sh
```

## Trend analysis

```bash
python3 scripts/analyze-ch952-trend.py /tmp/ch969-phase4-single
python3 scripts/analyze-ch952-trend.py /tmp/ch969-phase4-all
python3 scripts/analyze-ch952-trend.py /tmp/ch969-phase4-compare
```

Pass criteria:

| Metric | Pass threshold |
|---|---|
| Total failures | 0 |
| Persona resolve P95 latency | ≤ 5ms |
| Risk clamp P95 latency | ≤ 1ms |
| Sovereign clamp P95 latency | ≤ 1ms |
| Forbidden detector P95 latency | ≤ 0.5ms |
| Phase 4 cumulative perf delta vs ch 952.6 baseline | ≤ +5% |
| Forbidden pattern detection rate (in adversarial fuzz) | ≥ 95% (textbook patterns) |
| Forbidden false-positive rate (clean mid-range personas) | 0% |
| LOW-tier force-default rate (no warrant) | 100% |
| Monotonic-raise preservation (risk floor) | 100% — zero lowering observed |

## Phase 4 invariants checked per iteration

### Invariant 1 — Forbidden personas never reach the dispatcher

The SDK's `resolve(...)` returns `persona: nil` + `rejected: true` for
any composition matching a forbidden pattern (input OR output)。 The
dispatcher MUST NOT use a nil persona — verify trace log shows zero
turns where `dispatch(...)` was called with a forbidden-composition
persona ref。

### Invariant 2 — Monotonic raise preserved across full chain

Same as ch 967 critical:Risk's skepticism / guard floors MUST NEVER
be lowered by Sovereign clamp or any downstream consumer。 The
dispatcher's per-turn audit ledger records the final persona's
skepticism/guard — assert ≥ risk floor for every turn。

### Invariant 3 — LOW-tier force-default without warrant

Any LOW-tier agent (SovereignSentinel / ActionPermit /
DeleteRollbackSeal / MemorySeal) running WITHOUT a sovereign warrant
in its sovereign context MUST land at template defaults for every
field。 Verify by inspecting the trace's `sovereign_audit_notes`
field — should contain `sovereign.no-warrant:low-tier-force-default`
in 100% of LOW-tier turns without warrant。

### Invariant 4 — Lockdown overrides warrant

Lockdown turn (`sovereign.lockdownTurn = true`) MUST force-default
EVERY agent regardless of:
- visibility tier (HIGH, MED, LOW)
- presence of warrant (warrant IGNORED during lockdown)
- input overlay (overlay IGNORED during lockdown)

## Outcome recording

| Run date | Operator | Mode | Iterations | Failures | Perf delta | All invariants pass? |
|---|---|---|---|---|---|---|
| _pending_ | _pending_ | single | _pending_ | _pending_ | _pending_ | _pending_ |
| _pending_ | _pending_ | compareAll | _pending_ | _pending_ | _pending_ | _pending_ |
| _pending_ | _pending_ | compareSelected | _pending_ | _pending_ | _pending_ | _pending_ |

## Rollback (if needed)

Phase 4 is fully ADR-014 OPT-IN — `BAS_PERSONA_ENABLED=false` reverts
to pre-ch-966 behavior (seats use role-template defaults without
overlay)。 If smoke catches a regression,disable the flag and the
issue is contained to the persona layer。

## Phase 4 summary

Phase 4 closes the **persona overlay** half of the Agent Fabric
arc。 With Phase 4 sealed:

- **12 role templates** distributed across 3 visibility tiers
- **Resolver + 2-arm clamp pipeline** (`P_role ⊕ P_user ⊕ P_host`,
  then Risk clamp,then Sovereign clamp) — full plan formula
  `P_effective = Clamp(P_role ⊕ P_user ⊕ P_host, Risk, Sovereign)`
  shipped
- **4 forbidden patterns** (shame / gaslight / absolute-paternal /
  controlling) detected before AND after composition
- **3 transcript compare modes** (singleAgent / compareAll /
  compareSelected) defined for ch 970+ host wiring
- **Sovereign warrant gate** for LOW-tier overrides (no warrant →
  force-default;lockdown overrides warrant)
- **78 new tests** (23+18+17+20) across 4 chapters covering all
  invariants + critical fuzz suites

## Next phase gate

Phase 4 close is the gate to Phase 5 (Watchers, ch 970-972)。 Phase 5
adds 7 quiet-observer agents emitting hints (no direct action) that
route to L14 sentinel for sovereign-violation patterns。 With Phase 4
locked in,Watchers can use the persona pipeline if they need
user-tunable observation cadence。
