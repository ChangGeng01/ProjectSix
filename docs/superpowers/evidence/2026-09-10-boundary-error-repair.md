# Boundary-tool error propagation — 2026-09-10

Status: focused implementation, fresh local verification and scoped independent
re-review complete. This is not whole-repository or DS3 readiness.

## Scope

The Qinao import, host SDK import and residual-marker checkers now distinguish
scanner/filter matches, legitimate no-match and actual errors. Output-open
failures are checked separately rather than confused with scanner status 1.
HUP/INT/TERM stop the checker with a nonzero status, with cleanup owned by EXIT.
Each invocation owns its temporary output directory. Existing patterns,
allowlists, target scope, build/redaction obligations and the residual delegating
shim remain unchanged. The maintained regression suite is
`scripts/test_boundary_tool_errors.py`.

## Fresh verification

Root ran the final working patch, not just a historical test log:

- `python3 -B -m unittest -v scripts.test_boundary_tool_errors`: 14 methods,
  zero failures/errors/skips, 4.795 seconds, process exit0.
- `bash scripts/check_sdk_import_boundaries.sh`: actual repository host import
  check plus actual residual shim/marker, both passed, process exit0.
- `bash -n` on all three checkers and the shim: exit0.
- `git diff --check`: exit0.

Coverage includes ordinary rg/grep controls, partial-output scanner/filter
failures, optional Qinao tests, final-delegate failures, temporary creation/open
failures, filter-only output-open failures, TERM interruption in all three
checkers, and invocation-owned cleanup. HUP/INT handlers are inspected code,
not separately claimed signal-test executions. Python3.9 grammar was checked;
the actual test runtime was Python3.14.5 on macOS with Bash3.2.

Final tested source SHA256:

| File | SHA256 |
|---|---|
| Qinao checker | 8b5c7cde4ae4110b2f7c10a9b2af657d56161a08d9e09aa64ea53dec4b490665 |
| SDK checker | 228e01b4dec67708fd8832519e3aebdc0a9bd9246868989527a7cc8f3e84867a |
| Residual-marker checker | cda115a52c6ed34edbcb00283b011adf74787c652d0846e7ff290353d38f995b |
| Regression suite | 60d78103d1b2b1af0e0af39cfd405a7bae2f8f97c5818ccb665c3d74fc8e5b72 |

## History, review and limits

Original RED: 9 methods with 8 failure records. The first implementation passed
those tests but independent review found interruption and output-open false
success paths plus incomplete success-marker assertions. Fix-round RED recorded
13 methods with 5 failures; a further focused filter-output RED recorded 1 method
with 2 failing subcases. All are retained separately from final GREEN.

The original RED copied old scripts unchanged and therefore could write their
fixed global `/tmp/bas_*` and `/tmp/qinao_*` output paths despite setting TMPDIR.
Previous contents were not captured; no claim of untouched global outputs is
made. Unknown old files were not restored or cleared. Subsequent tests used the
private-temp implementation. This limitation does not disappear with a passing
test result.

Detailed reports/logs, the initial review, and hash-verified source snapshots are
retained in this plan's private SDD workspace. No raw private support exports,
credentials or ignored runtime records are included by this document.

Independent re-review marked all three findings addressed, spec compliant and
task quality approved, with no new breakage found in the fix diff. Its exact
original probe commands were retained without rerunning those old probes.

The Qinao full Swift build and real redaction execution were not run in this
slice; their fixture failure controls are not substitutes for final builds.
This suite is not yet registered in CI's explicit module list; integration is
pending with the separately approved CI work. No model/cloud/PCC call, new
Deep Scan, merge or full DS1/DS2 finding closure is claimed.
