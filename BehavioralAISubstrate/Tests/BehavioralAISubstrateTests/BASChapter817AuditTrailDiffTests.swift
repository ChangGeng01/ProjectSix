// MARK: - BASChapter817AuditTrailDiffTests
// chapter 八百十七 / M2736-M2740
//
// Verifies cross-session audit diff helpers。 Set-based per-store
// added/removed/unchanged delta + summary line formatting。
//
// Five invariants pinned:
//
//   1. Diff of identical trails reports zero added/removed across
//      all 5 stores;trailsHaveIdenticalIDSets == true。
//   2. Added record in CURRENT appears in `added`,not in
//      `removed`。
//   3. Missing record in CURRENT appears in `removed`,not in
//      `added`。
//   4. IDs in BOTH trails appear in `unchanged`。
//   5. summaryLines produces deterministic sorted output and
//      skips stores with empty deltas。

import XCTest
@testable import BASMemory
@testable import BASSovereign
@testable import BASOrchestration

#if os(iOS) || os(macOS)

final class BASChapter817AuditTrailDiffTests: XCTestCase {

    // MARK: - Identity diff

    func testDiffOfIdenticalTrailsHasZeroChanges() {
        let trail = makeTrail(
            sessionID: "s",
            presenceIDs: ["p1", "p2"],
            unknownIDs: ["u1"],
            contradictionIDs: [],
            atomIDs: ["a1"],
            versionIDs: [])
        let delta = BASAuditTrailDiff.diff(
            baseline: trail, current: trail)
        XCTAssertEqual(delta.totalAdded, 0)
        XCTAssertEqual(delta.totalRemoved, 0)
        XCTAssertTrue(delta.trailsHaveIdenticalIDSets)
        XCTAssertEqual(delta.presence.unchanged,
                       Set(["p1", "p2"]))
        XCTAssertEqual(delta.unknowns.unchanged, Set(["u1"]))
        XCTAssertEqual(delta.atomEvents.unchanged, Set(["a1"]))
    }

    // MARK: - Added in current

    func testAddedRecordAppearsInAddedSet() {
        let baseline = makeTrail(
            sessionID: "s",
            presenceIDs: ["p1"],
            unknownIDs: [],
            contradictionIDs: [],
            atomIDs: [],
            versionIDs: [])
        let current = makeTrail(
            sessionID: "s",
            presenceIDs: ["p1", "p2"],  // p2 added
            unknownIDs: [],
            contradictionIDs: [],
            atomIDs: [],
            versionIDs: [])
        let delta = BASAuditTrailDiff.diff(
            baseline: baseline, current: current)
        XCTAssertEqual(delta.presence.added, Set(["p2"]))
        XCTAssertEqual(delta.presence.removed, Set())
        XCTAssertEqual(delta.presence.unchanged, Set(["p1"]))
        XCTAssertFalse(delta.trailsHaveIdenticalIDSets)
        XCTAssertEqual(delta.totalAdded, 1)
    }

    // MARK: - Removed in current

    func testRemovedRecordAppearsInRemovedSet() {
        let baseline = makeTrail(
            sessionID: "s",
            presenceIDs: ["p1", "p2"],
            unknownIDs: [],
            contradictionIDs: [],
            atomIDs: [],
            versionIDs: [])
        let current = makeTrail(
            sessionID: "s",
            presenceIDs: ["p1"],  // p2 removed
            unknownIDs: [],
            contradictionIDs: [],
            atomIDs: [],
            versionIDs: [])
        let delta = BASAuditTrailDiff.diff(
            baseline: baseline, current: current)
        XCTAssertEqual(delta.presence.added, Set())
        XCTAssertEqual(delta.presence.removed, Set(["p2"]))
        XCTAssertEqual(delta.totalRemoved, 1)
    }

    // MARK: - Cross-store independence

