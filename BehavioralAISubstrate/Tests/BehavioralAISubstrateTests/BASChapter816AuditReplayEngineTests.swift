// MARK: - BASChapter816AuditReplayEngineTests
// chapter 八百十六 / M2731-M2735
//
// Verifies the BASAuditReplayEngine session loader。 Read-side
// counterpart of BASAuditPipeline (chapter 八百十五)。
//
// Six invariants pinned:
//
//   1. Empty session loads an empty trail (every array empty,
//      vault nil → versions empty,totalRecords=0)。
//   2. Pipeline-recorded turn round-trips through replay engine:
//      what the pipeline wrote is what loadSession sees。
//   3. distinctTurnIDs aggregates L6/L7 turn fields (L8 atom
//      events have no turnID column so they don't contribute)。
//   4. vaultID nil → versions array empty (no fetch attempt)。
//   5. vaultID non-nil → versions returned via versions(forVault:)。
//   6. loadAndSummarize bundles trail + 3 aggregation summaries
//      and stays consistent with the underlying records。

import XCTest
@testable import BASMemory
@testable import BASSovereign
@testable import BASOrchestration

#if os(iOS) || os(macOS)

final class BASChapter816AuditReplayEngineTests: XCTestCase {

    private var engine: BASAuditReplayEngine!
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
        engine = BASAuditReplayEngine(
            presenceStore: presenceMem,
            unknownStore: unknownMem,
            contradictionStore: contradictionMem,
            atomLifecycleStore: atomMem,
            versionTreeStore: versionMem)
    }

    // MARK: - Empty trail

    func testLoadEmptySessionReturnsEmptyTrail() async throws {
        let trail = await engine.loadSession(sessionID: "empty")
        XCTAssertEqual(trail.totalRecords, 0)
        XCTAssertTrue(trail.presence.isEmpty)
        XCTAssertTrue(trail.unknowns.isEmpty)
        XCTAssertTrue(trail.contradictions.isEmpty)
        XCTAssertTrue(trail.atomEvents.isEmpty)
        XCTAssertTrue(trail.versions.isEmpty)
        XCTAssertEqual(trail.sessionID, "empty")
        XCTAssertNil(trail.vaultID)
    }

    // MARK: - Round-trip pipeline → engine

    func testPipelineRecordedTurnRoundTripsThroughReplay() async throws {
        let observations = [
            BASChannelObservationInput(
                channelByte: 0, salience: 0.5, confidence: 0.8),
            BASChannelObservationInput(
                channelByte: 1, salience: 0.6, confidence: 0.7),
        ]
        let input = BASAuditPipeline.PerTurnInput(
            sessionID: "s",
            turnID: "t",
            nowMs: 100,
            eventIDPrefix: "rt",
            observations: observations,
            unknownSet: BASUnknownSet(
                missingFacts: ["F1"],
                ambiguityNotes: ["A1"]),
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
                atomID: "a",
                fromPhaseByte: 0,
                toPhaseByte: 1,
                actionByte: 0,
                outcome: 0),
            versionRecord: BASAuditPipeline.VersionRecordInput(
                versionID: "v",
                vaultID: "vault",
                canonicalBytes: Data("snap".utf8)))
        _ = try await pipeline.recordTurn(input: input)

        let trail = await engine.loadSession(
            sessionID: "s", vaultID: "vault")
        XCTAssertEqual(trail.presence.count, 2)
        XCTAssertEqual(trail.unknowns.count, 2,
            "1 fact + 1 ambiguity")
        XCTAssertEqual(trail.contradictions.count, 1)
        XCTAssertEqual(trail.atomEvents.count, 1)
        XCTAssertEqual(trail.versions.count, 1)
        XCTAssertEqual(trail.totalRecords, 7)
    }

    // MARK: - distinctTurnIDs aggregation

    func testDistinctTurnIDsAggregatesAcrossL6L7() async throws {
        for turnIdx in 0..<3 {
            let input = BASAuditPipeline.PerTurnInput(
                sessionID: "s",
                turnID: "turn-\(turnIdx)",
                nowMs: Int64(turnIdx),
                eventIDPrefix: "p\(turnIdx)",
                observations: [
                    BASChannelObservationInput(
                        channelByte: 0,
                        salience: 0.5,
                        confidence: 0.8),
                ])
            _ = try await pipeline.recordTurn(input: input)
        }
        let trail = await engine.loadSession(sessionID: "s")
        XCTAssertEqual(trail.distinctTurnIDs,
                       Set(["turn-0", "turn-1", "turn-2"]))
    }

    // MARK: - VaultID gating

    func testVaultIDNilSkipsVersionFetch() async throws {
        let input = BASAuditPipeline.PerTurnInput(
            sessionID: "s", turnID: "t",
            nowMs: 0, eventIDPrefix: "vn",
            versionRecord: BASAuditPipeline.VersionRecordInput(
                versionID: "v",
                vaultID: "vault",
                canonicalBytes: Data()))
        _ = try await pipeline.recordTurn(input: input)

        let trailNoVault = await engine.loadSession(sessionID: "s")
        XCTAssertTrue(trailNoVault.versions.isEmpty,
            "vaultID nil → engine doesn't fetch versions")
        XCTAssertNil(trailNoVault.vaultID)

        let trailWithVault = await engine.loadSession(
            sessionID: "s", vaultID: "vault")
        XCTAssertEqual(trailWithVault.versions.count, 1)
        XCTAssertEqual(trailWithVault.vaultID, "vault")
    }

    // MARK: - loadAndSummarize

    func testLoadAndSummarizeBundlesTrailAndAggregations() async throws {
        let input = BASAuditPipeline.PerTurnInput(
            sessionID: "s", turnID: "t",
            nowMs: 0, eventIDPrefix: "ls",
            observations: [
                BASChannelObservationInput(
                    channelByte: 0,
                    salience: 0.5,
                    confidence: 0.8),
                BASChannelObservationInput(
                    channelByte: 1,
                    salience: 0.6,
                    confidence: 0.7),
            ],
            unknownSet: BASUnknownSet(
                missingFacts: ["F1", "F2"]),
            contradictions: [
                BASContradictionRecord(
                    nodeID: "n",
                    kind: .textual,
                    summary: "x",
                    refs: [],
                    severity: 0.7,
                    unresolved: false),
            ])
        _ = try await pipeline.recordTurn(input: input)

        let summary = await engine.loadAndSummarize(sessionID: "s")
        XCTAssertEqual(summary.trail.presence.count, 2)
        XCTAssertEqual(summary.presence.totalObservations, 2)
        XCTAssertEqual(summary.presence.observationCountByChannel["task"], 1)
        XCTAssertEqual(summary.presence.observationCountByChannel["risk"], 1)
        XCTAssertEqual(summary.unknowns.factCount, 2)
        XCTAssertEqual(summary.contradictions.resolvedCount, 1)
        XCTAssertEqual(summary.contradictions.unresolvedCount, 0)
        XCTAssertEqual(summary.contradictions.avgSalience,
                       0.7, accuracy: 1e-12)
    }

    // MARK: - Cross-session isolation

    func testLoadSessionDoesntLeakAcrossSessions() async throws {
        // Session A: 2 presence records
        _ = try await pipeline.recordTurn(input:
            BASAuditPipeline.PerTurnInput(
                sessionID: "A", turnID: "t",
                nowMs: 0, eventIDPrefix: "a",
                observations: [
                    BASChannelObservationInput(
                        channelByte: 0,
                        salience: 0.5,
                        confidence: 0.5),
                    BASChannelObservationInput(
                        channelByte: 1,
                        salience: 0.5,
                        confidence: 0.5),
                ]))
        // Session B: 1 presence record
        _ = try await pipeline.recordTurn(input:
            BASAuditPipeline.PerTurnInput(
                sessionID: "B", turnID: "t",
                nowMs: 0, eventIDPrefix: "b",
                observations: [
                    BASChannelObservationInput(
                        channelByte: 0,
                        salience: 0.5,
                        confidence: 0.5),
                ]))

        let trailA = await engine.loadSession(sessionID: "A")
        let trailB = await engine.loadSession(sessionID: "B")
        XCTAssertEqual(trailA.presence.count, 2)
        XCTAssertEqual(trailB.presence.count, 1)
        XCTAssertEqual(Set(trailA.presence.map { $0.sessionID }),
                       Set(["A"]))
        XCTAssertEqual(Set(trailB.presence.map { $0.sessionID }),
                       Set(["B"]))
    }
}

#endif  // os(iOS) || os(macOS)
