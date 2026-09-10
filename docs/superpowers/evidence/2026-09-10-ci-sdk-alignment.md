# Ordinary Apple CI alignment — 2026-09-10

Status: implementation, local verification and independent review complete.
DS3 is not ready and has not started.

## Scope

Four existing Apple jobs use the standard Xcode27 preview environment. Each
selects the existing Xcode.app alias, then invokes a shared read-only version/SDK
check. SampleHost additionally requires its simulator SDK and retains its exact
iPhone17e destination. Wrong/missing tools or SDKs remain visible failures.

All six jobs, triggers, pinned actions, permissions, timeouts and existing product
commands remain. Rust/Python environments and Rust assertions are unchanged.
The existing helper-test step now explicitly runs the boundary-error regression
suite and requires its real rg dependency. No skipped tests, larger paid runner,
new action, SDK installation or local tool-selection operation was introduced.

## Actual local verification

The maintained RED found four unaligned runner contexts and missing boundary-test
integration before the workflow changed. Additional original execution fixtures
also failed; two absent-step KeyErrors are recorded as such, not behavioral proof.
An initial61-test GREEN candidate was simplified before independent review to
avoid maintaining four copies of the same check; that earlier record is retained.

Final command:

```sh
python3 -B -m unittest -v scripts.test_test_workflow_owner_ledger BehavioralAISubstrate.scripts.test_check_ios27_floor scripts.test_boundary_tool_errors
```

Result:62 tests passed in60.108s, zero failures/errors/skips, process exit0.
This includes26 workflow contracts/fixture tests,22 existing floor-helper tests,
and14 boundary regressions. Actual workflow bodies invoke the actual shared
script in private fixtures; all system-select/build tools there are test stubs.
The helper and17 workflow run bodies pass Bash3.2 syntax checks. Actual runtime
was Python3.14.5; Python3.9 grammar accepted, not a native3.9 execution claim.

## Limits

No new hosted CI run has occurred. The standard preview environment is
[officially documented](https://github.com/actions/runner-images/issues/14404),
but this repository's capacity and actual iPhone17e eligibility still
require hosted execution. Previous run34399139841 remains a completed failure;
its separate Rust performance assertion is still unresolved. No merge, model
call, reset, DS3 or historical-finding closure is implied by these local tests.

Complete source identities, command outputs, initial/final candidates and review
handoff are retained in the existing solo plan's private SDD task14 records.
The independent review approved the code; its minor packaging observation
(the untracked helper missing from the initial two-file diffstat/check) is
accounted for explicitly in the final staged-file verification.
