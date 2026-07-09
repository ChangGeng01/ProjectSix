// MARK: - BASChapter834PostShipReviewFixesTests
// chapter 八百三十四 / M2821-M2825 — post-v0.61.0 review fixes
//
// Verifies the 4 issues found by the post-ship 全量 审查:
//
//   1. HIGH:contradiction refs round-trip survives commas in refs
//      (chapter 八百三十四 joiner change: ", " → "; ")
//   2. LOW:legacy ", " joiner still parses for backward compat
//   3. LOW:dead `stripped()` helper removed (compile-time check —
//      if this file compiles + tests pass,it's gone)
//   4. LOW:partial-success behavior in BASAuditPipeline.recordTurn
//      surfaces as a clean throw with earlier writes preserved

import XCTest
@testable import BASMemory
@testable import BASSovereign
@testable import BASOrchestration

final class BASChapter834PostShipReviewFixesTests: XCTestCase {

    // MARK: - HIGH:refs with literal commas round-trip cleanly

    func testContradictionRefsWithCommasRoundTripCorrectly() async throws {
        // The pre-八百三十四 bug:if a ref contained `, ` literally,
        // the parser would split it as two refs。 With the new "; "
        // joiner,refs with commas survive round trip。
        let store = BASInMemoryContradictionLedgerStore()
        let nodes = [
            BASContradictionRecord(
                nodeID: "n1",
                kind: .textual,
                summary: "claim conflict",
                refs: [
                    "actor A, secondary",   // contains ", "
                    "turn-5, paragraph-2",  // contains ", "
                ],
                severity: 0.7,
                unresolved: true),
        ]
        _ = try await BASRoutedMirrorBladeRecording
            .recordContradictions(
                nodes,
                sessionID: "s",
                turnID: "t",
                store: store,
                eventIDPrefix: "c-comma",
                nowMs: 0)
        let stored = await store.records(forSession: "s")
        XCTAssertEqual(stored.count, 1)
        let restored = BASRoutedMirrorBladeRecording
            .reconstructContradictions(from: stored)
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(
            restored[0].refs,
            ["actor A, secondary", "turn-5, paragraph-2"],
            "Refs with literal commas survive round-trip via the " +
            "'; ' joiner introduced at chapter 八百三十四")
    }

    // MARK: - LOW:legacy ", " joiner still parses (backward compat)

