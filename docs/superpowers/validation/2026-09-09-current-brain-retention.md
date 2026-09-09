# Current-brain minimum recovery retention

Task7 corrects successful DS1 occurrence `occ_a2e754149cb4be652cb65b36`.
Base: `30e5c063f6570f0e2ec5d87415cf720595debfd1`.
Tested seven-file patch SHA256:
`6e9d8fc62ae40f1c00eb7dfba865200de170e9ebee21412e41f19ce27adc0266`.

## Result

Both current-brain update and evolution checkpoint planners protect every
record whose creation time is within the inclusive72hour minimum. Existing
60/40 count targets are soft while recent records exceed them. The existing
14/30day optional age windows, deterministic ordering, deduplication/linkage,
writer error reporting and explicit forget/revocation remain supported.

The policy lives in one small internal BASMemory selector. Actual exported
SwiftData writers are unchanged and use its retained IDs for delete/save.
This closes automatic recent-record loss from count/age selection in these
two paths, not every storage backend or every possible loss mechanism.

## Verification

The pre-fix regression produced the expected behavioral failure: a small count
cap dropped an additional recent update. Its normalization control passed.
The original worker RED/GREEN logs are retained with their honest limitation:
the pipeline reported tee's exit status, not an independent Swift exit code.

Fresh independent task review found spec compliance and approved quality,
with no Critical/Important/Minor findings. Root then ran the full seven named
focused suites with `set -o pipefail` on the unchanged reviewed patch:

```text
MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
swift test --package-path BehavioralAISubstrate --build-system native
  --scratch-path /private/tmp/qinao-bas-native-test-1329bde3
  --filter 'BASCurrentBrainPersistenceCoreTests|BASEvolutionCoreTests|BASAppleCurrentBrainUpdateWriterTests|BASAppleEvolutionCheckpointWriterTests|BASAppleCurrentBrainCommitterTests|BASAppleCurrentBrainHostLifecycleRuntimeTests|BASAppleCurrentBrainBootstrapTests'
```

Actual process completion: exit0;11XCTest plus50Swift Testing tests passed,
0failures and0skips. Root read the complete output. The sole warning is the
existing native-build-system deprecation. Both real disk-reopen tests ran:
61recent updates and41recent checkpoints survive, and expired records are
removed. Tests use isolated fixture schemas, no CloudKit and fresh containers
after releasing the first store/context. Boundary/invalid-policy/older-cleanup
and explicit revocation controls also passed.

Root log SHA256:
`174f3bb6a48992f900fa736e63b9495587472a8022362e5335f23e7c0a77ed87`.
Full reports, original logs and reviewed patches are preserved in this plan's
private SDD workspace; no private exports are uploaded by this document.

Event-log ingestion-age retention, storage failure/OS purge, authenticated
clocks, permanent pins and recovery of hidden model state are not established
by this change. DS3 has not started and readiness is not claimed.
