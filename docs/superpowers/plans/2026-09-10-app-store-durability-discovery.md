# Task 29 — App event-store durability and cold session discovery

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Root coordinates review and Git; one source/native owner only.

**Goal:** Give the actual App's next integration slice an explicitly configured durable event store and bounded cold conversation discovery on the SAME existing actor.
**Architecture:** Extend BASSQLiteEventLogStorage, not a second transcript database or developer controller. Preserve legacy initialization behavior. Add a value-only discovery port and an internal synchronous metadata reader; reuse the existing bounded UTF-8/UTF-16 identity preflight.
**Tech Stack:** Existing Swift 6, Foundation, SQLite3, XCTest; existing vendored/native toolchain.
**Spec:** The user-approved App persistence direction and approved decisions in docs/superpowers/specs/2026-09-10-qinao-approved-decisions.md; detailed App sequence in .superpowers/sdd/2026-09-09-qinao-ds3-readiness-solo/app-persistence-next-slice.md (including early-leaf placement amendment).

## Global constraints

- Preserve existing commits, worktrees, branches, dirty drafts and evidence. No cleanup, reset, amend, deletion of old work or force-push.
- Active work is App/runtime persistence and recovery, not development-workflow persistence.
- If the selected local model is unavailable, do not invoke a cloud fallback, including PCC.
- Only trusted host code holds credential issuers and halt-reset interfaces; this data-only storage API supplies neither.
- No native model, network inference, model download, DS3, main merge or approval machinery.
- No existing tests, required thresholds, dependency locks, public legacy behavior or historical records are removed to pass this task.
- New App records will use one actor and retain-all through a port with no prune operation. This task does not itself wire the App or prove all runtime retention/cold recovery.
- The keyless recorded chain is not keyed authentication, an external tail anchor, or proof against full database rewriting.
- Run tests alone with unique retained logs, preserve actual exit status and wait for the same live handle. Source remains stable during covering tests.
- Root owns Git/PR and existing drafts. Worker owns only files below and one retained BAS native scratch; no subagents.

## Files and interfaces

Create:
- BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogConfiguration.swift — immutable configuration plus internal checked pragma application.
- BehavioralAISubstrate/Sources/BASRuntimeCore/BASEventLogSessionDiscovery.swift — value-only limits/page/errors and protocol.
- BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogSessionDiscoveryReader.swift — synchronous non-owning metadata pagination on the actor connection.
- BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEventLogAppStorageTests.swift — real SQLite configuration/discovery tests.

Modify:
- BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogStorage.swift — additive explicit initializer, pinned write settings and discovery delegation.
- BehavioralAISubstrate/Sources/BASRuntimeCore/BASSQLiteEventLogRecoveryReader.swift — narrow internal bounded session-identity accessor using its existing incremental byte-counting helpers; do not duplicate those helpers or change old read semantics.

No manifest/schema version change, new package, provider, UI or old test modification in this task.

Exact public shapes:

```swift
public struct BASSQLiteEventLogConfiguration: Sendable, Equatable {
    public enum Synchronization: Sendable, Equatable { case normal, full }
    public let synchronization: Synchronization
    public let useBinaryPayload: Bool
    public let rowIntegrityChainEnabled: Bool
    public let runIntegrityCheckOnOpen: Bool
    public init(synchronization: Synchronization,
                useBinaryPayload: Bool = false,
                rowIntegrityChainEnabled: Bool = false,
                runIntegrityCheckOnOpen: Bool = false)
}
// Add overload; preserve existing init(databaseURL:) and internal clock/close seams.
public init(databaseURL: URL, configuration: BASSQLiteEventLogConfiguration) throws

public struct BASEventLogSessionDiscoveryLimits: Sendable, Equatable {
    public let maximumSessionCount: Int
    public let maximumSessionIDBytes: Int
    public let maximumTotalSessionIDBytes: Int
    public init(maximumSessionCount: Int, maximumSessionIDBytes: Int,
                maximumTotalSessionIDBytes: Int) throws
}
public struct BASEventLogSessionPage: Sendable, Equatable {
    public let sessionIDs: [String]
    public let nextAfter: String?
    public init(sessionIDs: [String], nextAfter: String?)
}
public enum BASEventLogSessionDiscoveryError: Error, Sendable, Equatable {
    case invalidLimits, invalidQuery, sessionIDByteLimitExceeded
    case totalSessionIDBytesExceeded, malformedIdentity
}
public protocol BASEventLogSessionDiscovering: Sendable {
    func recoverySessionPage(
        prefix: String, after: String?,
        limits: BASEventLogSessionDiscoveryLimits
    ) async throws -> BASEventLogSessionPage
}
```

The next actual App will pass synchronization .full, JSON, chain true, open integrity check false. Its initial metadata page budgets will be 50 IDs / 512 UTF-8 bytes per ID / 25,600 bytes total. These are not hard-coded generic defaults or automatic truncation behavior.

## Required implementation behavior

### Explicit durable configuration

