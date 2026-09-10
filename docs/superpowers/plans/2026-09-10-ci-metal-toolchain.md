# Task 16 — prepare the hosted Metal compiler

**Local completion checkpoint:** Initial implementation plus fix round1 are
complete; final74tests passed with no skips/failures. The same independent
reviewer marked the original Important finding addressed and approved the
scoped change with no new findings. Hosted installation and actual product
builds still require a post-commit CI run; no merge or DS3 approval is implied.

**Independent-review amendment:** The original xcrun-only requirement below is
insufficient. Existing retained diagnostics establish xcrun success while the
direct Xcode launcher used by builds fails. Fix round1 must verify both before
skipping installation and after installation, using the effective selected
developer directory. See the retained task-16-fix1-brief for bounded controls.
The original plan and first 70-test result remain historical evidence, not an
approved repair.

This is an additive repair under the approved solo-readiness plan, not DS3.
Task 15 independently owns the SwiftData sources and native build scratch.

## Evidence and scope

Hosted run 34435310975 at b0413146 ended with Python/Rust successful and four
Apple jobs failing Metal compilation. SampleHost explicitly reports a missing
Metal Toolchain. All four already selected Xcode 27 / SDK 27 successfully.
The other three share the failing vendored MLX Metal build, so the missing
component is a supported common-cause inference, not yet a verified repair.

Official WebKit build instructions for Xcode 26+ prescribe
`xcodebuild -downloadComponent MetalToolchain`:
https://webkit.org/build-tools/
The local read-only `xcrun --sdk macosx metal --version` probe succeeded on the
already installed Xcode 27 beta compiler; no local installation was performed.

Owned files: new `scripts/ensure_ci_metal_toolchain.sh`, new
`scripts/test_ci_metal_toolchain.py`, existing ordinary workflow and its
`scripts/test_test_workflow_owner_ledger.py` contract. Root owns evidence.
Do not change SDK helper semantics, Swift sources, model access, deployment
floors, runner labels, action pins, permissions, job timeouts, destination,
existing product commands or Rust performance thresholds.

## Implementation and acceptance

1. Add a workflow assertion showing all four Apple jobs lack a compiler
   preparation step after selection and before product commands; capture actual
   assertion RED against the unchanged workflow. Add isolated helper fixtures.
2. Implement a Bash 3.2 helper requiring explicit supported SDK arguments
   (macosx / iphonesimulator). Validate all arguments before any command.
   Probe the executable with `xcrun --sdk SDK metal --version`.
   Already available: no download. If a probe fails: one official component
   download, then verify all requested SDKs. Failed download or re-probe stops
   the job visibly. No retries, false success or global configuration changes.
   Only hosted CI invokes this installing helper; tests use owned fake tools.
3. Add one early preparation step to each Apple job; SampleHost checks macosx
   and iphonesimulator, others macosx. Add the new regression module to the
   existing helper-test command. Keep all six jobs and full existing checks.
4. Fixture tests execute the actual helper and actual workflow preparation
   bodies with PATH restricted to private stub commands: available compiler,
   missing compiler repaired, only simulator missing, download failure,
   still-missing compiler, both SDKs missing, invalid/empty arguments, missing
   tools and no product marker after failure. No real installation/network.
   Existing contract mutation tests reject deleted/skipped/masked steps and
   missing regression membership.
5. Run focused RED/GREEN, then all four CI/helper/floor/boundary modules on final
   source with Bash syntax and Python 3.9 grammar compatibility checks.
   Save exact command outcomes/counts and limits. Obtain independent review,
   resolve findings, commit only intended files/evidence, then ordinary PR CI.
   Local fixtures do not prove hosted installation, product tests or DS3 ready.

Root implements this independent initial CI slice while Task 15 runs, following
executing-plans/TDD; the available worker is already occupied and previous
dispatch attempts hit the agent-thread limit. Review remains independent and
root will not implement fixes to its own independent-review findings.
