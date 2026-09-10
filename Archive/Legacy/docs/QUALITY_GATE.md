# Quality Gate

Before should clear a `20 / 20` quality bar before a branch is treated as release-grade.

This gate is intentionally stricter than "the default suite is green." It is designed to protect:

- runtime integrity
- privacy boundaries
- recovery continuity
- memory governance
- UI stability
- on-device adaptability
- shared-state hygiene

## Apex Standard Library

The executable `20 / 20` gate is the release floor.

The full `200`-standard apex library lives at:

- [QUALITY_GATE_200.md](/Users/changgeng/Project/Project06/Project06/docs/QUALITY_GATE_200.md)
- [QUALITY_GATE_DOUBLE.md](/Users/changgeng/Project/Project06/Project06/docs/QUALITY_GATE_DOUBLE.md)
- [QUALITY_GATE_EXTREME.md](/Users/changgeng/Project/Project06/Project06/docs/QUALITY_GATE_EXTREME.md)

That document defines the long-range operating-system-grade standard. The runnable gate should evolve by sampling more of that library over time, not by inventing a fresh bar on each iteration.

The `double-difficulty` runnable companion lives in `QUALITY_GATE_DOUBLE.md` and is meant to pressure the same system twice instead of trusting one green run. The `extreme` gate then adds a third-pass soak plus repeated high-risk subsets for determinism and fatigue resistance.

## 20-Point Standard

Each item is worth `1` point. The branch passes only at `20 / 20`.

1. `xcodegen generate` succeeds without breaking the project.
2. `xcodebuild -list` succeeds so scheme/project metadata is healthy.
3. Full `Before` scheme tests pass.
4. `BeforeUISmoke` passes once.
5. `BeforeUISmoke` passes a second time to catch simple flake.
6. Recovery continuity tests pass.
7. Record restoration and replay tests pass.
8. Protected launch + pending reflection handoff tests pass.
9. Widget-safe snapshot and public-copy privacy tests pass.
10. Shared protected state tests pass.
11. Support inbox + shared life protected storage tests pass.
12. Runtime admission and circuit-breaker tests pass.
13. Provider routing, capability, and execution profile tests pass.
14. Prompt contract, debug privacy, and response cache tests pass.
15. Telemetry, budget, and coordinator observability tests pass.
16. Memory governance / trust / rebuild tests pass.
17. Neural, rule, and review engine tests pass.
18. Runtime asset catalog / bridge / on-device library tests pass.
19. Launch, notification, reminder, and action-surface tests pass.
20. The worktree remains clean after the gate run.

## Why This Bar Exists

- A local-first cognition system cannot rely on one happy-path suite.
- Storage, widget, and shared-container surfaces carry privacy risk.
- Recovery must survive relaunch, interruption, and replay.
- Runtime adaptation only matters if routing, budgets, and telemetry stay deterministic.
- Memory and response-cache behavior must remain governed as history grows.

## Command

Run the gate from the repo root:

```bash
./scripts/run_quality_gate.sh
```

The script prints a scored summary and exits non-zero if the branch does not hit `20 / 20`.
