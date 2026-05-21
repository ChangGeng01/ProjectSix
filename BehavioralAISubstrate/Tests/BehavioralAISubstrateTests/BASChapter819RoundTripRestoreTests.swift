// MARK: - BASChapter819RoundTripRestoreTests
// chapter 八百十九 / M2746-M2750
//
// End-to-end stress test:pipeline → SQLite → replay → archive
// → diff。 50 turns through real SQLite stores,verify the audit
// trail roundtrips identically and the archive captures the
// aggregate-level information correctly。
//
// Five invariants pinned:
//
//   1. 50-turn pipeline write completes without throwing。
//   2. Replay engine loads exactly what was written (per-store
//      counts match;trail.totalRecords == 50 × 9 = 450 if all
//      turns supplied all 4 record types)。
//   3. Cold restart through SQLite reopens preserves the trail
//      byte-equivalent (replay engine loads identical data
//      after closing + reopening the stores)。
//   4. Archive of the post-restart trail equals the archive of
//      the pre-close trail (compression is deterministic)。
//   5. Diff of pre-close vs post-restart trails has
//      trailsHaveIdenticalIDSets == true。

import XCTest
@testable import BASMemory
@testable import BASSovereign
@testable import BASOrchestration

#if os(iOS) || os(macOS)

final class BASChapter819RoundTripRestoreTests: XCTestCase {

    private var dbDir: URL!
    private var presenceDB: URL!
    private var unknownDB: URL!
    private var contradictionDB: URL!
    private var atomDB: URL!
    private var versionDB: URL!

    override func setUp() async throws {
        try await super.setUp()
        let token = UUID().uuidString
        dbDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-restore-\(token)")
        try FileManager.default.createDirectory(
            at: dbDir, withIntermediateDirectories: true)
        presenceDB = dbDir.appendingPathComponent("p.sqlite")
        unknownDB = dbDir.appendingPathComponent("u.sqlite")
        contradictionDB = dbDir.appendingPathComponent("c.sqlite")
        atomDB = dbDir.appendingPathComponent("a.sqlite")
        versionDB = dbDir.appendingPathComponent("v.sqlite")
    }

