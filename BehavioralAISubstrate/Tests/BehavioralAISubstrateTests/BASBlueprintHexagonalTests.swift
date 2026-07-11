// MARK: - BASBlueprintHexagonalTests
// 主线 全面 开发: six blueprint-aligned moves tested
// together
//   1. Rust provenance (record_lineage)
//   2. Metal RMSNorm GPU kernel
//   3. Metal MatMul GPU kernel
//   4. SQL ReplayLog
//   5. SQL AuditLog
//   6. SQL FTS5 + notes
//   7. C++ flat vector NN index

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASBlueprintHexagonalTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-blueprint-hex-\(UUID().uuidString).sqlite")
    }

    // MARK: - 1. Rust provenance

    func testRecordLineageEmptyAtom() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let lineage = try await tracker.recordLineage(
            forAtomID: "never-seen")
        XCTAssertTrue(lineage.isEmpty)
    }

    func testRecordLineageOrdered() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // 3 records for same atomID at spaced timestamps
        for i in 0..<3 {
            _ = try await tracker.record(
                atomID: "shared", sessionRef: "S",
                turnRef: String(i), permitMode: "safe",
                retrievedAt: t0.addingTimeInterval(
                    Double(i)))
        }
        // 1 record for a different atomID (should not
        // appear in lineage)
        _ = try await tracker.record(
            atomID: "other", sessionRef: "S",
            turnRef: "99", permitMode: "safe")
        let lineage = try await tracker.recordLineage(
            forAtomID: "shared")
        XCTAssertEqual(lineage.count, 3,
            "Lineage filters by atomID")
        XCTAssertEqual(lineage[0].lineageIndex, 0)
        XCTAssertEqual(lineage[1].lineageIndex, 1)
        XCTAssertEqual(lineage[2].lineageIndex, 2)
        // Timestamps ascending
        XCTAssertLessThan(
            lineage[0].retrievedAtMs,
            lineage[1].retrievedAtMs)
        XCTAssertLessThan(
            lineage[1].retrievedAtMs,
            lineage[2].retrievedAtMs)
    }

    func testRecordLineageCodable() throws {
        let e = BASRecordLineageEntry(
            atomID: "abc",
            recordID: "rec-1",
            lineageIndex: 5,
            retrievedAtMs: 1_700_000_000_000,
            sessionRef: "S",
            turnRef: "0",
            permitMode: "safe",
            helpedFlag: "unknown",
            schemaVersion: "1.0.0")
        let data = try JSONEncoder().encode(e)
        let decoded = try JSONDecoder().decode(
            BASRecordLineageEntry.self, from: data)
        XCTAssertEqual(decoded, e)
    }

    // MARK: - 2. Metal RMSNorm

    func testRMSNormUniformInput() async throws {
        // x = [1, 1, 1, 1] → mean(x²) = 1
        // inv_rms = 1 / sqrt(1 + eps) ≈ 1
        // y = x * inv_rms ≈ x
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let x: [Float] = [1.0, 1.0, 1.0, 1.0]
        let y = try await brain.rmsnorm(x)
        XCTAssertEqual(y.count, 4)
        for v in y {
            XCTAssertEqual(v, 1.0, accuracy: 1e-3,
                "Uniform input → uniform normalized output")
        }
    }

    func testRMSNormScaleInvariance() async throws {
        // RMSNorm of α·x === RMSNorm of x (up to sign)
        // because inv_rms scales as 1/α — output is unit-
        // RMS regardless of input magnitude
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let x: [Float] = [2.0, 3.0, 4.0, 5.0]
        let xScaled: [Float] = [20.0, 30.0, 40.0, 50.0]
        let y = try await brain.rmsnorm(x)
        let yScaled = try await brain.rmsnorm(xScaled)
        for i in 0..<4 {
            XCTAssertEqual(y[i], yScaled[i],
                accuracy: 1e-4,
                "RMSNorm is scale-invariant")
        }
    }

    func testRMSNormZeroVectorYieldsZeros() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let x: [Float] = [0, 0, 0, 0]
        let y = try await brain.rmsnorm(x, epsilon: 1e-3)
        // 0 / sqrt(eps) = 0
        for v in y {
            XCTAssertEqual(v, 0.0, accuracy: 1e-6)
        }
    }

    func testRMSNormEmptyThrows() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        do {
            _ = try await brain.rmsnorm([])
            XCTFail("Empty input must throw")
        } catch BASMetalRMSNormDispatcherError
            .zeroLengthVector
        {
            // expected
        }
    }

    // MARK: - 3. Metal MatMul

    func testMatMulIdentityIsIdentity() async throws {
        // 2x2 identity × any 2x2 matrix = the same matrix
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let I: [Float] = [1, 0, 0, 1]
        let B: [Float] = [1, 2, 3, 4]
        let C = try await brain.matmul(
            a: I, aRows: 2, aCols: 2,
            b: B, bRows: 2, bCols: 2)
        for i in 0..<4 {
            XCTAssertEqual(C[i], B[i], accuracy: 1e-5)
        }
    }

    func testMatMulSmallKnownProduct() async throws {
        // A = [[1, 2],
        //      [3, 4]]
        // B = [[5, 6],
        //      [7, 8]]
        // A·B = [[1*5+2*7=19, 1*6+2*8=22],
        //        [3*5+4*7=43, 3*6+4*8=50]]
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let A: [Float] = [1, 2, 3, 4]
        let B: [Float] = [5, 6, 7, 8]
        let C = try await brain.matmul(
            a: A, aRows: 2, aCols: 2,
            b: B, bRows: 2, bCols: 2)
        XCTAssertEqual(C[0], 19, accuracy: 1e-5)
        XCTAssertEqual(C[1], 22, accuracy: 1e-5)
        XCTAssertEqual(C[2], 43, accuracy: 1e-5)
        XCTAssertEqual(C[3], 50, accuracy: 1e-5)
    }

    func testMatMulShapeMismatchThrows() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        do {
            _ = try await brain.matmul(
                a: [1, 2, 3], aRows: 1, aCols: 3,
                b: [1, 2, 3, 4], bRows: 2, bCols: 2)
            XCTFail("aCols(3) != bRows(2) must throw")
        } catch BASMetalMatMulDispatcherError
            .shapeMismatch
        {
            // expected
        }
    }

    func testMatMulNonSquare() async throws {
        // 2x3 · 3x2 = 2x2
        // A = [[1, 2, 3],
        //      [4, 5, 6]]
        // B = [[1, 0],
        //      [0, 1],
        //      [1, 1]]
        // A·B = [[1+0+3, 0+2+3], = [[4, 5],
        //        [4+0+6, 0+5+6]]    [10, 11]]
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let A: [Float] = [1, 2, 3, 4, 5, 6]
        let B: [Float] = [1, 0, 0, 1, 1, 1]
        let C = try await brain.matmul(
            a: A, aRows: 2, aCols: 3,
            b: B, bRows: 3, bCols: 2)
        XCTAssertEqual(C[0], 4, accuracy: 1e-5)
        XCTAssertEqual(C[1], 5, accuracy: 1e-5)
        XCTAssertEqual(C[2], 10, accuracy: 1e-5)
        XCTAssertEqual(C[3], 11, accuracy: 1e-5)
    }

    // MARK: - 4. SQL ReplayLog

    func testReplayLogAppendAndQuery() async throws {
        let tracker = BASMemoryUsageTracker()
        let id1 = try await tracker.appendReplayLog(
            eventType: "user.input",
            payload: "hello",
            recordedAt: Date(
                timeIntervalSince1970: 1_700_000_000))
        let id2 = try await tracker.appendReplayLog(
            eventType: "user.input",
            payload: "world",
            recordedAt: Date(
                timeIntervalSince1970: 1_700_000_001))
        XCTAssertEqual(id1.count, 36)
        XCTAssertNotEqual(id1, id2)
        let entries = try await tracker
            .replayLogEntriesViaSQL()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].payload, "hello")
        XCTAssertEqual(entries[1].payload, "world")
    }

    func testReplayLogSQLiteBacked() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        _ = try await tracker.appendReplayLog(
            eventType: "sys.start", payload: "boot")
        let entries = try await tracker
            .replayLogEntriesViaSQL()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].eventType, "sys.start")
    }

    func testReplayLogEntryCodable() throws {
        let e = BASReplayLogEntry(
            eventID: "uuid-1",
            eventType: "test",
            payload: "data",
            recordedAtMs: 1_700_000_000_000)
        let data = try JSONEncoder().encode(e)
        let decoded = try JSONDecoder().decode(
            BASReplayLogEntry.self, from: data)
        XCTAssertEqual(decoded, e)
    }

    // MARK: - 5. SQL AuditLog

    func testAuditLogAppendAndQuery() async throws {
        let tracker = BASMemoryUsageTracker()
        let id = try await tracker.appendAuditLog(
            actor: "host",
            action: "purge",
            detail: "tombstoned 5 records",
            recordedAt: Date(
                timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(id.count, 36)
        let entries = try await tracker
            .auditLogEntriesViaSQL()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].actor, "host")
        XCTAssertEqual(entries[0].action, "purge")
    }

    func testAuditLogSQLiteBacked() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        for i in 0..<3 {
            _ = try await tracker.appendAuditLog(
                actor: "actor-\(i)",
                action: "action",
                detail: "detail-\(i)")
        }
        let entries = try await tracker
            .auditLogEntriesViaSQL()
        XCTAssertEqual(entries.count, 3)
    }

    func testAuditLogEntryCodable() throws {
        let e = BASAuditLogEntry(
            entryID: "uuid-1",
            actor: "tester",
            action: "verify",
            detail: "ok",
            recordedAtMs: 1_700_000_000_000)
        let data = try JSONEncoder().encode(e)
        let decoded = try JSONDecoder().decode(
            BASAuditLogEntry.self, from: data)
        XCTAssertEqual(decoded, e)
    }

    // MARK: - 6. SQL FTS5

    func testFTSEmptyQueryReturnsEmpty() async throws {
        let tracker = BASMemoryUsageTracker()
        let matches = try await tracker.searchNotesFTS(
            query: "")
        XCTAssertTrue(matches.isEmpty)
    }

    func testFTSInMemoryFallback() async throws {
        let tracker = BASMemoryUsageTracker()
        try await tracker.attachNotes(
            recordID: "rec-1",
            notes: "Apple banana cherry")
        try await tracker.attachNotes(
            recordID: "rec-2",
            notes: "Dog elephant frog")
        let matches = try await tracker.searchNotesFTS(
            query: "banana")
        XCTAssertEqual(matches, ["rec-1"])
    }

    func testFTSSQLiteBackedFullTextSearch() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        try await tracker.attachNotes(
            recordID: "rec-1",
            notes: "The quick brown fox jumps over the lazy dog")
        try await tracker.attachNotes(
            recordID: "rec-2",
            notes: "Quantum mechanics is fundamental physics")
        try await tracker.attachNotes(
            recordID: "rec-3",
            notes: "A fox in the henhouse is bad news")
        let foxMatches = try await tracker.searchNotesFTS(
            query: "fox")
        // FTS5 tokenizes by word + matches stem;both
        // rec-1 and rec-3 contain "fox"
        XCTAssertEqual(Set(foxMatches),
            Set(["rec-1", "rec-3"]))
        let quantumMatches = try await tracker
            .searchNotesFTS(query: "quantum")
        XCTAssertEqual(quantumMatches, ["rec-2"])
    }

    func testFTSAttachNotesReplaces() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        try await tracker.attachNotes(
            recordID: "rec-1", notes: "original text")
        try await tracker.attachNotes(
            recordID: "rec-1", notes: "replaced content")
        let originalMatches = try await tracker
            .searchNotesFTS(query: "original")
        let replacedMatches = try await tracker
            .searchNotesFTS(query: "replaced")
        XCTAssertTrue(originalMatches.isEmpty,
            "Old content no longer matches after replace")
        XCTAssertEqual(replacedMatches, ["rec-1"])
    }

    // MARK: - 7. C++ vector NN index

    func testVectorIndexEmptySearchReturnsEmpty()
        async throws
    {
        let bridge = BASCxxVectorIndexBridge(
            useCxxIndex: true)
        try await bridge.clear()
        let results = try await bridge.search(
            query: [1, 0, 0], k: 5)
        XCTAssertTrue(results.isEmpty)
    }

    func testVectorIndexAddAndSearch() async throws {
        let bridge = BASCxxVectorIndexBridge(
            useCxxIndex: true)
        try await bridge.clear()
        // Add 3 vectors; query is closest to first
        try await bridge.add(id: "v1",
            vector: [1, 0, 0])
        try await bridge.add(id: "v2",
            vector: [0, 1, 0])
        try await bridge.add(id: "v3",
            vector: [0, 0, 1])
        let results = try await bridge.search(
            query: [1, 0.1, 0], k: 3)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].id, "v1",
            "Top match is the vector most aligned" +
            " with the query")
        XCTAssertEqual(results[0].similarity, 1.0,
            accuracy: 0.01)
    }

    func testVectorIndexAddReplaces() async throws {
        let bridge = BASCxxVectorIndexBridge(
            useCxxIndex: true)
        try await bridge.clear()
        try await bridge.add(id: "v1",
            vector: [1, 0, 0])
        try await bridge.add(id: "v1",
            vector: [0, 1, 0])  // replace
        let size = await bridge.size()
        XCTAssertEqual(size, 1,
            "Re-adding same id replaces,size stays 1")
        let results = try await bridge.search(
            query: [0, 1, 0], k: 1)
        XCTAssertEqual(results[0].similarity, 1.0,
            accuracy: 0.01,
            "Replaced vector matches new query")
    }

    func testVectorIndexLimitK() async throws {
        let bridge = BASCxxVectorIndexBridge(
            useCxxIndex: true)
        try await bridge.clear()
        // 10 vectors with VARYING directions (cosine
        // similarity is direction-based, so vectors
        // need different orientations to produce
        // distinct rankings)。
        for i in 0..<10 {
            let angle = Float(i) * 0.1
            try await bridge.add(id: "v\(i)",
                vector: [cosf(angle), sinf(angle), 0])
        }
        let top3 = try await bridge.search(
            query: [1, 0, 0], k: 3)
        XCTAssertEqual(top3.count, 3,
            "k=3 returns at most 3 results")
        // Top match is the most-aligned vector
        // (angle=0 → v0)
        XCTAssertEqual(top3[0].id, "v0",
            "Most-aligned vector ranks first")
        // Results sorted descending by similarity
        XCTAssertGreaterThanOrEqual(
            top3[0].similarity, top3[1].similarity)
        XCTAssertGreaterThanOrEqual(
            top3[1].similarity, top3[2].similarity)
    }

    func testVectorIndexV1PathThrows() async throws {
        let bridge = BASCxxVectorIndexBridge(
            useCxxIndex: false)
        do {
            try await bridge.add(
                id: "x", vector: [1, 2, 3])
            XCTFail("V1 must throw on add")
        } catch
            BASCxxVectorIndexBridgeError
                .unknownReturnCode(let rc)
        {
            XCTAssertEqual(rc, -99)
        }
        // Search returns empty without throwing
        let results = try await bridge.search(
            query: [1, 2, 3], k: 5)
        XCTAssertTrue(results.isEmpty)
        let size = await bridge.size()
        XCTAssertEqual(size, 0)
    }

    func testVectorIndexResultCodable() throws {
        let r = BASCxxVectorIndexResult(
            id: "v1", similarity: 0.95)
        let data = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder().decode(
            BASCxxVectorIndexResult.self, from: data)
        XCTAssertEqual(decoded, r)
    }
}
