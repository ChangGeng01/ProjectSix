# Complete durable vector recovery

Date: 2026-09-10. Base: `cc79e8f0b77b5d4d00c67a3df5d9a196548b4e57`.
Existing DS1 input: `occ_87c113a9c6933ab2a8c62385`, finding
`csf_a45626c796dd4cd63498f630`, rule
`bas.vector-recovery.silent-partial-success`.
The input is the stored/indexed export of the first successful scan, not a
recovered canonical sealed report. This repair does not start another scan.

## Bounded result

The corrected implementation passes 115 focused native tests and an actual iOS
App build. The one independent candidate review found two surviving paths in the
initial implementation; both were reproduced before correction and checked again
in the final tests. This is a bounded recovery-integrity repair, not a demonstrated
remotely reachable exploit or a claim that the repository is DS3-ready.

Previously, SQLite enumeration accepted any terminal step as success. A failure
before the first row became empty data, and a later failure returned its prefix.
Legacy preload inserted incrementally, and opted-in global recall startup could
publish a partial replica after a swallowed durable-read or engine-insert error.

The retained changes are:

- Vector and atom full reads, including atom IDs, require `SQLITE_DONE`; other
  terminal codes throw the existing typed error. Prepare/decode errors remain.
- `BASVectorIndex.upsertAll` validates the complete batch before any mutation in
  one actor turn. Failure preserves entries, ordering and the dimension shared
  with the int8 index. Success retains normal upsert/duplicate semantics.
- `BASSQLiteVectorIndexStorage.preloadOrThrow` uses the strict read and atomic
  batch. This is merge/upsert, not replacement: destination-only entries remain.
  Legacy best-effort public APIs remain compatible and are documented as such.
- `BASGlobalRecallRecovery` stages the real durable reads, Rust memory engine,
  resolver, synced IDs and recall seam before returning. Selected persisted vectors
  must have finite components and the host's explicit query dimension before
  insertion. The actual App publishes only the successful result; errors reach its
  existing Brain-init failure path. This global path does not re-embed or reset.
- The default routed-memory path now carries additive throwing atom/vector loaders
  through persistence, the real factory, service, brain and App. Complete reads and
  shape validation precede fallback embedding, backfill and snapshot replacement.
  Failure propagates without replacing the prior snapshot or treating a read error
  as a missing-vector repair request. Genuine missing vectors retain the existing
  local backfill behavior. The App's authoritative startup call is inside the same
  Brain-init catch; the later duplicate best-effort startup call was removed.
- Legacy-only callbacks remain compatible and explicitly best-effort; an error
  already swallowed inside a caller cannot be reconstructed. Old `refresh()` uses
  the strict path when strict hooks are supplied and preserves its snapshot on
  failure. The configured 384-dimensional App query space uses its existing static
  dimension constant; no extra model construction or provider change was added.

The startup cap, domain pin and newest-window behavior remain; newest atoms
without a vector stay pending for the existing later synchronization. The helper
uses the resolver's same effective minimum cap. Its host must quiesce startup
writers: two independently read databases are not a cross-database transaction.
Routed refreshes must likewise be serialized at session boundaries. Normal zero
vectors remain valid; this patch adds neither a nonzero-norm rule nor provider-
provenance validation. Existing nonthrowing backfill writes are not newly guaranteed
durable, and later query/delta-sync semantics are unchanged.

## Authored files

Within `BehavioralAISubstrate`:

- `Sources/BASMemory/BASSQLiteMemoryAtomStore.swift`
- `Sources/BASMemory/BASSQLiteVectorIndexStorage.swift`
- `Sources/BASMemory/BASVectorIndex.swift`
- `Sources/BASHostKit/BASGlobalRecallRecovery.swift` (new)
- `Sources/BASHostKit/BASCognitiveOSBundle.swift` (documentation)
- `Sources/BASHostKit/BASL8RoutedMemoryService.swift`
- `Sources/BASHostKit/BASCognitiveBrain+Construction.swift`
- `Sources/BASHostKit/BASCognitiveBrain.swift`
- `DeviceTestApp/Sources/App/BASEnduranceAppRunner.swift` (recovery/startup wiring)
- Five new `Tests/BehavioralAISubstrateTests` suites:
  `BASSQLiteMemoryAtomReadCompletionTests`, `BASSQLiteVectorReadCompletionTests`,
  `BASVectorRecoveryAtomicityTests`, `BASGlobalRecallRecoveryTests`,
  `BASRoutedMemoryRecoveryFailureTests`.

