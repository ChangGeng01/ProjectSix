# Extreme Quality Gate

`DOUBLE QUALITY GATE` proves the system can survive one serious pressure cycle.

`EXTREME QUALITY GATE` is the next rung: it treats non-determinism, repetition drift, queue churn, template duplication, and UI fatigue as first-class failure modes.

This gate is intentionally harsher than [QUALITY_GATE_DOUBLE.md](/Users/changgeng/Project/Project06/Project06/docs/QUALITY_GATE_DOUBLE.md):

- it starts by requiring the full `40 / 40` double gate
- it adds a third full-suite run
- it adds a third UI smoke run
- it adds multi-run soak loops for the most drift-prone subsystems
- it specifically pressures deterministic ordering, repeated bootstrap, repeated queue churn, recovery, and launch/action boundaries

## 12-Point Extreme Standard

Each item is worth `1` point. The branch passes only at `12 / 12`.

1. The entire double gate passes first.
2. Full `Before` suite pass `#3` succeeds.
3. `BeforeUISmoke` pass `#3` succeeds.
4. `BeforeWatch` build pass `#3` succeeds.
5. Envelope, bandit, current-brain, prediction, and embedding stability subset survives `3` consecutive runs.
6. Recovery, replay, launch handoff, and protected/shared state subset survives `3` consecutive runs.
7. Memory governance, trust, template, failure archive, and embedding subset survives `3` consecutive runs.
8. Admission and circuit-breaker subset survives `3` consecutive runs.
9. Provider routing, prompt contract, debug privacy, response cache, and telemetry subset survives `3` consecutive runs.
10. Launch, notification, reminder, router, and Tomorrow Box action subset survives `3` consecutive runs.
11. On-device runtime and model catalog subset survives `3` consecutive runs.
12. Widget privacy and shared public state subset survives `3` consecutive runs.

## Command

Run from repo root:

```bash
./scripts/run_quality_gate_extreme.sh
```

This is the executable way to say: the system did not just go green once, it stayed green under repeated stress across the parts most likely to drift in a real long-lived local cognition product.