- Store the supplied configuration immutably per actor. Explicit instances must never reread process-global flags for append payload/chain or open integrity policy.
- Existing no-configuration initializer retains its actual current behavior: NORMAL and legacy flags, including per-append changes used by existing tests. Correct misleading comments that claim these legacy flags are per-instance snapshots; do not silently change that compatibility contract.
- Apply WAL and requested synchronous mode using checked SQLite execution. Explicit configuration must read back and verify journal_mode is wal and synchronous is 1 (NORMAL) or 2 (FULL). Check prepare/step/DONE, not sqlite3_exec success alone. Use existing typed StorageError.openFailed/prepareFailed/stepFailed for unavailable or mismatched settings with informative messages. A failed open closes the handle through the existing transfer guard.
- Keep busy_timeout, secure-delete, migration, schema checks, checkpoint size, duplicate-ID semantics, existing atomic append/chain transaction and closeObserver behavior. Reuse existing chain writer; binary+chain remains the existing JSON+chain path.
- New internal configuration helper may take a non-owning SQLite handle synchronously for use by init and real-handle tests; never expose a public raw handle.
- FULL is the verified SQLite commit synchronization policy, not a promise of bitwise RAM/power-loss restoration or filesystem encryption.

### Bounded exact-prefix session discovery

- Separate protocol is additive; do not make existing recovery-reading conformers implement a new method.
- Limits require all values positive, count < Int.max; validate before SQL. Empty prefix or prefix/cursor beyond per-ID byte budget, or a cursor not having the exact UTF-8 prefix, throws invalidQuery. Prefix and cursor are data, not SQL.
- Enumerate distinct session IDs from event_log metadata, ordered by SQLite BINARY comparison with an exclusive after cursor. Bind explicit UTF-8 byte lengths (embedded NUL supported); no LIKE wildcard semantics, SQL interpolation of user input, OFFSET, payload materialization, all-history decode, extra catalog or global ID cache.
- Use the existing session/sequence index and a literal binary prefix range. Derive an exclusive upper bound by incrementing the last incrementable Unicode scalar (skip surrogate range, carry past U+10FFFF); if none exists omit the upper predicate. Exact raw UTF-8 prefix/cursor validation must not rely on Swift's canonical-equivalent String comparison. Test Unicode and UTF-16 databases rather than assuming collation behavior.
- Obtain a representative rowid and type for each distinct ID, at most count+1 metadata rows. Group/order by the same binary session key. The count+1 row is lookahead only: do not materialize its unbounded ID/payload. If present, nextAfter is the last returned ID; otherwise nil. Empty page is []/nil.
- Keep the metadata query and all bounded identity reads in one BEGIN DEFERRED transaction on the actor-owned connection, no await inside. Check every SQLite step and final completion; rollback on error and never return a successful partial page on malformed/over-budget/SQLite failure.
- Reuse the recovery reader's sqlite3_blob_open UTF-8 byte preflight and fixed-chunk UTF-16 accounting. Add only a narrow internal identity accessor there, then decode full validated UTF-8 text after per-ID and total budget checks. No CAST of an arbitrarily large identity followed by materialization before checking.
- Charge returned identities exactly, with checked arithmetic; over-per-ID and over-total errors remain distinct. No reserveCapacity from arbitrary caller ceilings.
- Duplicate events for one session yield one ID. Wrong or unknown payload bytes do not prevent metadata discovery; reopen remains the existing strict read. Malformed matching identity itself fails explicitly.
- This page is one snapshot, not a cross-page frozen catalog: a new session sorting before a used cursor is found on refresh from nil. Document that ordinary paging limit.

## TDD and tests

- [x] Write BASEventLogAppStorageTests first and run the focused filter. Record an API compile RED as such (zero tests), not a behavioral failure.
- [x] Implement the specified paths, then focused GREEN. Add genuine failing behavioral regressions before correcting any newly discovered bug.
- [x] Real-handle pragma test: open an ordinary temporary SQLite file, call the SAME internal pragma helper used by actor init with .full, query journal_mode/synchronous and assert wal/2; .normal yields wal/1. A :memory: connection cannot honor WAL and must throw rather than appear configured. A transaction-conflicting pragma failure must propagate.
- [x] Explicit actor test: construct JSON+chain FULL actor while globals select binary/no chain; flip globals across two appends; recoveryEvents(... .recordedChain) returns both complete originals. Construct explicit binary/no-chain actor while globals select chain/JSON; inspect stored payload_format and recover using .none. Restore globals with defer.
- [x] Preserve legacy flag behavior via existing unmodified dual-write/recovery tests in the covering run. Check failure close semantics using the existing internal clock/close seam, adding optional config only if needed.
- [x] Discovery tests: zero/negative/Int.max limit rejection; huge valid count with empty/one-row store (no eager allocation); empty page; multi-page distinct sessions and exclusive cursor; repeated events; literal %/_ prefix, Unicode, embedded NUL and neighboring prefixes; malformed cursor; refresh after inserted earlier ID. Assert concrete arrays/cursors/bytes, not only counts.
- [x] Exact per-ID/total UTF-8 boundary succeeds and one byte less fails with correct errors, including both UTF-16LE and UTF-16BE stores, multibyte/supplementary scalars and large identities. Include lookahead with an overlarge next ID: first full page can return a cursor without decoding it; next page refuses.
- [x] Insert a matching malformed TEXT identity using SQLite bytes and prove explicit malformedIdentity. Drop/rename required event table after open and prove throwing SQLite error, not empty success; restore fixture or use fresh store for subsequent success to verify no transaction leak.
- [x] Put a malformed or large payload under a valid session ID and prove discovery is metadata-only; strict recovery of malformed payload still refuses.
- [x] Reopen a real file with a new actor, discover and read exact full original records, without providers. This is storage evidence, not actual GUI fresh-process acceptance.
- [x] Run final covering filter once after source stability:
  BASEventLogAppStorageTests|BASEventLogRecoveryReadingTests|BASEventLogIngestionRetentionTests|BASEventLogIngestionMigrationTests|BASEventLogBinaryDecodeSafetyTests|BASEventLogTamperRedTeamTests|BASSQLiteEventLogDualWriteInvariantTests
