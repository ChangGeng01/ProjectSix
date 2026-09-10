# Hosted Metal compiler preparation

The ordinary CI follow-up to b0413146 keeps all six jobs, existing product tests,
SDK27 floors, exact simulator destination, standard runners, permissions and
action pins. Four Apple jobs now resolve the effective selected Xcode developer
directory with the read-only selector, including a `DEVELOPER_DIR` selection,
then check both its direct XcodeDefault `metal` launcher and every requested
SDK's `xcrun` launcher. If either check fails, they download Apple's Metal
Toolchain at most once and recheck both launcher forms before any build. The
existing read-only SDK helper remains read-only.

This addresses evidence from
[run34435310975](https://github.com/ChangGeng01/ProjectSix/actions/runs/34435310975):
Python and Rust succeeded, but the four Apple jobs failed in MLX Metal
compilation. SampleHost explicitly reported a missing Metal Toolchain. The
shared cause for the other three is an inference to verify on the next run.
[Official WebKit build instructions](https://webkit.org/build-tools/) document
the component installation command. No download was executed on the local host.

Verification on the proposed source:

- Initial workflow RED and 70-test implementation result remain retained as
  historical evidence. Independent review then identified that `xcrun` success
  did not prove the direct launcher used by product builds was usable.
- Fix-round behavioral RED: one test, one expected failure, natural exit1. With
  `xcrun` succeeding and the selected direct launcher failing, the reviewed old
  helper skipped download and reached the product marker.
- Fix-round focused GREEN: 11 tests, zero failures, 3.881 seconds, exit0.
- Final four-module suite: 74 tests, zero failures/skips, 58.760 seconds, exit0.
  This includes 27 workflow-contract, 22 iOS-floor, 14 boundary and 11
  Metal-helper tests. Private fake selector, Xcode tree and executables cover
  effective `DEVELOPER_DIR` selection, a selected path with spaces, direct-good
  and direct-bad launchers, install/no-install, failed install, failed rechecks,
  missing tools, selector failure/empty output, invalid input and actual workflow
  preparation bodies. No fixture resolves a host Xcode, compiler or installer.
- All 21 workflow run bodies pass the existing Bash3.2 syntax test; the new
  helper also passes Bash syntax checking. Two changed Python files parse with
  Python3.9 grammar under the installed interpreter, not an actual3.9 runtime.

Focused same-reviewer re-review approved the fix with no open findings.
Ordinary hosted CI is still pending. Local
fixtures prove neither hosted installation nor full Swift/package/simulator
success. The prior Rust timing failure remains distinct: its unchanged assertion
passed the cited CI run, but one pass is not stable performance evidence. No
merge, DS3 or whole-candidate readiness claim.