No dependency, target, project setting, model/provider default or later per-turn
synchronization was changed. Existing unrelated project/Keychain drafts remain.

## Ordered verification

1. Original vector behavioral RED: build succeeded, 18 tests ran, two intended
   failures and 16 passing controls, zero unexpected errors. Real system SQLite
   produced error-before-row and a proven `ROW` then error. The old read returned
   `[]` and a prefix respectively. This SQL-runtime-error fixture is not a claimed
   physical disk or `SQLITE_IOERR` injection.
2. Original atom behavioral RED: build succeeded, eight tests ran; five methods
   failed with seven assertions and zero unexpected errors; three controls passed.
   Exact-SELECT probes proved the prefix before error. Earlier compile/fixture
   failures are retained separately, not counted as accepted behavioral RED.
   Tests for new APIs initially failed compilation because those APIs were absent;
   those are not mislabeled behavioral reproductions.
3. Initial implementation native checks: core 22/22, host helper 8/8, then full focused
   selection 91/91. These intermediate results overlap, not additional coverage.
4. Root iOS27 simulator App build: `BUILD SUCCEEDED`, writer exit0 and log writer
   exit0. The new helper and actual App caller compiled. This was build only,
   signing disabled as a command setting, no App install, launch or test.
5. Root final native verification after the macOS-only repository-wiring-test
   guard: build27.90s, 91/91 tests, zero failures/unexpected, writer exit0 and log
   writer exit0. Original strict-read triggers now throw; failed preload preserves
   its destination; an actual later Rust rejection cannot replace a prior staged
   result. Empty and complete cold reopening, normal merge/duplicates, domain/cap
   behavior, missing-vector pending behavior and nearest existing suites passed.
   The int8 control measured 198/200 overlap (99%, required70%).
6. Initial source/archive hashes matched the worker's preserved post-platform-guard
   candidate; diff whitespace/error check passes. Independent review then found
   default startup swallowing an atom-read failure and global recovery accepting
   vectors that queries skip. The initial 91 tests and build do not establish that
   these newly identified paths were fixed.
7. Review-defect behavioral RED: build25.41s;11 tests, three failing methods/four
   assertions, zero unexpected errors; eight prior global controls passed. The
   actual factory with the old App callback replaced snapshot1 with0 on a read
   error. Publicly persisted mixed-dimension and NaN vectors produced two synced
   rows while the real Rust query omitted one. The original pre-run test bytes,
   archive and log remain retained. A separate missing-API compilation failure
   executed zero tests and is not mislabeled behavioral evidence.
8. Correction GREEN: global12+routed/factory9 passed21/21; relevant legacy routed
   controls passed11/11. The final combined selection passed115/115, zero failures
   or unexpected errors, terminal exit0, build0.26s. Intermediate test counts
   overlap this final selection. Controls include genuine empty/cold reopening,
   missing-vector backfill, failure before/after an actual SQLite row, decode and
   vector-read errors, unchanged prior snapshot and no premature embed/backfill,
   mixed and uniformly wrong dimensions, NaN rejection and valid zero vectors.
   An oversized but shape-consistent vector reaches a real Rust dimension-cap
   rejection; the original later-second-insert fixture is superseded by earlier
   validation, not silently claimed to follow the same path. Int8 overlap remains
   198/200=99% against the existing70% floor.
9. Root's corrected iOS27 simulator App build: `BUILD SUCCEEDED`, writer exit0 and
   log writer exit0. Actual caller/helper compilation and linking succeeded;
   build only, no App install/test/launch. Root reconciled both review findings
   against the final source and test results, not a second candidate-review cycle.
   All14 source/test files match the retained corrected archive; unrelated dirty
   project/Keychain hashes remain unchanged. Diff whitespace/error check passes.

## Reproduction commands

Run from the worktree with the existing compatible toolchain and retained
same-source MLX library. The selected tests do not load model assets:

