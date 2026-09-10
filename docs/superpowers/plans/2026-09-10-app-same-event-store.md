# App-owned event store injection implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development for Task25.
> Continue the existing solo workspace; root owns Git and independent review.

**Goal:** let the existing real brain and runtime engine share the event store
already opened and retained by a host, without constructing a second store.

**Architecture:** add one optional instance override through the existing
builder, real-services initializer and two factories. The bundle and engine
already accept the same storage protocol; reuse them unchanged. Nil preserves
the current configuration-only path.

**Tech Stack:** Swift actors, existing BASHostKit/BASRuntimeCore, XCTest.

**Spec:** `docs/superpowers/specs/2026-09-10-qinao-approved-decisions.md`, especially
choices3/8/10 and actual App persistence. The source-checked interface contract
is in the existing solo workspace's `same-store-injection-contract-2026-09-10.md`.
Ordinary scoped technical decisions are delegated by that spec.

## Global constraints

- Preserve existing source, tests, history and dirty drafts. No data migration.
- No new storage/controller/schema/dependency, options serialization change,
  provider fallback, new model provisioning, cloud/PCC, scan or real App run.
- The two real-factory tests exercise their unchanged bundled local CoreML
  classifier/native pilots. They are not provider-free recovery tests or proof
  that the selected Qwen/MiniCPM models are healthy. If existing local resources
  are unavailable, report the failure; do not download, substitute or skip.
  Source checks confirm the SQL tracker defaults to in-memory, the Rust tracker
  creates an in-memory handle, and the classifier loads from `Bundle.module`.
  Existing CoreML compilation/cache behavior may run; do not add manual cache
  cleanup or change that unrelated loader to make these tests pass.
- No changes to explicit `contextService:` initializer, bundle, engine,
  lifecycle semantics, append error propagation or stored event wire format.
- Wait for Task23 acceptance and Task24 source/native release before dispatch.
  Only one owner uses the retained BAS native scratch at a time.
- Constructor identity and in-process engine writes are the deliverable here,
  not durable raw conversation inputs, App startup or fresh-process recovery.

## Task25: Propagate the existing host-owned event store

**Files:** Modify exactly these six files:

- `BehavioralAISubstrate/Sources/BASHostKit/BASCognitiveOSBuilder.swift`
- `BehavioralAISubstrate/Sources/BASHostKit/BASCognitiveBrain.swift`
- `BehavioralAISubstrate/Sources/BASHostKit/BASCognitiveBrain+Construction.swift`
- `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCognitiveOSBuilderTests.swift`
- `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCognitiveBrainFacadeIntegrationTests.swift`
- `BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCognitiveBrainAllPilotsTests.swift`

**Interfaces:** public argument `eventLog: (any BASEventLogStorage)? = nil`.
Consume the existing `BASCognitiveOSBundle.eventLog` and
`BASTurnRuntimeEngine(coordinator:eventLog:)`; do not create replacements.

- [x] Add focused tests before implementation. In builder tests, exercise both
  overloads with `.allDisabled` and the same actor:

```swift
func testInjectedEventLogSurvivesBothEmptyShortcutsByIdentity() throws {
    let log = BASInMemoryEventLogStorage()
    let first = try BASCognitiveOSBuilder.build(options: .allDisabled, eventLog: log)
    let second = try BASCognitiveOSBuilder.build(
        options: .allDisabled, embeddingProvider: nil, eventLog: log)
    for bundle in [first, second] {
        XCTAssertEqual(bundle.populatedCount, 1)
        let actual = try XCTUnwrap(bundle.eventLog as? BASInMemoryEventLogStorage)
        XCTAssertTrue(actual === log)
    }
}

func testInjectedEventLogOverridesSQLiteURLWithoutOpeningIt() throws {
    let url = try XCTUnwrap(tempDir).appendingPathComponent("missing/events.sqlite")
    let log = BASInMemoryEventLogStorage()
    for enabled in [false, true] {
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: enabled, eventLogSQLiteURL: url), eventLog: log)
        let actual = try XCTUnwrap(bundle.eventLog as? BASInMemoryEventLogStorage)
        XCTAssertTrue(actual === log)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }
}
```

In the facade tests, use the real factory and observe its actual engine output:

```swift
func testMakeWithDefaultsUsesInjectedEventLogForBundleAndEngine() async throws {
    let log = BASInMemoryEventLogStorage()
    let brain = try await BASCognitiveBrain.makeWithDefaults(eventLog: log)
    let bundle = await brain.bundle
    let actual = try XCTUnwrap(bundle.eventLog as? BASInMemoryEventLogStorage)
    XCTAssertTrue(actual === log)
    let result = await brain.process("compile the swift package")
    let entries = await log.events(forSession: result.runtimeTrace.sessionID)
    XCTAssertEqual(entries.count, 2)
    XCTAssertEqual(entries.map(\.kind), [.substrateAudit, .substrateAudit])
    XCTAssertEqual(entries.map(\.actions), [["turn-start"], ["turn-complete"]])
    XCTAssertEqual(entries.map(\.sequenceNumber), [0, 1])
    XCTAssertEqual(Set(entries.map(\.eventID)).count, 2)
    XCTAssertTrue(entries.allSatisfy { $0.source == "turn-runtime-engine" })
}
```

In all-pilots tests, add `import BASRuntimeCore` and this construction check:

```swift
func testMakeWithAllPilotsForwardsInjectedEventLog() async throws {
    let log = BASInMemoryEventLogStorage()
    let brain = try await BASCognitiveBrain.makeWithAllPilots(eventLog: log)
    let bundle = await brain.bundle
    let actual = try XCTUnwrap(bundle.eventLog as? BASInMemoryEventLogStorage)
    XCTAssertTrue(actual === log)
}
```

