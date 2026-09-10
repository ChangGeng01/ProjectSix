# App recovery read implementation plan

> Use subagent-driven-development for Task23; reuse the current solo workspace.

**Goal:** read complete, bounded saved runtime events without constructing any
model/provider, and reject incomplete or malformed reads instead of returning a
plausible prefix. This is a necessary core slice, not complete App recovery.

**Architecture:** a read-only capability on the existing SQLite store. One SQLite
read transaction covers size preflight, decoding and requested existing-chain
verification. No new database, controller, authority ledger or replay action.

**Tech Stack:** existing Swift, SQLite3, BASEventLogEntry and binary codec.

**Spec:** approved-decisions choices1/3/8/12 and App-persistence clarification;
existing shared-operation-current-design/host-preflight and real-owner-disposition
in the solo workspace supply the source-backed recovery-read requirement. The
read-only refinement below supersedes inheriting append/prune from the old sketch.

## Global constraints

- Preserve all old source, keys, records and history. No stored-data migration.
- Selected-local-model unavailability never activates cloud/PCC or another model.
- Keep old event-read behavior and all existing caller signatures unchanged.
- No App/engine/provider construction, hidden reasoning capture, new key/authority
  mechanism, schema/dependency change, automatic retry/prune or new scan.
- Host-level inputs/plans/tasks/output persistence, 72-hour floor, permanent
  private chats and actual fresh-process App wiring remain required later.
- Tests use temporary databases only. No real model, app, device or network run.
- Root owns Git/docs/review; worker owns only the four source/test paths below.

## Task 23: Bounded provider-free event recovery reading

Base: `da83d9f25319ce0733a2be2481748b3ddbed309b`.

Files:
- Create `BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLogRecoveryReading.swift`
  for public value-only limits, integrity requirement, typed read errors and port.
- Create `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogRecoveryReader.swift`
  for an internal synchronous SQLite implementation, with no owned connection.
- Modify `BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift`
  only for conformance/thin actor entrypoint and minimal shared decode/hash access.
  Never expose the raw handle through a public or general-purpose getter.
- Create `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEventLogRecoveryReadingTests.swift`.

Public interface (use these names):
```swift
public struct BASEventLogRecoveryReadLimits: Sendable, Equatable {
    public let maximumEventCount: Int
    public let maximumEncodedEventBytes: Int
    public let maximumTotalEncodedBytes: Int
    public init(maximumEventCount: Int, maximumEncodedEventBytes: Int,
                maximumTotalEncodedBytes: Int) throws
}
public enum BASEventLogRecoveryIntegrityRequirement: Sendable, Equatable {
    case none
    case recordedChain
}
public protocol BASEventLogRecoveryReading: Sendable {
    func recoveryEvents(forSession sessionID: String,
        limits: BASEventLogRecoveryReadLimits,
        integrity: BASEventLogRecoveryIntegrityRequirement
    ) async throws -> [BASEventLogEntry]
}
```
No protocol inheritance from writable storage and no default budgets. Reject
nonpositive limits and count overflow before SQL. Add a small Equatable/Sendable
typed recovery error distinguishing invalid limits, exceeded bounds, malformed/
unsupported records and missing/invalid integrity. Existing SQLite prepare/step
errors may propagate; errors must not contain stored prompt/payload text.

- [x] **RED:** exercise the new public capability with a real SQLite database.
  For the initial missing-API compile phase, label it honestly; after adding the
  minimum declaration, show a behavioral RED (e.g. excess count/bytes must throw,
  but an initial forwarding implementation returns rows). No production stub may
  remain. Assert actual returned entries and typed failures, not source text.
- [x] **Implement complete bounded read.** One synchronous read transaction on
  the actor-owned connection, no await/reentrancy during it. Preflight at most
  count+1 rows using integer lengths/type/format metadata, not copied payloads.
  Charge actual UTF-8/blob byte lengths, including every variable-length identity
  or metadata field that will be materialized, to per-row/aggregate limits. Define
  that accounting clearly in the limits documentation; count does not include
  fixed Swift/SQLite object overhead. UTF-8 databases use metadata-only lengths.
  For legacy UTF-16LE/BE databases, fixed-size incremental reads may validate and
  count exact UTF-8 length, stopping at the remaining byte budget; stored-encoding
  metadata alone cannot supply that length. This scoped compatibility exception
  must not materialize unbounded payloads or silently change accounting units.
  Check each length/type and use checked
  arithmetic. Count/byte excess fails before payload decode, never truncates.
  A second bounded SELECT in the same snapshot decodes all rows; terminal step
  must be SQLITE_DONE in every query. SQL errors after rows fail the entire read.
  COMMIT only on success, ROLLBACK on every error; never return a partial array.
