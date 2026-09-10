# CI failure diagnostics implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development for
> Task26 in the existing solo workspace. Root owns Git and independent review.

**Goal:** make the next ordinary hosted run retain actionable XCTest-crash and
symbol-graph failure evidence without changing whether the original checks pass.

**Architecture:** one small shared Bash test runner keeps the two normal Swift
commands and collects failure-only diagnostics. The existing redaction helper
adds an explicitly CI-only diagnostic branch; its scanner and local behavior
stay unchanged. Ordinary GitHub artifacts retain the bounded selected outputs.

**Tech Stack:** Bash 3.2+, Python unittest subprocess fixtures, existing GitHub CI.

**Spec:** `docs/superpowers/specs/2026-09-10-qinao-approved-decisions.md`, necessary
ordinary CI and preservation. The existing solo workspace's
`ci-34456200441-native-diagnosis.md` and `ci-next-probe-proposal-v2.md` supply
observations, not a root-cause verdict or an instruction to copy v2 verbatim.

## Global constraints

- Preserve original source, tests, drafts and diagnostic bytes. No cleanup of
  old evidence, whole build trees, model caches, user data or Git history.
- No scan, push, hosted dispatch, native Swift/Xcode execution, model call,
  download, runner/timeout change, new permission or paid service in this task.
  Tests run scripts against temporary command stubs, not the real toolchain.
- Preserve all six CI jobs, ordinary primary test scope, existing setup and
  boundary checks. No test filter, continue-on-error, permanent framework
  disable, partial-graph acceptance or converting diagnostic success to green.
- This is a finite diagnostic patch, not developer authorization, snapshot,
  admission or persistence infrastructure. Actual App recovery remains separate.
- Every local verification attempt gets a fresh log allocated inside its own
  command. Never overwrite an earlier failed attempt's log on retry.

## Task26: Retain the first failure and run one informative diagnostic

**Files:**

- Create `scripts/run_ci_swift_tests.sh`: two exact modes, normal test + crash capture.
- Modify `scripts/check_sovereign_redaction.sh`: CI-only graph-failure branch.
- Modify `.github/workflows/test.yml`: call runner and upload failure artifacts.
- Create `scripts/test_ci_failure_diagnostics.py`: behavioral subprocess tests.
- Modify `scripts/test_ci_native_macos.py`: keep actual metallib-to-test handoff
  test working through the new runner; adjust boundary env expectation only.
- Modify `scripts/test_test_workflow_owner_ledger.py`: update ordinary workflow
  expectations for these exact steps/env/action and new test module only. Keep
  historical tests, parser and existing mutation coverage; do not expand the
  old development-workflow validation machinery or weaken unrelated contracts.

**Interfaces and exact commands:**

```bash
# Invoked from repository root for BAS, existing Qinao directory for Qinao.
bash scripts/run_ci_swift_tests.sh bas
bash ../scripts/run_ci_swift_tests.sh qinao

# Runner mode selects these unchanged primary argument arrays:
test_cmd=(swift test --build-system native --package-path BehavioralAISubstrate) # bas
test_cmd=(swift test --build-system native) # qinao
```

- [x] Add subprocess RED tests before implementation. A new fixture creates
  a repository path containing spaces, scripts, QinaoRuntimeSDK, RUNNER_TEMP,
  fake HOME/Library/Logs/DiagnosticReports and PATH stubs. Copy actual scripts
  under test; use real `/bin/bash`, filesystem operations and `mktemp`. Stub
  only Swift, sleep and selected error-injection commands. Swift logs exact
  argv/cwd and emits different primary/probe bytes/exits; fake sleep records
  calls without waiting. Never call installed Swift. Concrete assertions:

