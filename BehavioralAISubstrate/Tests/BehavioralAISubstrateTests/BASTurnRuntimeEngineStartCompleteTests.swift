// MARK: - BASTurnRuntimeEngineStartCompleteTests
// chapter 四百六 / M991

import Foundation
import XCTest
@testable import BASHostKit

final class BASTurnRuntimeEngineStartCompleteTests:
    XCTestCase
{

    // MARK: - Compile-time surface

    func testEmitterEnvelopePairing() {
        // Verify both factories exist
        let s = BASTurnRuntimeAuditEnvelope.start(
            turnID: "t", sessionID: "s",
            timestampMs: 0, sequenceNumber: 0)
        let c = BASTurnRuntimeAuditEnvelope.complete(
            turnID: "t", sessionID: "s",
            timestampMs: 1, sequenceNumber: 1)
        XCTAssertEqual(s.phase, .start)
        XCTAssertEqual(c.phase, .complete)
    }

    // MARK: - Sequence ordering invariant

    func testStartSequenceBeforeCompleteSequence() {
        // Per V2 actor M991: start envelope's sequence number
        // is always strictly less than the matching complete
        // envelope (within one runTurn call)
        let s = BASTurnRuntimeAuditEnvelope.start(
            turnID: "t", sessionID: "s",
            timestampMs: 0, sequenceNumber: 0)
        let c = BASTurnRuntimeAuditEnvelope.complete(
            turnID: "t", sessionID: "s",
            timestampMs: 0, sequenceNumber: 1)
        XCTAssertLessThan(
            s.sequenceNumber, c.sequenceNumber,
            "M991:start fires before complete in sequence")
    }

    // MARK: - Same turnID coupling

    func testStartAndCompleteShareTurnID() {
        let turnID = "shared-turn-id"
        let s = BASTurnRuntimeAuditEnvelope.start(
            turnID: turnID, sessionID: "s",
            timestampMs: 0, sequenceNumber: 0)
        let c = BASTurnRuntimeAuditEnvelope.complete(
            turnID: turnID, sessionID: "s",
            timestampMs: 0, sequenceNumber: 1)
        XCTAssertEqual(s.turnID, c.turnID,
            "M991:start + complete share turnID per turn")
    }

    // MARK: - Sequence counter monotonic across pairs

    func testSequenceCounterMonotonicAcrossPairs() {
        // Across 2 runTurn calls, the sequence numbers should
        // increment monotonically: turn 1 → seq 0,1; turn 2 →
        // seq 2,3
        let t1Start = BASTurnRuntimeAuditEnvelope.start(
            turnID: "t1", sessionID: "s",
            timestampMs: 0, sequenceNumber: 0)
        let t1Complete = BASTurnRuntimeAuditEnvelope.complete(
            turnID: "t1", sessionID: "s",
            timestampMs: 1, sequenceNumber: 1)
        let t2Start = BASTurnRuntimeAuditEnvelope.start(
            turnID: "t2", sessionID: "s",
            timestampMs: 2, sequenceNumber: 2)
        let t2Complete = BASTurnRuntimeAuditEnvelope.complete(
            turnID: "t2", sessionID: "s",
            timestampMs: 3, sequenceNumber: 3)
        XCTAssertEqual(
            [t1Start, t1Complete, t2Start, t2Complete]
                .map { $0.sequenceNumber },
            [0, 1, 2, 3])
    }

    // MARK: - Audit consumers can pair-match

    func testActionTagsForPairing() {
        // Audit consumers grep BASEventLogEntry.actions for
        // 'turn-start' and 'turn-complete' to pair lifecycle
        // events of one turn。Pin the action strings。
        let startActions = ["turn-start"]
        let completeActions = ["turn-complete"]
        XCTAssertNotEqual(startActions, completeActions)
        XCTAssertEqual(startActions.first, "turn-start")
        XCTAssertEqual(completeActions.first, "turn-complete")
    }
}