```sh
/usr/bin/env -u QINAO_FM_E2E -u QINAO_AFM_MULTI_TURN_E2E \
  -u QINAO_MLX_E2E -u QINAO_MLX_E2E_FULL -u QINAO_MLX_BENCH \
  -u QINAO_COREML_E2E -u QINAO_COREML_STRESS_20MIN \
  -u BAS_PERF_GATE -u BAS_PERF_PRINT \
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib \
  swift test --package-path BehavioralAISubstrate --build-system native \
  --scratch-path /private/tmp/qinao-bas-native-test-1329bde3 \
  --filter 'BASSQLiteMemoryAtomReadCompletionTests|BASSQLiteVectorReadCompletionTests|BASVectorRecoveryAtomicityTests|BASGlobalRecallRecoveryTests|BASRoutedMemoryRecoveryFailureTests|BASSQLiteVectorIndexStorageTests|BASSQLiteMemoryAtomStoreTests|BASVectorRAGMVPTests/testIndex|BASADR037GlobalRecallTests|BASGlobalRecallResolverTests|BASVectorIndexNonFiniteTests|BASVectorIndexTieBreakTests|BASChapter727Int8VectorDriftGateTests/testInt8VectorIndexTopKRecallAtTen|BASL8RoutedMemoryServiceTests|BASL8RoutedMemoryServiceVectorIndexTests/testRefreshLoadsPersistedEmbeddingInsteadOfReEmbedding|BASL8RoutedMemoryServiceVectorIndexTests/testLazyBackfillUpsertsEmbeddingOnFirstRefresh|BASL8RoutedMemoryServiceVectorIndexTests/testDrainUpsertsSelfPopEmbeddingToIndex'
```

```sh
/usr/bin/env DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild build \
  -project BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj \
  -scheme BASDeviceTestApp -configuration Debug \
  -destination 'platform=iOS Simulator,id=2DEFA437-05C8-4457-B0F5-313E9A5DF167' \
  -derivedDataPath /private/tmp/qinao-keychain-ios27-sim \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO
```

The exact full logs, command records, original RED evidence and final snapshots
are retained in the private local SDD directory
`.superpowers/sdd/2026-09-09-qinao-ds3-readiness-solo/`.
Some new test-source bundles were collected after their runs; the report records
their collection times and byte comparisons, not fictitious pre-run snapshots.

SHA-256:

- Initial ten-file source/test diff (review input, before correction):
  `48020371d18652d07b11aff170f74a4b8c03074d94d0d5707cbc855d2aae4d8d`.
- Initial root native log:
  `6b00d3e9b0451877c40d63d57fcbbbafa17a4520be2410994f57367356163aa8`.
- Initial root iOS build log:
  `771bc21fd834971dee9a5aed43d48072bffe71fa4f4214086721af2003836db8`.
- Initial source/test archive (after test-only platform guard):
  `62ff06b2b5b4ab87a57a0ff1c21b6bcc2e1b34bc29725646fd54aa2dab6f8a98`.
- Review-defect behavioral RED log:
  `ba05845b30b1a299bf71dcdadcd3ee5e250d2a35b313cfcb7ab42e795cd68a09`.
- Corrected final115 native log:
  `97ae87dab70c58d2b59fd92b6b5d23ad5a2c50f4a9c694c6414bd71862195f54`.
- Corrected root iOS build log:
  `54f7f7172abaa874f7d1472b659d2de7e1d2560cd4b659ddd07a4736a4de6bc6`.
- Corrected14-file source/test archive:
  `0b08b4b19095c9384c89947dc03d219c841b05c34cb5b0320591028db62a987e`.

## Limits

No full package/repository baseline, physical-device test, App runtime recovery,
real model/provider test, performance suite or DS3 was performed. Existing
compiler warnings and native-build deprecation remain visible. The tests do not
prove power-loss exactly-once behavior, cross-process snapshot isolation, recovery
of hidden reasoning/KV/OS state or complete retained-dialogue architecture.
Tests execute the actual model-free memory-service factory, not a full brain whose
default construction loads a model. Brain forwarding and App wiring are source-
checked, with a macOS-only wiring regression and separate actual iOS build.
Optional legacy best-effort consumers and later query/delta-sync error semantics
are not relabeled authoritative by this startup repair. No cloud/PCC fallback,
issuer/halt-reset exposure, legacy audit migration or Keychain-policy change is
authorized by this result. Broader baseline failures and product decisions remain
separate pending work.