```python
def test_probe_success_cannot_hide_primary_failure(self):
    result = self.fx.run_tests("bas", primary_rc=139, probe_rc=0)
    self.assertEqual(result.returncode, 139, result.stderr)
    self.assertEqual(self.fx.swift_calls(), [
        "test --build-system native --package-path BehavioralAISubstrate",
        "test --build-system native --package-path BehavioralAISubstrate --skip-build --disable-swift-testing",
    ])
    diag = self.fx.diagnostics("bas-xctest-diagnostics.*")[0]
    self.assertEqual((diag / "primary.log").read_text(), "primary output\n")
    self.assertEqual((diag / "full-xctest-retained-products.log").read_text(), "probe output\n")

def test_graph_retry_never_enters_scanner_or_loses_first_bytes(self):
    result = self.fx.run_graph(ci=True, graph_rc=42, build_rc=0, retry_rc=0)
    self.assertEqual(result.returncode, 1, result.stderr)  # existing CLI contract
    self.assertEqual(self.fx.scanner_calls(), [])
    diag = self.fx.diagnostics("qinao-symbolgraph-diagnostics.*")[0]
    self.assertEqual((diag / "first-pass/dump.log").read_text(), "first dump failed\n")
    self.assertEqual(self.fx.graph_bytes(diag, "first-pass"), b"original graph")
    self.assertEqual(self.fx.graph_bytes(diag, "after-test-products"), b"retry graph")
```

  Implement the named fixture helpers in this test file. Also cover both modes'
  success (one command, no probe), two consecutive unique retained directories,
  primary/probe both failing, tee/copy failure retaining primary failure, no new
  report (at most five polls/two-second sleeps), matching new report copied,
  old/unrelated report excluded, graph local failure (no extra build/retry),
  local and CI graph success (normal scanner still runs), build/retry failures
  recorded separately, and preservation failure stopping graph retry before it
  can overwrite first-pass bytes. Verify actual workflow step execution and
  upload configuration, not just matching source strings.

- [x] Run focused RED using the command below. Missing-file/API RED alone is
  insufficient: preserve at least a behavioral RED for swallowed original status
  or overwritten graph bytes before accepting the implementation.

- [x] Implement the shared runner. Reject arguments other than exactly one
  `bas` or `qinao` with exit2 before Swift. Resolve repository/cwd from the
  script location. Allocate `mktemp -d "$RUNNER_TEMP/$name-xctest-diagnostics.XXXXXX"`
  and a marker in that directory before primary execution. Stream primary
  output through tee, capture both pipeline statuses immediately, and avoid
  errexit aborting evidence collection. On primary success do not run probes;
  a failed output capture must not report green. On primary failure, run exactly
  one full unfiltered retained-products XCTest-only command, preserve its output
  and exit, collect reports, and always return the original nonzero status.

```bash
set +e
"${test_cmd[@]}" 2>&1 | tee "$diag/primary.log"
statuses=("${PIPESTATUS[@]}")
primary_rc=${statuses[0]}
capture_rc=${statuses[1]}
printf 'primary=%s\nprimary_capture=%s\n' "$primary_rc" "$capture_rc" >"$diag/exits.txt"
# If primary_rc != 0, collect once; secondary errors are recorded/reported.
# Final result: nonzero primary_rc wins, otherwise return capture_rc.
```

  New reports must be newer than the marker and match only `xctest*.ips`,
  `xctest*.crash`, `*PackageTests*.ips` or `*PackageTests*.crash` under
  `$HOME/Library/Logs/DiagnosticReports`. Poll at most five times, sleeping
  two seconds only between unsuccessful polls. Copy into `crash-reports/`
  with unique indexed filenames; retain selected paths and explicit no-report
  outcome. Never copy all HOME, environment variables, unrelated reports or
  the whole build directory. Report copy/poll failures without changing the
  original test result. No manual cache cleanup.

- [x] Extend the graph helper without touching the scanner. With
  `QINAO_CI_DIAGNOSTICS=1`, allocate a unique
  `$RUNNER_TEMP/qinao-symbolgraph-diagnostics.XXXXXX` before the first dump;
  place its log directly at `first-pass/dump.log` so a later copy failure cannot
  erase it. Without opt-in retain the existing local path, single command and
  normalized exit1 behavior. Keep the first Swift command unchanged.

  On first dump failure, record the actual graph exit immediately. Run the
  diagnostic in a separately checked plain subshell, NOT a function/subshell
  used as an `if` condition (Bash can disable errexit throughout that body).
  Preserve matching `.build/*/debug/Modules/QinaoRuntimeSDKPackageTests.swiftmodule*`
  bytes under `first-pass/modules/<path-relative-to-.build>`. Move the actual
  `.build/*/symbolgraph` directories into `first-pass/graphs/<relative-path>`
  before any retry; a hash/listing is not a substitute. Any preservation
  failure stops the diagnostic before build/retry and leaves the original log.

```bash
swift build ${swift_backend_args[@]+"${swift_backend_args[@]}"} --build-tests --verbose
swift package ${swift_backend_args[@]+"${swift_backend_args[@]}"} --verbose dump-symbol-graph
```

  Capture each command into separate `after-test-products/build.log` and
  `after-test-products/dump.log`, each exit separately. Run the fresh dump once
  even if test-product build fails, retaining the reason. Preserve resulting
  module/graph bytes under the after phase with the same relative layout.
  Record diagnostic failure separately; after any first dump failure, print
  available diagnostics and exit1, never run the scanner. Existing scanner,
  public allowlist and success decision stay byte-for-byte unchanged.

