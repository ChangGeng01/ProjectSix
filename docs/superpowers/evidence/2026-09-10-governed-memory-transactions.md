# Governed-memory persistence verification

Task20, based on `8da05ad94853b9e01461e6644a4247ee21d3f5ab` plus the
task-only source/test diff. Implementation and final focused validation are
complete for the initial candidate. Independent review found two implementation
issues and two test-evidence gaps; fix round1 is implemented and its39case
covering run passed. Scoped re-review ACCEPTED all four fixes, with no new
Critical/Important/Minor findings. The106case result below
describes the preserved initial candidate, not proof that its known issues were
absent. This is not full-candidate acceptance or DS3 readiness.

## Verified execution

The pre-fix regression used the old public reconciliation API and a real
SwiftData file configuration with saves disabled. SwiftData returned Cocoa513;
the old writer invoked its error callback but still returned a success result.
The assertion rejecting that result failed, exit1. After repair, the same
read-only failure escaped and the one selected test passed, exit0. Writable
reopen retained only the original seed.

The final native invocation selected the governed-persistence suite, memory
draft derivation and projection refresh/selection/lifecycle suites, current-
brain committer/update/bootstrap/host-lifecycle suites, evolution checkpoint
writer, lifecycle bootstrap/orchestration, and relevant host runtime tests.

- 11 XCTest cases passed, zero failures.
- 95 Swift Testing cases in12suites passed, zero issues.
- Overall106selectedcases; observed process exit0.
- Full final log SHA256:
  `aa91d76615c8fdd9e8437a9a7431e1001c56d72174684f2c17042657a441ac29`.
- Frozen29path source/test diff SHA256:
  `64b8d718f65ab9574e457f3ca54a631dcb6852245ce275a9d1c9104be46a6706`.

Tests exercise each authoritative fetch failure and later-prefix failure,
save-error propagation, unrelated caller insert/update/delete isolation,
immutable returned values, complete17/21field conversion, zero/one save,
all three post-transaction embedding-failure dispositions, host failure
propagation, unsupported configuration refusal, and successful file reopen.
Task15's existing transaction tests remain selected after the neutral helper
rename. Deterministic pure projection compilation remains nonthrowing.

Selected bodies were inspected; no real model, cloud/PCC, application or
simulator was invoked. Existing SwiftPM scratch and same-source Metal library
were reused without a download or cache clean. Expected read-only Cocoa513
diagnostics and the pre-existing native-build deprecation warning remain in
the complete output. The initial sandbox/cache failure did not execute the
regression and is not substituted for the genuine behavioral RED.

## Review correction and amended verification

The first review found lossless read/receipt conversion incorrectly reused a
tag-normalizing writer helper and comparative/reflective selection lost its
equal-timestamp tie breaker before limiting. The other two findings concerned
exact set/order/deletion assertions on reopen and real file-reopen evidence
after committed reconciliation followed by an embedding failure.

Fix1 adds one lossless mapping per stored-field type, preserving the existing
normalizing write policy; it restores the persistent-ID tie key before limiting.
Independent literal tag/tie tests genuinely failed before these fixes. The
amended reopen test checks complete row sets and canonical order. A separate
real file-store/host composition verifies the committed failure disposition,
one save, no publication or dirty-bit clearing, and complete reopened values.

The final amendment run selected BASMemory field mapping, governed persistence,
projection refresh/selection/lifecycle and affected host runtime cases:

- 11 XCTest and28 Swift Testing cases passed; observed exit0.
- Full final log SHA256:
  `7473c58b0b4eaed8fe9b9ec6621c63a634193ca85c42c2d7d3ee56085aae6be8`.
- Six-path fix-only patch SHA256:
  `2b4f4e9e42b989bd4c949f2ec96385715cad4de82329b00a332cdc210611aaf3`.
- Complete31path Task20 source/test patch SHA256:
  `e8132f56242b515d53ff7dd0d04c9dd92528a0abb37a7c7f5dff02ac1d52f811`.

This39case selection covers the amendment; it is not added to106 as a count of
distinct tests. The initial106case result remains historical evidence for its
candidate. Scoped re-review checks each finding and only new breakage in the
six-path fix; no duplicate full-task review or unchanged baseline rerun.
The fresh reviewer returned4ADDRESSED/0NOT ADDRESSED and root independently
matched all30extant source/test files to the tested manifest before staging.
This accepts the bounded Task20 repair, not the broader recovery guarantees
or complete branch/readiness state.

## Evidence retention and limits

The original task brief, design, report, exact environment/filter commands,
full logs, process receipts, frozen patch and per-file hashes are retained in
the solo plan's local SDD evidence directory. No prior history or failed
iteration was removed. These local retained artifacts are not represented as
uploaded canonical DS1 evidence.

Injected fetch/save failures prove control flow, not every physical storage
failure mode. Ordinary file reopen is not abrupt-kill, power-loss or hardware
durability. This slice does not establish a consistent cross-fetch MVCC
snapshot, mixed/custom-store support, recovery quiescence, stale-writer or
external-writer isolation, safe automatic replay, hidden-state restoration,
or concrete out-of-tree host adoption. The one-standard-configuration limit
remains explicit. Those broader requirements remain open.
