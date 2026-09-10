import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

/// M101 — `BASMemoryForgetCascadeRunner` pure-function executor
/// tests.
///
/// The runner takes a forget cascade + a memory field and produces
/// a new field with matched records scrubbed plus a typed outcome.
/// These tests pin:
///
/// 1. Enum raw values stable (5-case lifecycle)
/// 2. isTerminal semantics
/// 3. Happy path: targets match records → `.completed` with
///    removed record IDs + updated cascade state
/// 4. No-match short-circuit: targets exist but match nothing →
///    `.skipped` with reason `"nothing-to-remove"`, field unchanged
/// 5. Pre-flight validation: empty targets + empty dependents →
///    `.failed` with reason `"empty-cascade-targets"`, field
///    unchanged
/// 6. dependentRefs are matched in addition to rootTargets
/// 7. Other field collections (sanctumEntries / quarantineRecords /
///    etc.) are preserved byte-for-byte across apply
/// 8. The cascade itself stays in the field's forgetCascades
///    collection (runner does not self-delete its own cascade)
final class BASMemoryForgetCascadeRunnerTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1000)
    private let t1 = Date(timeIntervalSince1970: 2000)

    // MARK: - Helpers

    private func makeRecord(
        memoryID: String
    ) -> BASTemporalMemoryRecord {
        BASTemporalMemoryRecord(
            memoryID: memoryID,
            summary: "r-\(memoryID)",
            memoryType: .episode,
            sourceClass: "test",
            timestamp: t0,
            certainty: 0.8,
            evidenceStrength: 0.5,
            hostScope: "host.v1",
            sovereignScope: "sov.v1")
    }

    private func makeField(
        memoryIDs: [String]
    ) -> BASTemporalMemoryField {
        BASTemporalMemoryField(
            records: memoryIDs.map(makeRecord))
    }

    private func makeCascade(
        cascadeID: String = "cascade.1",
        rootTargets: [String] = [],
        dependentRefs: [String] = []
    ) -> BASMemoryForgetCascade {
        BASMemoryForgetCascade(
            cascadeID: cascadeID,
            rootTargets: rootTargets,
            dependentRefs: dependentRefs,
            executionState:
                BASForgetCascadeExecutionState.queued.rawValue)
    }

    // MARK: - 1. Enum raw values + isTerminal

    func testExecutionStateRawValuesAreStable() {
        XCTAssertEqual(
            BASForgetCascadeExecutionState.queued.rawValue,
            "queued")
        XCTAssertEqual(
            BASForgetCascadeExecutionState.inFlight.rawValue,
            "in-flight")
        XCTAssertEqual(
            BASForgetCascadeExecutionState.completed.rawValue,
            "completed")
        XCTAssertEqual(
            BASForgetCascadeExecutionState.skipped.rawValue,
            "skipped")
        XCTAssertEqual(
            BASForgetCascadeExecutionState.failed.rawValue,
            "failed")
    }

    func testIsTerminalFlagsTerminalStates() {
        XCTAssertFalse(
            BASForgetCascadeExecutionState.queued.isTerminal)
        XCTAssertFalse(
            BASForgetCascadeExecutionState.inFlight.isTerminal)
        XCTAssertTrue(
            BASForgetCascadeExecutionState.completed.isTerminal)
        XCTAssertTrue(
            BASForgetCascadeExecutionState.skipped.isTerminal)
        XCTAssertTrue(
            BASForgetCascadeExecutionState.failed.isTerminal)
    }

    // MARK: - 2. Happy path — targets match records

    func testHappyPathRemovesMatchingRecordsAndMarksCompleted() {
        let field = makeField(
            memoryIDs: ["a", "b", "c", "d"])
        let cascade = makeCascade(
            rootTargets: ["b", "d"])
        let runner = BASMemoryForgetCascadeRunner()
        var clockCallCount = 0
        let clock: () -> Date = { [t0, t1] in
            clockCallCount += 1
            return clockCallCount == 1 ? t0 : t1
        }

        let (newField, outcome) = runner.apply(
            cascade, to: field, now: clock)

        XCTAssertEqual(
            newField.records.map(\.memoryID), ["a", "c"],
            "only unmatched records survive, insertion order preserved")
        XCTAssertEqual(outcome.terminalState, .completed)
        XCTAssertEqual(
            outcome.removedRecordIDs, ["b", "d"],
            "removed IDs match target set in insertion order")
        XCTAssertEqual(outcome.reasonCodes, [])
        XCTAssertEqual(outcome.startedAt, t0)
        XCTAssertEqual(outcome.finishedAt, t1)
        XCTAssertEqual(
            outcome.cascade.executionState,
            BASForgetCascadeExecutionState.completed.rawValue,
            "cascade's executionState stamped with terminal state")
    }

    // MARK: - 3. No-match short-circuit

    func testNoMatchSkipsAndLeavesFieldUnchanged() {
        let field = makeField(memoryIDs: ["a", "b"])
        let cascade = makeCascade(rootTargets: ["x", "y"])
        let runner = BASMemoryForgetCascadeRunner()

        let (newField, outcome) = runner.apply(
            cascade, to: field, now: { self.t0 })

        XCTAssertEqual(
            newField.records.map(\.memoryID), ["a", "b"],
            "field unchanged when no target matches")
        XCTAssertEqual(outcome.terminalState, .skipped)
        XCTAssertEqual(outcome.removedRecordIDs, [])
        XCTAssertEqual(outcome.reasonCodes, ["nothing-to-remove"])
        XCTAssertEqual(
            outcome.cascade.executionState,
            BASForgetCascadeExecutionState.skipped.rawValue)
    }

    // MARK: - 4. Empty-cascade pre-flight

    func testEmptyCascadeFailsFastWithReason() {
        let field = makeField(memoryIDs: ["a"])
        // Cascade with no targets AND no dependent refs.
        let cascade = makeCascade()
        let runner = BASMemoryForgetCascadeRunner()

        let (newField, outcome) = runner.apply(
            cascade, to: field, now: { self.t0 })

        XCTAssertEqual(
            newField.records.map(\.memoryID), ["a"],
            "field untouched on validation failure")
        XCTAssertEqual(outcome.terminalState, .failed)
        XCTAssertEqual(
            outcome.reasonCodes, ["empty-cascade-targets"])
        XCTAssertEqual(
            outcome.cascade.executionState,
            BASForgetCascadeExecutionState.failed.rawValue)
    }

    // MARK: - 5. dependentRefs also match

    func testDependentRefsAreMatchedAlongsideRootTargets() {
        let field = makeField(
            memoryIDs: ["root.a", "dep.b", "other.c"])
        let cascade = makeCascade(
            rootTargets: ["root.a"],
            dependentRefs: ["dep.b"])
        let runner = BASMemoryForgetCascadeRunner()

        let (newField, outcome) = runner.apply(
            cascade, to: field, now: { self.t0 })

        XCTAssertEqual(
            newField.records.map(\.memoryID), ["other.c"])
        XCTAssertEqual(
            Set(outcome.removedRecordIDs),
            Set(["root.a", "dep.b"]),
            "both rootTargets and dependentRefs matched")
    }

    // MARK: - 6. Other collections preserved

    func testOtherFieldCollectionsPreservedAcrossApply() {
        let sanctum = BASMemorySanctumEntry(
            entryID: "sanct.1",
            memoryRef: "a",
            accessPolicy: "frozen",
            revealConditions: ["test"],
            frozenUntil: nil)
        let quarantine = BASMemoryQuarantineRecord(
            quarantineID: "q.1",
            memoryRef: "b",
            reasonCodes: ["test"])
        let field = BASTemporalMemoryField(
            records: [makeRecord(memoryID: "a")],
            quarantineRecords: [quarantine],
            sanctumEntries: [sanctum])
        let cascade = makeCascade(rootTargets: ["a"])
        let runner = BASMemoryForgetCascadeRunner()

        let (newField, outcome) = runner.apply(
            cascade, to: field, now: { self.t0 })

        XCTAssertEqual(newField.records.count, 0,
            "matched record removed")
        XCTAssertEqual(outcome.terminalState, .completed)
        XCTAssertEqual(
            newField.sanctumEntries.map(\.entryID),
            [sanctum.entryID],
            "sanctum collection preserved byte-for-byte")
        XCTAssertEqual(
            newField.quarantineRecords.map(\.quarantineID),
            [quarantine.quarantineID],
            "quarantine collection preserved byte-for-byte")
    }

    // MARK: - 7. Input field never mutated

    func testInputFieldIsNeverMutated() {
        let originalField = makeField(memoryIDs: ["a", "b"])
        let originalIDs = originalField.records.map(\.memoryID)
        let cascade = makeCascade(rootTargets: ["a"])
        let runner = BASMemoryForgetCascadeRunner()

        _ = runner.apply(
            cascade, to: originalField, now: { self.t0 })

        XCTAssertEqual(
            originalField.records.map(\.memoryID),
            originalIDs,
            "input field untouched — pure-value semantics")
    }
}
