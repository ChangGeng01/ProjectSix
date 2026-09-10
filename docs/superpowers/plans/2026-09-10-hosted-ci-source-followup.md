# Hosted CI source follow-up

> Use subagent-driven-development for the bounded Task21 after Task20 source
> handback. Reuse the existing solo recovery workspace; do not start a second
> source writer or contend with its Swift validation.

Goal: correct three concrete failures exposed by ordinary CI34446191538 while
preserving actual product coverage and historical results. This is not DS3.

Status: implementation and local validation completed on 2026-09-10. The final
three Python modules passed 52 tests (31.135s, exit 0); the native
BASArtifactStoreTests passed 18 tests (exit 0). Independent review approved spec
compliance and code quality, with no critical/important findings. Existing
unrelated native warnings remain. Actual hosted Xcode compilation, fresh
metallib construction and iOS compiler consumption await a new-head CI result;
this is not an App persistence or DS3-readiness acceptance claim.

Authority: approved decisions1/2/14 permit ordinary technical fixes/API migration
and standard CI, not merge, new scan, paid runners, data/history removal or model
fallback. Task19's scoped fixture approval did not establish hosted success.

## Evidence and design

- BAS/Qinao installed CMake3.31.6 and prepared the SDK-resolved Metal compiler,
  then failed fresh offline CMake generation for missing gguflib-src/fp16.c.
  Root's retained `ci-offline-metallib-probe-2026-09-10.md` reproduces this and
  records successful fresh generation with only MLX_BUILD_GGUF=OFF added. The
  first local probe also had a sandbox cache diagnostic; the second used normal
  compiler-cache access. Both hosted failures independently confirm the missing
  dependency. These probes have finished; do not repeat them unchanged.
- The standalone mlx-metallib target depends on AIR/kernel inputs, not GGUF IO.
  Disable that unused IO component only in this temporary CMake recipe. Do not
  change the Swift package, vendored source or runtime GGUF support. The prior
  local cache had disconnected mode OFF, unlike the new CI recipe.
- Boundary native compilation reached BASMemory, then the hosted compiler
  rejected Optional.map capturing db in BASArtifactSQLiteStore:244 before later
  actor-isolated COMMIT/ROLLBACK uses. Use an explicit conditional inside the
  same method/transaction. No new isolation annotation, unsafe cast, Sendable
  declaration, suspension point, detached task or lock is needed.
- SampleHost's current failure is still in preparation, not its product build.
  The complete log confirms both SDK-qualified compilers work after official
  component acquisition, but the extra fixed launcher fails. The read-only
  `samplehost-metal-resolution-2026-09-10.md` handback establishes no supported
  manual Metal executable/toolchain override. Use existing xcrun resolver mode
  for this preparation too, then let the unchanged Xcode build actually verify
  automatic component resolution. Do not invent a new scheme or compiler path.

Ruling: fix the unused standalone dependency and remove the optional closure
capture — both are directly supported by source and actual logs — cost if wrong:
the later hosted run can still reveal another configuration/compiler difference;
local success is never represented as that hosted verdict.

Ruling: accept official SDK-resolved compiler readiness before the real iOS build
— the extra fixed launcher is not established as the compiler that Xcode must
use after component registration — cost if wrong: that build still fails visibly
and requires toolchain-image diagnosis. No build or test failure is suppressed.

Alternatives not selected: enable arbitrary dependency downloads for unused
GGUF, reuse a warm build cache, or suppress Swift isolation checking. These add
scope or weaken the diagnostic without correcting the actual narrow boundary.

## Global constraints

- Preserve all original data, keys, commits, logs, drafts and current source work.
- Do not change tests/thresholds/platform floors/CI jobs or skip checks. Keep
  both iOS xcodebuild commands, scheme and destination unchanged. Only its
  preparation resolver changes; actual iOS compiler consumption remains unproved.
- No dependency/lockfile/vendor/schema changes; no real datastore migration.
- No models/cloud/PCC/app/simulator/new scan/merge, component installation or
  broad native suite. Parent owns Git writes, PR updates and hosted validation.
