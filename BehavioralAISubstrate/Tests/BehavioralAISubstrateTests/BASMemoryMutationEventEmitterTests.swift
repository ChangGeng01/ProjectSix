// MARK: - BASMemoryMutationEventEmitterTests — chapter 四百二 / M944
//
// Test coverage for Phase 1 第四刀:typed event emitter that
// bridges `BASMemoryTieringReconciliationOutcome` decisions into
// typed event-log appends。
//
// Targets per the M944 plan spec (16 tests):
//   - emit per BASMemoryTierTransition variant (5)
//   - declaration-order preservation (3)
//   - idempotent-retry contract (3)
//   - null-outcome (no decisions) cleanly handles (2)
//   - interaction parity: emitter + event-sourced store vs legacy
//     mutation writer + in-memory store (3)

import Foundation
import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASMemoryMutationEventEmitterTests: XCTestCase {

    // MARK: - Fixtures

    private func makeProfile(
        atomID: String,
        currentTier: BASMemoryTier = .warm
    ) -> BASMemoryTieringProfile {
        BASMemoryTieringProfile(
            atomID: atomID,
            currentTier: currentTier,
            recencyScore: 0.5,
            accessFrequency: 0.5,
            sensitivityDrift: 0.0,
            worldContextStaleness: 0.0,
            observedAt: Date(timeIntervalSince1970: 1_700_000))
    }

    private func dec(
        _ atomID: String,
        _ t: BASMemoryTierTransition
    ) -> BASMemoryTieringReconciliationOutcome.Decision {
        BASMemoryTieringReconciliationOutcome.Decision(
            profile: makeProfile(atomID: atomID),
            transition: t)
    }

    private func makeOutcome(
        decisions: [BASMemoryTieringReconciliationOutcome.Decision]
    ) -> BASMemoryTieringReconciliationOutcome {
        BASMemoryTieringReconciliationOutcome(
            evaluatedCount: decisions.count,
            heldCount: 0,
            promotedCount: 0,
            demotedCount: 0,
            quarantineSuggestedCount: 0,
            evictSuggestedCount: 0,
            decisions: decisions,
            startedAt: Date(timeIntervalSince1970: 0),
            completedAt: Date(timeIntervalSince1970: 1))
    }

    /// Sendable counter for deterministic test eventIDs。
    private final class Counter: @unchecked Sendable {
        private var n: Int = 0
        private let lock = NSLock()
        func next() -> String {
            lock.lock(); defer { lock.unlock() }
            n += 1
            return "evt-\(n)"
        }
    }

    private func makeEmitter(
        log: any BASEventLogStorage =
            BASInMemoryEventLogStorage(),
        sessionID: String = "sess-emit"
    ) -> BASMemoryMutationEventEmitter {
        let counter = Counter()
        return BASMemoryMutationEventEmitter(
            eventLog: log,
            sessionID: sessionID,
            clockMs: { 1_700_000_000_000 },
            eventIDFactory: { counter.next() },
            source: "test-emit")
    }

    // MARK: - Emit per transition variant (5)

    func testEmitHoldProducesNoEvent() async throws {
        let log = BASInMemoryEventLogStorage()
        let emitter = makeEmitter(log: log)
        let outcome = makeOutcome(decisions: [
            dec("a", .hold(tier: .warm,
                reason: .withinThresholds))
        ])
        let result = try await emitter.emit(outcome: outcome)
        XCTAssertEqual(result.appended, 0)
        XCTAssertEqual(result.skipped, 1)
        let events = await log.events(forSession: "sess-emit")
        XCTAssertTrue(events.isEmpty,
            "M944:.hold must not append events")
    }

    func testEmitPromoteProducesTierEvent() async throws {
        let log = BASInMemoryEventLogStorage()
        let emitter = makeEmitter(log: log)
        let outcome = makeOutcome(decisions: [
            dec("p", .promote(from: .cold, to: .warm,
                reason: .highRecency))
        ])
        let result = try await emitter.emit(outcome: outcome)
        XCTAssertEqual(result.appended, 1)
        XCTAssertEqual(result.payloads.count, 1)
        XCTAssertEqual(result.payloads.first?.op, .tierChanged)
        XCTAssertEqual(result.payloads.first?.tier, .warm)
    }

    func testEmitDemoteProducesTierEvent() async throws {
        let log = BASInMemoryEventLogStorage()
        let emitter = makeEmitter(log: log)
        let outcome = makeOutcome(decisions: [
            dec("d", .demote(from: .hot, to: .warm,
                reason: .lowRecency))
        ])
        let result = try await emitter.emit(outcome: outcome)
        XCTAssertEqual(result.appended, 1)
        XCTAssertEqual(result.payloads.first?.op, .tierChanged)
        XCTAssertEqual(result.payloads.first?.tier, .warm)
    }

    func testEmitQuarantineSuggestProducesGovernanceEvent()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        let emitter = makeEmitter(log: log)
        let outcome = makeOutcome(decisions: [
            dec("q", .quarantineSuggest(from: .warm,
                reason: .sensitivityEscalated))
        ])
        let result = try await emitter.emit(outcome: outcome)
        XCTAssertEqual(result.appended, 1)
        XCTAssertEqual(
            result.payloads.first?.op, .governanceChanged)
        XCTAssertEqual(
            result.payloads.first?.governanceStatus,
            .quarantined)
    }

    func testEmitEvictSuggestProducesRemoveEvent() async throws {
        let log = BASInMemoryEventLogStorage()
        let emitter = makeEmitter(log: log)
        let outcome = makeOutcome(decisions: [
            dec("e", .evictSuggest(from: .cold,
                reason: .coldStaleUnused))
        ])
        let result = try await emitter.emit(outcome: outcome)
        XCTAssertEqual(result.appended, 1)
        XCTAssertEqual(result.payloads.first?.op, .removed)
    }

    // MARK: - Declaration-order preservation (3)

    func testEmitOrderMatchesDecisionOrder() async throws {
        let log = BASInMemoryEventLogStorage()
        let emitter = makeEmitter(log: log)
        let outcome = makeOutcome(decisions: [
            dec("first", .promote(from: .cold, to: .warm,
                reason: .highRecency)),
            dec("second", .demote(from: .hot, to: .warm,
                reason: .lowRecency)),
            dec("third", .quarantineSuggest(from: .warm,
                reason: .sensitivityEscalated))
        ])
        let result = try await emitter.emit(outcome: outcome)
        XCTAssertEqual(
            result.payloads.map { $0.atomID },
            ["first", "second", "third"])
    }

    func testEventLogSequenceMatchesEmitOrder() async throws {
        let log = BASInMemoryEventLogStorage()
        let emitter = makeEmitter(log: log, sessionID: "ord")
        let outcome = makeOutcome(decisions: [
            dec("a", .promote(from: .cold, to: .warm,
                reason: .highRecency)),
            dec("b", .promote(from: .cold, to: .warm,
                reason: .highRecency))
        ])
        _ = try await emitter.emit(outcome: outcome)
        let events = await log.events(forSession: "ord")
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(
            events.map { $0.memoryAtomEventPayload?.atomID },
            ["a", "b"])
    }

    func testHoldInterspersedDoesNotShiftRemainingOrder()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        let emitter = makeEmitter(log: log)
        let outcome = makeOutcome(decisions: [
            dec("alpha", .promote(from: .cold, to: .warm,
                reason: .highRecency)),
            dec("hold-skip", .hold(tier: .hot,
                reason: .withinThresholds)),
            dec("beta", .demote(from: .hot, to: .warm,
                reason: .lowRecency))
        ])
        let result = try await emitter.emit(outcome: outcome)
        XCTAssertEqual(
            result.payloads.map { $0.atomID },
            ["alpha", "beta"])
    }

    // MARK: - Idempotent retry (3)

    func testDuplicateEventIDDoesNotDoubleAppend() async throws {
        let log = BASInMemoryEventLogStorage()
        let emitter = BASMemoryMutationEventEmitter(
            eventLog: log,
            sessionID: "dup",
            clockMs: { 1 },
            eventIDFactory: { "fixed-evt" },
            source: "test")
        let o = makeOutcome(decisions: [
            dec("x", .promote(from: .cold, to: .warm,
                reason: .highRecency)),
            dec("y", .promote(from: .cold, to: .warm,
                reason: .highRecency))
        ])
        let result = try await emitter.emit(outcome: o)
        // 1st append wasNew=true, 2nd append same ID
        // wasNew=false → counted as duplicate
        XCTAssertEqual(result.appended, 1)
        XCTAssertEqual(result.duplicateAppendsSkipped, 1)
    }

    func testRetrySameOutcomeIsObservablyIdempotent() async throws {
        let log = BASInMemoryEventLogStorage()
        let counter = Counter()
        let emitter = BASMemoryMutationEventEmitter(
            eventLog: log,
            sessionID: "r",
            clockMs: { 1 },
            eventIDFactory: { counter.next() },
            source: "test")
        let o = makeOutcome(decisions: [
            dec("a", .promote(from: .cold, to: .warm,
                reason: .highRecency))
        ])
        // First emit succeeds
        _ = try await emitter.emit(outcome: o)
        // Second emit with new IDs (n=2) appends a 2nd event;
        // not idempotent at the EMITTER level — idempotency is
        // an event-LOG-level guarantee。This test pins the
        // factory contract:emitter does NOT dedupe on its own,
        // it relies on the event log's wasNew flag。
        _ = try await emitter.emit(outcome: o)
        let events = await log.events(forSession: "r")
        XCTAssertEqual(events.count, 2,
            "M944:emitter does NOT dedupe;event log wasNew is the gate")
    }

    func testEmptyOutcomeProducesNoEvents() async throws {
        let log = BASInMemoryEventLogStorage()
        let emitter = makeEmitter(log: log, sessionID: "z")
        let outcome = BASMemoryTieringReconciliationOutcome(
            evaluatedCount: 0,
            heldCount: 0,
            promotedCount: 0,
            demotedCount: 0,
            quarantineSuggestedCount: 0,
            evictSuggestedCount: 0,
            decisions: [],
            startedAt: Date(),
            completedAt: Date())
        let result = try await emitter.emit(outcome: outcome)
        XCTAssertEqual(result.appended, 0)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertTrue(result.payloads.isEmpty)
    }

    // MARK: - Null-outcome handling (2)

    func testAllHoldsProducesAllSkipped() async throws {
        let log = BASInMemoryEventLogStorage()
        let emitter = makeEmitter(log: log)
        let outcome = makeOutcome(decisions: [
            dec("h1", .hold(tier: .warm,
                reason: .withinThresholds)),
            dec("h2", .hold(tier: .hot,
                reason: .withinThresholds))
        ])
        let result = try await emitter.emit(outcome: outcome)
        XCTAssertEqual(result.appended, 0)
        XCTAssertEqual(result.skipped, 2)
        let events = await log.events(forSession: "sess-emit")
        XCTAssertTrue(events.isEmpty)
    }

    func testEmptyOutcomeReturnsEmptyEmitOutcomeStruct()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        let emitter = makeEmitter(log: log)
        let outcome = makeOutcome(decisions: [])
        let result = try await emitter.emit(outcome: outcome)
        XCTAssertEqual(result, BASMemoryMutationEventEmitter
            .EmitOutcome(
                appended: 0,
                skipped: 0,
                duplicateAppendsSkipped: 0,
                payloads: []))
    }

    // MARK: - Parity: emitter + event-sourced store vs legacy (3)

    func testParityWithLegacyMutationWriter() async throws {
        // Setup atom for both stores
        let atomID =
            "00000000-0000-4000-8000-000000000001"
        let atom = BASGovernedMemory(
            id: UUID(uuidString: atomID)!,
            kind: .semantic,
            content: "x",
            scope: .user,
            sensitivity: .low,
            tier: .warm,
            confidence: 0.5,
            sourceType: "t",
            lastConfirmedAt: nil,
            decayScore: 0.0,
            governanceStatus: .governed,
            provenanceSummary: "p")

        // Legacy: in-memory store + mutation writer
        let legacyStore = BASInMemoryMemoryAtomStore(
            initial: [atom])
        let writer = BASMemoryMutationWriter(
            store: legacyStore)

        // Event-sourced: store + emitter
        let log = BASInMemoryEventLogStorage()
        let evStore = BASEventSourcedMemoryAtomStore(
            eventLog: log,
            sessionID: "p",
            clockMs: { 0 })
        try await evStore.admit(atom)
        let emitter = makeEmitter(log: log, sessionID: "p")

        // Same outcome
        let outcome = makeOutcome(decisions: [
            dec(atomID, .promote(from: .warm, to: .hot,
                reason: .highRecency))
        ])

        _ = await writer.apply(outcome: outcome)
        _ = try await emitter.emit(outcome: outcome)

        // Legacy: tier should be hot
        let legacyTier =
            await legacyStore.atom(forID: atomID)?.tier
        // Event-sourced: tier should also be hot
        let evTier = await evStore.atom(forID: atomID)?.tier
        XCTAssertEqual(legacyTier, .hot)
        XCTAssertEqual(evTier, .hot,
            "M944:emitter + event-sourced store reach same observable state")
    }

    func testParityForQuarantine() async throws {
        let atomID =
            "00000000-0000-4000-8000-000000000002"
        let atom = BASGovernedMemory(
            id: UUID(uuidString: atomID)!,
            kind: .semantic,
            content: "x",
            scope: .user,
            sensitivity: .low,
            tier: .warm,
            confidence: 0.5,
            sourceType: "t",
            lastConfirmedAt: nil,
            decayScore: 0.0,
            governanceStatus: .governed,
            provenanceSummary: "p")
        let legacyStore = BASInMemoryMemoryAtomStore(
            initial: [atom])
        let writer = BASMemoryMutationWriter(
            store: legacyStore)
        let log = BASInMemoryEventLogStorage()
        let evStore = BASEventSourcedMemoryAtomStore(
            eventLog: log, sessionID: "p")
        try await evStore.admit(atom)
        let emitter = makeEmitter(log: log, sessionID: "p")
        let outcome = makeOutcome(decisions: [
            dec(atomID, .quarantineSuggest(from: .warm,
                reason: .sensitivityEscalated))
        ])
        _ = await writer.apply(outcome: outcome)
        _ = try await emitter.emit(outcome: outcome)
        let legacy = await legacyStore.atom(forID: atomID)?
            .governanceStatus
        let ev = await evStore.atom(forID: atomID)?
            .governanceStatus
        XCTAssertEqual(legacy, .quarantined)
        XCTAssertEqual(ev, .quarantined)
    }

    func testParityForEvict() async throws {
        let atomID =
            "00000000-0000-4000-8000-000000000003"
        let atom = BASGovernedMemory(
            id: UUID(uuidString: atomID)!,
            kind: .semantic,
            content: "x",
            scope: .user,
            sensitivity: .low,
            tier: .cold,
            confidence: 0.5,
            sourceType: "t",
            lastConfirmedAt: nil,
            decayScore: 0.0,
            governanceStatus: .governed,
            provenanceSummary: "p")
        let legacyStore = BASInMemoryMemoryAtomStore(
            initial: [atom])
        let writer = BASMemoryMutationWriter(
            store: legacyStore)
        let log = BASInMemoryEventLogStorage()
        let evStore = BASEventSourcedMemoryAtomStore(
            eventLog: log, sessionID: "p")
        try await evStore.admit(atom)
        let emitter = makeEmitter(log: log, sessionID: "p")
        let outcome = makeOutcome(decisions: [
            dec(atomID, .evictSuggest(from: .cold,
                reason: .coldStaleUnused))
        ])
        _ = await writer.apply(outcome: outcome)
        _ = try await emitter.emit(outcome: outcome)
        let legacy = await legacyStore.atom(forID: atomID)
        let ev = await evStore.atom(forID: atomID)
        XCTAssertNil(legacy)
        XCTAssertNil(ev)
    }
}
