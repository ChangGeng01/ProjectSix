import XCTest
@testable import QinaoLoop

/// M572 (chapter 一百四十七) — pin QinaoLongRunningSmoke
/// helper functions + value-type Codable round-trip.
final class LongRunningSmokeTests: XCTestCase {

    // MARK: - 1. iso8601 helper produces parseable string

    func testISO8601RoundTrip() {
        let date = Date(timeIntervalSince1970: 1714824000) // arbitrary
        let s = QinaoLongRunningSmokeHelpers.iso8601(date)
        XCTAssertTrue(s.contains("T"))
        XCTAssertTrue(s.hasSuffix("Z"))
        XCTAssertTrue(s.contains("."))
    }

    // MARK: - 2. median helper happy path

    func testMedianOddCount() {
        XCTAssertEqual(
            QinaoLongRunningSmokeHelpers.median([1, 2, 3, 4, 5]), 3)
    }

    func testMedianEvenCount() {
        XCTAssertEqual(
            QinaoLongRunningSmokeHelpers.median(
                [1.0, 2.0, 3.0, 4.0]), 2.5)
    }

    func testMedianEmpty() {
        XCTAssertEqual(
            QinaoLongRunningSmokeHelpers.median([]), 0)
    }

    // MARK: - 3. average helper

    func testAverageHappyPath() {
        XCTAssertEqual(
            QinaoLongRunningSmokeHelpers.average(
                [1.0, 2.0, 3.0]), 2.0)
    }

    func testAverageEmpty() {
        XCTAssertEqual(
            QinaoLongRunningSmokeHelpers.average([]), 0)
    }

    // MARK: - 4. jsonLine round-trip

    func testJSONLineRoundTrip() throws {
        let row = QinaoLongRunningSmokeRow(
            timestamp: "2026-05-04T12:00:00.000Z",
            iteration: 42,
            persona: "anxious",
            scenario: "irreversibleStep",
            prompt: "Should I quit?",
            endpoint: "afm",
            responseLength: 100,
            responseRedLineCount: 0,
            durationSeconds: 1.234,
            status: "ok",
            errorMessage: nil,
            userValueScore: 75)
        let line = try QinaoLongRunningSmokeHelpers.jsonLine(row)
        // Round-trip
        let data = line.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(
            QinaoLongRunningSmokeRow.self, from: data)
        XCTAssertEqual(decoded, row)
        // Sorted keys: timestamp comes after iteration
        XCTAssertTrue(line.contains("\"iteration\":42"))
        XCTAssertTrue(line.contains("\"persona\":\"anxious\""))
    }

    // MARK: - 5. progress snapshot

    func testMakeProgressSnapshot() {
        let start = Date(timeIntervalSince1970: 1000)
        let now = Date(timeIntervalSince1970: 1300) // +300s
        let progress = QinaoLongRunningSmokeHelpers.makeProgress(
            runStart: start,
            now: now,
            iterations: 50,
            afmCompleted: 50,
            openModelCompleted: 49,
            afmTimeouts: 1,
            openModelTimeouts: 0,
            afmErrors: 0,
            openModelErrors: 1,
            afmRedLineTotal: 12,
            openModelRedLineTotal: 8)
        XCTAssertEqual(progress.iterationsCompleted, 50)
        XCTAssertEqual(progress.afmCallsCompleted, 50)
        XCTAssertEqual(progress.elapsedSeconds, 300, accuracy: 1)
    }

    // MARK: - 6. per-persona aggregation

    func testAggregatePerPersonaCounts() {
        let rows = [
            (persona: "anxious", count: 1),
            (persona: "anxious", count: 1),
            (persona: "agentic", count: 1),
            (persona: "vulnerable", count: 2)
        ]
        let result = QinaoLongRunningSmokeHelpers
            .aggregatePerPersonaCounts(rows: rows)
        XCTAssertEqual(result["anxious"], 2)
        XCTAssertEqual(result["agentic"], 1)
        XCTAssertEqual(result["vulnerable"], 2)
        XCTAssertEqual(result.count, 3)
    }

