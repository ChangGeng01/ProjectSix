# Memory derivation timezone fixture implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development for Task24.
> Continue the existing solo workspace; root owns Git and independent review.

**Goal:** restore meaningful late-session coverage on both UTC CI and the local
Melbourne host, without changing the product's local-time interpretation.

**Architecture:** correct the test fixture's clock assumptions in its existing
test file. Construct intended wall-clock hours using the same current calendar
as the consumer; retain all existing assertions and add day/night boundaries.

**Tech Stack:** Foundation Calendar, Swift Testing, existing BASMemory compiler.

**Spec:** `docs/superpowers/specs/2026-09-10-qinao-approved-decisions.md`, ordinary
necessary CI with retained coverage. Source-confirmed cause candidate: the first
test's 22/23-hour +10:00 instants become 12/13-hour UTC, while
`MemoryDerivationCore.swift` semanticDrafts uses `Calendar.current` at line927.
CI run34456200441 omitted only the expected late_session draft. The unchanged
native case has now reproduced that failure in UTC (1 case, 1 issue, exit1) and
passed in Melbourne (1 case, 0 issues, exit0). Reuse both retained baselines;
do not repeat them merely to rediscover the cause.

## Global constraints

- Preserve old source, tests, records and history; no test deletion or skip.
- Do not change product timezone semantics, dependencies or workflow timezone.
- No models, cloud/PCC, new scans, data migration, cache cleanup or full suite.
- Task23 owns the BAS scratch until it explicitly releases it. Never run native
  work concurrently with that owner. Use the same retained scratch/metallib.
- This is a CI fixture repair, not completion of App persistence or DS3 readiness.

## Task24: Host-calendar test data and semantic boundary controls

**Files:** Modify only
`BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASMemoryDerivationCoreTests.swift`.

**Interfaces:** consume unchanged `BASMemoryDraftCompiler.derive(_:)`; no new
product API. Existing `date(_:)` helper and unrelated fixtures stay unchanged.

- [x] **RED:** reuse `/private/tmp/task-24-memory-utc-baseline.log` if the actual
  named original test ran and failed on its late_session assertion. Otherwise
  run only `BASMemoryDerivationCoreTests/derivesStructuredDraftsFromEvidence` in
  a fresh `TZ=UTC` process, using `swift test --build-system native --skip-build`
  when the existing bundle contains that unchanged test. Record exact command,
  count and exit. A zero-test result or compilation failure is not behavioral
  RED. If it does not reproduce, stop this proposed fix and report the evidence.
- [x] **Correct intended late-hour fixtures:** add the following test-only
  helper and use it for the first test's three event dates, with the existing
  date strings and intended hours/minutes (22:10, 22:45 and 23:05):

```swift
private func localEventDate(_ value: String, hour: Int, minute: Int) throws -> Date {
    let anchor = try #require(ISO8601DateFormatter().date(from: value))
    return try #require(Calendar.current.date(
        bySettingHour: hour, minute: minute, second: 0, of: anchor
    ))
}
```

For example the first value becomes
`createdAt: try localEventDate("2026-04-08T22:10:00+10:00", hour: 22, minute: 10)`.
The fixture describes local wall-clock intent; the original absolute instants
are not product requirements. Retain every existing draft/promotion assertion.

- [x] **Add real semantic boundary coverage:** add this parameterized test:

```swift
@Test("late-session derivation respects local day/night boundaries", arguments: [5, 6, 20, 21])
func lateSessionBoundaries(hour: Int) throws {
    let minute = (hour == 5 || hour == 20) ? 59 : 0
    let instant = try localEventDate("2026-04-08T12:00:00Z", hour: hour, minute: minute)
    #expect(Calendar.current.component(.hour, from: instant) == hour)
    #expect(Calendar.current.component(.minute, from: instant) == minute)
    let events = (1...3).map { index in
        BASCheckEventMemoryInput(
            id: "boundary-\(index)", scenarioID: "buy", scenarioTitle: "Buy",
            actionID: "decideTomorrow", actionTitle: "Tomorrow Box",
            note: "Boundary fixture", createdAt: instant
        )
    }
    let drafts = BASMemoryDraftCompiler.derive(BASMemoryDerivationRequest(
        cues: [], checkEvents: events, comparativeRecords: [], reflectiveRecords: [], now: instant
    ))
    let late = drafts.first { $0.id == "semantic.pattern.late_session" }
    let expectedLate = hour == 5 || hour == 21
    #expect((late != nil) == expectedLate)
    if expectedLate {
        let pattern = try #require(late)
        #expect(pattern.evidenceCount == 3)
        #expect(pattern.promotionPolicy == .repeated(minConfirmationCount: 2, minEvidenceCount: 3))
    }
}
```

- [x] **GREEN and covering evidence:** run the complete
  `BASMemoryDerivationCoreTests` filter once under `TZ=UTC` and once in a separate
  `TZ=Australia/Melbourne` process. First invocation builds amended code;
  second may use `--skip-build`. Keep task21-report's native/offline/model-opt-out
  command, adding only TZ and the filter. Record actual test/parameter counts,
  failures and exit; do not claim both tests/frameworks ran if only one did.

Use this command from `BehavioralAISubstrate/`, substituting unique LOG and TZ
values for each of the two processes; the second may add `--skip-build`:

```sh
/usr/bin/script -q LOG /usr/bin/env -u QINAO_JOURNAL_GROUND -u QINAO_JOURNAL_GROUND_REPO -u QINAO_JOURNAL_GROUND_SEMANTIC -u BAS_ENDURANCE_AUTOSTART -u BAS_V12_PROBE -u BAS_FUZZ_BENCH_RUN -u QINAO_MLX_E2E -u QINAO_MLX_BENCH -u QINAO_FM_E2E -u BAS_T5_XCTEST -u BAS_AGENT_FABRIC TZ=TIMEZONE MLX_METAL_PATH=/private/tmp/qinao-mlx-metallib-1329bde3/mlx/backend/metal/kernels/mlx.metallib swift test --build-system native --scratch-path /private/tmp/qinao-bas-native-test-1329bde3 --disable-automatic-resolution --filter BASMemoryDerivationCoreTests
```

- [x] **Handback:** write concise commands/results/log paths, self-review and
  one-file frozen diff to the existing solo workspace as `task-24-report.md`
  and `task-24-scoped.diff`. Root independently reviews before scoped commit.

## Preflight consistency

| Relationship | Check |
| --- | --- |
| Task23 / Task24 | No source overlap; shared native scratch requires serial ownership |
| Fixture / product | Both use current-calendar wall-clock time; no product behavior edit |
| Existing positive / new boundaries | All old expectations retained; 05:59 and21:00 positive,06:00 and20:59 negative |
| Scope / evidence | One file, original UTC RED, amended full selected suite in two fresh timezone processes |

## Accepted bounded result

Both timezone processes passed the same10 Swift Testing definitions, including
four boundary arguments, with zero issues. Independent review found the code
spec-compliant and approved; existing compiler/native-backend warnings remain
deferred. The initial sandbox-denied attempt's temporary log was overwritten
by its successful retry and is not claimed retained; the original RED/Melbourne
control and both GREEN logs remain. No new baseline was run to recreate it.
Production timezone behavior, stored data and App persistence are unchanged.
