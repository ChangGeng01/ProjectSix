// MARK: - BASTrainingDataExporterTests — chapter 三百九九 / M903
//
// Test coverage for the typed training-data export primitive
// that walks event log + optional state store and writes JSONL
// for offline ML training pipelines。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

final class BASTrainingDataExporterTests: XCTestCase {

    // MARK: - Fixtures

    private func makeEvent(
        index: Int,
        sessionID: String = "test-session",
        kind: BASEventLogKind = .substrateAudit,
        riskBand: BASEventLogRiskBand = .low,
        timestampMs: Int64? = nil
    ) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: "ev-\(index)-\(UUID().uuidString)",
            timestampMs: timestampMs ??
                Int64(1_700_000_000_000 + index),
            kind: kind,
            sessionID: sessionID,
            sequenceNumber: 0,
            riskBand: riskBand,
            actions: ["action-\(index)"])
    }

    private func makeTempURL() -> URL {
        let dir = URL(
            fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("M903-\(UUID().uuidString)",
                                    isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("export.jsonl")
    }

    // MARK: - Empty corpus

    func testEmptyEventLogProducesEmptyFile() async throws {
        let log = BASInMemoryEventLogStorage()
        let exp = BASTrainingDataExporter(eventLog: log)

        let url = makeTempURL()
        let summary = try await exp.exportToJSONL(
            filter: .all, to: url)

        XCTAssertEqual(summary.recordsWritten, 0)
        XCTAssertEqual(summary.bytesWritten, 0)
        XCTAssertNil(summary.firstEventTimestampMs)
        XCTAssertNil(summary.lastEventTimestampMs)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: url.path))
    }

    // MARK: - Round-trip

    func testRoundTripSingleEvent() async throws {
        let log = BASInMemoryEventLogStorage()
        let event = makeEvent(index: 1)
        _ = try await log.append(event)

        let exp = BASTrainingDataExporter(eventLog: log)
        let url = makeTempURL()
        let summary = try await exp.exportToJSONL(
            filter: .all, to: url)

        XCTAssertEqual(summary.recordsWritten, 1)
        XCTAssertGreaterThan(summary.bytesWritten, 0)

        // Read back + parse
        let raw = try Data(contentsOf: url)
        let lines = String(data: raw, encoding: .utf8)!
            .split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 1)

        let decoder = JSONDecoder()
        let lineData = lines[0].data(using: .utf8)!
        let datum = try decoder.decode(
            BASTrainingDatum.self, from: lineData)
        XCTAssertEqual(datum.event.eventID, event.eventID)
    }

    func testRoundTripManyEvents() async throws {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<150 {
            _ = try await log.append(makeEvent(index: i))
        }

        let exp = BASTrainingDataExporter(
            eventLog: log, pageSize: 50)
        let url = makeTempURL()
        let summary = try await exp.exportToJSONL(
            filter: .all, to: url)

        XCTAssertEqual(summary.recordsWritten, 150,
            "Multi-page export must emit every event exactly once")

        // Verify line count matches summary
        let raw = try Data(contentsOf: url)
        let lines = String(data: raw, encoding: .utf8)!
            .split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 150)
    }

    // MARK: - Filter — session

    func testFilterBySessionID() async throws {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<10 {
            _ = try await log.append(
                makeEvent(index: i, sessionID: "alice"))
        }
        for i in 100..<120 {
            _ = try await log.append(
                makeEvent(index: i, sessionID: "bob"))
        }

        let exp = BASTrainingDataExporter(eventLog: log)
        let url = makeTempURL()
        let summary = try await exp.exportToJSONL(
            filter: BASTrainingDataExportFilter(
                sessionID: "alice"),
            to: url)

        XCTAssertEqual(summary.recordsWritten, 10,
            "Only Alice's 10 events should write")
        XCTAssertEqual(summary.recordsFilteredOut, 20,
            "Bob's 20 events filtered out")
    }

    // MARK: - Filter — kind

    func testFilterByKind() async throws {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<5 {
            _ = try await log.append(
                makeEvent(index: i, kind: .substrateAudit))
        }
        for i in 100..<108 {
            _ = try await log.append(
                makeEvent(index: i, kind: .internalSignal))
        }

        let exp = BASTrainingDataExporter(eventLog: log)
        let url = makeTempURL()
        let summary = try await exp.exportToJSONL(
            filter: BASTrainingDataExportFilter(
                kinds: [.internalSignal]),
            to: url)

        XCTAssertEqual(summary.recordsWritten, 8)
        XCTAssertEqual(summary.recordsFilteredOut, 5)
    }

    // MARK: - Filter — risk band

    func testFilterByRiskBand() async throws {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<3 {
            _ = try await log.append(
                makeEvent(index: i, riskBand: .low))
        }
        for i in 100..<105 {
            _ = try await log.append(
                makeEvent(index: i, riskBand: .high))
        }

        let exp = BASTrainingDataExporter(eventLog: log)
        let url = makeTempURL()
        let summary = try await exp.exportToJSONL(
            filter: BASTrainingDataExportFilter(
                riskBands: [.high]),
            to: url)

        XCTAssertEqual(summary.recordsWritten, 5)
        XCTAssertEqual(summary.recordsFilteredOut, 3)
    }

    // MARK: - Filter — time bounds

    func testFilterBySinceTimestamp() async throws {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<10 {
            _ = try await log.append(makeEvent(
                index: i,
                timestampMs: Int64(1_000 + i * 1_000)))
        }

        let exp = BASTrainingDataExporter(eventLog: log)
        let url = makeTempURL()
        let summary = try await exp.exportToJSONL(
            filter: BASTrainingDataExportFilter(
                sinceMs: 5_000),
            to: url)

        // Events at ts 5_000, 6_000, ..., 10_000 → 6 events
        XCTAssertEqual(summary.recordsWritten, 6)
    }

    func testFilterByUntilTimestamp() async throws {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<10 {
            _ = try await log.append(makeEvent(
                index: i,
                timestampMs: Int64(1_000 + i * 1_000)))
        }

        let exp = BASTrainingDataExporter(eventLog: log)
        let url = makeTempURL()
        let summary = try await exp.exportToJSONL(
            filter: BASTrainingDataExportFilter(
                untilMs: 5_000),
            to: url)

        // Events at ts 1_000..4_000 → 4 events (5_000 is exclusive)
        XCTAssertEqual(summary.recordsWritten, 4)
    }

    // MARK: - Filter — limit

    func testFilterRespectsLimitCap() async throws {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<100 {
            _ = try await log.append(makeEvent(index: i))
        }

        let exp = BASTrainingDataExporter(eventLog: log)
        let url = makeTempURL()
        let summary = try await exp.exportToJSONL(
            filter: BASTrainingDataExportFilter(limit: 25),
            to: url)

        XCTAssertEqual(summary.recordsWritten, 25,
            "Limit must cap output at 25 even though log " +
            "has 100 events")
    }

    // MARK: - State context

    func testStateContextRequestedRequiresStore() async {
        let log = BASInMemoryEventLogStorage()
        let exp = BASTrainingDataExporter(eventLog: log)

        let url = makeTempURL()
        do {
            _ = try await exp.exportToJSONL(
                filter: BASTrainingDataExportFilter(
                    includeStateContext: true),
                to: url)
            XCTFail("Must throw when state context requested " +
                "but no store wired")
        } catch BASTrainingDataExportError
            .stateContextRequestedButNoStore
        {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    // MARK: - Atomic file rename

    func testAtomicTempFilePatternLeavesNoStaleFile()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(index: 1))

        let exp = BASTrainingDataExporter(eventLog: log)
        let url = makeTempURL()
        _ = try await exp.exportToJSONL(
            filter: .all, to: url)

        let tempURL = url.appendingPathExtension("tmp")
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: tempURL.path),
            "Temp file must be renamed to final URL,not " +
            "left orphaned")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "Final file must exist after successful export")
    }

    // MARK: - JSONL formatting

    func testEachLineIsValidJSON() async throws {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<5 {
            _ = try await log.append(makeEvent(index: i))
        }

        let exp = BASTrainingDataExporter(eventLog: log)
        let url = makeTempURL()
        _ = try await exp.exportToJSONL(filter: .all, to: url)

        let raw = try Data(contentsOf: url)
        let text = String(data: raw, encoding: .utf8)!
        let lines = text.split(separator: "\n",
            omittingEmptySubsequences: true)

        let decoder = JSONDecoder()
        for line in lines {
            let lineData = line.data(using: .utf8)!
            let datum = try decoder.decode(
                BASTrainingDatum.self, from: lineData)
            XCTAssertFalse(datum.event.eventID.isEmpty)
        }
    }

    // MARK: - Summary correctness

    func testSummaryFirstAndLastTimestampsCorrect()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<5 {
            _ = try await log.append(makeEvent(
                index: i,
                timestampMs: Int64(10_000 + i * 1_000)))
        }

        let exp = BASTrainingDataExporter(eventLog: log)
        let url = makeTempURL()
        let summary = try await exp.exportToJSONL(
            filter: .all, to: url)

        XCTAssertEqual(summary.firstEventTimestampMs, 10_000)
        XCTAssertEqual(summary.lastEventTimestampMs, 14_000)
    }

    // MARK: - Combined filters

    func testCombinedFiltersAreANDed() async throws {
        let log = BASInMemoryEventLogStorage()
        // Alice low / Alice high / Bob low / Bob high
        _ = try await log.append(makeEvent(index: 0,
            sessionID: "alice", riskBand: .low,
            timestampMs: 1_000))
        _ = try await log.append(makeEvent(index: 1,
            sessionID: "alice", riskBand: .high,
            timestampMs: 2_000))
        _ = try await log.append(makeEvent(index: 2,
            sessionID: "bob", riskBand: .low,
            timestampMs: 3_000))
        _ = try await log.append(makeEvent(index: 3,
            sessionID: "bob", riskBand: .high,
            timestampMs: 4_000))

        let exp = BASTrainingDataExporter(eventLog: log)
        let url = makeTempURL()
        let summary = try await exp.exportToJSONL(
            filter: BASTrainingDataExportFilter(
                sessionID: "alice",
                riskBands: [.high]),
            to: url)

        XCTAssertEqual(summary.recordsWritten, 1,
            "Only Alice high event matches both filters")
    }
}
