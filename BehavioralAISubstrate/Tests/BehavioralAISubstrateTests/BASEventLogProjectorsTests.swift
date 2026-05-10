// MARK: - BASEventLogProjectorsTests
// chapter 四百二十八 / M1087

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASEventLogProjectorsTests: XCTestCase {

    // MARK: - Empty input → empty projections

    func testProjectMemoryAtomEventsEmpty() {
        let result = BASEventLogProjectors
            .projectMemoryAtomEvents([])
        XCTAssertTrue(result.isEmpty)
    }

    func testProjectAllKindsEmpty() {
        XCTAssertTrue(
            BASEventLogProjectors
                .projectTurnLifecycleEvents([])
                .isEmpty)
        XCTAssertTrue(
            BASEventLogProjectors
                .projectParallelStageEvents([])
                .isEmpty)
        XCTAssertTrue(
            BASEventLogProjectors
                .projectPermitEscalationEvents([])
                .isEmpty)
    }

    // MARK: - Filters by payload kind

    func testProjectorsFilterByKind() {
        let lifecyclePayload =
            BASTurnLifecycleEventPayload(
                phase: .start,
                turnID: "t1",
                sessionID: "s1",
                sequenceNumber: 1)
        let parallelPayload =
            BASParallelStageEventPayload(
                groupTag: .entryAA2,
                turnID: "t1",
                memberStageCount: 2,
                observedOutputCount: 2,
                executionNanos: 1000)
        let permitPayload =
            BASPermitEscalationEventPayload(
                turnID: "t1",
                initialPermitModeRawValue: "answer",
                initialPermitReasonCodes: ["init"],
                stageRecords: [],
                firedStageCount: 0)

        let entries: [BASEventLogEntry] = [
            BASEventLogEntry.turnLifecycleEvent(
                eventID: "e1",
                timestampMs: 100,
                sessionID: "s1",
                sequenceNumber: 1,
                payload: lifecyclePayload),
            BASEventLogEntry.parallelStageEvent(
                eventID: "e2",
                timestampMs: 101,
                sessionID: "s1",
                sequenceNumber: 2,
                payload: parallelPayload),
            BASEventLogEntry.permitEscalationEvent(
                eventID: "e3",
                timestampMs: 102,
                sessionID: "s1",
                sequenceNumber: 3,
                payload: permitPayload)
        ]

        XCTAssertEqual(
            BASEventLogProjectors
                .projectTurnLifecycleEvents(entries)
                .count, 1,
            "lifecycle projector picks only its kind")
        XCTAssertEqual(
            BASEventLogProjectors
                .projectParallelStageEvents(entries)
                .count, 1)
        XCTAssertEqual(
            BASEventLogProjectors
                .projectPermitEscalationEvents(entries)
                .count, 1)
        XCTAssertTrue(
            BASEventLogProjectors
                .projectMemoryAtomEvents(entries)
                .isEmpty,
            "memory-atom projector picks none from a" +
            " stream that has no memory-atom events")
    }

    // MARK: - Sequence-number sorted output

    func testProjectorSortsBySequenceNumber() {
        let p1 = BASTurnLifecycleEventPayload(
            phase: .start,
            turnID: "t1",
            sessionID: "s1",
            sequenceNumber: 1)
        let p2 = BASTurnLifecycleEventPayload(
            phase: .complete,
            turnID: "t1",
            sessionID: "s1",
            sequenceNumber: 2)
        // Append OUT-OF-ORDER (sequence 2 first, then 1)
        let entries = [
            BASEventLogEntry.turnLifecycleEvent(
                eventID: "evt-2",
                timestampMs: 200,
                sessionID: "s1",
                sequenceNumber: 2,
                payload: p2),
            BASEventLogEntry.turnLifecycleEvent(
                eventID: "evt-1",
                timestampMs: 100,
                sessionID: "s1",
                sequenceNumber: 1,
                payload: p1)
        ]
        let projected = BASEventLogProjectors
            .projectTurnLifecycleEvents(entries)
        XCTAssertEqual(
            projected.map { $0.sequenceNumber },
            [1, 2],
            "projector must sort by sequenceNumber" +
            " regardless of input order (chapter" +
            " 三百九二)")
    }

    // MARK: - Combined turn projection

    func testProjectTurnFiltersByTurnRef() {
        let p1 = BASTurnLifecycleEventPayload(
            phase: .start,
            turnID: "turn-A",
            sessionID: "s1",
            sequenceNumber: 1)
        let p2 = BASTurnLifecycleEventPayload(
            phase: .start,
            turnID: "turn-B",
            sessionID: "s1",
            sequenceNumber: 2)
        let entries = [
            BASEventLogEntry.turnLifecycleEvent(
                eventID: "e1",
                timestampMs: 100,
                sessionID: "s1",
                sequenceNumber: 1,
                payload: p1),
            BASEventLogEntry.turnLifecycleEvent(
                eventID: "e2",
                timestampMs: 200,
                sessionID: "s1",
                sequenceNumber: 2,
                payload: p2)
        ]
        let projection = BASEventLogProjectors
            .projectTurn(
                "turn-A", from: entries)
        XCTAssertEqual(projection.turnID, "turn-A")
        XCTAssertEqual(
            projection.turnLifecycleEvents.count, 1,
            "projectTurn must filter by turnRef ==" +
            " turnID")
        XCTAssertEqual(
            projection.turnLifecycleEvents.first?
                .turnID, "turn-A")
    }

    func testProjectTurnTotalEventCount() {
        let lifecyclePayload =
            BASTurnLifecycleEventPayload(
                phase: .start,
                turnID: "turn-X",
                sessionID: "s1",
                sequenceNumber: 1)
        let parallelPayload =
            BASParallelStageEventPayload(
                groupTag: .dD2,
                turnID: "turn-X",
                memberStageCount: 2,
                observedOutputCount: 2,
                executionNanos: 1000)
        let entries = [
            BASEventLogEntry.turnLifecycleEvent(
                eventID: "e1",
                timestampMs: 100,
                sessionID: "s1",
                sequenceNumber: 1,
                payload: lifecyclePayload),
            BASEventLogEntry.parallelStageEvent(
                eventID: "e2",
                timestampMs: 101,
                sessionID: "s1",
                sequenceNumber: 2,
                payload: parallelPayload)
        ]
        let projection = BASEventLogProjectors
            .projectTurn(
                "turn-X", from: entries)
        XCTAssertEqual(
            projection.totalEventCount, 2,
            "totalEventCount sums across the 4 kinds")
    }

    // MARK: - Determinism (chapter 三百九二)

    func testProjectorIsDeterministic() {
        let payload = BASParallelStageEventPayload(
            groupTag: .m1FourWay,
            turnID: "t1",
            memberStageCount: 4,
            observedOutputCount: 4,
            executionNanos: 5000)
        let entries = [
            BASEventLogEntry.parallelStageEvent(
                eventID: "e1",
                timestampMs: 100,
                sessionID: "s1",
                sequenceNumber: 1,
                payload: payload)
        ]
        let r1 = BASEventLogProjectors
            .projectParallelStageEvents(entries)
        let r2 = BASEventLogProjectors
            .projectParallelStageEvents(entries)
        XCTAssertEqual(r1, r2)
    }
}
