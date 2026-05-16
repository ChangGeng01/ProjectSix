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
            "ADR-016.M2060",
            "M2060:doctrine version reflects chapter 六百七十 — PHASE K env var bridge shipped。 NEW BASSampleHostRuntimeModeEnvVarBridge reads BAS_RUNTIME_MODE env var via ProcessInfo + maps to BASTurnRuntimeMode at M2057。 4-method API。 13 PROOF tests (M2058)。 NEW BASEnvVarBridgeDoctrine + 12 anti-drift tests (M2059)。 close-out (M2060)。 Default .v1ByteEqual preserves M2032 per ADR-014。 212 typed surfaces cumulative。 644 consecutive byte-equality clean commits。 V1 byte-equality preserved。 ADR-014 OPT-IN preserved。 Chapter 671 ships Phase K close-out doctrine NEXT。 Phase L flip target chapter 六百七十四 / M2074")
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
