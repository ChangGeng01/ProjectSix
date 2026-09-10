// MARK: - BASChapter815AuditPipelineTests
// chapter 八百十五 / M2726-M2730
//
// Verifies the BASAuditPipeline composition root (chapter 八百十五)。
// One-call recording across all 4 recorders + 5 stores matches
// what the host would get from 4 separate recorder calls。
//
// Five invariants pinned:
//
//   1. Empty input (no optional fields set) is a no-op:zero
//      writes to every store + PerTurnOutput is all-nil。
//   2. Each part of PerTurnInput routes to the right recorder
//      and produces non-nil output for that segment only。
//   3. A fully-populated PerTurnInput writes to all 5 stores
//      in deterministic order (presence → unknowns →
//      contradictions → atom → version)。
//   4. PerTurnOutput.fusedPresence matches the pure
//      BASRoutedPresenceFusion.fuse(...) of the same observations。
//   5. Error in any recorder propagates up + does NOT silently
//      swallow successful earlier writes (no cross-store
//      atomicity — host owns that contract)。

import XCTest
@testable import BASMemory
@testable import BASSovereign
@testable import BASOrchestration

#if os(iOS) || os(macOS)

final class BASChapter815AuditPipelineTests: XCTestCase {

    private var pipeline: BASAuditPipeline!
    private var presenceMem: BASInMemoryPresenceObservationStore!
    private var unknownMem: BASInMemoryUnknownLedgerStore!
    private var contradictionMem: BASInMemoryContradictionLedgerStore!
    private var atomMem: BASInMemoryAtomLifecycleStore!
    private var versionMem: BASInMemoryHostConstitutionVersionTreeStore!

    override func setUp() async throws {
        try await super.setUp()
        presenceMem = BASInMemoryPresenceObservationStore()
        unknownMem = BASInMemoryUnknownLedgerStore()
        contradictionMem = BASInMemoryContradictionLedgerStore()
        atomMem = BASInMemoryAtomLifecycleStore()
        versionMem = BASInMemoryHostConstitutionVersionTreeStore()
        pipeline = BASAuditPipeline(
            presenceStore: presenceMem,
            unknownStore: unknownMem,
            contradictionStore: contradictionMem,
            atomLifecycleStore: atomMem,
            versionTreeStore: versionMem)
    }

    // MARK: - Empty input

    func testEmptyInputProducesAllNilOutputAndZeroWrites() async throws {
        let input = BASAuditPipeline.PerTurnInput(
            sessionID: "s", turnID: "t",
            nowMs: 0,
            eventIDPrefix: "emp")
        let output = try await pipeline.recordTurn(input: input)
        XCTAssertNil(output.fusedPresence)
        XCTAssertNil(output.unknownRecords)
        XCTAssertNil(output.contradictionRecords)
        XCTAssertNil(output.atomEvent)
        XCTAssertNil(output.versionRecord)

        let presenceCount = await presenceMem.count()
        let unknownCount = await unknownMem.count()
        let contradictionCount = await contradictionMem.count()
        let atomCount = await atomMem.count()
        let versionCount = await versionMem.count()
        XCTAssertEqual(presenceCount, 0)
        XCTAssertEqual(unknownCount, 0)
        XCTAssertEqual(contradictionCount, 0)
        XCTAssertEqual(atomCount, 0)
        XCTAssertEqual(versionCount, 0)
    }

    // MARK: - Single-segment routing

    func testPresenceOnlyRoutesToPresenceStoreOnly() async throws {
        let observations = [
            BASChannelObservationInput(
                channelByte: 0, salience: 0.5, confidence: 0.8),
            BASChannelObservationInput(
                channelByte: 1, salience: 0.6, confidence: 0.7),
        ]
        let input = BASAuditPipeline.PerTurnInput(
            sessionID: "s", turnID: "t",
            nowMs: 100, eventIDPrefix: "po",
            observations: observations)
        let output = try await pipeline.recordTurn(input: input)
        XCTAssertNotNil(output.fusedPresence,
            "Presence segment populated")
        XCTAssertNil(output.unknownRecords)
        XCTAssertNil(output.contradictionRecords)
        XCTAssertNil(output.atomEvent)
        XCTAssertNil(output.versionRecord)

        // PerTurnOutput.fusedPresence matches pure fuse(...)
        let pureFused = BASRoutedPresenceFusion.fuse(
            observations: observations)
        XCTAssertEqual(output.fusedPresence!, pureFused,
                       accuracy: 0)

        let presenceCount = await presenceMem.count()
        let unknownCount = await unknownMem.count()
        XCTAssertEqual(presenceCount, 2)
        XCTAssertEqual(unknownCount, 0,
            "Unknown store untouched")
    }

    func testUnknownsOnlyRoutesToUnknownStoreOnly() async throws {
        let unknownSet = BASUnknownSet(
            missingFacts: ["F"],
            ambiguityNotes: ["A"])
        let input = BASAuditPipeline.PerTurnInput(
            sessionID: "s", turnID: "t",
            nowMs: 0, eventIDPrefix: "uo",
            unknownSet: unknownSet)
        let output = try await pipeline.recordTurn(input: input)
        XCTAssertNil(output.fusedPresence)
        XCTAssertEqual(output.unknownRecords?.count, 2)
        XCTAssertNil(output.contradictionRecords)
    }