- [x] **Decode faithfully.** Support both existing JSON1 and binary2 formats.
  Unknown/null formats, invalid UTF-8, malformed payload/envelope, invalid typed
  identity/sequence and row/payload identity mismatch fail explicitly. SQL text
  binding/reading is length-aware (embedded NUL must not silently truncate).
  Reuse current codecs/hash logic rather than another independent wire format.
  Current binary compatibility decoder catches invalid envelope and defaults
  fields: the strict path must not inherit that silent success. Minimal optional
  strict-mode factoring is allowed if legacy defaults/behavior stay unchanged;
  preserve valid legacy forms, or explicitly refuse genuinely ambiguous records.
  Do not invent lost values, re-sign or rewrite them. No broad codec refactor.
- [x] **Existing-chain option.** For recordedChain, obtain only bounded matching
  sidecar evidence in the same read transaction; check identity/session/sequence,
  strict hash shapes and existing semantic hashes/links. Missing evidence and
  orphan/deleted event evidence fail. Legitimate prefix pruning remains valid.
  No unbounded helper call hidden inside the bounded reader. Keep keyless-chain
  limitations explicit: not authentication against the database owner, not proof
  of an externally anchored undeleted tail. No sidecar creation during read.
- [x] **Tests:** JSON/binary valid full-field round trips and empty session;
  exact count/per-row/total boundaries and +1; multibyte UTF-8, NUL identity,
  invalid limits/overflow; oversized malformed payload rejected before decode;
  malformed later JSON/binary envelope/unknown format fails with no prefix;
  SQL read error differs from empty; missing/tampered chain fails, valid and
  legitimately prefix-pruned chain passes; all-failure paths leave connection
  usable. Prove real close (existing closeObserver) then reopen equality, with
  no brain/provider dependency. Test snapshot consistency using a real second
  connection if a deterministic fixture is feasible; do not add a public test
  seam or a general fault framework. Test helpers stay in test utilities.
- [x] **Verify:** iterate focused new tests, then one covering invocation of
  BASEventLogRecoveryReadingTests, BASEventLogIngestionRetentionTests,
  BASEventLogIngestionMigrationTests, BASEventLogBinaryDecodeSafetyTests,
  BASEventLogTamperRedTeamTests and BASSQLiteEventLogDualWriteInvariantTests.
  Use the existing native BAS scratch and same-source metallib, with automatic
  dependency resolution disabled and model opt-ins unset, as in task21-report.
  Existing warnings remain disclosed; no full-suite rerun or cache clean.
- [x] **Handback:** concise actual commands/counts/exits and complete retained
  log paths; source-only frozen diff, self-review and explicit limitations in
  existing solo workspace/task-23-report.md. Root performs independent review.

## Consistency / scope check

| Boundary | Required relationship |
| --- | --- |
| Read capability / existing store | same connection, no exposed append/prune authority |
| Preflight / decode / integrity | same snapshot, complete checked reads, common budgets |
| Strict / legacy decoder | strict rejects uncertainty without changing legacy callers |
| Reader / App lifecycle | provider-free primitive; does not claim App wiring is done |
| Existing retention / this read | no prune/write-policy changes or shorter retention |

## Accepted bounded result

Implemented in `dd6bdde50a0625bec32cefd865f8e8fb72ba80da`. Fix-round1 independent
review addressed both Important findings with no new findings; the amended
six-suite run passed62tests. Existing native warnings remain. Ambiguous binary
records are explicitly refused by the strict API, not recovered by guessing.
The optional deterministic second-connection mutation fixture was not feasible
without a new pause seam; no such concurrency-test claim is made. Actual App
startup, task/output persistence and fresh-process recovery remain outside this
completed primitive and still required for overall readiness.
