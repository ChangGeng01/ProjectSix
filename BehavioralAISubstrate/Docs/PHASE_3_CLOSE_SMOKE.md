# Phase 3 Close — iPhone Air 2-hour Real-Device Smoke (Operator Procedure)

**Arc**: Agent Fabric 953-981
**Phase**: 3 — Host/Sovereign/Evolution (ch 963-965)
**Status**: simulator-verified host-level CI passes (13,958 tests, 0 failures) — device-verification PENDING
**Operator**: maintainer with physical iPhone Air

---

## What this smoke validates

Per plan PHASE 3 close requirements:

1. All 9 core agents wired and emitting cleanly under real-device load
2. Zero single-writer violations across the 12-domain state graph
3. Phase 3 cumulative perf delta ≤ +5% vs ch 952.6 baseline
4. NEVER-effective-same-turn invariant for `.evolutionProposal`
5. Sovereign-lock invariants for `.hostVersion` + `.sovereignVerdict`

## Pre-flight

```bash
cd /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate
git status   # clean tree
swift build  # green
swift test --filter "BASChapter9[56]" 2>&1 | grep "Executed [0-9]"  # 0 failures
```

Confirm iPhone Air is connected via USB-C cable + Xcode trusts the device + the BAS host app is buildable for arm64-apple-ios target。

## Run

```bash
MAX_SEC=7200 \
    BAS_AGENT_FABRIC=enabled \
    BAS_AGENT_TIER=phase3 \
    BAS_DEVICE_LOG_DIR=/tmp/ch965-phase3-close \
    bash scripts/run-iphone-air-10hr.sh
```

The runner streams metrics every 30s to `/tmp/ch965-phase3-close/iter-NNNN.json`。 Expect ~240 iterations across 2 hours。

## Trend analysis

```bash
python3 scripts/analyze-ch952-trend.py /tmp/ch965-phase3-close
```

The analyzer produces a per-metric trend report。 Pass criteria:

| Metric | Pass threshold |
|---|---|
| Total failures | 0 |
| Single-writer violations | 0 |
| Perf delta vs ch 952.6 baseline | ≤ +5% (Phase 3 budget) |
| `.evolutionProposal` same-turn consumer count | 0 (NEVER-effective-same-turn invariant) |
| `.sovereignVerdict` writer | "sentinel.1" only (ch 964 invariant) |
| `.hostVersion` writes from non-L5/L14 agents | 0 |

## Phase 3 invariants checked per iteration

Beyond the standard ch 952.6 trend analysis,Phase 3 close adds 3
invariant assertions the analyzer floor-checks at every iteration:

### Invariant 1 — EvolutionShadow proposals never consumed same turn

For every turn observed in the log,scan all per-seat reads。 If
ANY non-EvolutionShadow seat reads `.evolutionProposal` in the
same turn as the proposal was emitted,FAIL the iteration。 The
shadow is exclusively for async ShadowTrial consumption — same-turn
consumption violates Root Law 4 (单主权)。

### Invariant 2 — SovereignSentinel sole writer of `.sovereignVerdict`

For every turn,check that `graph.writerForDomain(.sovereignVerdict)`
returns the registered SovereignSentinel agentID。 Any other
authorship indicates a Single-Writer-Per-Domain violation。

### Invariant 3 — No `.hostVersion` write from non-L5/L14 agent

For every turn,check that `graph.writerForDomain(.hostVersion)` is
nil (no agent should write it through the fabric — sovereign-locked
per Single-Writer table)。 Any non-nil value indicates a sovereign
bypass。 Particularly,EvolutionShadow MUST NOT appear here even
though it emits host-change CANDIDATES — those go to
`.evolutionProposal`,not `.hostVersion`。

## Outcome recording

After the 2-hour run completes,record the outcome here:

| Run date | Operator | Iterations | Failures | Perf delta | All invariants pass? |
|---|---|---|---|---|---|
| _pending_ | _pending_ | _pending_ | _pending_ | _pending_ | _pending_ |

If all 3 invariants pass + perf within budget,Phase 3 is **device-sealed**。
If any invariant fails,file a `ch 965.5 USER-PASS-6` fix sub-chapter with
the bug detail + regression test BEFORE proceeding to Phase 4。

## Rollback (if needed)

Phase 3 is fully ADR-014 OPT-IN — `BAS_AGENT_FABRIC=disabled` reverts
the host to pre-ch-953 behavior (ch 952.6 baseline) without touching
any code。 If the smoke catches a regression,disable the flag and
the issue is contained to the fabric layer。

## Next phase gate

Phase 3 close is the gate to Phase 4 (Persona Studio, ch 966-969)。
Phase 4 builds user-customizable persona overlay on the HIGH/MED tier
seats from Phase 1-3。 The persona overlay LIVES ATOP the fabric +
respects sovereign clamps + LOW-tier seal — but it cannot be safely
shipped until Phase 3 invariants are device-verified。