    func testEachStoreDiffsIndependently() {
        let baseline = makeTrail(
            sessionID: "s",
            presenceIDs: ["p1"],
            unknownIDs: ["u1", "u2"],
            contradictionIDs: ["c1"],
            atomIDs: [],
            versionIDs: ["v1"])
        let current = makeTrail(
            sessionID: "s2",
            presenceIDs: ["p1", "p2"],   // +p2
            unknownIDs: ["u2"],          // -u1
            contradictionIDs: ["c1"],    // unchanged
            atomIDs: ["a1"],             // +a1 (was empty)
            versionIDs: ["v1", "v2"])    // +v2
        let delta = BASAuditTrailDiff.diff(
            baseline: baseline, current: current)
        XCTAssertEqual(delta.presence.added, Set(["p2"]))
        XCTAssertEqual(delta.presence.removed, Set())
        XCTAssertEqual(delta.unknowns.added, Set())
        XCTAssertEqual(delta.unknowns.removed, Set(["u1"]))
        XCTAssertEqual(delta.contradictions.unchanged, Set(["c1"]))
        XCTAssertTrue(delta.contradictions.isIdentitySet)
        XCTAssertEqual(delta.atomEvents.added, Set(["a1"]))
        XCTAssertEqual(delta.versions.added, Set(["v2"]))
        XCTAssertEqual(delta.versions.unchanged, Set(["v1"]))

        XCTAssertEqual(delta.baselineSessionID, "s")
        XCTAssertEqual(delta.currentSessionID, "s2")
        XCTAssertFalse(delta.trailsHaveIdenticalIDSets)
        XCTAssertEqual(delta.totalAdded, 1 + 0 + 0 + 1 + 1)  // 3
        XCTAssertEqual(delta.totalRemoved, 0 + 1 + 0 + 0 + 0)  // 1
    }

    // MARK: - summaryLines formatting

    func testSummaryLinesIsDeterministicAndSkipsEmpty() {
        let baseline = makeTrail(
            sessionID: "s",
            presenceIDs: ["p1"],
            unknownIDs: [],
            contradictionIDs: [],
            atomIDs: [],
            versionIDs: [])
        let current = makeTrail(
            sessionID: "s",
            presenceIDs: ["p1", "p2", "p3"],
            unknownIDs: ["u1"],
            contradictionIDs: [],
            atomIDs: [],
            versionIDs: [])
        let delta = BASAuditTrailDiff.diff(
            baseline: baseline, current: current)
        let lines = BASAuditTrailDiff.summaryLines(delta)
        XCTAssertEqual(lines.count, 2,
            "Only presence + unknowns produced non-empty deltas")
        XCTAssertEqual(lines[0],
            "[presence] added 2: p2, p3",
            "Sorted alphabetical for determinism")
        XCTAssertEqual(lines[1],
            "[unknowns] added 1: u1")
    }

    func testDiffIDsAcceptsDuplicateInputsViaSet() {
        let delta = BASAuditTrailDiff.diffIDs(
            baseline: ["a", "a", "b"],  // duplicates collapse
            current: ["a", "c"])
        XCTAssertEqual(delta.added, Set(["c"]))
        XCTAssertEqual(delta.removed, Set(["b"]))
        XCTAssertEqual(delta.unchanged, Set(["a"]))
    }

    // MARK: - Helpers

    private func makeTrail(
        sessionID: String,
        presenceIDs: [String],
        unknownIDs: [String],
        contradictionIDs: [String],
        atomIDs: [String],
        versionIDs: [String]
    ) -> BASAuditReplayEngine.SessionAuditTrail {
        let presence = presenceIDs.map {
            BASPresenceObservationRecord(
                eventID: $0,
                sessionID: sessionID,
                turnID: "t",
                channelKind: "task",
                salience: 0.5, confidence: 0.5,
                observedAtMs: 0)
        }
        let unknowns = unknownIDs.map {
            BASUnknownLedgerRecord(
                eventID: $0,
                sessionID: sessionID,
                turnID: "t",
                unknownText: "fact: x",
                confidence: 1.0,
                discoveredAtMs: 0)
        }
        let contradictions = contradictionIDs.map {
            BASContradictionLedgerRecord(
                eventID: $0,
                sessionID: sessionID,
                turnID: "t",
                contradictionText: "textual: x",
                salience: 0.5, confidence: 1.0,
                resolved: false, resolvedAtMs: nil)
        }
        let atoms = atomIDs.map {
            BASAtomLifecycleEvent(
                eventID: $0,
                atomID: "a",
                sessionID: sessionID,
                fromPhaseByte: 0, toPhaseByte: 1,
                actionByte: 0, outcome: 0,
                recordedAtMs: 0)
        }
        let versions = versionIDs.map {
            BASHostConstitutionVersionRecord(
                versionID: $0,
                vaultID: "v",
                createdAtMs: 0,
                signatureHash: Data(count: 32))
        }
        return BASAuditReplayEngine.SessionAuditTrail(
            sessionID: sessionID,
            vaultID: nil,
            presence: presence,
            unknowns: unknowns,
            contradictions: contradictions,
            atomEvents: atoms,
            versions: versions)
    }
}

#endif  // os(iOS) || os(macOS)
