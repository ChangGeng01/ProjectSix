# Sample ledger key preservation

Date: 2026-09-10. Base: `8ae8805994f0ab90f747b6fa72055e3c7c7626c3`.
Existing input: `DS2:integrity.ledger-key-regeneration`, candidate index row31
(ordinal30, failed/unsealed second scan). This is not a new scan.

## Bounded result

Outcome: **fixed** for this sample key-preservation/recoverability defect, with
independent bounded review and fresh root verification. No DS3-ready or
whole-repository green claim is made.

Previously, the sample combined every key read failure and every non-32-byte key
with the missing-key branch, generated new bytes and atomically replaced the file.
The ledger still rejected a wrong key later: this was lost recovery evidence, not
a proven signature bypass or a supported lower-trust attacker exploit.

The shared sample loader now:

- Returns valid existing key bytes unchanged, without further path observation.
- Refuses malformed keys and propagates non-missing read errors.
- Requires explicit missing-file status and checks actual canonical filesystem
  paths for the key and SQLite primary, WAL, SHM and rollback-journal artifacts.
  Existing/dangling entries and filesystem case aliases are not treated as absence.
- Creates a key only for a genuine first run, using non-overwrite creation.
- Does not delete, replace, repair or reset key/ledger state on failure.

This stays in `QinaoSample/SampleSovereignSpine.swift`; regression tests are in
`QinaoSampleSovereignSpineTests.swift`. Public provider APIs, host caching,
default/injected directory selection and normal cold ledger reopening are retained.
No new authority service, Keychain migration or model/provider call is introduced.

## Verification evidence

1. Original behavioral RED: native build succeeded; 10 tests ran, four regression
   methods failed with 21 assertions and zero unexpected errors; six controls passed.
2. Initial candidate passed 20 focused tests. Root's alias challenge then reproduced
   an omitted path: one case-alias test failed with two assertions on this actual
   case-insensitive test volume. The canonical path resolved the mixed-case file;
   the case was executed, not skipped.
3. After canonical-path correction: native build succeeded (11.21 seconds),
   21 tests passed, zero failures/unexpected: 11 sample spine + 10 sample session.
4. Candidate diff whitespace/error check passed. A fresh read-only reviewer found
   no concrete bypass/regression, independently confirming the exact two-file diff.
5. Root independently reran the same frozen candidate: native build8.45 seconds,
   21/21 passed, zero failures/unexpected (spine11+session10). The case-alias test
   executed without a skip. Both source hashes remained unchanged after execution
   and independent review required no revision. The test command exited0.

The original production, corrected original RED test source, pre-alias production
and all attempt logs remain in the private local SDD workspace. Cache permission
denial, a new-test actor-isolation compile error and a corrected test postcondition
are separate setup/fixture attempts, not mislabeled successful behavioral REDs.

Reproduce focused validation with the existing native toolchain and same-source
MLX library; no model assets are loaded by these selected tests:

```sh
/usr/bin/env -u QINAO_FM_E2E -u QINAO_MLX_E2E \
  -u QINAO_AFM_MULTI_TURN_E2E -u QINAO_MLX_E2E_FULL \
  -u QINAO_MLX_BENCH -u QINAO_COREML_E2E \
  -u QINAO_COREML_STRESS_20MIN -u BAS_PERF_GATE -u BAS_PERF_PRINT \
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib \
  swift test --package-path QinaoRuntimeSDK --build-system native \
  --scratch-path /private/tmp/qinao-sdk-native-test-7806dc5a \
  --filter 'QinaoSample(SovereignSpine|Session)Tests'
```

Final candidate source SHA-256:

- Production: `b2241750ef5ba92c61a45883bb3457416f494a9151a8593b64e6c6a2897ae670`.
- Tests: `328abd5d32bd753eadd95468e265e58a1fcddad2d0bea8fe49776cabcfc4b361`.
- Two-file diff: `2a8e1b402cc905db700ff0e145f526ce6483c456996c55def8e07ac81df8ad91`.

Local original RED log SHA-256:
`1346f2b86d05242e7022d3c04e051bc12060d358643a2007e814aced7591b66c`.
Case-alias RED log:
`0ca60d5461bf7ada6f08517646382489812a09dcdaeebfb55def6459710ef896`.
Implementer final green log:
`c1c3a67d39b51d727bf9ca089e2b785e2b0c57c40fd94ed41c6cb63c8853f7c0`.
Root final green log:
`a118fa2a78b2e92df764392988ca39951de5dcefcfb73928e907010dfb3bba5c`.

## Limits

These are focused native macOS tests, not a new unfiltered package baseline,
physical-device run, iOS runtime validation or full DS3 verification. The existing
native-build deprecation warning remains visible; no warning was suppressed.
The package's known broader baseline failures remain separate open work.

Non-overwrite creation is not a power-loss/fsync guarantee: interruption may leave
a partial newly created file which is refused on next load. This does not implement
full hostile-filesystem or cross-process transaction isolation, change existing
key permissions, provide encrypted snapshots, recover hidden reasoning/KV state,
or establish the broader retained-dialogue/shared-generation architecture. A
missing/corrupt key is not automatically healed; restoring a real original key is
a trusted-host operation. Pending compatibility decisions remain pending.
