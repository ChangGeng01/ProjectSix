# Ordinary CI and the iOS 27 floor

The active `test.yml` workflow runs the six existing product jobs: BAS XCTest,
QinaoRuntimeSDK XCTest, SampleHost simulator build/tests, boundary/schema/size
checks, Python fuzz tests, and locked Rust build/tests. Their triggers, product
commands, pinned actions and read-only permissions are unchanged. Checkout does
not persist credentials, load submodules or LFS, or alter safe-directory settings.
The boundary job also runs the workflow contract and iOS-floor helper unit tests.

The old admission/report job, protected admission workflow and special iOS JIT
runner coupling are retired. Their history and production readers remain in Git;
they are not prerequisites for ordinary development or PR review. No replacement
admission inputs, signing keys, runner attestations or receipt publication are
needed. Review the final PR results and obtain the user's explicit merge approval.

## Required real iOS-floor validation

Helper unit tests use controlled tool output: they do **not** prove a real build,
simulator test enumeration, or binary deployment floor. Before claiming final
iOS-floor readiness, run the existing helper on the final reviewed checkout with
a real Xcode 27 toolchain, iOS 27+ SDKs, an available arm64 iOS 27+ simulator,
Python 3 and ripgrep. Package dependencies and vendored XCFrameworks must be
available. Do not lower platform requirements or substitute fake tools to pass.

From the repository root, in Bash, set `DEVELOPER_DIR` to the actual installation
(the example path is not an assertion that it exists):

```bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode-27.app/Contents/Developer
unset QINAO_SWIFT QINAO_XCODEBUILD QINAO_OTOOL QINAO_RG
export PATH="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH"
xcodebuild -version
xcodebuild -version | /usr/bin/grep -E '^Xcode 27([.]|$)'
swift --version
xcrun simctl list devices available
python3 --version
rg --version
bash BehavioralAISubstrate/scripts/check-ios27-floor.sh "$PWD"
```

Retain the selected commit, tool versions, complete outer output and actual exit
status in the PR/final validation evidence. A nonzero result is a failed check,
not permission to skip it. If Xcode 27 or required inputs are unavailable, report
that validation as pending with the concrete missing prerequisite. No hosted
Xcode 27 availability is assumed by this workflow.

The helper resolves the package/project floor, performs device and simulator
`build-for-testing`, checks simulator test enumeration, resolved build settings
and built product minimum versions, and inspects XCFramework Mach-O deployment
metadata. It is not a substitute for the retained product tests or DS3 device
acceptance. If fresh XCFrameworks are part of the candidate, also provide their
actual paths via `QINAO_IOS27_FRESH_XCFRAMEWORKS` (colon-separated) so the helper
checks them alongside vendored binaries.