    // MARK: - 7. summary round-trip

    func testSummaryRoundTrip() throws {
        let summary = QinaoLongRunningSmokeSummary(
            runStartTimestamp: "2026-05-04T08:00:00.000Z",
            runEndTimestamp: "2026-05-04T16:00:00.000Z",
            totalElapsedSeconds: 28800,
            totalIterations: 1000,
            afmCallsCompleted: 1000,
            openModelCallsCompleted: 980,
            afmTimeouts: 5,
            openModelTimeouts: 15,
            afmErrors: 2,
            openModelErrors: 5,
            totalRedLineViolationsAFM: 100,
            totalRedLineViolationsOpenModel: 50,
            avgAFMDurationSeconds: 1.5,
            avgOpenModelDurationSeconds: 2.0,
            medianAFMDurationSeconds: 1.4,
            medianOpenModelDurationSeconds: 1.9,
            perPersonaCounts: ["anxious": 200])
        let line = try QinaoLongRunningSmokeHelpers.jsonLine(summary)
        let data = line.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(
            QinaoLongRunningSmokeSummary.self, from: data)
        XCTAssertEqual(decoded.totalIterations, 1000)
        XCTAssertEqual(decoded.totalElapsedSeconds, 28800)
        XCTAssertEqual(decoded.perPersonaCounts["anxious"], 200)
    }

    // MARK: - 8. Configuration default 8h

    func testConfigurationDefaultDuration() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let config = QinaoLongRunningSmokeConfiguration(
            outputDirectory: url)
        XCTAssertEqual(config.maxDurationSeconds, 8 * 3600)
        XCTAssertTrue(config.runAFM)
        XCTAssertTrue(config.runOpenModel)
        XCTAssertFalse(config.runUserValueJudge)
        XCTAssertEqual(config.checkpointIntervalSeconds, 60)
    }

    // MARK: - 9. Writer ensures directory + appends row

    func testWriterAppendsRow() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "long-smoke-test-\(UUID().uuidString)")
        let writer = QinaoLongRunningSmokeWriter(
            outputDirectory: tmpDir)
        let row = QinaoLongRunningSmokeRow(
            timestamp: "2026-05-04T12:00:00.000Z",
            iteration: 1,
            persona: "anxious",
            scenario: "irreversibleStep",
            prompt: "test",
            endpoint: "afm",
            responseLength: 50,
            responseRedLineCount: 0,
            durationSeconds: 1.0,
            status: "ok",
            errorMessage: nil,
            userValueScore: nil)
        try await writer.appendRow(row)
        try await writer.appendRow(row)
        try await writer.flush()
        try await writer.close()

        // Verify content
        let url = tmpDir
            .appendingPathComponent("iterations.jsonl")
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content
            .split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 2)

        // Cleanup
        try? FileManager.default.removeItem(at: tmpDir)
    }

    // MARK: - 10. Writer writes progress atomically

    func testWriterProgressAtomic() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "long-smoke-progress-\(UUID().uuidString)")
        let writer = QinaoLongRunningSmokeWriter(
            outputDirectory: tmpDir)
        let progress = QinaoLongRunningSmokeProgress(
            runStartTimestamp: "2026-05-04T08:00:00.000Z",
            lastCheckpointTimestamp: "2026-05-04T08:01:00.000Z",
            elapsedSeconds: 60,
            iterationsCompleted: 5,
            afmCallsCompleted: 5,
            openModelCallsCompleted: 5,
            afmTimeouts: 0,
            openModelTimeouts: 0,
            afmErrors: 0,
            openModelErrors: 0,
            totalRedLineViolationsAFM: 0,
            totalRedLineViolationsOpenModel: 0)
        try await writer.writeProgress(progress)

        let url = tmpDir.appendingPathComponent("progress.json")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path))
        let tmpURL = tmpDir
            .appendingPathComponent("progress.json.tmp")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: tmpURL.path),
            "tmp file should be moved away after atomic write")

        // Cleanup
        try? FileManager.default.removeItem(at: tmpDir)
    }
}