- [x] Wire the existing test step names to the helper above. Add only the
  boundary env `QINAO_CI_DIAGNOSTICS: "1"` beside the existing native setting.
  Put a failure upload after each package test and after Sovereign redaction
  (also reached when Qinao import boundaries failed and redaction was skipped).
  Use this exact action pin, seven-day retention, default compression6 and no
  overwrite or hidden-file inclusion. Distinct bas/qinao/symbolgraph names:

```yaml
- name: Upload BAS XCTest failure diagnostics
  if: failure()
  uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02
  with:
    name: bas-xctest-${{ github.run_id }}-${{ github.run_attempt }}
    path: ${{ runner.temp }}/bas-xctest-diagnostics.*
    if-no-files-found: warn
    retention-days: 7
    compression-level: 6
```

  Qinao uses `qinao-xctest`/`qinao-xctest-diagnostics.*`; graph uses
  `qinao-symbolgraph`/`qinao-symbolgraph-diagnostics.*`. No additional permissions.
  Add `scripts.test_ci_failure_diagnostics` to the existing ordinary unit command.
  Update expected-step constants and their affected tests, preserving all
  unrelated restrictions and historical tests. The native fixture must copy
  the new runner/provide its ordinary commands and continue checking the exact
  primary Swift args and nonempty MLX_METAL_PATH through actual workflow text.

- [x] Run all four affected Python modules once after focused GREEN and self-
  review; no Apple native run is needed for a stubbed shell/workflow patch:

```bash
LOG="$(mktemp /private/tmp/task-26-tests.XXXXXX)"
printf 'Retained log: %s\n' "$LOG"
/usr/bin/script -q "$LOG" python3 -B -m unittest -v scripts.test_ci_failure_diagnostics scripts.test_ci_native_macos scripts.test_test_workflow_owner_ledger scripts.test_boundary_tool_errors
```

  Focused command uses only `scripts.test_ci_failure_diagnostics`. Any required
  retry allocates another fresh log. Record actual exit/count, zero-test runs
  and warnings honestly. Finish with `bash -n` on both touched shell files and
  `git diff --check`. Save report and frozen six-file diff plus SHA-256 in the
  existing solo workspace as `task-26-report.md` and `task-26-scoped.diff`.
  No child Git writes or subagents. Root reviews and commits named files only.

## Preflight rulings and limits

| Relationship | Consistency ruling |
| --- | --- |
| Two XCTest jobs / shared helper | Keep one implementation and exact existing primary argv/cwd; diagnostic never replaces baseline coverage |
| First graph / retry / scanner | Retain original bytes before retry; first failure always exits1, scanner is never fed a partial result |
| Local CLI / hosted investigation | Extra build/retry requires explicit CI env; no heavy surprise for local boundary checks |
| Helper / workflow tests | Preserve exact command behavior through subprocess tests and update only changed ordinary step contracts |
| Task25 / Task26 | No shared source or native scratch; prior Task25 remains accepted and is not retested |
| Artifacts / user preservation | Unique invocation paths avoid overwrite; these new hosted diagnostics expire after seven days and are not permanent App storage |

The official [action definition](https://github.com/actions/upload-artifact/blob/ea165f8d65b6e75b540449e92b4886f43607fa02/action.yml)
and [v4.6.2 release](https://github.com/actions/upload-artifact/releases/tag/v4.6.2)
were checked by root. This pin is compatible, not claimed latest. Artifacts
remain subject to quota/runner cancellation; no-report is not proof of no crash.
Existing job timeouts can cut off probes; do not increase them speculatively.
SampleHost Metal availability and the native signal11 cause remain unresolved.

## Verified completion — 2026-09-10

Independent review found a real post-primary diagnostic-I/O status bug and an
associated graph-staging output gap. Fix round1 reproduced the faults with
4 test methods/5 behavioral failures, then passed those cases, all22 focused
tests and the amended75-test four-module matrix. Both shell syntax checks and
diffcheck passed. The same independent reviewer accepted all three findings
as addressed with no new breakage. No native/hosted test was substituted by
these script-fixture tests.

Exact reports/logs and original/fix/full patches remain in the existing solo
workspace, `task-26-report.md`. Amended full patch SHA-256:
`57927f3971b351cc18f5a09142c0787c71a25893205cefe91c80ae8b06948fd8`.
Root read the actual amended test output and checked the frozen patch against
the worktree. Hosted collection behavior, quota/cancellation and the underlying
native/Metal failures still require the next real CI result. DS3 is not ready
or started on the strength of this diagnostic patch.
