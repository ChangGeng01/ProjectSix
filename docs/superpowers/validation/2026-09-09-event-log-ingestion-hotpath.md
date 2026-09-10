# Event-log ingestion hot path — Task10 validation

Status: accepted; focused tests and independent scoped review passed.
Not a DS3 readiness or all-event-log-finding closure claim.

Base: `f5d1d107dc0da338cb26fe60389b871a1f724fe4`. The candidate is the
nine-file Task10 implementation patch against that base, SHA256
`863a725986e3fdcb42c1774ffbaa34105abc7e325b317cd2566a1919d7d37afd`.
No schema version, wire/API, retention policy, semantic timestamp, payload,
sequence or integrity contract changes are included.

Both SQLite implementations install the same valid-ingestion partial index
after ingestion-column availability. In-memory append uses a cached maximum
of currently retained rows; actual prune recomputes it from survivors and
full prune clears it. Database append keeps its database-owned MAX query.

## Actual verification

- Swift:62tests passed,0failed,0skipped. Covers ingestion/migration, exact
  retention boundaries, survivor cache, sequence continuity, chain/tamper,
  federation and six real Rust-vs-Swift routed byte-equality controls.
- Locked Rust event-log suite:33passed,0failed,0ignored,86filtered.
- Ordinary macOS/iOS/simulator Rust rebuild succeeded. Packaged headers
  matched canonical headers; all old and additive ingestion-clock exports
  remained. Object minimums: macOS14.0, iOS27.0, simulator27.0.
- Fresh root acceptance after worker handback:62/62, test exit0 and log-writer
  exit0. Full output SHA256
  `1d3da49a044efec4f82ce391d1566d7b18d4c195eceb8665c8a297e5eac3f046`.

Root command, from the worktree root:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib \
swift test --package-path BehavioralAISubstrate \
  --scratch-path /private/tmp/qinao-bas-native-test-1329bde3 \
  --build-system native \
  --filter 'BASEventLogIngestionRetentionTests|BASEventLogIngestionMigrationTests|BASEventLogSeqHighWaterMarkTests|BASEventLogTamperRedTeamTests|BASChapter901EventLogByteEqTests|BASFederatedEventLogStorageTests'
```

Root captured stdout/stderr together and checked both pipeline exits. The
native-build-system deprecation warning remains visible; Rust also reports
an unrelated pre-existing test-name warning and existing rustfmt drift.
Do not describe all validation output as pristine. No dependency installation,
cold-clean, actual model/provider call or user database was involved.

Private detailed report/logs and review snapshot are retained under
`.superpowers/sdd/2026-09-09-qinao-ds3-readiness-solo/`. Initial review found
report accuracy defects, not a production defect. Two report-only fix rounds
resolved them; the scoped re-review approved spec compliance and task quality.
No code changed or tests were rerun for those prose corrections.

The first minimal Swift RED is a contemporaneously reported observation whose
raw log was not retained. An expanded pre-change run has three unexpected
SQLite errors and an unknown log-writer exit; it is inconclusive, not evidence
of a particular cause. Later clean mutation/restoration checks establish test
sensitivity, not the missing original test-first chronology. That evidence gap
is retained, not reconstructed or hidden. Current-source acceptance rests on
the reviewed patch and actual post-restoration Swift/Rust/platform results.

## Limits

Index creation scans existing retained rows and costs a write lock, disk space
and future index maintenance. Query-plan checks establish index selection,
not measured end-to-end latency or bounded total storage. The optimization
preserves the existing72-hour ingestion floor; it does not implement durable
generation recovery, universal storage authorization, arbitrary custom-backend
retention, physical erasure parity, or power-loss guarantees.
