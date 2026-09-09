# Journal CLI test discovery — verified correction

The three CLI integration suites now find the actual same-build executable
beside the loaded test bundle, including when SwiftPM builds into external
scratch storage. A shared macOS-only test helper keeps the four legacy lookup
locations as fallbacks and rejects directories/non-executable files. Genuine
absence is handled once during setup, before assertions; execution cannot throw
a nested skip. Product code, process arguments and all32 existing integration
cases/assertions are unchanged.

The implementation started at397833fa34583b8c108b1da3aff460f4c4ab282f. Its real
discovery regression first failed with1 expected assertion and no skips. The
three complete integration suites plus8 locator cases subsequently passed:
41executed,0failures,0skips, including all32 pre-existing integration cases.

Independent review was spec-compliant and requested one test-teardown change:
do not suppress temporary-directory cleanup failures. That one-line correction
passed8 locator tests; scoped re-review found the finding addressed and no new
blocking regression. Root's final independent run also passed8/8,0skips,exit0
(build3.14s, tests0.011s). The unchanged integration behavior is covered by the
retained41-test run; it was not needlessly rerun for a teardown-only correction.

Commands from the development worktree:

```sh
MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --package-path BehavioralAISubstrate --build-system native --scratch-path /private/tmp/qinao-bas-native-test-1329bde3 --filter 'BAS(JournalCLIBinaryLocator|JournalCLIIntegration|JournalGroundingIntegration|BetCommitIntegration)Tests'
MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --package-path BehavioralAISubstrate --build-system native --scratch-path /private/tmp/qinao-bas-native-test-1329bde3 --filter BASJournalCLIBinaryLocatorTests
```

The root's initial sandboxed invocation could not write the normal Swift module
cache and ran no tests. A normally authorized retry completed successfully;
neither environment failure nor pre-existing compiler/native-build deprecation
warnings were hidden. No toolchain files or permissions were modified.

Full source/diff identities, original RED/GREEN outputs, both independent review
reports and root post-review output remain in this plan's private SDD workspace.
Only this concise verification note and intended source/plan changes are
uploaded, not private historical exports or runtime data.

This closes the CLI discovery failure, not the separate provider/default or
Qinao operation-ownership failures. It is not a full-package pass, DS3 readiness
claim, scan launch or merge authorization.
