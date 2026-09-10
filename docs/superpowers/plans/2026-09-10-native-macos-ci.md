# Native macOS CI bridge implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development for the
> bounded Task19; preserve the current solo plan's evidence workspace.

**Goal:** Connect the already locally proven native macOS build/test and symbol
graph paths to ordinary CI without weakening tests, redaction or iOS coverage.

**Architecture:** BAS and Qinao use SwiftPM's currently available native backend
and a same-checkout MLX metallib built by upstream CMake. Boundary scripts accept
one explicit native backend choice; default caller behavior stays unchanged.
SampleHost remains on its separate iOS Xcode route, with its unresolved failures
visible. This is a tactical bridge because native is deprecated, not a permanent
toolchain guarantee or a hosted-pass claim.

**Tech Stack:** Existing Swift/Xcode27, macOS Bash/Python, isolated CMake3.31.6,
vendored MLX/metal-cpp/json/fmt. No production package/dependency/lockfile changes.

**Spec:** `docs/superpowers/specs/2026-09-10-qinao-approved-decisions.md`, choices
1/14 and unchanged coverage requirements. Supporting retained evidence:
`ci-metal-hosted-diagnosis-2026-09-10.md` final addendum and
`native-symbolgraph-probe-2026-09-10.md` in the solo SDD.

## Global constraints

- Preserve commits, worktrees, dirty drafts, all prior CI results and evidence.
- No paid runner, new workflow, seventh job, skipped test, relaxed threshold,
  model/cloud/PCC/inference, simulator launch, component installation on this
  workstation, merge or DS3. Ordinary future CI tool installation is in scope.
- Keep all six jobs, existing permissions/checkouts/pinned actions, Rust default
  test profile and strict gate, Python tests, SampleHost iOS commands/destination.
- Preserve all boundary rules/allowlists and tool-failure behavior. A real
  violation or missing artifact stays failed. No PATH wrapper or compiler binary
  mutation. Do not fabricate a graph or copy an old graph into a fresh result.
- No full native/Rust rerun during implementation. Use isolated command fixtures;
  parent owns any real one-shot hosted candidate validation after review/commit.

## Design ruling and preflight

The default frontend used a failing direct Xcode Metal launcher even after an
official component download. xcrun resolved the downloaded compiler. Prior
retained native BAS/Qinao runs built and entered actual tests with the same-source
CMake metallib; those runs were not wholly green. New probe90618 exited0 and
emitted25 fresh JSON files covering19 library modules in
`<scratch>/arm64-apple-macosx/symbolgraph`, confirming the scanner's relative
layout. The scanner itself has not yet passed on this source.

Alternative1: retry unchanged component preparation — rejected, same known
resolver split. Alternative2: invent bare-package Xcode schemes/DerivedData
mapping — rejected, not established. Chosen bridge reuses the upstream CMake
target and current repository runtime loader. Cost: native deprecation and a
pinned build-tool dependency; hosted product failures may remain and are not
reclassified as tool success.

Ruling: apply the same macOS family bridge in one reviewed candidate rather than
spend multiple CI pushes on known identical preparation failures. BAS/Qinao
need the runtime metallib; boundary-only native compilation/emission does not
execute tensor code and needs no separate component/metallib download. Removing
that prerequisite is conditional on selecting native throughout the nested
boundary build path, not a claim the boundary script is shell-only.

## Task19: Native macOS CI and exact artifact handoff

**Files:**

- Modify `.github/workflows/test.yml`.
- Modify `scripts/ensure_ci_metal_toolchain.sh` and its existing tests.
- Create `scripts/prepare_ci_mlx_metallib.sh` and
  `scripts/test_ci_native_macos.py` (focused command fixtures).
- Modify only backend argument construction/invocations in
  `scripts/check_qinao_import_boundaries.sh` and
  `scripts/check_sovereign_redaction.sh`.
- Update necessary workflow/command expectations in
  `scripts/test_test_workflow_owner_ledger.py` and
  `scripts/test_boundary_tool_errors.py`; retain behavioral assertions.
- Parent owns this plan, public evidence and commit. No other source ownership.

**Interfaces:**

1. Metal prerequisite keeps its existing SDK-only invocation/default direct
   launcher checks. Add optional leading `--resolver xcrun` or
   `--resolver selected-xcode`; reject missing/unknown values/SDKs before tools.
   xcrun mode skips only the unused direct launcher probe, retaining each actual
   SDK probe, maximum one official download, post-download verification and
   visible refusal. Default behavior and iOS use remain unchanged.
2. New helper takes no arguments and requires existing writable `RUNNER_TEMP`
   and `GITHUB_ENV`. It creates a fresh unique retained scratch with mktemp;
   never clears/reuses another artifact or cleans failed output. Inside it:

