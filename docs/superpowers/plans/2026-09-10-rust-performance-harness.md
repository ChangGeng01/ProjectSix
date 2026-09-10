# Rust performance harness implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development for the
> bounded Task18 below. Preserve the existing solo plan's recovery workspace.

**Goal:** Make the existing mandatory timing test validate successful observable
work in a dedicated process with balanced ordering, without changing its strict
speed requirements or claiming unexplained hosted failures are solved.

**Architecture:** Relocate only the performance test into Cargo's ordinary
integration-test discovery. Keep all39 other unit tests and all production
implementations intact. Use small private test functions, no benchmark framework.

**Tech Stack:** Existing Rust1.96.0, Cargo default test profile, locked existing
Rayon dependency and the production-global thread pool; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-10-qinao-approved-decisions.md` ordinary
technical delegation and unchanged-test-threshold constraints; retained design
handback `rust-performance-harness-design-handback-2026-09-10.md` in the solo SDD.

## Global constraints

- Preserve existing commits, worktrees, branches, dirty drafts and evidence.
- No kernel, C ABI dispatch, crate/workspace manifest, lockfile or CI change.
- Preserve B=8,L=128,D=128, exactly3 warmups and30 measured calls per path, both
  unconditional strict comparisons `v2 < v1` and `v2 < sequential`, and positive
  timing assertions. No tolerance, skip, filter-only CI, retry or run-until-green.
- Use the process-global Rayon pool, not a private fixed-size pool. Do not set a
  favorable worker count. Record the observed count and default test profile.
- A pass does not prove shared-runner stability or explain the prior failures.
- No model, cloud/PCC, app, simulator, new scan, merge or data/history migration.

## Evidence and design ruling

Two hosted failures now exist on unchanged source: first run34399139841 failed
v2<sequential; new run34439301116 failed v2<v1 with seq105.869ms/v1 80.755ms/
v2 102.266ms. The intervening run passed. Root read the new raw failure block;
the three production functions, existing test and dependency contract are
unchanged. Older diagnostic matrices are complete and must not be repeated.

The old harness discards every Result, observes no output, runs a fixed order
and shares a process-global pool with unrelated tests. These are concrete
measurement limitations; none is established as the sole cause of either
hosted failure. This slice repairs those limitations while retaining the gate.
Universal worker-count guarantees, a private production pool, release-profile
certification and dedicated paid runners are separate product decisions.

Ruling: implement only the minimum test-harness design under the delegated
ordinary technical choices — it preserves the measured product path, workload
and strict comparisons — cost if wrong: hosted performance may still fail and
require separately scoped investigation; no success or guarantee is inferred.

## Task18: One mandatory, observed, counterbalanced performance test

**Files:**

- Modify only the performance function and immediately associated comments in
  `BehavioralAISubstrate/Cargo/bas-mamba-scan/src/tests.rs`.
- Create `BehavioralAISubstrate/Cargo/bas-mamba-scan/tests/scan_parallel_v2_performance.rs`.
- Root owns this plan, the report/public note and scoped commit/review.

**Interfaces:** Public existing `MambaScanShape`, `scan_sequential`,
`scan_parallel`, `scan_parallel_v2`, `MambaScanError`. No public additions.

- [ ] Preserve the exact current test/source identities and cite the retained
  real hosted RED, not an invented deterministic local timing reproduction.
  This is a test-only harness change, not a new product behavior; do not add a
  contrived failing assertion merely to obtain a RED label.
- [ ] Move the single performance test into the new integration file. Cargo's
  normal `cargo test --locked` must discover and run it with exactly one test
  in that binary, independent of the other39 unmodified unit tests. Copy the
  original fixture construction exactly using `MambaScanShape {b:8,l:128,d:128}`.
- [ ] Before all timers, call each actual scan and require Ok. Compare each
  parallel result to sequential by element `to_bits()` for true byte equality,
  not approximate numeric equality. These comparisons are outside timing.
- [ ] Use one private observed-call helper, passing all five slices and copied
  shape through `std::hint::black_box`, requiring the returned Result to be Ok,
  then consuming its Vec through black_box and dropping it before elapsed time
  is captured. Each selected path runs the same input/output/expect treatment.
  A failed scan must panic visibly, not supply a timing sample.
- [ ] Use the exact schedules below. For warmups, one call at each position in
  the three cyclic orders. For each measured permutation, time five calls of
  each listed implementation and add the full block duration to its accumulator.
  This preserves30 measured calls per path. Check accumulated call counts before
  accepting timings; do not time correctness comparisons or fixture creation.

```rust
// 0 = sequential, 1 = parallel v1, 2 = parallel v2
const WARMUP: [[usize; 3]; 3] = [[0,1,2], [1,2,0], [2,0,1]];
const MEASURED: [[usize; 3]; 6] = [
    [0,1,2], [0,2,1], [1,0,2], [1,2,0], [2,0,1], [2,1,0],
];
// After loops: warmup_counts == [3;3], measured_counts == [30;3].
// Always assert seq_ns>0, par_ns>0, v2_ns>0;
// then v2_ns<par_ns and v2_ns<seq_ns.
```

- [ ] Print actual global Rayon workers, available parallelism if obtainable,
  debug-assertions/profile context, schedule, total times and ratios. The Cargo
  command/log is authoritative for the selected test profile; do not claim an
  optimization level from cfg(debug_assertions) alone. Do not enumerate secrets
  or unrelated environment. No worker-count override or runtime reconfiguration.
- [ ] Verify discovery before timing. Use the retained idle Cargo target
  `/private/tmp/qinao-rust-ci-perf-412b6ab7` only after the controller releases
  native/CPU-heavy testing; do not benchmark concurrently with Task17 tests.

```sh
# Working directory: BehavioralAISubstrate/Cargo
env -u RAYON_NUM_THREADS -u RUST_TEST_THREADS \
  CARGO_TARGET_DIR=/private/tmp/qinao-rust-ci-perf-412b6ab7 \
  rustup run 1.96.0 cargo test --offline --locked -p bas-mamba-scan -- --list

