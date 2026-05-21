// MARK: - BASChapter818AuditTrailArchiveTests
// chapter 八百十八 / M2741-M2745
//
// Verifies audit trail archival / compaction。 Compresses raw
// per-record audit trail into per-turn summary rows + session-
// level atom + version summaries。
//
// Six invariants pinned:
//
//   1. Empty trail archives to empty ArchivedTrail (zero turns,
//      zero atom events,zero versions)。
//   2. Per-turn presence aggregation:correct count + avg
//      salience + avg confidence + per-channel breakdown。
//   3. Unknown-kind prefix bucketing maps to the 5 typed counts
//      (fact/role/constraint/permission/ambiguity)。
//   4. Contradiction resolved/unresolved split + max severity
//      preserved per turn。
//   5. L8 atom events aggregate at the SESSION level (not per
//      turn) since schema 023 doesn't carry turnID。
//   6. L5 versions count + rollbackVersionCount preserved at
//      session level。

import XCTest
@testable import BASMemory
@testable import BASSovereign
@testable import BASOrchestration

#if os(iOS) || os(macOS)

final class BASChapter818AuditTrailArchiveTests: XCTestCase {

    // MARK: - Empty trail

    func testEmptyTrailArchivesToEmpty() {
        let trail = makeTrail(sessionID: "empty")
        let arch = BASAuditTrailArchive.archive(trail: trail)
        XCTAssertEqual(arch.sessionID, "empty")
        XCTAssertEqual(arch.turnCount, 0)
        XCTAssertEqual(arch.atomEventCount, 0)
        XCTAssertTrue(arch.atomOutcomeCounts.isEmpty)
        XCTAssertEqual(arch.versionCount, 0)
        XCTAssertEqual(arch.rollbackVersionCount, 0)
    }

    // MARK: - Per-turn presence aggregation

    func testPerTurnPresenceAggregationAndOrdering() {
        let presence = [
            BASPresenceObservationRecord(
                eventID: "p1", sessionID: "s", turnID: "t1",
                channelKind: "task",
                salience: 0.6, confidence: 0.8,
                observedAtMs: 100),
            BASPresenceObservationRecord(
                eventID: "p2", sessionID: "s", turnID: "t1",
                channelKind: "risk",
                salience: 0.4, confidence: 0.6,
                observedAtMs: 100),
            BASPresenceObservationRecord(
                eventID: "p3", sessionID: "s", turnID: "t2",
                channelKind: "task",
                salience: 0.8, confidence: 1.0,
                observedAtMs: 200),
        ]
        let trail = makeTrail(
            sessionID: "s", presence: presence)
        let arch = BASAuditTrailArchive.archive(trail: trail)
        XCTAssertEqual(arch.turnCount, 2)
        // Turns sorted by firstTimestampMs ASC
        XCTAssertEqual(arch.turns[0].turnID, "t1")
        XCTAssertEqual(arch.turns[1].turnID, "t2")
        // Turn 1: 2 observations,avg sal = 0.5,avg conf = 0.7
        XCTAssertEqual(arch.turns[0].presenceObservationCount, 2)
        XCTAssertEqual(arch.turns[0].presenceAvgSalience,
                       0.5, accuracy: 1e-12)
        XCTAssertEqual(arch.turns[0].presenceAvgConfidence,
                       0.7, accuracy: 1e-12)
        XCTAssertEqual(arch.turns[0].presenceCountByChannel,
                       ["task": 1, "risk": 1])
        XCTAssertEqual(arch.turns[0].firstTimestampMs, 100)
        XCTAssertEqual(arch.turns[0].lastTimestampMs, 100)
        // Turn 2: 1 observation
        XCTAssertEqual(arch.turns[1].presenceObservationCount, 1)
        XCTAssertEqual(arch.turns[1].presenceAvgSalience, 0.8)
        XCTAssertEqual(arch.turns[1].presenceAvgConfidence, 1.0)
    }

    // MARK: - Unknown kind bucketing

