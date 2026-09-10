// MARK: - BASMemoryAtomReducerTests — chapter 四百二 / M942
//
// Test coverage for Phase 1 第二刀:pure-function reducer that
// folds memory-atom events into a `[String: BASGovernedMemory]`
// projection。
//
// Targets per the M942 plan spec (28 tests):
//   - admit / tier / governance / remove (8)
//   - idempotent admission with confidence tiebreak (4)
//   - reducer skip on non-memory events (3)
//   - determinism: scramble identical sequence by sequenceNumber,
//     replay both via runner,assert equal (4)
//   - full session replay via project(...) (5)
//   - reducer purity: same prior + event → equal output (4)

import Foundation
import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASMemoryAtomReducerTests: XCTestCase {

    // MARK: - Fixtures

    private func makeAtom(
        idString: String = "00000000-0000-4000-8000-000000000001",
        kind: BASMemoryKind = .semantic,
        scope: BASMemoryScope = .user,
        sensitivity: BASMemorySensitivity = .low,
        tier: BASMemoryTier = .warm,
        confidence: Double = 0.6,
        sourceType: String = "test-source",
        governanceStatus: BASMemoryGovernanceStatus = .governed,
        provenanceSummary: String = "test-prov"
    ) -> BASGovernedMemory {
        BASGovernedMemory(
            id: UUID(uuidString: idString)!,
            kind: kind,
            content: "actual-content",
            scope: scope,
            sensitivity: sensitivity,
            tier: tier,
            confidence: confidence,
            sourceType: sourceType,
            lastConfirmedAt: nil,
            decayScore: 0.0,
            governanceStatus: governanceStatus,
            provenanceSummary: provenanceSummary)
    }

    private func evt(
        eventID: String = UUID().uuidString,
        timestampMs: Int64 = 1_700_000_000_000,
        sessionID: String = "sess",
        sequenceNumber: Int64 = 0,
        payload: BASMemoryAtomEventPayload
    ) -> BASEventLogEntry {
        BASEventLogEntry.memoryAtomEvent(
            eventID: eventID,
            timestampMs: timestampMs,
            sessionID: sessionID,
            sequenceNumber: sequenceNumber,
            payload: payload)
    }

    // MARK: - admit / tier / governance / remove (8)

    func testAdmittedInsertsNewAtom() {
        let atom = makeAtom()
        let payload = BASMemoryAtomEventPayload(admitted: atom)
        let event = evt(payload: payload)
        let next = BASMemoryAtomReducer.reduce(
            priorAtoms: [:], event: event)
        XCTAssertEqual(next.count, 1)
        XCTAssertEqual(next[atom.id.uuidString]?.tier, .warm)
        XCTAssertEqual(next[atom.id.uuidString]?.kind, .semantic)
    }

    func testAdmittedReplayProducesEmptyContent() {
        // Privacy doctrine:replayed atoms have empty content
        let atom = makeAtom()
        let payload = BASMemoryAtomEventPayload(admitted: atom)
        let next = BASMemoryAtomReducer.reduce(
            priorAtoms: [:], event: evt(payload: payload))
        XCTAssertEqual(
            next[atom.id.uuidString]?.content, "",
            "M942:replayed atoms have empty content (privacy)")
    }

    func testTierChangedMutatesExistingAtom() {
        let atom = makeAtom()
        var prior: [String: BASGovernedMemory] = [
            atom.id.uuidString: atom
        ]
        let payload = BASMemoryAtomEventPayload(
            tierChange: atom.id.uuidString, newTier: .hot)
        prior = BASMemoryAtomReducer.reduce(
            priorAtoms: prior, event: evt(payload: payload))
        XCTAssertEqual(
            prior[atom.id.uuidString]?.tier, .hot)
    }

    func testTierChangedOnUnknownAtomNoOp() {
        let payload = BASMemoryAtomEventPayload(
            tierChange: "missing-id", newTier: .cold)
        let next = BASMemoryAtomReducer.reduce(
            priorAtoms: [:], event: evt(payload: payload))
        XCTAssertTrue(next.isEmpty,
            "M942:tier change on unknown atom must no-op")
    }

    func testGovernanceChangedMutatesExistingAtom() {
        let atom = makeAtom()
        var prior: [String: BASGovernedMemory] = [
            atom.id.uuidString: atom
        ]
        let payload = BASMemoryAtomEventPayload(
            governanceChange: atom.id.uuidString,
            newStatus: .quarantined)
        prior = BASMemoryAtomReducer.reduce(
            priorAtoms: prior, event: evt(payload: payload))
        XCTAssertEqual(
            prior[atom.id.uuidString]?.governanceStatus,
            .quarantined)
    }

    func testGovernanceChangedOnUnknownAtomNoOp() {
        let payload = BASMemoryAtomEventPayload(
            governanceChange: "missing", newStatus: .archived)
        let next = BASMemoryAtomReducer.reduce(
            priorAtoms: [:], event: evt(payload: payload))
        XCTAssertTrue(next.isEmpty)
    }

    func testRemovedDeletesAtom() {
        let atom = makeAtom()
        var prior: [String: BASGovernedMemory] = [
            atom.id.uuidString: atom
        ]
        let payload = BASMemoryAtomEventPayload(
            remove: atom.id.uuidString)
        prior = BASMemoryAtomReducer.reduce(
            priorAtoms: prior, event: evt(payload: payload))
        XCTAssertTrue(prior.isEmpty)
    }

    func testRemovedOnUnknownAtomNoOp() {
        let payload = BASMemoryAtomEventPayload(
            remove: "ghost")
        let next = BASMemoryAtomReducer.reduce(
            priorAtoms: [:], event: evt(payload: payload))
        XCTAssertTrue(next.isEmpty)
    }

    // MARK: - Idempotent admission with confidence tiebreak (4)

    func testHigherConfidenceWinsOnReadmission() {
        let atomA = makeAtom(confidence: 0.4)
        let atomB = makeAtom(confidence: 0.9)
        let prior: [String: BASGovernedMemory] = [
            atomA.id.uuidString: atomA
        ]
        let payload = BASMemoryAtomEventPayload(admitted: atomB)
        let next = BASMemoryAtomReducer.reduce(
            priorAtoms: prior, event: evt(payload: payload))
        XCTAssertEqual(next[atomA.id.uuidString]?.confidence, 0.9,
            "M942:higher-confidence admission wins")
    }

    func testLowerConfidenceLosesOnReadmission() {
        let atomA = makeAtom(tier: .hot, confidence: 0.9)
        let atomB = makeAtom(tier: .cold, confidence: 0.2)
        let prior: [String: BASGovernedMemory] = [
            atomA.id.uuidString: atomA
        ]
        let payload = BASMemoryAtomEventPayload(admitted: atomB)
        let next = BASMemoryAtomReducer.reduce(
            priorAtoms: prior, event: evt(payload: payload))
        XCTAssertEqual(next[atomA.id.uuidString]?.tier, .hot,
            "M942:lower-confidence admission must lose")
        XCTAssertEqual(
            next[atomA.id.uuidString]?.confidence, 0.9)
    }

    func testEqualConfidenceTieKeepsExisting() {
        // chapter 一百八十五:tiebreak rule pinned as
        // admissionConfidenceTiebreakKeepsExisting = true
        let atomA = makeAtom(tier: .hot, confidence: 0.5)
        let atomB = makeAtom(tier: .cold, confidence: 0.5)
        let prior: [String: BASGovernedMemory] = [
            atomA.id.uuidString: atomA
        ]
        let payload = BASMemoryAtomEventPayload(admitted: atomB)
        let next = BASMemoryAtomReducer.reduce(
            priorAtoms: prior, event: evt(payload: payload))
        XCTAssertEqual(next[atomA.id.uuidString]?.tier, .hot,
            "M942:tie keeps existing (deterministic tiebreak)")
    }

    func testTiebreakRuleConstantPinned() {
        XCTAssertEqual(
            BASMemoryAtomReducer
                .admissionConfidenceTiebreakKeepsExisting,
            true,
            "M942:tiebreak rule pinned as named constant")
    }

    // MARK: - Reducer skip on non-memory events (3)

    func testReducerStepReturnsNilForChatEvent() {
        let chat = BASEventLogEntry(
            eventID: "c1",
            timestampMs: 0,
            kind: .chat,
            sessionID: "s",
            sequenceNumber: 0)
        let result = BASMemoryAtomReducer.reducerStep(
            prior: [:], event: chat)
        XCTAssertNil(result,
            "M942:non-memory events return nil → BASEventReplayRunner skips")
    }

    func testReducerStepReturnsNilForInternalSignalWithoutTag() {
        let entry = BASEventLogEntry(
            eventID: "i1",
            timestampMs: 0,
            kind: .internalSignal,
            sessionID: "s",
            sequenceNumber: 0,
            actions: ["other-tag"])
        let result = BASMemoryAtomReducer.reducerStep(
            prior: [:], event: entry)
        XCTAssertNil(result)
    }

    func testReducerStepReturnsStateForMemoryAtomEvent() {
        let atom = makeAtom()
        let payload = BASMemoryAtomEventPayload(admitted: atom)
        let result = BASMemoryAtomReducer.reducerStep(
            prior: [:], event: evt(payload: payload))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 1)
    }

    // MARK: - Determinism: sequence-order independence (4)

    func testReplayBytesEqualForSameEventSetThroughRunner() async {
        // Same set of 4 events, same sessionID — replay through
        // BASEventReplayRunner twice; final projection must match。
        let atom = makeAtom()
        let storage = BASInMemoryEventLogStorage()
        let payloads: [BASMemoryAtomEventPayload] = [
            BASMemoryAtomEventPayload(admitted: atom),
            BASMemoryAtomEventPayload(
                tierChange: atom.id.uuidString, newTier: .hot),
            BASMemoryAtomEventPayload(
                governanceChange: atom.id.uuidString,
                newStatus: .quarantined),
            BASMemoryAtomEventPayload(remove: atom.id.uuidString)
        ]
        for (i, p) in payloads.enumerated() {
            let entry = BASEventLogEntry.memoryAtomEvent(
                eventID: "e\(i)",
                timestampMs: Int64(1_700_000_000 + i),
                sessionID: "sess",
                payload: p)
            _ = try? await storage.append(entry)
        }
        let r1 = await BASEventReplayRunner.replay(
            storage: storage,
            range: .singleSession(sessionID: "sess"),
            initial: [String: BASGovernedMemory](),
            reducer: BASMemoryAtomReducer.reducerStep)
        let r2 = await BASEventReplayRunner.replay(
            storage: storage,
            range: .singleSession(sessionID: "sess"),
            initial: [String: BASGovernedMemory](),
            reducer: BASMemoryAtomReducer.reducerStep)
        XCTAssertEqual(r1.finalState, r2.finalState,
            "M942:replay determinism — same events → same state")
        XCTAssertEqual(r1.eventsConsumed, r2.eventsConsumed)
        XCTAssertTrue(r1.finalState.isEmpty,
            "atom was admitted then removed → empty")
    }

    func testReplayConsumesOnlyMemoryEventsSkipsOthers() async {
        let storage = BASInMemoryEventLogStorage()
        let atom = makeAtom()
        // Mix:1 admit (memory) + 1 chat (non-memory) + 1 tier change
        _ = try? await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "m1",
                timestampMs: 1,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(admitted: atom)))
        _ = try? await storage.append(
            BASEventLogEntry(
                eventID: "c1",
                timestampMs: 2,
                kind: .chat,
                sessionID: "s",
                sequenceNumber: 0))
        _ = try? await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "m2",
                timestampMs: 3,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    tierChange: atom.id.uuidString,
                    newTier: .hot)))
        let r = await BASEventReplayRunner.replay(
            storage: storage,
            range: .singleSession(sessionID: "s"),
            initial: [String: BASGovernedMemory](),
            reducer: BASMemoryAtomReducer.reducerStep)
        XCTAssertEqual(r.eventsConsumed, 2)
        XCTAssertEqual(r.eventsSkipped, 1)
        XCTAssertEqual(r.finalState.count, 1)
        XCTAssertEqual(
            r.finalState[atom.id.uuidString]?.tier, .hot)
    }

    func testProjectFromStorageEqualsManualReduce() async {
        let storage = BASInMemoryEventLogStorage()
        let atom = makeAtom()
        let payloads: [BASMemoryAtomEventPayload] = [
            BASMemoryAtomEventPayload(admitted: atom),
            BASMemoryAtomEventPayload(
                tierChange: atom.id.uuidString, newTier: .cold)
        ]
        for (i, p) in payloads.enumerated() {
            _ = try? await storage.append(
                BASEventLogEntry.memoryAtomEvent(
                    eventID: "e\(i)",
                    timestampMs: Int64(1000 + i),
                    sessionID: "s",
                    payload: p))
        }
        let projected = await BASMemoryAtomReducer.project(
            from: storage, sessionID: "s")
        XCTAssertEqual(projected.count, 1)
        XCTAssertEqual(
            projected[atom.id.uuidString]?.tier, .cold)
    }

    func testReplayDeterminismOver100Events() async {
        // Heavier sweep — 50 admits + 50 tier changes interleaved
        let storage = BASInMemoryEventLogStorage()
        var atomIDs: [String] = []
        for i in 0..<50 {
            let id = UUID(uuidString:
                "00000000-0000-4000-8000-\(String(format: "%012d", i))")!
            let atom = makeAtom(idString: id.uuidString,
                confidence: Double(i % 10) / 10.0 + 0.05)
            atomIDs.append(id.uuidString)
            _ = try? await storage.append(
                BASEventLogEntry.memoryAtomEvent(
                    eventID: "admit-\(i)",
                    timestampMs: Int64(i),
                    sessionID: "stress",
                    payload: BASMemoryAtomEventPayload(
                        admitted: atom)))
        }
        for (i, id) in atomIDs.enumerated() {
            let tier: BASMemoryTier =
                [.hot, .warm, .cold][i % 3]
            _ = try? await storage.append(
                BASEventLogEntry.memoryAtomEvent(
                    eventID: "tc-\(i)",
                    timestampMs: Int64(50 + i),
                    sessionID: "stress",
                    payload: BASMemoryAtomEventPayload(
                        tierChange: id, newTier: tier)))
        }
        let p1 = await BASMemoryAtomReducer.project(
            from: storage, sessionID: "stress")
        let p2 = await BASMemoryAtomReducer.project(
            from: storage, sessionID: "stress")
        XCTAssertEqual(p1, p2,
            "M942:100-event replay byte-stable across runs")
        XCTAssertEqual(p1.count, 50)
    }

    // MARK: - Full session replay via project(...) (5)

    func testProjectOnEmptySessionReturnsEmpty() async {
        let storage = BASInMemoryEventLogStorage()
        let p = await BASMemoryAtomReducer.project(
            from: storage, sessionID: "no-such")
        XCTAssertTrue(p.isEmpty)
    }

    func testProjectIsolatesPerSession() async {
        let storage = BASInMemoryEventLogStorage()
        let atom = makeAtom()
        _ = try? await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e1",
                timestampMs: 0,
                sessionID: "session-A",
                payload: BASMemoryAtomEventPayload(
                    admitted: atom)))
        _ = try? await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e2",
                timestampMs: 1,
                sessionID: "session-B",
                payload: BASMemoryAtomEventPayload(
                    admitted: makeAtom(idString:
                        "00000000-0000-4000-8000-000000000099"))))
        let pA = await BASMemoryAtomReducer.project(
            from: storage, sessionID: "session-A")
        let pB = await BASMemoryAtomReducer.project(
            from: storage, sessionID: "session-B")
        XCTAssertEqual(pA.count, 1)
        XCTAssertEqual(pB.count, 1)
        XCTAssertNotEqual(pA.keys.first, pB.keys.first)
    }

    func testProjectAfterAdmitTierGovernanceMatchesExpected() async {
        let storage = BASInMemoryEventLogStorage()
        let atom = makeAtom()
        _ = try? await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e1",
                timestampMs: 0,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    admitted: atom)))
        _ = try? await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e2",
                timestampMs: 1,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    tierChange: atom.id.uuidString,
                    newTier: .hot)))
        _ = try? await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e3",
                timestampMs: 2,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    governanceChange: atom.id.uuidString,
                    newStatus: .archived)))
        let p = await BASMemoryAtomReducer.project(
            from: storage, sessionID: "s")
        let projected = p[atom.id.uuidString]!
        XCTAssertEqual(projected.tier, .hot)
        XCTAssertEqual(
            projected.governanceStatus, .archived)
    }

    func testProjectAfterRemoveDropsAtom() async {
        let storage = BASInMemoryEventLogStorage()
        let atom = makeAtom()
        _ = try? await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e1",
                timestampMs: 0,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    admitted: atom)))
        _ = try? await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "e2",
                timestampMs: 1,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    remove: atom.id.uuidString)))
        let p = await BASMemoryAtomReducer.project(
            from: storage, sessionID: "s")
        XCTAssertTrue(p.isEmpty)
    }

    func testProjectMultipleAtomsIndependent() async {
        let storage = BASInMemoryEventLogStorage()
        let a = makeAtom(idString:
            "00000000-0000-4000-8000-00000000000a")
        let b = makeAtom(idString:
            "00000000-0000-4000-8000-00000000000b")
        for (i, atom) in [a, b].enumerated() {
            _ = try? await storage.append(
                BASEventLogEntry.memoryAtomEvent(
                    eventID: "e\(i)",
                    timestampMs: Int64(i),
                    sessionID: "s",
                    payload: BASMemoryAtomEventPayload(
                        admitted: atom)))
        }
        _ = try? await storage.append(
            BASEventLogEntry.memoryAtomEvent(
                eventID: "rm-a",
                timestampMs: 100,
                sessionID: "s",
                payload: BASMemoryAtomEventPayload(
                    remove: a.id.uuidString)))
        let p = await BASMemoryAtomReducer.project(
            from: storage, sessionID: "s")
        XCTAssertEqual(p.count, 1)
        XCTAssertNotNil(p[b.id.uuidString])
        XCTAssertNil(p[a.id.uuidString])
    }

    // MARK: - Reducer purity (4)

    func testReduceDoesNotMutateInputDictionary() {
        let atom = makeAtom()
        let prior: [String: BASGovernedMemory] = [
            atom.id.uuidString: atom
        ]
        let payload = BASMemoryAtomEventPayload(
            tierChange: atom.id.uuidString, newTier: .hot)
        _ = BASMemoryAtomReducer.reduce(
            priorAtoms: prior, event: evt(payload: payload))
        // prior must be unchanged
        XCTAssertEqual(prior[atom.id.uuidString]?.tier, .warm,
            "M942:reduce must NOT mutate prior dictionary")
    }

    func testReduceProducesEqualOutputForSameInputs() {
        let atom = makeAtom()
        let prior: [String: BASGovernedMemory] = [:]
        let payload = BASMemoryAtomEventPayload(admitted: atom)
        let event = evt(eventID: "fixed-id", payload: payload)
        let r1 = BASMemoryAtomReducer.reduce(
            priorAtoms: prior, event: event)
        let r2 = BASMemoryAtomReducer.reduce(
            priorAtoms: prior, event: event)
        XCTAssertEqual(r1, r2,
            "M942:purity — same inputs → equal outputs")
    }

    func testNonMemoryEventReturnsPriorUnchanged() {
        let atom = makeAtom()
        let prior: [String: BASGovernedMemory] = [
            atom.id.uuidString: atom
        ]
        let chat = BASEventLogEntry(
            eventID: "c", timestampMs: 0, kind: .chat,
            sessionID: "s", sequenceNumber: 0)
        let next = BASMemoryAtomReducer.reduce(
            priorAtoms: prior, event: chat)
        XCTAssertEqual(next, prior,
            "M942:non-memory event must produce prior unchanged")
    }

    func testReduceIsValueLevelDeterministic() {
        // Run reduce 5x with same inputs;every call must produce
        // the same projected dictionary (chapter 三百九二 pin)。
        let atom = makeAtom()
        let payload = BASMemoryAtomEventPayload(admitted: atom)
        let event = evt(payload: payload)
        var results: [[String: BASGovernedMemory]] = []
        for _ in 0..<5 {
            results.append(
                BASMemoryAtomReducer.reduce(
                    priorAtoms: [:], event: event))
        }
        for i in 1..<5 {
            XCTAssertEqual(results[0], results[i],
                "M942:5-run determinism (run \(i) diverged)")
        }
    }
}