    override func tearDown() async throws {
        if let dir = dbDir,
           FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.removeItem(at: dir)
        }
        try await super.tearDown()
    }

    // MARK: - 50-turn round trip

    func testFiftyTurnRoundTripPreservesEverything() async throws {
        let preTrail: BASAuditReplayEngine.SessionAuditTrail
        let preArchive: BASAuditTrailArchive.ArchivedTrail

        // === Write phase + first replay ===
        do {
            let writePipeline = try makePipeline()
            let writeEngine = try makeEngine()

            for turnIdx in 0..<50 {
                let turnID = "turn-\(turnIdx)"
                let nowMs = Int64(turnIdx * 100)
                let observations = (0..<5).map { i in
                    BASChannelObservationInput(
                        channelByte: UInt8(i),
                        salience: 0.4 + Double(i) * 0.1,
                        confidence: 0.8)
                }
                let input = BASAuditPipeline.PerTurnInput(
                    sessionID: "rt",
                    turnID: turnID,
                    nowMs: nowMs,
                    eventIDPrefix: "t\(turnIdx)",
                    observations: observations,
                    unknownSet: BASUnknownSet(
                        missingFacts: ["fact-\(turnIdx)"]),
                    contradictions: [
                        BASContradictionRecord(
                            nodeID: "n-\(turnIdx)",
                            kind: .textual,
                            summary: "c-\(turnIdx)",
                            refs: [],
                            severity: 0.5 + Double(turnIdx) * 0.001,
                            unresolved: turnIdx % 3 != 0),
                    ],
                    atomTransition: BASAuditPipeline.AtomTransitionInput(
                        atomID: "atom-\(turnIdx)",
                        fromPhaseByte: 0,
                        toPhaseByte: 1,
                        actionByte: 0,
                        outcome: 0))
                _ = try await writePipeline.recordTurn(input: input)
            }
            preTrail = await writeEngine.loadSession(sessionID: "rt")
            preArchive = BASAuditTrailArchive.archive(trail: preTrail)
        }

        // === Cold restart ===
        let readEngine = try makeEngine()
        let postTrail = await readEngine.loadSession(sessionID: "rt")
        let postArchive = BASAuditTrailArchive.archive(
            trail: postTrail)

        // === Invariant 2: counts match expectations ===
        XCTAssertEqual(postTrail.presence.count, 50 * 5,
            "5 presence observations per turn × 50 turns")
        XCTAssertEqual(postTrail.unknowns.count, 50,
            "1 unknown per turn × 50 turns")
        XCTAssertEqual(postTrail.contradictions.count, 50,
            "1 contradiction per turn × 50 turns")
        XCTAssertEqual(postTrail.atomEvents.count, 50,
            "1 atom transition per turn × 50 turns")
        XCTAssertEqual(postTrail.totalRecords, 50 * 5 + 50 * 3)
        XCTAssertEqual(postTrail.distinctTurnIDs.count, 50)

        // === Invariant 3: pre vs post counts identical ===
        XCTAssertEqual(postTrail.presence.count,
                       preTrail.presence.count)
        XCTAssertEqual(postTrail.unknowns.count,
                       preTrail.unknowns.count)
        XCTAssertEqual(postTrail.contradictions.count,
                       preTrail.contradictions.count)
        XCTAssertEqual(postTrail.atomEvents.count,
                       preTrail.atomEvents.count)

        // === Invariant 4: archive identical pre vs post ===
        XCTAssertEqual(postArchive.turnCount, preArchive.turnCount)
        XCTAssertEqual(postArchive.atomEventCount,
                       preArchive.atomEventCount)
        XCTAssertEqual(postArchive.atomOutcomeCounts,
                       preArchive.atomOutcomeCounts)
        XCTAssertEqual(postArchive, preArchive,
            "Archive is deterministic across cold restart")

        // === Invariant 5: diff has identical ID sets ===
        let delta = BASAuditTrailDiff.diff(
            baseline: preTrail, current: postTrail)
        XCTAssertTrue(delta.trailsHaveIdenticalIDSets,
            "Cold-restart roundtrip preserves all event IDs")
        XCTAssertEqual(delta.totalAdded, 0)
        XCTAssertEqual(delta.totalRemoved, 0)
    }

    // MARK: - Archive size measurement (informational)

    func testArchiveCompactsRawTrailMeaningfully() async throws {
        let pipeline = try makePipeline()
        let engine = try makeEngine()

        // 20 turns with 5 obs + 3 unknowns + 1 contradiction each
        for turnIdx in 0..<20 {
            _ = try await pipeline.recordTurn(input:
                BASAuditPipeline.PerTurnInput(
                    sessionID: "compact",
                    turnID: "turn-\(turnIdx)",
                    nowMs: Int64(turnIdx),
                    eventIDPrefix: "c\(turnIdx)",
                    observations: (0..<5).map { i in
                        BASChannelObservationInput(
                            channelByte: UInt8(i),
                            salience: 0.5,
                            confidence: 0.8)
                    },
                    unknownSet: BASUnknownSet(
                        missingFacts: ["F\(turnIdx)"],
                        missingRoles: ["R\(turnIdx)"],
                        ambiguityNotes: ["A\(turnIdx)"]),
                    contradictions: [
                        BASContradictionRecord(
                            nodeID: "n",
                            kind: .textual,
                            summary: "x",
                            refs: [],
                            severity: 0.5,
                            unresolved: false),
                    ]))
        }
        let trail = await engine.loadSession(sessionID: "compact")
        let arch = BASAuditTrailArchive.archive(trail: trail)
        // Raw: 20 × 5 + 20 × 3 + 20 = 180 records
        XCTAssertEqual(trail.totalRecords, 180)
        // Archive: 20 turn rows (atoms/versions session-scoped)
        XCTAssertEqual(arch.turnCount, 20)
        // Compression ratio: ~9× (180 raw → 20 turn rows)
        XCTAssertLessThan(arch.turnCount, trail.totalRecords,
            "Archive strictly smaller than raw trail")
        print("== ARCHIVE COMPACTION: \(trail.totalRecords) raw records → " +
              "\(arch.turnCount) turn rows (~9× reduction)")
    }

    // MARK: - Helpers

    private func makePipeline() throws -> BASAuditPipeline {
        return BASAuditPipeline(
            presenceStore: try BASSQLitePresenceObservationStore(
                databaseURL: presenceDB),
            unknownStore: try BASSQLiteUnknownLedgerStore(
                databaseURL: unknownDB),
            contradictionStore: try BASSQLiteContradictionLedgerStore(
                databaseURL: contradictionDB),
            atomLifecycleStore: try BASSQLiteAtomLifecycleStore(
                databaseURL: atomDB),
            versionTreeStore: try BASSQLiteHostConstitutionVersionTreeStore(
                databaseURL: versionDB))
    }

    private func makeEngine() throws -> BASAuditReplayEngine {
        return BASAuditReplayEngine(
            presenceStore: try BASSQLitePresenceObservationStore(
                databaseURL: presenceDB),
            unknownStore: try BASSQLiteUnknownLedgerStore(
                databaseURL: unknownDB),
            contradictionStore: try BASSQLiteContradictionLedgerStore(
                databaseURL: contradictionDB),
            atomLifecycleStore: try BASSQLiteAtomLifecycleStore(
                databaseURL: atomDB),
            versionTreeStore: try BASSQLiteHostConstitutionVersionTreeStore(
                databaseURL: versionDB))
    }
}

#endif  // os(iOS) || os(macOS)