- [x] Run these four exact new test names with the retained native/offline
  command and unique log. Missing argument/compiler failure is API RED, not
  behavioral RED. Once signatures exist, preserve at least a behavioral check
  of a dropped override before completing forwarding. Do not simulate success
  by accepting zero tests, broad catches, placeholders or unavailable resources.
- [x] Builder implementation: use internal parameter name `injectedEventLog`
  to retain the existing resolved local `eventLog` without broad renaming:

```swift
public static func build(
    options: BASCognitiveOSBundleOptions,
    eventLog injectedEventLog: (any BASEventLogStorage)? = nil
) throws -> BASCognitiveOSBundle

public static func build(
    options: BASCognitiveOSBundleOptions,
    embeddingProvider: (any BASMemory.BASEmbeddingProvider)?,
    eventLog injectedEventLog: (any BASEventLogStorage)? = nil
) throws -> BASCognitiveOSBundle
```

Add `&& injectedEventLog == nil` to both empty shortcuts. The first overload
forwards `eventLog: injectedEventLog` to the second. Resolve the second's log as:

```swift
let eventLog: (any BASEventLogStorage)?
if let injectedEventLog {
    eventLog = injectedEventLog
} else if options.enableEventLog {
    if let url = options.eventLogSQLiteURL {
        eventLog = try BASSQLiteEventLogStorage(databaseURL: url)
    } else {
        eventLog = BASInMemoryEventLogStorage()
    }
} else {
    eventLog = nil
}
```

Leave all other primitive construction untouched. Document that explicit
instance injection overrides both the flag and URL, without opening the URL.

- [x] Add `eventLog: (any BASEventLogStorage)? = nil` immediately after
  `options:` on the real-services brain initializer. Change its builder call
  to `.build(options: options, eventLog: eventLog)`. Keep the existing engine's
  `eventLog: bundle.eventLog` unchanged.
- [x] Add the same argument as the final defaulted parameter on each of
  `makeWithDefaults` and `makeWithAllPilots`. Defaults forwards it immediately
  after `options:` to the real initializer; all-pilots forwards it as the final
  argument to defaults. Preserve every existing parameter and default.
- [x] Run the new focused cases, then the complete three affected test-class
  filters once on amended code. Preserve their existing nil-path/SQLite and
  real-provider expectations. Report actual counts/exits/logs and native
  warnings; do not call these selected-model or fresh-process recovery tests.
- [x] Save `task-25-report.md` and `task-25-scoped.diff` in the existing solo
  workspace, with exact commands/results and a hash. No child Git writes or
  subagents. Root checks the result and dispatches independent task review.

### Native command and log preservation

Run from `BehavioralAISubstrate/`. Compiler-cache writes already require scoped
escalation on this host; request that for the first native attempt. Allocate a
fresh log inside **every** invocation, including retries, so even an identical
retried command cannot overwrite an earlier log. Record its printed resolved
path and actual terminal handle/exit. Use this shape with the named focused or
three-class covering filter, without enabling any model opt-in variables:

```sh
LOG="$(mktemp /private/tmp/task-25-native.XXXXXX)"
printf 'Retained log: %s\n' "$LOG"
/usr/bin/script -q "$LOG" /usr/bin/env -u QINAO_JOURNAL_GROUND -u QINAO_JOURNAL_GROUND_REPO -u QINAO_JOURNAL_GROUND_SEMANTIC -u BAS_ENDURANCE_AUTOSTART -u BAS_V12_PROBE -u BAS_FUZZ_BENCH_RUN -u QINAO_MLX_E2E -u QINAO_MLX_BENCH -u QINAO_FM_E2E -u BAS_T5_XCTEST -u BAS_AGENT_FABRIC MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib swift test --build-system native --scratch-path /private/tmp/qinao-bas-native-test-1329bde3 --disable-automatic-resolution --filter FILTER
```

## Preflight consistency

| Relationship | Check |
| --- | --- |
| Task23 / Task25 | Reader protocol/storage unchanged; this task passes the same existing actor, not its file URL |
| Task24 / Task25 | Different source/tests, shared scratch requires serial ownership |
| Builder / real initializer / factories | Same public label/type, existing nil branch preserved; both shortcuts respect override |
| Bundle / engine | Existing reference forwarded unchanged; identity plus observed engine writes checked |
| Test scope / App requirement | Existing bundled classifier tests allowed as ordinary offline validation, no new model or fallback; cold App recovery still open |
| Lifecycle history / new claims | Existing start marker is emitted after coordinator work and append errors can be swallowed; this task does not fix or relabel either behavior |

## Verified completion — 2026-09-10

Task25 passed independent spec and code-quality review with no Critical or
Important findings. Four focused behavioral tests went from 10 expected
failures to zero; the three affected classes then ran 71 tests with zero
failures. The retained report and exact log paths are in
`.superpowers/sdd/2026-09-09-qinao-ds3-readiness-solo/task-25-report.md`.
The root verified that the current six-file diff matches the reviewed patch
SHA-256 `18d3d44c0f0c34ddc7ef322caab208da407fd8d603469ee308643f15c7eccf3a`.
Task23 was already accepted and Task24 had released the shared native scratch
before Task25 ran. Existing native-build/test warnings remain disclosed.

This completes only the shared-instance seam. Actual App host integration,
durable originals/plans/results, provider-free fresh-process recovery and
append-error propagation remain separate work. DS3 is not started or ready
on the strength of this change.
