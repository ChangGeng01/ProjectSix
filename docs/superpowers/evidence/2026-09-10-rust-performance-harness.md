# Mandatory Rust performance harness — local verification

The existing performance check now runs as one ordinary Cargo integration test,
separate from the other 39 unchanged unit tests. Production kernels, dispatch,
manifests and lockfiles are unchanged. B=8/L=128/D=128, three warmups, 30 measured
calls per implementation, positive times and both unconditional strict v2<v1
and v2<sequential comparisons remain mandatory.

The harness requires successful results, checks bitwise output agreement before
timing, observes inputs and outputs, includes result destruction in each timed
call, and counterbalances the order. It uses the unmodified global Rayon pool;
it does not force a favorable worker count, ignore the test or relax thresholds.

Verification used Rust 1.96.0 with existing locked dependencies, offline mode
and the default test profile (Cargo reports unoptimized + debuginfo):

- Discovery found 39 unit tests and one integration test.
- One complete pre-review run passed 40/40, with no ignored or filtered tests.
  Observed totals: sequential 79.157 ms, v1 39.220 ms, v2 12.885 ms; 18 workers.
- Independent review required recording the environment before measurement.
  After that isolated fix, one covering integration run passed 1/1, with no
  ignored/filtered tests: sequential 111.978 ms, v1 54.525 ms, v2 17.111 ms;
  18 workers. The full suite was not repeated after the print relocation.
- Scoped re-review confirmed the finding addressed, spec compliant and quality
  approved, with no new Critical/Important breakage.

Commands ran from `BehavioralAISubstrate/Cargo`, with `RAYON_NUM_THREADS` and
`RUST_TEST_THREADS` unset and the retained Cargo target directory:

```sh
rustup run 1.96.0 cargo test --offline --locked -p bas-mamba-scan -- --list
rustup run 1.96.0 cargo test --offline --locked -p bas-mamba-scan -- --nocapture
rustup run 1.96.0 cargo test --offline --locked -p bas-mamba-scan \
  --test scan_parallel_v2_performance -- --nocapture
```

The old unused-Arc import warning remains outside this patch; its absence from
the integration-only invocation does not mean it was fixed. No benchmark matrix,
unchanged retry, optimization-profile change, model or network operation ran.
Raw output and exact source/diff identities are retained in the solo-readiness
workspace's `task-18-report.md` and associated logs/reviews.

These local passes do not explain or close the earlier hosted failures, prove
shared-runner timing stability, validate whole-workspace CI, approve merge or
establish DS3 readiness. All failed hosted histories remain preserved.
