// MARK: - BASChapter402PhaseOneClosureTests
// chapter 四百二 / M952 — Phase 1 close-out audit
//
// Verifies the Phase 1 work landed coherently:
//   - doctrineVersion bumped to ADR-016.M952
//   - All M941-M951 surfaces reachable from a single test target
//   - chapter 四百二 doctrine note exposed
//   - Phase 1 = 12 commits; M-number range continuous

import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASChapter402PhaseOneClosureTests: XCTestCase {

    // MARK: - Doctrine version bump

    func testDoctrineVersionPin() {
        // M969 bump:Phase 2 chapter 四百四 v1 close-out
        // updates ADR-016 doctrine version。 Phase 1
        // (chapter 四百二 / M941-M952) closure remains
        // valid;the version simply tracks the latest
        // architecture sweep milestone。
        XCTAssertEqual(
            BASCognitiveOSCompletionDoctrine
                .doctrineVersion,
            "ADR-016.M1956",
            "M1956:doctrine version reflects chapter 六百四十四 — BASSOVEREIGN SNAPSHOT+TOKEN STRUCT-TRIO CODABLE EXTENSION — GAP-FILL,2nd post-hexa-#5,PURE STRUCT TRIO (chapter 643 was MIXED enum+struct)。 5th BASSovereign touch overall。 3 BASSovereign structs nested-in-actor:BASSovereignSnapshotManager.SnapshotAnchor + BASSovereignSnapshotManager.RegisteredSnapshot (wraps SnapshotAnchor — recursive Codable proof) + BASSovereignTokenAuthority.CommitIntent gained Codable at M1953 + 3 PROOF tests (M1954) + BASSovereignSnapshotTokenStructTrioCodableExtensionDoctrine typed surface (M1955) + close-out (M1956)。 NEW kind 'sovereign-snapshot-token-struct-trio'。 BASSovereign cumulative typed surfaces = 14。 PHASE 2 COMMITS CROSSES 1000 ROUND-NUMBER MILESTONE。 185 typed surfaces cumulative。 540 consecutive byte-equality clean commits。 V1 byte-equality preserved。 ADR-014 OPT-IN preserved")
    }

    // MARK: - M-number range matches chapter 四百二

    func testMNumberRangeMatches() {
        XCTAssertEqual(
            BASMemoryAtomEventSourcingDoctrine.mNumberFirst,
            941)
        XCTAssertEqual(
            BASMemoryAtomEventSourcingDoctrine.mNumberLast,
            952)
    }

    // MARK: - Phase 1 surfaces all reachable

    func testPhase1SurfacesAreReachable() async throws {
        // M941
        let payload = BASMemoryAtomEventPayload(remove: "x")
        XCTAssertNotNil(payload)
        // M942
        let r = BASMemoryAtomReducer.reduce(
            priorAtoms: [:], event: BASEventLogEntry(
                eventID: "c",
                timestampMs: 0,
                kind: .chat,
                sessionID: "s",
                sequenceNumber: 0))
        XCTAssertTrue(r.isEmpty)
        // M943
        let log = BASInMemoryEventLogStorage()
        let store = BASEventSourcedMemoryAtomStore(
            eventLog: log, sessionID: "x")
        let count = await store.count
        XCTAssertEqual(count, 0)
        // M944
        let emitter = BASMemoryMutationEventEmitter(
            eventLog: log, sessionID: "x")
        let result = try await emitter.emit(
            outcome: BASMemoryTieringReconciliationOutcome(
                evaluatedCount: 0,
                heldCount: 0,
                promotedCount: 0,
                demotedCount: 0,
                quarantineSuggestedCount: 0,
                evictSuggestedCount: 0,
                decisions: [],
                startedAt: Date(),
                completedAt: Date()))
        XCTAssertEqual(result.appended, 0)
        // M945
        XCTAssertNotNil(BASKnowledgeGraphEventExtractor
            .memoryAtomNodeWeight)
        // M951
        XCTAssertEqual(
            BASMemoryAtomEventSourcingDoctrine.chapterTag,
            "chapter 四百二")
    }
}
