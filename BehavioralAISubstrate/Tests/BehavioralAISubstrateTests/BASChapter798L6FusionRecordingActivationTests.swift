// MARK: - BASChapter798L6FusionRecordingActivationTests
// chapter 七百九十八 / M2641-M2645
//
// Verifies the opt-in `fuseAndRecord(...)` activation of the L6
// presence fusion against the L6 observation store (chapter 七百
// 九十五 storage adapters)。 Three guarantees pinned:
//
//   1. The fused value returned by `fuseAndRecord` is byte-identical
//      to `fuse(observations:)` for the same input — no behavior
//      drift introduced by adding the recording side channel。
//   2. The InMemory store ends up with one record per valid
//      input observation,with matching salience / confidence /
//      channelKind / sessionID / turnID。
//   3. The SQLite-backed store survives a cold restart — records
//      reopened from disk match what was just written。

import XCTest
@testable import BASOrchestration
@testable import BASSovereign

final class BASChapter798L6FusionRecordingActivationTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "bas-test-fusion-record-\(UUID().uuidString).sqlite")
    }

    override func tearDown() async throws {
        if let url = tempURL,
           FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        try await super.tearDown()
    }

    // MARK: - Channel byte ↔ kind mapping pin

    func testChannelKindMappingMatchesSchema013Order() {
        // Schema 013 CHECK literal order:task / risk /
        // manipulation / environment / bodyRhythm。
        XCTAssertEqual(BASRoutedPresenceFusion.channelKindByByte,
                       ["task", "risk", "manipulation",
                        "environment", "bodyRhythm"])
        XCTAssertEqual(BASRoutedPresenceFusion.channelKind(forByte: 0), "task")
        XCTAssertEqual(BASRoutedPresenceFusion.channelKind(forByte: 4),
                       "bodyRhythm")
        XCTAssertNil(BASRoutedPresenceFusion.channelKind(forByte: 5))
        XCTAssertNil(BASRoutedPresenceFusion.channelKind(forByte: 255))
    }

    // MARK: - InMemory store activation

    func testFuseAndRecordInMemoryPersistsAllObservations() async throws {
        let store = BASInMemoryPresenceObservationStore()
        let observations = sampleObservations()
        let direct = BASRoutedPresenceFusion.fuse(
            observations: observations)
        let viaRecorded = try await BASRoutedPresenceFusion
            .fuseAndRecord(
                observations: observations,
                sessionID: "sess-A",
                turnID: "turn-A1",
                store: store,
                eventIDPrefix: "ev-mem",
                nowMs: 1_000)

        // (1) Math is identical to the pure fuse path
        XCTAssertEqual(viaRecorded, direct, accuracy: 0,
            "fuseAndRecord MUST NOT alter the fusion math")

        // (2) One record per valid observation
        let recordCount = await store.count()
        XCTAssertEqual(recordCount, observations.count)

        let bySession = await store.records(forSession: "sess-A")
        XCTAssertEqual(bySession.count, observations.count)
        XCTAssertEqual(bySession.map { $0.eventID },
            (0..<observations.count).map { "ev-mem-\($0)" },
            "Event IDs use index-suffixed prefix in input order")
        XCTAssertEqual(bySession.map { $0.channelKind },
            ["task", "risk", "manipulation", "environment", "bodyRhythm"])
        XCTAssertEqual(bySession.map { $0.salience },
            observations.map { $0.salience })
        XCTAssertEqual(bySession.map { $0.confidence },
            observations.map { $0.confidence })
        XCTAssertEqual(Set(bySession.map { $0.observedAtMs }),
                       Set([1_000]),
            "All records carry the same observed_at_ms")
    }

    func testFuseAndRecordSkipsOutOfRangeChannelByte() async throws {
        let store = BASInMemoryPresenceObservationStore()
        let observations = [
            BASChannelObservationInput(
                channelByte: 0, salience: 0.5, confidence: 0.8),
            // Out-of-range byte — skipped for recording,but still
            // filtered by fuse(...)
            BASChannelObservationInput(
                channelByte: 9, salience: 0.99, confidence: 0.99),
            BASChannelObservationInput(
                channelByte: 1, salience: 0.6, confidence: 0.7),
        ]
        _ = try await BASRoutedPresenceFusion.fuseAndRecord(
            observations: observations,
            sessionID: "sess-skip",
            turnID: "turn-skip",
            store: store,
            eventIDPrefix: "ev-skip",
            nowMs: 42)
        let saved = await store.records(forSession: "sess-skip")
        XCTAssertEqual(saved.count, 2,
            "Out-of-range channelByte must NOT be persisted")
        XCTAssertEqual(saved.map { $0.channelKind }, ["task", "risk"])
        XCTAssertEqual(saved.map { $0.eventID },
            ["ev-skip-0", "ev-skip-2"],
            "Skipped indexes leave gaps in the eventID suffixes")
    }

    // MARK: - SQLite-backed store activation

    func testFuseAndRecordSQLiteSurvivesColdRestart() async throws {
        let observations = sampleObservations()
        let expectedFused = BASRoutedPresenceFusion.fuse(
            observations: observations)

        do {
            let store = try BASSQLitePresenceObservationStore(
                databaseURL: tempURL)
            let recorded = try await BASRoutedPresenceFusion
                .fuseAndRecord(
                    observations: observations,
                    sessionID: "sess-cold",
                    turnID: "turn-cold",
                    store: store,
                    eventIDPrefix: "ev-sqlite",
                    nowMs: 5_000)
            XCTAssertEqual(recorded, expectedFused, accuracy: 0)
            let liveCount = await store.count()
            XCTAssertEqual(liveCount, observations.count)
        }

        // Cold restart — reopen the same file
        let reopened = try BASSQLitePresenceObservationStore(
            databaseURL: tempURL)
        let restored = await reopened.records(forSession: "sess-cold")
        XCTAssertEqual(restored.count, observations.count)
        XCTAssertEqual(restored.map { $0.eventID },
            (0..<observations.count).map { "ev-sqlite-\($0)" })
        XCTAssertEqual(restored.map { $0.channelKind },
            ["task", "risk", "manipulation", "environment", "bodyRhythm"])
        XCTAssertEqual(restored.map { $0.salience },
            observations.map { $0.salience })
        XCTAssertEqual(restored.map { $0.confidence },
            observations.map { $0.confidence })
    }

    func testFuseAndRecordDuplicatePrefixThrows() async throws {
        let store = BASInMemoryPresenceObservationStore()
        let observations = [
            BASChannelObservationInput(
                channelByte: 0, salience: 0.5, confidence: 0.8),
        ]
        _ = try await BASRoutedPresenceFusion.fuseAndRecord(
            observations: observations,
            sessionID: "sess-dup",
            turnID: "turn-dup",
            store: store,
            eventIDPrefix: "ev-dup",
            nowMs: 1)
        // Reusing the same prefix collides on event_id (ev-dup-0)
        do {
            _ = try await BASRoutedPresenceFusion.fuseAndRecord(
                observations: observations,
                sessionID: "sess-dup",
                turnID: "turn-dup",
                store: store,
                eventIDPrefix: "ev-dup",
                nowMs: 2)
            XCTFail("Expected duplicate-eventID throw on prefix collision")
        } catch BASInMemoryPresenceObservationStore.StoreError
            .duplicateEventID(let id) {
            XCTAssertEqual(id, "ev-dup-0")
        }
    }

    // MARK: - Helpers

    private func sampleObservations() -> [BASChannelObservationInput] {
        return [
            BASChannelObservationInput(
                channelByte: 0, salience: 0.5, confidence: 0.8),
            BASChannelObservationInput(
                channelByte: 1, salience: 0.6, confidence: 0.7),
            BASChannelObservationInput(
                channelByte: 2, salience: 0.7, confidence: 0.9),
            BASChannelObservationInput(
                channelByte: 3, salience: 0.4, confidence: 0.6),
            BASChannelObservationInput(
                channelByte: 4, salience: 0.5, confidence: 0.5),
        ]
    }
}
