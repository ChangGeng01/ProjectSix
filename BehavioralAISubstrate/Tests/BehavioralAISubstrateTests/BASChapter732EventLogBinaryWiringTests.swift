// MARK: - BASChapter732EventLogBinaryWiringTests
// chapter 七百三十二 第四刀 / M2334
//
// 50-entry byte-equality test (mirrors chapter 七百十六 audit
// ledger pattern) + per-append perf measurement for the binary
// payload path in BASSQLiteEventLogStorage。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter732EventLogBinaryWiringTests:
    XCTestCase
{

    private func makeEntry(seed: Int) -> BASEventLogEntry {
        return BASEventLogEntry(
            eventID: "evt-\(seed)-\(UUID().uuidString)",
            timestampMs: Int64(1_700_000_000_000 + seed),
            kind: seed % 3 == 0
                ? .substrateAudit
                : (seed % 3 == 1
                   ? .appBehavior
                   : .internalSignal),
            sessionID: "session-\(seed % 5)",
            sequenceNumber: 0,  // storage overwrites
            source: "test.host",
            turnRef: "turn-\(seed)",
            rawInputDigest: "digest-\(seed)",
            intent: "ask",
            emotion: "calm",
            riskBand: seed % 2 == 0 ? .low : .medium,
            project: "proj-\(seed % 3)",
            memoryRefs: ["atom-\(seed)-a", "atom-\(seed)-b"])
    }

    private func makeTempURL(label: String) -> URL {
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "bas_evlog_\(label)_"
                + UUID().uuidString
                + ".sqlite")
    }

    // MARK: - 50-entry byte-equality across paths

    func testJSONAndBinaryPathsProduceEquivalentRows()
        async throws
    {
        let entries = (0..<50).map { makeEntry(seed: $0) }

        // Path 1: write all 50 as JSON (legacy default)
        BASSQLiteEventLogStorage.useBinaryPayload = false
        let urlA = makeTempURL(label: "json")
        let storageA = try BASSQLiteEventLogStorage(
            databaseURL: urlA)
        for e in entries {
            _ = try await storageA.append(e)
        }
        // Path 2: write all 50 as binary (v2)
        BASSQLiteEventLogStorage.useBinaryPayload = true
        let urlB = makeTempURL(label: "binary")
        let storageB = try BASSQLiteEventLogStorage(
            databaseURL: urlB)
        for e in entries {
            _ = try await storageB.append(e)
        }
        BASSQLiteEventLogStorage.useBinaryPayload = false

        // Compare via the SAME public read API
        let jsonReplay = try await storageA.events(
            sinceTimestampMs: 0, limit: 1000)
        let binaryReplay = try await storageB.events(
            sinceTimestampMs: 0, limit: 1000)
        XCTAssertEqual(
            jsonReplay.count, binaryReplay.count)
        XCTAssertEqual(jsonReplay.count, 50)
        // Field-by-field equality across the entries
        for i in 0..<jsonReplay.count {
            let j = jsonReplay[i]
            let b = binaryReplay[i]
            XCTAssertEqual(
                j.eventID, b.eventID,
                "eventID @ \(i)")
            XCTAssertEqual(
                j.timestampMs, b.timestampMs,
                "timestampMs @ \(i)")
            XCTAssertEqual(
                j.kind, b.kind,
                "kind @ \(i)")
            XCTAssertEqual(
                j.sessionID, b.sessionID,
                "sessionID @ \(i)")
            XCTAssertEqual(
                j.sequenceNumber, b.sequenceNumber,
                "seq @ \(i)")
            XCTAssertEqual(
                j.turnRef, b.turnRef,
                "turnRef @ \(i)")
            XCTAssertEqual(
                j.riskBand, b.riskBand,
                "riskBand @ \(i)")
            XCTAssertEqual(
                j.source, b.source,
                "source @ \(i)")
            XCTAssertEqual(
                j.intent, b.intent,
                "intent @ \(i)")
            XCTAssertEqual(
                j.emotion, b.emotion,
                "emotion @ \(i)")
            XCTAssertEqual(
                j.project, b.project,
                "project @ \(i)")
            XCTAssertEqual(
                j.memoryRefs, b.memoryRefs,
                "memoryRefs @ \(i)")
        }
    }

    // MARK: - Dual-read works on a mixed v1/v2 corpus

    func testMixedV1V2RowsReadBackCorrectly() async throws {
        let url = makeTempURL(label: "mixed")
        let storage = try BASSQLiteEventLogStorage(
            databaseURL: url)
        // First 10 as JSON
        BASSQLiteEventLogStorage.useBinaryPayload = false
        for i in 0..<10 {
            _ = try await storage.append(makeEntry(seed: i))
        }
        // Next 10 as binary
        BASSQLiteEventLogStorage.useBinaryPayload = true
        for i in 10..<20 {
            _ = try await storage.append(makeEntry(seed: i))
        }
        BASSQLiteEventLogStorage.useBinaryPayload = false

        // Read all 20 back via standard API — should NOT
        // throw + should return all 20 entries with correct
        // fields。
        let replay = try await storage.events(
            sinceTimestampMs: 0, limit: 1000)
        XCTAssertEqual(replay.count, 20)
        for (i, entry) in replay.enumerated() {
            XCTAssertEqual(
                entry.timestampMs,
                Int64(1_700_000_000_000 + i),
                "timestamp ordering broken at \(i)")
        }
    }

    // MARK: - Per-append perf measurement

    func testPerfBinaryVsJSONAppend() async throws {
        let entriesPerRun = 200
        let entries = (0..<entriesPerRun)
            .map { makeEntry(seed: $0) }

        // JSON path
        BASSQLiteEventLogStorage.useBinaryPayload = false
        let urlA = makeTempURL(label: "perf_json")
        let storageA = try BASSQLiteEventLogStorage(
            databaseURL: urlA)
        // Warm up
        _ = try await storageA.append(entries[0])
        let jsonStart = CFAbsoluteTimeGetCurrent()
        for e in entries {
            _ = try await storageA.append(e)
        }
        let jsonElapsed = CFAbsoluteTimeGetCurrent()
            - jsonStart

        // Binary path
        BASSQLiteEventLogStorage.useBinaryPayload = true
        let urlB = makeTempURL(label: "perf_binary")
        let storageB = try BASSQLiteEventLogStorage(
            databaseURL: urlB)
        _ = try await storageB.append(entries[0])
        let binStart = CFAbsoluteTimeGetCurrent()
        for e in entries {
            _ = try await storageB.append(e)
        }
        let binElapsed = CFAbsoluteTimeGetCurrent()
            - binStart
        BASSQLiteEventLogStorage.useBinaryPayload = false

        let jsonUs =
            jsonElapsed / Double(entriesPerRun) * 1e6
        let binUs =
            binElapsed / Double(entriesPerRun) * 1e6
        let speedup = jsonElapsed / binElapsed

        // Storage footprint comparison via file size
        func fileSize(_ url: URL) -> Int {
            guard let attrs = try? FileManager.default
                .attributesOfItem(atPath: url.path)
            else { return 0 }
            return (attrs[.size] as? Int) ?? 0
        }
        let jsonBytes = fileSize(urlA)
        let binBytes  = fileSize(urlB)
        let storageRatio = Double(jsonBytes)
            / Double(max(binBytes, 1))

        print("")
        print(
            "## chapter 七百三十二 第四刀 — append perf + storage")
        print("")
        print(String(
            format: "  JSON path:   %.2f µs/append",
            jsonUs))
        print(String(
            format: "  Binary path: %.2f µs/append",
            binUs))
        print(String(
            format: "  Speedup:     %.2f×", speedup))
        print("")
        print(String(
            format: "  JSON DB file:   %d bytes", jsonBytes))
        print(String(
            format: "  Binary DB file: %d bytes", binBytes))
        print(String(
            format: "  Storage ratio:  %.2f×",
            storageRatio))
        print("")
        print(
            "  Plan-agent estimate: 1.5-2× speed + 30-50% storage")
        print(
            "  Honest decision rule:flip default if ≥ 1.5× on EITHER")
        print(
            "  axis (matches chapter 七百二十三 / 七百二十四 / 七百二十六")
        print(
            "  precedents)。")
        print("")

        // No strict gate — let the chapter close-out (knife 5)
        // decide based on actual measurement
    }
}
