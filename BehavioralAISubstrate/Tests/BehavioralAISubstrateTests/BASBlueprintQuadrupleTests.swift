// MARK: - BASBlueprintQuadrupleTests
// 主线 全面 开发 — four moves aligned with user's final
// blueprint:
//   1. Rust: ledger_replay_verify (Rust owns
//      "ledger/replay")
//   2. SQL: Tombstone soft-delete (SQL owns
//      "Tombstone")
//   3. SQL: episode summaries (SQL owns "Episode")
//   4. Metal: cosine similarity kernel (Metal owns
//      "embedding similarity")

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

#if !os(iOS)  // ch 1022 source-gate
final class BASBlueprintQuadrupleTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-blueprint-\(UUID().uuidString).sqlite")
    }

    // MARK: - 1. Rust ledger_replay_verify

    func testReplayVerifyMatchesValidChain() throws {
        // Build a 3-event chain manually with
        // appendStep,then verify replay matches。
        var current = BASRustLedgerCore.genesisHash
        let payloads = [
            "event-1".data(using: .utf8)!,
            "event-2".data(using: .utf8)!,
            "event-3".data(using: .utf8)!,
        ]
        for p in payloads {
            current = try BASRustLedgerCore.appendStep(
                previousHash: current, payload: p)
        }
        let ok = try BASRustLedgerCore.replayVerify(
            initialHash: BASRustLedgerCore.genesisHash,
            payloads: payloads,
            expectedFinalHash: current)
        XCTAssertTrue(ok,
            "Replay of identical payloads must match")
    }

    func testReplayVerifyMismatchOnBadFinalHash()
        throws
    {
        var current = BASRustLedgerCore.genesisHash
        let payloads = [
            "event-1".data(using: .utf8)!,
            "event-2".data(using: .utf8)!,
        ]
        for p in payloads {
            current = try BASRustLedgerCore.appendStep(
                previousHash: current, payload: p)
        }
        let wrong = Data(repeating: 0xFF, count: 32)
        let ok = try BASRustLedgerCore.replayVerify(
            initialHash: BASRustLedgerCore.genesisHash,
            payloads: payloads,
            expectedFinalHash: wrong)
        XCTAssertFalse(ok,
            "Wrong expected hash → mismatch")
    }

    func testReplayVerifyDetectsTampering() throws {
        // Genuine chain
        var current = BASRustLedgerCore.genesisHash
        let original = [
            "event-1".data(using: .utf8)!,
            "event-2".data(using: .utf8)!,
            "event-3".data(using: .utf8)!,
        ]
        for p in original {
            current = try BASRustLedgerCore.appendStep(
                previousHash: current, payload: p)
        }
        let expected = current
        // Attacker replays with one event swapped
        let tampered = [
            "event-1".data(using: .utf8)!,
            "tampered-event".data(using: .utf8)!,
            "event-3".data(using: .utf8)!,
        ]
        let ok = try BASRustLedgerCore.replayVerify(
            initialHash: BASRustLedgerCore.genesisHash,
            payloads: tampered,
            expectedFinalHash: expected)
        XCTAssertFalse(ok,
            "Tampered payload sequence must NOT match" +
            " original final hash — that's the tamper" +
            " detection guarantee")
    }

    func testReplayVerifyEmptyPayloads() throws {
        // Empty chain → final hash == initial hash
        let ok = try BASRustLedgerCore.replayVerify(
            initialHash: BASRustLedgerCore.genesisHash,
            payloads: [],
            expectedFinalHash:
                BASRustLedgerCore.genesisHash)
        XCTAssertTrue(ok,
            "Empty replay → final = initial")
    }

    func testReplayVerifyWrongInitialHashLength() throws {
        do {
            _ = try BASRustLedgerCore.replayVerify(
                initialHash: Data(
                    repeating: 0, count: 16),
                payloads: [],
                expectedFinalHash:
                    BASRustLedgerCore.genesisHash)
            XCTFail("16-byte initial should throw")
        } catch {
            // expected
        }
    }

    // MARK: - 2. SQL Tombstone

    func testTombstoneInMemoryTracker() async throws {
        let tracker = BASMemoryUsageTracker()
        let id = try await tracker.record(
            atomID: "a", sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        var tomb = await tracker.isTombstoned(
            recordID: id)
        var active = await tracker.activeRecordCount
        var tcount = await tracker.tombstoneCount
        XCTAssertFalse(tomb)
        XCTAssertEqual(active, 1)
        XCTAssertEqual(tcount, 0)
        try await tracker.tombstoneRecord(recordID: id)
        tomb = await tracker.isTombstoned(recordID: id)
        active = await tracker.activeRecordCount
        tcount = await tracker.tombstoneCount
        XCTAssertTrue(tomb)
        XCTAssertEqual(active, 0)
        XCTAssertEqual(tcount, 1)
    }

    func testTombstoneSQLiteBacked() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let id = try await tracker.record(
            atomID: "x", sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        try await tracker.tombstoneRecord(recordID: id)
        let tcount = await tracker.tombstoneCount
        XCTAssertEqual(tcount, 1)
    }

    func testPurgeTombstonedRemovesRecords()
        async throws
    {
        let tracker = BASMemoryUsageTracker()
        let id1 = try await tracker.record(
            atomID: "keep", sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        let id2 = try await tracker.record(
            atomID: "discard", sessionRef: "S",
            turnRef: "1", permitMode: "safe")
        try await tracker.tombstoneRecord(recordID: id2)
        let purged = try await tracker.purgeTombstoned()
        XCTAssertEqual(purged, 1)
        let count = await tracker.recordCount
        XCTAssertEqual(count, 1,
            "Only the non-tombstoned record remains")
        let tcount = await tracker.tombstoneCount
        XCTAssertEqual(tcount, 0,
            "Tombstone set cleared after purge")
        let kept = await tracker.record(forID: id1)
        let removed = await tracker.record(forID: id2)
        XCTAssertNotNil(kept)
        XCTAssertNil(removed)
    }

    func testPurgeTombstonedSQLiteRollback() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let id = try await tracker.record(
            atomID: "x", sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        try await tracker.tombstoneRecord(recordID: id)
        _ = try await tracker.purgeTombstoned()
        let count = await tracker.recordCount
        XCTAssertEqual(count, 0,
            "SQLite purge removed the row")
    }

    // MARK: - 3. SQL Episode summaries

    func testEpisodeSummariesEmptyTracker() async throws {
        let tracker = BASMemoryUsageTracker()
        let summaries = try await tracker
            .episodeSummariesViaSQL()
        XCTAssertTrue(summaries.isEmpty)
    }

    func testEpisodeSummariesGroupsBySession() async throws {
        let tracker = BASMemoryUsageTracker()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // Session A:3 records spanning 5 seconds
        for i in 0..<3 {
            _ = try await tracker.record(
                atomID: "a\(i)", sessionRef: "alpha",
                turnRef: String(i), permitMode: "safe",
                retrievedAt: t0.addingTimeInterval(
                    Double(i) * 2.5))
        }
        // Session B:1 record
        _ = try await tracker.record(
            atomID: "b", sessionRef: "beta",
            turnRef: "0", permitMode: "safe",
            retrievedAt: t0.addingTimeInterval(100))
        let summaries = try await tracker
            .episodeSummariesViaSQL()
        XCTAssertEqual(summaries.count, 2)
        // Sorted by startMs:alpha (0s) before beta (100s)
        XCTAssertEqual(summaries[0].sessionRef, "alpha")
        XCTAssertEqual(summaries[0].recordCount, 3)
        XCTAssertEqual(
            summaries[0].durationSeconds, 5.0,
            accuracy: 0.001,
            "Alpha episode = 5 seconds (0s..5s)")
        XCTAssertEqual(summaries[1].sessionRef, "beta")
        XCTAssertEqual(summaries[1].recordCount, 1)
        XCTAssertEqual(
            summaries[1].durationSeconds, 0,
            "Single-record episode duration = 0")
    }

    func testEpisodeSummariesSQLBacked() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<5 {
            _ = try await tracker.record(
                atomID: "a", sessionRef: "S",
                turnRef: String(i), permitMode: "safe",
                retrievedAt: t0.addingTimeInterval(
                    Double(i)))
        }
        let summaries = try await tracker
            .episodeSummariesViaSQL()
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].recordCount, 5)
        XCTAssertEqual(
            summaries[0].durationSeconds, 4.0,
            accuracy: 0.001)
    }

    func testEpisodeSummaryCodableRoundTrip() throws {
        let e = BASEpisodeSummary(
            sessionRef: "S",
            recordCount: 10,
            startMs: 1_700_000_000_000,
            endMs: 1_700_000_005_000)
        let data = try JSONEncoder().encode(e)
        let decoded = try JSONDecoder().decode(
            BASEpisodeSummary.self, from: data)
        XCTAssertEqual(decoded, e)
        XCTAssertEqual(
            decoded.durationSeconds, 5.0,
            accuracy: 0.001)
    }

    // MARK: - 4. Metal cosine similarity

    func testCosineIdenticalVectorsOne() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        // Identical non-zero vectors → cos = 1
        let v: [Float] = [1.0, 2.0, 3.0, 4.0]
        let result = try await brain.cosineSimilarity(v, v)
        XCTAssertEqual(result.similarity, 1.0,
            accuracy: 1e-5,
            "Identical vectors → cos = 1")
    }

    func testCosineOrthogonalVectorsZero() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        // [1, 0] ⊥ [0, 1] → cos = 0
        let a: [Float] = [1.0, 0.0]
        let b: [Float] = [0.0, 1.0]
        let result = try await brain.cosineSimilarity(a, b)
        XCTAssertEqual(result.similarity, 0.0,
            accuracy: 1e-5,
            "Orthogonal vectors → cos = 0")
    }

    func testCosineAntiparallelVectorsMinusOne()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        // [1, 2] ⋅ [-1, -2] / (|a| * |b|) = -1
        let a: [Float] = [1.0, 2.0]
        let b: [Float] = [-1.0, -2.0]
        let result = try await brain.cosineSimilarity(a, b)
        XCTAssertEqual(result.similarity, -1.0,
            accuracy: 1e-5,
            "Antiparallel vectors → cos = -1")
    }

    func testCosineZeroVectorYieldsZero() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let a: [Float] = [1.0, 2.0, 3.0]
        let b: [Float] = [0.0, 0.0, 0.0]
        let result = try await brain.cosineSimilarity(a, b)
        XCTAssertEqual(result.similarity, 0.0,
            "Zero-vector input → similarity 0 by" +
            " convention (no NaN)")
        XCTAssertEqual(result.normB, 0.0)
    }

    func testCosineLengthMismatchThrows() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        do {
            _ = try await brain.cosineSimilarity(
                [1.0, 2.0],
                [3.0, 4.0, 5.0])
            XCTFail("Length mismatch must throw")
        } catch
            BASMetalCosineSimilarityDispatcherError
                .payloadCountMismatch
        {
            // expected
        }
    }

    func testCosineEmptyVectorThrows() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        do {
            _ = try await brain.cosineSimilarity([], [])
            XCTFail("Empty input must throw")
        } catch
            BASMetalCosineSimilarityDispatcherError
                .zeroLengthVectors
        {
            // expected
        }
    }

    func testCosineWithoutMetalLoaderThrows() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()  // no Metal
        do {
            _ = try await brain.cosineSimilarity(
                [1.0], [1.0])
            XCTFail("No loader must throw")
        } catch
            BASMetalCosineSimilarityDispatcherError
                .libraryUnavailable
        {
            // expected
        }
    }

    func testCosineCodableRoundTrip() throws {
        let r = BASMetalCosineSimilarityResult(
            similarity: 0.95,
            normA: 1.41,
            normB: 1.42,
            dotProduct: 1.91)
        let data = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder().decode(
            BASMetalCosineSimilarityResult.self,
            from: data)
        XCTAssertEqual(decoded, r)
    }

    func testCosineLargerVector() async throws {
        // 128-dim deterministic vectors, verify GPU path
        // matches CPU expectation within tolerance
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        var seed: UInt32 = 0xCAFEBABE
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF) /
                Float(0xFFFF) - 0.5
        }
        let a = (0..<128).map { _ in next() }
        let b = (0..<128).map { _ in next() }
        let result = try await brain.cosineSimilarity(a, b)
        // CPU reference
        var dot: Float = 0
        var na: Float = 0
        var nb: Float = 0
        for i in 0..<128 {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let expected = dot / (sqrtf(na) * sqrtf(nb))
        XCTAssertEqual(result.similarity, expected,
            accuracy: 1e-5,
            "GPU cosine matches CPU reference within" +
            " float32 tolerance")
    }
}
#endif