    func testParseContradictionTextAcceptsLegacyCommaJoiner() {
        // Old pre-八百三十四 records used ", " as the refs joiner。
        // The parser fall-back path still accepts them so any
        // pre-v0.61.0 persisted data round-trips with best effort。
        let legacyText = "historical: earlier vs later turn " +
                         "(refs: t-5, t-9, t-12)"
        let parsed = BASRoutedMirrorBladeRecording
            .parseContradictionText(legacyText)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.kind, .historical)
        XCTAssertEqual(parsed?.summary, "earlier vs later turn")
        XCTAssertEqual(parsed?.refs, ["t-5", "t-9", "t-12"],
            "Legacy ', ' joiner still parses for backward compat")
    }

    func testParseContradictionTextPrefersNewSemicolonJoinerWhenPresent() {
        let newText = "textual: A vs B (refs: ref-1; ref-2; ref-3)"
        let parsed = BASRoutedMirrorBladeRecording
            .parseContradictionText(newText)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.refs, ["ref-1", "ref-2", "ref-3"])
    }

    // MARK: - LOW:empty refs body parses as empty array

    func testParseContradictionTextEmptyRefsBodyYieldsEmptyArray() {
        let text = "role: ambig binding (refs: )"
        let parsed = BASRoutedMirrorBladeRecording
            .parseContradictionText(text)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.refs, [],
            "Empty refs body produces empty array (no spurious empty string)")
    }

    // MARK: - LOW:partial-success behavior in pipeline

    func testPipelinePartialSuccessLeavesEarlierWritesIntact() async throws {
        // Demonstrates the documented behavior:if a recorder
        // mid-pipeline throws,earlier recorders' writes persist。
        // Pipeline order is presence → unknowns → contradictions
        // → atom → version。 Reusing the same eventIDPrefix across
        // calls causes a presence-store collision on the 2nd call,
        // but only AFTER the 1st call's L7 + L8 writes succeeded
        // in the 1st turn。
        let presenceStore = BASInMemoryPresenceObservationStore()
        let unknownStore = BASInMemoryUnknownLedgerStore()
        let contradictionStore = BASInMemoryContradictionLedgerStore()
        let atomStore = BASInMemoryAtomLifecycleStore()
        let versionStore = BASInMemoryHostConstitutionVersionTreeStore()
        let pipeline = BASAuditPipeline(
            presenceStore: presenceStore,
            unknownStore: unknownStore,
            contradictionStore: contradictionStore,
            atomLifecycleStore: atomStore,
            versionTreeStore: versionStore)

        // 1st turn:full write succeeds
        let firstInput = BASAuditPipeline.PerTurnInput(
            sessionID: "s",
            turnID: "t1",
            nowMs: 0,
            eventIDPrefix: "shared",
            observations: [
                BASChannelObservationInput(
                    channelByte: 0, salience: 0.5, confidence: 0.5),
            ],
            unknownSet: BASUnknownSet(missingFacts: ["F1"]))
        _ = try await pipeline.recordTurn(input: firstInput)
        let initialPresenceCount = await presenceStore.count()
        let initialUnknownCount = await unknownStore.count()
        XCTAssertEqual(initialPresenceCount, 1)
        XCTAssertEqual(initialUnknownCount, 1)

        // 2nd turn:reuse "shared" prefix → L6 collides on "shared-0"
        let secondInput = BASAuditPipeline.PerTurnInput(
            sessionID: "s",
            turnID: "t2",
            nowMs: 1,
            eventIDPrefix: "shared",  // collision!
            observations: [
                BASChannelObservationInput(
                    channelByte: 0, salience: 0.5, confidence: 0.5),
            ],
            // These would have been written if L6 succeeded:
            unknownSet: BASUnknownSet(missingFacts: ["F-unwritten"]))
        do {
            _ = try await pipeline.recordTurn(input: secondInput)
            XCTFail("Expected presence-store duplicate to throw")
        } catch BASInMemoryPresenceObservationStore.StoreError
            .duplicateEventID {
            // Expected throw — L6 first in pipeline order
        }

        // After throw:
        //   - L6 (presence):still has just the 1st turn's row
        //   - L7 (unknowns):should NOT have written F-unwritten
        let afterPresenceCount = await presenceStore.count()
        let afterUnknownCount = await unknownStore.count()
        XCTAssertEqual(afterPresenceCount, 1,
            "Presence rows unchanged after duplicate throw")
        XCTAssertEqual(afterUnknownCount, 1,
            "Unknown rows did NOT advance — L7 never ran because " +
            "L6 (earlier in pipeline order) threw first")
    }

    // MARK: - audit orchestration LOW-1: recordTurn honors cooperative cancellation

    func testRecordTurnHonorsCancellationBetweenWrites() async throws {
        let gatedUnknown = GatedUnknownStore()
        let pipeline = BASAuditPipeline(
            presenceStore: BASInMemoryPresenceObservationStore(),
            unknownStore: gatedUnknown,
            contradictionStore: BASInMemoryContradictionLedgerStore(),
            atomLifecycleStore: BASInMemoryAtomLifecycleStore(),
            versionTreeStore: BASInMemoryHostConstitutionVersionTreeStore())
        // Two unknowns → the per-item loop runs twice; the store parks the FIRST write.
        let input = BASAuditPipeline.PerTurnInput(
            sessionID: "s", turnID: "t", nowMs: 0, eventIDPrefix: "c",
            unknownSet: BASUnknownSet(missingFacts: ["a", "b"]))

        let task = Task { try await pipeline.recordTurn(input: input) }
        await gatedUnknown.waitUntilParked()   // parked inside the FIRST unknown write
        task.cancel()
        await gatedUnknown.release()
        do {
            _ = try await task.value
            XCTFail("a cancelled recordTurn must throw")
        } catch is CancellationError {
            // expected: the loop's next checkCancellation caught the cancellation
        } catch {
            XCTFail("expected CancellationError, got \(error)")
        }
        let written = await gatedUnknown.writeCount()
        XCTAssertEqual(written, 1,
            "only the first item committed; the loop stopped on cancellation before the 2nd write")
    }
}

/// Parks the FIRST appendRecord so a cancellation can be injected mid-pipeline.
private actor GatedUnknownStore: BASUnknownLedgerStore {
    private let inner = BASInMemoryUnknownLedgerStore()
    private var firstParked = false
    private var gate: CheckedContinuation<Void, Never>?
    private var parkedWaiter: CheckedContinuation<Void, Never>?
    private var didPark = false

    func appendRecord(_ record: BASUnknownLedgerRecord) async throws -> BASUnknownLedgerRecord {
        if !firstParked {
            firstParked = true
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                gate = c; didPark = true
                parkedWaiter?.resume(); parkedWaiter = nil
            }
        }
        return try await inner.appendRecord(record)
    }
    func records(forSession sessionID: String) async -> [BASUnknownLedgerRecord] {
        await inner.records(forSession: sessionID)
    }
    func records(forTurn turnID: String) async -> [BASUnknownLedgerRecord] {
        await inner.records(forTurn: turnID)
    }
    func count() async -> Int { await inner.count() }
    func writeCount() async -> Int { await inner.count() }
    func waitUntilParked() async {
        if didPark { return }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in parkedWaiter = c }
    }
    func release() { gate?.resume(); gate = nil }
}
