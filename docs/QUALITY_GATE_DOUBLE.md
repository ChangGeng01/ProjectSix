# Double-Difficulty Quality Gate

Before should clear a `40 / 40` pressure gate before we say the original `200+` test surface has been pushed to a meaningfully harder bar.

This gate is not a replacement for the existing release-floor gate in [QUALITY_GATE.md](/Users/changgeng/Project/Project06/Project06/docs/QUALITY_GATE.md). It is the `double-difficulty` companion:

- repeatability over one-off green runs
- watch-companion health in addition to iPhone health
- re-execution of high-risk suites instead of trusting one pass
- explicit pressure on recovery, launch, storage, memory, routing, and prediction paths

## 40-Point Standard

Each item is worth `1` point. The branch passes only at `40 / 40`.

1. `xcodegen generate` succeeds.
2. `xcodebuild -list` succeeds.
3. `BeforeWatch` builds cleanly.
4. Full `Before` suite pass `#1` succeeds.
5. Full `Before` suite pass `#2` succeeds.
6. `BeforeUISmoke` pass `#1` succeeds.
7. `BeforeUISmoke` pass `#2` succeeds.
8. Recovery continuity tests pass.
9. Recovery continuity tests pass again.
10. Record restoration and replay tests pass.
11. Record restoration and replay tests pass again.
12. Launch handoff and pending reflection tests pass.
13. Launch handoff and pending reflection tests pass again.
14. Envelope, bandit, current-brain, and prediction tests pass.
15. Envelope, bandit, current-brain, and prediction tests pass again.
16. Widget privacy tests pass.
17. Widget privacy tests pass again.
18. Shared/protected state tests pass.
19. Shared/protected state tests pass again.
20. Support and shared-life protected storage tests pass.
21. Support and shared-life protected storage tests pass again.
22. Admission and circuit-breaker tests pass.
23. Admission and circuit-breaker tests pass again.
24. Provider routing and capability tests pass.
25. Provider routing and capability tests pass again.
26. Prompt contract, debug privacy, and response cache tests pass.
27. Prompt contract, debug privacy, and response cache tests pass again.
28. Telemetry and coordinator observability tests pass.
29. Telemetry and coordinator observability tests pass again.
30. Memory governance, trust, embedding, and rebuild tests pass.
31. Memory governance, trust, embedding, and rebuild tests pass again.
32. Neural, rule, and review engine tests pass.
33. Neural, rule, and review engine tests pass again.
34. On-device runtime, model catalog, and watch build-linked tests pass.
35. On-device runtime, model catalog, and watch build-linked tests pass again.
36. Launch, notification, reminder, and action-surface tests pass.
37. Launch, notification, reminder, and action-surface tests pass again.
38. Launch, notification, reminder, and action-surface tests pass.
39. Launch, notification, reminder, and action-surface tests pass again.
40. The script itself exits only at `40 / 40`.

## Command

Run from repo root:

```bash
./scripts/run_quality_gate_double.sh
```

This is the executable way to say: the existing suite does not merely pass once, it survives deliberate repetition across the riskiest local-cognition subsystems.
