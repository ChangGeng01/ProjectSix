# Event-log minimum ingestion-age retention

Task8 addresses successful DS1 occurrence `occ_f689fce8a8044ba9b5afec3b`.
Base: `dca3e44c9ede4da0db76ca9430bc816d24891ee2`.
Status: accepted after independent review, one fix round and fresh root
verification. This accepts the scoped recovery correction, not DS3 readiness.

## Changed behavior

The built-in memory, Swift SQLite and routed Rust event stores delete an event
through retention only if both its caller-owned semantic timestamp precedes
the requested cutoff and its storage-owned ingestion age exceeds72hours.
Exactly72hours is retained;72hours+1ms is eligible. Nonpositive caller cutoffs
retain everything. Checked clock arithmetic and invalid stored metadata fail
closed. Changed duplicate inserts preserve the original event and age; a new
event at a regressed clock is clamped against retained valid ingestion stamps.

Swift migration adds metadata and seeds sequence high-water marks in one
checked transaction, setting schema version3 last. Legacy rows get one new
ingestion baseline only when that column is introduced; reopen does not
refresh it. Rust uses the same structural protection without taking ownership
of the caller's database user_version. Failed initialization releases handles.
Full prune and real close/reopen preserve subsequent sequence allocation.

Public event Codable/wire/JSON/blob contents and hash inputs are unchanged.
For existing integrity-chain sessions, automatic retention removes only an
eligible contiguous prefix and removes the same sidecar/event IDs atomically.
It does not rewrite chain hashes. Existing Rust exports remain; explicit-time
siblings support deterministic tests. Production routed calls use old exports
with the protected implementation. Three bundled archives were refreshed.

## Verification

The initial independent review found two defects and specific evidence gaps,
despite previously green focused tests. The fix adds the memory retain-all
guard, propagates Rust schema-index probe errors and supplies missing real
clock, migration, binary-decode, close/reopen and cross-language-chain cases.
The sentinel regression failed before the guard and passed afterward.

The independent scoped re-review verified all three Important findings and
their missing-proof subparts as addressed, with no new Critical/Important
breakage. Its only fix-local Minor is the test-only weak-probe mutability
warning. The separately planned retained-history performance correction
remains open and does not disappear behind this acceptance.

Final worker results:32/32 locked Rust event-log tests; ordinary three-slice
rebuild; all3packaged headers match the canonical header; old/additive
append/init/prune symbols and macOS14/iOS27/simulator27 minimum OS verified;
60/60 focused Swift cases passed against the refreshed macOS bundle. A later
test-only refinement retries a changed duplicate at a later clock before a
new-ID append at a regressed clock; its exact changed test passed1/1.

Root independently matched final source/archive identities and then ran a
fresh covering selection on the final refined test source:

```text
MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
swift test --package-path BehavioralAISubstrate --build-system native
  --scratch-path /private/tmp/qinao-bas-native-test-1329bde3
  --filter 'BASEventLogIngestion(Retention|Migration)Tests|BASChapter901EventLogByteEqTests'
```

Actual completion: exit0,21tests passed,0failures,0skips. Root read the entire
output; the only warning in this fresh run was native-build-system deprecation.
The selection executes8retention,7migration and6actual routed byte-equality
tests, including valid legacy format2 decoded by Swift and a real Swift-created
chain closed, pruned by Rust, then reopened and verified by Swift.

Root log SHA256:
`4d136870b94633f3900a77b169cbb1c967989441ff186efe3648d53e371447c4`.
Original reviewed text patch SHA256:
`7819d4d93f0ad3893d37ee27ac622109515210ceae129b26f28f5fb6f4b80ff0`.
Fix-only text delta SHA256:
`6e21f241ec547634024df63749fb820cd09372db2cf53cdafd3f360964897911`.
Full commands, logs, source/archive hashes and the immutable original review
are preserved in this plan's private SDD workspace; no private exports are
uploaded by this document.

## Limits and follow-up

No safe existing direct PRAGMA row/terminal-step fault-injection seam was
available. Checked error propagation plus actual late-migration rollback,
retry and reopen supply the finite evidence; no new injection system was made.
Earlier sandbox, shell-wrapper and incomplete-JSON-fixture failures remain
recorded, not counted as successful tests. Broader runs also emitted existing
Rust/Swift warnings and weak-probe mutability suggestions in the new tests.

The per-append retained-history maximum scan is a confirmed performance issue,
with a separately planned partial-index/cache correction. No end-to-end speed
or bounded total storage claim is made. This change does not guarantee hidden
model-state restoration, arbitrary third-party backend behavior, recovery
through full/unavailable storage, authenticated clocks, OS purge protection,
permanent pinning or unlimited history. Memory storage remains process-only.
Swift's checked post-commit checkpoint is not a Rust physical-erasure guarantee.
No cold-build reproducibility or final whole-candidate baseline is claimed.
DS3 has not started and readiness is not claimed.