- [x] Self-review source, check diff whitespace, freeze actual Git diff including new files, and hand back. Root independently reviews before commit.

Illustrative next-consumer contract (use exact public names above):

```swift
let store = try BASSQLiteEventLogStorage(
    databaseURL: url,
    configuration: .init(synchronization: .full,
                         rowIntegrityChainEnabled: true))
let page = try await store.recoverySessionPage(
    prefix: "qinao.sample.conversation.v1/", after: nil,
    limits: .init(maximumSessionCount: 50, maximumSessionIDBytes: 512,
                  maximumTotalSessionIDBytes: 25_600))
XCTAssertEqual(page.sessionIDs, expectedIDs)
XCTAssertNil(page.nextAfter)
```

## Native execution and report contract

Work in BehavioralAISubstrate. Reuse released scratch /private/tmp/qinao-bas-native-test-1329bde3 and metallib /private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib. Do not clean/rebuild dependencies or use another native owner. First native attempt uses require_escalated for known compiler-cache permission needs. All environment opt-outs and --disable-automatic-resolution are retained:

```sh
LOG="$(mktemp /private/tmp/task-29-native.XXXXXX)"
printf 'Retained log: %s\n' "$LOG"
/usr/bin/script -q "$LOG" /usr/bin/env -u QINAO_JOURNAL_GROUND -u QINAO_JOURNAL_GROUND_REPO -u QINAO_JOURNAL_GROUND_SEMANTIC -u BAS_ENDURANCE_AUTOSTART -u BAS_V12_PROBE -u BAS_FUZZ_BENCH_RUN -u QINAO_MLX_E2E -u QINAO_MLX_BENCH -u QINAO_FM_E2E -u BAS_T5_XCTEST -u BAS_AGENT_FABRIC MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib swift test --build-system native --scratch-path /private/tmp/qinao-bas-native-test-1329bde3 --disable-automatic-resolution --filter 'BASEventLogAppStorageTests'
```

Use the listed covering filter for the final stable run. Do not chain a test behind semicolon-separated successful checks; capture its actual terminal exit. Retain every attempt's unique path and session/terminal identifiers. Pre-existing warnings remain disclosed, not suppressed.

Write .superpowers/sdd/2026-09-09-qinao-ds3-readiness-solo/task-29-report.md (result, exact files, commands/counts/RED/GREEN, frozen diff path/hash, concerns and handles). Return only status, <=1 line test summary, concerns and report path. No Git writes: root stages/commits only after independent acceptance.

## Root self-review / ordering ruling

This concrete task covers the two missing store capabilities named by the App feasibility review. Existing Task23 checked reopen and Task25 same-actor injection stay intact. The next slice creates the final host leaf once, retains the existing GUI and data locations, and wires these capabilities into normal UI/session flow; it is not gated on all provider relocation. No library test substitutes for fresh GUI process acceptance.

Shared file check: Task23 reader plus Task29 identity helper use the same bounded encoding implementation; old reader tests cover compatibility. Task25 consumes the unchanged BASEventLogStorage protocol/actor identity. Future App consumes the exact configuration/discovery signatures above. Task29 keeps optional configuration on the legacy path precisely because existing tests and callers change flags between appends. No current source/native owner overlaps this task.

## Task29 acceptance

Implementation plus one independent-review fix round accepted. Final focused
18/18 and seven-class covering80/80 passed, including four added interruption,
checked-binding, empty-TEXT and over-budget-query regressions. Original14/14,
76/76 and failed-review evidence remains retained, not replaced. Final review:
all findings addressed, no new Critical/Important breakage. Exact six-file
review patch SHA256 adc0b7c899dcb99b909fd322a00290044ceaff04887282d02b78decde07c0221.
Detailed logs, intermediate attempts and review disposition are in existing
SDD task-29-report.md / task-29-review-disposition.md. Unchanged init-close
guard checked directly and covered by the existing migration/reopen tests.
Pre-existing Swift warnings/native-backend deprecation remain disclosed.
This completes the bounded storage prerequisite, NOT actual App recovery,
whole-package CI, DS3 readiness, merge approval or permission to start DS3.