# Exactly one final covering invocation on the completed source; retain its
# full generated output using pipefail and an owned, uniquely named tee log.
env -u RAYON_NUM_THREADS -u RUST_TEST_THREADS \
  CARGO_TARGET_DIR=/private/tmp/qinao-rust-ci-perf-412b6ab7 \
  rustup run 1.96.0 cargo test --offline --locked -p bas-mamba-scan -- --nocapture
```

- [ ] Report actual full outcome, counts, times, workers, commands, warnings,
  source identities and limits. A failed performance assertion remains failed;
  stop without unchanged retry, worker/profile tuning or threshold relaxation.
  Preserve all39 original unit test bodies and production/lock/manifest hashes.
  Freeze the two-file task-only diff and hand ownership back for independent
  spec/quality review. No staging/commit/push/subagents by implementer.

## Execution status

Implemented and independently reviewed. The original one complete local run
passed40/40. Review fix round1 moved only environment capture/output before the
timers; its one covering integration invocation passed1/1 and scoped re-review
approved the fix. No threshold or production change. Exact evidence and limits:
`docs/superpowers/evidence/2026-09-10-rust-performance-harness.md`.
The checklist above is the preserved original execution contract; completion
is recorded here without rewriting its original wording or failed CI evidence.

## Preflight consistency (retained)

| Boundary | Check/result |
|---|---|
| Unit vs integration | Move1 test, retain39; no manifest filtering required |
| Timed vs correctness work | Preflight outside timers, successful output drop inside |
| Balanced ordering vs fixed counts | Six orders x5 =30; cyclic3 warmups |
| Global pool vs product path | Same Rayon-global behavior; no four-worker substitution |
| Local vs hosted evidence | Exact current CI RED retained; no stability inference |
| Task17 vs Task18 | No shared files; CPU-heavy tests are serialized |
| Full goal vs bounded slice | No source-finding, merge or DS3-ready closure |