    func testUnknownPrefixBucketing() {
        let unknowns = [
            makeUnknown(turn: "t1", text: "fact: F1"),
            makeUnknown(turn: "t1", text: "role: R1"),
            makeUnknown(turn: "t1", text: "constraint: C1"),
            makeUnknown(turn: "t1", text: "permission: P1"),
            makeUnknown(turn: "t1", text: "ambiguity: A1"),
            makeUnknown(turn: "t1", text: "ambiguity: A2"),
        ]
        let trail = makeTrail(
            sessionID: "s", unknowns: unknowns)
        let arch = BASAuditTrailArchive.archive(trail: trail)
        XCTAssertEqual(arch.turns.count, 1)
        let t = arch.turns[0]
        XCTAssertEqual(t.unknownFactCount, 1)
        XCTAssertEqual(t.unknownRoleCount, 1)
        XCTAssertEqual(t.unknownConstraintCount, 1)
        XCTAssertEqual(t.unknownPermissionCount, 1)
        XCTAssertEqual(t.unknownAmbiguityCount, 2)
    }

    // MARK: - Contradiction summary

    func testContradictionResolvedSplitAndMaxSalience() {
        let contradictions = [
            makeContradiction(
                turn: "t1", salience: 0.3,
                resolved: true, resolvedAtMs: 50),
            makeContradiction(
                turn: "t1", salience: 0.9,  // max
                resolved: false, resolvedAtMs: nil),
            makeContradiction(
                turn: "t1", salience: 0.5,
                resolved: true, resolvedAtMs: 75),
        ]
        let trail = makeTrail(
            sessionID: "s", contradictions: contradictions)
        let arch = BASAuditTrailArchive.archive(trail: trail)
        XCTAssertEqual(arch.turns.count, 1)
        let t = arch.turns[0]
        XCTAssertEqual(t.contradictionTotal, 3)
        XCTAssertEqual(t.contradictionResolved, 2)
        XCTAssertEqual(t.contradictionMaxSalience,
                       0.9, accuracy: 1e-12)
    }

    // MARK: - Atom session-scoped summary

    func testAtomEventsAggregateAtSessionLevel() {
        let atoms = [
            makeAtomEvent(outcome: 0),  // advanced
            makeAtomEvent(outcome: 0),
            makeAtomEvent(outcome: 1),  // illegal
            makeAtomEvent(outcome: 2),  // terminal
        ]
        let trail = makeTrail(sessionID: "s", atomEvents: atoms)
        let arch = BASAuditTrailArchive.archive(trail: trail)
        XCTAssertEqual(arch.atomEventCount, 4)
        XCTAssertEqual(arch.atomOutcomeCounts[0], 2)
        XCTAssertEqual(arch.atomOutcomeCounts[1], 1)
        XCTAssertEqual(arch.atomOutcomeCounts[2], 1)
        // Atoms don't appear in per-turn rows
        XCTAssertEqual(arch.turnCount, 0,
            "Atom-only trail produces no per-turn rows")
    }

    // MARK: - Version summary

    func testVersionsSessionScopedWithRollbackCount() {
        let versions = [
            makeVersion(versionID: "v1", isRollback: false),
            makeVersion(versionID: "v2", isRollback: true),
            makeVersion(versionID: "v3", isRollback: false),
            makeVersion(versionID: "v4", isRollback: true),
        ]
        let trail = makeTrail(sessionID: "s", versions: versions)
        let arch = BASAuditTrailArchive.archive(trail: trail)
        XCTAssertEqual(arch.versionCount, 4)
        XCTAssertEqual(arch.rollbackVersionCount, 2)
    }

    // MARK: - End-to-end through pipeline

