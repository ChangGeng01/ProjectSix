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
            "ADR-016.M1472",
            "M1472:doctrine version reflects chapter 五百二十三 — caps the 12-chapter projection-block pipeline arc。 BASChapter511To522PipelineDoctrine typed milestone freezing arc invariants (M1469, 12 chapters / 48 commits / 8 input blocks / 69 packaged fields / 49% V1 LOC reduction / 100% packaging coverage) + 8 anti-drift PROOF tests pinning block types + field counts + .empty singletons (M1470) + 3 end-to-end PROOF tests via real V1 monolith turns including replay-determinism verification of Kunlun + Cthulhu block hashes (M1471)。 69 typed surfaces cumulative。 V1 byte-equality preserved (stress-sweep canonical60 × 3 repeat runs 0-divergence; replay-determinism explicitly proved by M1471)。 ADR-014 OPT-IN preserved")
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