- Use retained BAS scratch only after Task20 releases it; one source writer.

## Task 21: Hosted compiler preparation and actor-local CAS compilation

Owned files:

- `scripts/prepare_ci_mlx_metallib.sh`.
- `scripts/test_ci_native_macos.py`.
- `.github/workflows/test.yml`: only SampleHost's preparation command.
- `scripts/test_ci_metal_toolchain.py` and
  `scripts/test_test_workflow_owner_ledger.py`: only necessary actual-command/
  workflow expectations and additional controls; retain default helper tests.
- `BehavioralAISubstrate/Sources/BASMemory/BASArtifactSQLiteStore.swift`.
- `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASArtifactStoreTests.swift`
  only for explicit missing branch assertions, not wholesale fixture rewrites.
- Parent owns this plan, public evidence and commit.

- [ ] Read the two actual CI failure sequences and completed real CMake probe
  record. Inspect the exact source/test branch and existing transaction tests.
- [ ] Before changing the helper, extend the exact executed-command fixture to
  require `-DMLX_BUILD_GGUF=OFF` in its standalone configure command. Run/save
  the genuine focused failure, then add the flag and brief scope comment.
  Do not simulate a whole CMake dependency resolver in a fake tool.
- [ ] Replace the Optional.map in put with `let updatedHead: BASArtifactHead?`
  plus explicit `if let headUpdate` assigning the existing applyHeadCAS result,
  else nil. Keep the same do/catch transaction, arguments and operation order.
  The preserved hosted compiler failure is the pre-fix build RED; an older
  local compiler need not reproduce it and must not be portrayed as doing so.
- [ ] Retain all current store tests. The existing suite covers ordinary nil
  head puts, CAS success/scope/stale/concurrent winners, revision overflow
  rollback, attestation/corruption/schema and reopen. Add explicit receipt/head
  nil assertions only if absent; no irrelevant new concurrency framework.
- [ ] Add/adjust behavioral workflow fixtures before editing the SampleHost step:
  require `bash scripts/ensure_ci_metal_toolchain.sh --resolver xcrun macosx
  iphonesimulator`, then make only that one workflow-command amendment. Ensure
  both SDK probes succeed before product execution; a failed SDK probe after
  installation must still stop it. Default selected-xcode helper semantics stay.
- [ ] Run final `python3 -B -m unittest -v scripts.test_ci_native_macos
  scripts.test_ci_metal_toolchain scripts.test_test_workflow_owner_ledger` once
  after completed helper/test amendments. This executes real helper/workflow
  snippets against fixtures; it does not replace the actual CMake probes.
- [ ] Inspect selected store-test bodies (model-free temporary SQLite fixtures),
  then run one native `--filter BASArtifactStoreTests` using the existing
  `/private/tmp/qinao-bas-native-test-1329bde3` scratch and same-source
  `/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib`.
  Use the Task20 no-model environment unsets. No full-suite rerun or cache clean.
- [ ] Preserve exact commands/full logs/session IDs on yield; source/diff hashes,
  test counts/observed exits, warnings, self-review, limitations. Freeze scoped
  diff without staging. Parent independently reviews before commit/push.

## Consistency check

| Producer/consumer | Checked requirement |
|---|---|
| CMake recipe/Swift package | only standalone metallib config changes; actual package IO retained |
| Helper/command fixture | one exact additional flag, same fresh artifact/error handoff |
| put/CAS/COMMIT/ROLLBACK | same actor method and order, explicit branch removes capture only |
| SampleHost prep/build | real SDK compiler probes first; unchanged actual iOS build/test verdict |
| Existing store tests/new compiler | runtime regressions checked locally; hosted compile remains separate |
| Task20/Task21 | source ownership serialized and actual base recorded at dispatch |

Dispatch base: `8831179d6126c1917b87df65653c2835127719b1`. Task20 accepted and
committed; its source and retained BAS scratch are released. One fresh Task21
implementer owns this bounded source/build slice; root retains docs/Git/review.