    func testArchiveAfterPipelineRecordingPreservesAggregates() async throws {
        let presenceMem = BASInMemoryPresenceObservationStore()
        let unknownMem = BASInMemoryUnknownLedgerStore()
        let contradictionMem = BASInMemoryContradictionLedgerStore()
        let atomMem = BASInMemoryAtomLifecycleStore()
        let versionMem = BASInMemoryHostConstitutionVersionTreeStore()
        let pipeline = BASAuditPipeline(
            presenceStore: presenceMem,
            unknownStore: unknownMem,
            contradictionStore: contradictionMem,
            atomLifecycleStore: atomMem,
            versionTreeStore: versionMem)
        let engine = BASAuditReplayEngine(
            presenceStore: presenceMem,
            unknownStore: unknownMem,
            contradictionStore: contradictionMem,
            atomLifecycleStore: atomMem,
            versionTreeStore: versionMem)

        for turnIdx in 0..<3 {
            _ = try await pipeline.recordTurn(input:
                BASAuditPipeline.PerTurnInput(
                    sessionID: "s",
                    turnID: "turn-\(turnIdx)",
                    nowMs: Int64(turnIdx * 10),
                    eventIDPrefix: "p\(turnIdx)",
                    observations: [
                        BASChannelObservationInput(
                            channelByte: 0,
                            salience: 0.5,
                            confidence: 0.8),
                    ],
                    unknownSet: BASUnknownSet(
                        missingFacts: ["F\(turnIdx)"])))
        }
        let trail = await engine.loadSession(sessionID: "s")
        let arch = BASAuditTrailArchive.archive(trail: trail)
        XCTAssertEqual(arch.turnCount, 3)
        for (idx, turn) in arch.turns.enumerated() {
            XCTAssertEqual(turn.turnID, "turn-\(idx)",
                "Sorted by firstTimestampMs ASC matches insertion")
            XCTAssertEqual(turn.presenceObservationCount, 1)
            XCTAssertEqual(turn.unknownFactCount, 1)
        }
    }

    // MARK: - Helpers

    private func makeTrail(
        sessionID: String,
        presence: [BASPresenceObservationRecord] = [],
        unknowns: [BASUnknownLedgerRecord] = [],
        contradictions: [BASContradictionLedgerRecord] = [],
        atomEvents: [BASAtomLifecycleEvent] = [],
        versions: [BASHostConstitutionVersionRecord] = []
    ) -> BASAuditReplayEngine.SessionAuditTrail {
        return BASAuditReplayEngine.SessionAuditTrail(
            sessionID: sessionID,
            vaultID: nil,
            presence: presence,
            unknowns: unknowns,
            contradictions: contradictions,
            atomEvents: atomEvents,
            versions: versions)
    }

    private func makeUnknown(
        turn: String, text: String
    ) -> BASUnknownLedgerRecord {
        return BASUnknownLedgerRecord(
            eventID: UUID().uuidString,
            sessionID: "s",
            turnID: turn,
            unknownText: text,
            confidence: 1.0,
            discoveredAtMs: 0)
    }

    private func makeContradiction(
        turn: String,
        salience: Double,
        resolved: Bool,
        resolvedAtMs: Int64?
    ) -> BASContradictionLedgerRecord {
        return BASContradictionLedgerRecord(
            eventID: UUID().uuidString,
            sessionID: "s",
            turnID: turn,
            contradictionText: "textual: x",
            salience: salience,
            confidence: 1.0,
            resolved: resolved,
            resolvedAtMs: resolvedAtMs)
    }

    private func makeAtomEvent(
        outcome: Int32
    ) -> BASAtomLifecycleEvent {
        return BASAtomLifecycleEvent(
            eventID: UUID().uuidString,
            atomID: "a",
            sessionID: "s",
            fromPhaseByte: 0,
            toPhaseByte: outcome == 0 ? 1 : 0,
            actionByte: 0,
            outcome: outcome,
            recordedAtMs: 0)
    }

    private func makeVersion(
        versionID: String, isRollback: Bool
    ) -> BASHostConstitutionVersionRecord {
        return BASHostConstitutionVersionRecord(
            versionID: versionID,
            vaultID: "v",
            createdAtMs: 0,
            signatureHash: Data(count: 32),
            isRollbackPoint: isRollback)
    }
}

#endif  // os(iOS) || os(macOS)