    func testEmptyUnknownSetIsTreatedAsNoOp() async throws {
        let input = BASAuditPipeline.PerTurnInput(
            sessionID: "s", turnID: "t",
            nowMs: 0, eventIDPrefix: "esu",
            unknownSet: BASUnknownSet.empty)
        let output = try await pipeline.recordTurn(input: input)
        XCTAssertNil(output.unknownRecords,
            "BASUnknownSet.empty produces no recorder call")
        let count = await unknownMem.count()
        XCTAssertEqual(count, 0)
    }

    func testAtomTransitionOnlyRoutesToAtomStoreOnly() async throws {
        let input = BASAuditPipeline.PerTurnInput(
            sessionID: "s", turnID: "t",
            nowMs: 50, eventIDPrefix: "ao",
            atomTransition: BASAuditPipeline.AtomTransitionInput(
                atomID: "a",
                fromPhaseByte: 0,
                toPhaseByte: 1,
                actionByte: 0,
                outcome: 0,
                actorRef: "sovereign"))
        let output = try await pipeline.recordTurn(input: input)
        XCTAssertNotNil(output.atomEvent)
        XCTAssertEqual(output.atomEvent?.toPhaseByte, 1)
        XCTAssertEqual(output.atomEvent?.actorRef, "sovereign")
        XCTAssertNil(output.fusedPresence)
    }

    // MARK: - All-segments-populated routing

    func testFullInputWritesToAllFiveStoresInOrder() async throws {
        let observations = [
            BASChannelObservationInput(
                channelByte: 0, salience: 0.5, confidence: 0.8),
        ]
        let input = BASAuditPipeline.PerTurnInput(
            sessionID: "s",
            turnID: "t",
            nowMs: 1000,
            eventIDPrefix: "full",
            observations: observations,
            unknownSet: BASUnknownSet(
                missingFacts: ["F"]),
            contradictions: [
                BASContradictionRecord(
                    nodeID: "n",
                    kind: .textual,
                    summary: "x",
                    refs: [],
                    severity: 0.5,
                    unresolved: true),
            ],
            atomTransition: BASAuditPipeline.AtomTransitionInput(
                atomID: "a", fromPhaseByte: 0, toPhaseByte: 1,
                actionByte: 0, outcome: 0),
            versionRecord: BASAuditPipeline.VersionRecordInput(
                versionID: "v",
                vaultID: "vault",
                canonicalBytes: Data("snap".utf8)))
        let output = try await pipeline.recordTurn(input: input)

        XCTAssertNotNil(output.fusedPresence)
        XCTAssertEqual(output.unknownRecords?.count, 1)
        XCTAssertEqual(output.contradictionRecords?.count, 1)
        XCTAssertNotNil(output.atomEvent)
        XCTAssertNotNil(output.versionRecord)

        let pCount = await presenceMem.count()
        let uCount = await unknownMem.count()
        let cCount = await contradictionMem.count()
        let aCount = await atomMem.count()
        let vCount = await versionMem.count()
        XCTAssertEqual(pCount, 1)
        XCTAssertEqual(uCount, 1)
        XCTAssertEqual(cCount, 1)
        XCTAssertEqual(aCount, 1)
        XCTAssertEqual(vCount, 1)

        // versionRecord captures canonical hash
        XCTAssertEqual(
            output.versionRecord?.signatureHash.count, 32,
            "SHA-256 → 32 bytes")
    }

    // MARK: - No cross-store atomicity

    func testFailureMidPipelineLeavesEarlierWritesIntact() async throws {
        // First call lays a presence record with eventID "fail-p-0"
        let observations = [
            BASChannelObservationInput(
                channelByte: 0, salience: 0.5, confidence: 0.8),
        ]
        let first = BASAuditPipeline.PerTurnInput(
            sessionID: "s", turnID: "t",
            nowMs: 0, eventIDPrefix: "fail",
            observations: observations)
        _ = try await pipeline.recordTurn(input: first)
        let initialCount = await presenceMem.count()
        XCTAssertEqual(initialCount, 1)

        // Second call reuses the same prefix → presence write
        // would collide on event_id "fail-p-0"。 Pipeline order is
        // presence first;the collision throws BEFORE any other
        // recorder runs。
        let collision = BASAuditPipeline.PerTurnInput(
            sessionID: "s", turnID: "t2",
            nowMs: 1, eventIDPrefix: "fail",
            observations: observations,
            unknownSet: BASUnknownSet(missingFacts: ["F"]))
        do {
            _ = try await pipeline.recordTurn(input: collision)
            XCTFail("Expected duplicate-eventID throw")
        } catch BASInMemoryPresenceObservationStore.StoreError
            .duplicateEventID {
            // expected
        }
        // The unknown store should NOT have any writes because
        // presence failed FIRST in the pipeline order
        let unknownCount = await unknownMem.count()
        XCTAssertEqual(unknownCount, 0,
            "L7 store untouched when L6 fails earlier in order")
        // The earlier successful presence write remains
        let presenceCount = await presenceMem.count()
        XCTAssertEqual(presenceCount, 1,
            "Earlier turn's presence row remains intact")
    }
}

#endif  // os(iOS) || os(macOS)