```sh
python3 -m venv "$scratch/tools"
"$scratch/tools/bin/python" -m pip install --disable-pip-version-check \
  --no-deps cmake==3.31.6
cmake="$scratch/tools/bin/cmake"
"$cmake" --version
"$cmake" -S "$vendor/mlx" -B "$scratch/build" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DMLX_BUILD_METAL=ON -DMLX_METAL_JIT=OFF \
  -DMLX_BUILD_TESTS=OFF -DMLX_BUILD_EXAMPLES=OFF \
  -DMLX_BUILD_BENCHMARKS=OFF -DMLX_BUILD_PYTHON_BINDINGS=OFF \
  -DMLX_BUILD_PYTHON_STUBS=OFF -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
  -DFETCHCONTENT_SOURCE_DIR_METAL_CPP="$vendor/metal-cpp" \
  -DFETCHCONTENT_SOURCE_DIR_JSON="$vendor/json" \
  -DFETCHCONTENT_SOURCE_DIR_FMT="$vendor/fmt"
"$cmake" --build "$scratch/build" --target mlx-metallib --parallel 8
```

   `vendor` is the absolute repository `BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx`.
   Require all four input directories; record the successful pinned CMake version.
   Only after successful commands and a nonempty regular output file at
   `build/mlx/backend/metal/kernels/mlx.metallib`, print its path/size/SHA-256 and
   append its absolute `MLX_METAL_PATH` to GITHUB_ENV for the later test step.
   Reject newline-containing scratch/output-record paths. No environment record
   on failure, no ignored download/configure/build failure or unchanged retry.
3. Boundary scripts accept `QINAO_SWIFT_BUILD_SYSTEM` unset/`default`/`native`.
   Unset/default use their old commands. Native uses Bash argument arrays:

```sh
swift build "${swift_backend_args[@]}"
swift package "${swift_backend_args[@]}" dump-symbol-graph
# native array: (--build-system native); default array: ()
```

   Reject any other value before build/emission. Preserve the existing default
   `.build/*/symbolgraph` scanner, all declarations/rules and failure statuses.
   Do not add a skip-emission or arbitrary command-arguments option.
4. BAS/Qinao CI: retain selected Xcode guard; prepare Metal using xcrun mode,
   add existing pinned setup-python action/version3.14.5 as needed for isolated
   venv support, run the helper, then unfiltered `swift test --build-system native`
   in their existing packages. MLX_METAL_PATH comes only from successful helper.
   Boundary job: explicitly set `QINAO_SWIFT_BUILD_SYSTEM: native`, remove its
   now-unused Metal preparation step, keep every existing check/helper-test and
   add the new focused fixture module. SampleHost remains unchanged.

- [x] First add genuine failing fixtures for xcrun-only resolver and actual
  workflow native/artifact handoff against current implementation; run/save RED.
  Keep all tool fixture paths isolated: no real installer/compiler/build/model.
- [x] Implement the exact interfaces above. Test ready/missing/post-install
  failure resolver cases, invalid arguments, setup/pip/configure/build failures,
  missing/empty artifact, unsafe output record, quoted paths, fresh scratch and
  one successful GITHUB_ENV handoff. Test default/native/invalid boundary choice
  and actual nested build/emission argument order/failure propagation.
- [x] Verify retained workflow structure and all old behavioral contracts,
  changing only expectations made obsolete by the explicit new backend. No
  delete/skip of failure cases or static-only replacement for command fixtures.
- [x] Run one final covering fixture command after completed source:

```sh
python3 -B -m unittest -v scripts.test_ci_native_macos \
  scripts.test_ci_metal_toolchain scripts.test_test_workflow_owner_ledger \
  scripts.test_boundary_tool_errors \
  BehavioralAISubstrate.scripts.test_check_ios27_floor
```

- [x] Save exact commands/full output/source identities, self-review, freeze a
  task-only diff and hand ownership back for independent review. No Git write,
  push, real build/download, simulator, model, network or subagent by implementer.

## Cross-file consistency

Implementation accepted after independent fix-round1 review: both Important
findings addressed, no open findings. The final91-test command exited0 after
relative RUNNER_TEMP normalization and all test amendments. Earlier90-test
outputs,26-test amendment check, genuine REDs and both reviews remain preserved;
see the matching public evidence. Native Bash3.2 uses the tested empty-array-safe
expansion rather than the illustrative array spelling above. Hosted product
validation remains pending; SampleHost/overall readiness is not claimed.

| Producer / consumer | Required invariant |
|---|---|
| Resolver / CMake | xcrun compiler, same selected Xcode; no direct-stub gate |
| Helper / tests | unique same-source nonempty artifact; export after success only |
| Boundary parent / child | same explicit native choice; no hidden default rebuild |
| Graph producer / scanner | real fresh default `.build` relative layout retained |
| Native / SampleHost | macOS evidence never substituted for iOS validation |
| Fixture / hosted | isolated tests prove command contract only, not runner success |
| Task18 / Task19 | Rust source frozen/committed; no timing or threshold changes |
