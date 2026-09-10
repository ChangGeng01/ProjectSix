# Double-Difficulty Quality Gate

Before should clear a `40 / 40` pressure gate before we say the original `200+` test surface has been pushed to a meaningfully harder bar.

This gate is not a replacement for the existing release-floor gate in [QUALITY_GATE.md](/Users/changgeng/Project/Project06/Project06/docs/QUALITY_GATE.md). It is the `double-difficulty` companion:

- repeatability over one-off green runs
- watch-companion health in addition to iPhone health
- re-execution of high-risk suites instead of trusting one pass
- explicit pressure on recovery, launch, storage, memory, routing, and prediction paths

## 40-Point Standard

Each item is worth `1` point. The branch passes only at `40 / 40`.

1. `xcodegen generate` pass `#1` succeeds.
2. `xcodegen generate` pass `#2` succeeds.
3. `xcodebuild -list` pass `#1` succeeds.
4. `xcodebuild -list` pass `#2` succeeds.
5. `BeforeWatch` build pass `#1` succeeds.
6. `BeforeWatch` build pass `#2` succeeds.
7. Full `Before` suite pass `#1` succeeds.
8. Full `Before` suite pass `#2` succeeds.
9. `BeforeUISmoke` pass `#1` succeeds.
10. `BeforeUISmoke` pass `#2` succeeds.
11. Recovery continuity tests pass `#1`.
12. Recovery continuity tests pass `#2`.
13. Replay and runtime export tests pass `#1`.
14. Replay and runtime export tests pass `#2`.
15. Launch handoff and pending reflection tests pass `#1`.
16. Launch handoff and pending reflection tests pass `#2`.
17. Envelope, bandit, current-brain, and prediction tests pass `#1`.
18. Envelope, bandit, current-brain, and prediction tests pass `#2`.
19. Widget privacy tests pass `#1`.
20. Widget privacy tests pass `#2`.
21. Shared/protected state tests pass `#1`.
22. Shared/protected state tests pass `#2`.
23. Support and shared-life protected storage tests pass `#1`.
24. Support and shared-life protected storage tests pass `#2`.
25. Admission and circuit-breaker tests pass `#1`.
26. Admission and circuit-breaker tests pass `#2`.
27. Provider routing and capability tests pass `#1`.
28. Provider routing and capability tests pass `#2`.
29. Prompt contract, debug privacy, and response cache tests pass `#1`.
30. Prompt contract, debug privacy, and response cache tests pass `#2`.
31. Telemetry and coordinator observability tests pass `#1`.
32. Telemetry and coordinator observability tests pass `#2`.
33. Memory governance, trust, embedding, and rebuild tests pass `#1`.
34. Memory governance, trust, embedding, and rebuild tests pass `#2`.
35. Neural, rule, and review engine tests pass `#1`.
36. Neural, rule, and review engine tests pass `#2`.
37. On-device runtime, model catalog, and watch build-linked tests pass `#1`.
38. On-device runtime, model catalog, and watch build-linked tests pass `#2`.
39. Launch, notification, reminder, and action-surface tests pass `#1`.
40. Launch, notification, reminder, and action-surface tests pass `#2`.

## Command

Run from repo root:

```bash
./scripts/run_quality_gate_double.sh
```

This is the executable way to say: the existing suite does not merely pass once, it survives deliberate repetition across the riskiest local-cognition subsystems.

If you want to keep squeezing past this floor, the next rung is the `extreme` soak gate in [QUALITY_GATE_EXTREME.md](/Users/changgeng/Project/Project06/Project06/docs/QUALITY_GATE_EXTREME.md).
