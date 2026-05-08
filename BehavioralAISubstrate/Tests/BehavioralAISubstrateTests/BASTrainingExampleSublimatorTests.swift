// MARK: - BASTrainingExampleSublimatorTests — chapter 四百一 / M939

import XCTest
@testable import BASHostKit
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASTrainingExampleSublimatorTests:
    XCTestCase
{

    private func makeCandidate(
        input: String = "test input",
        score: Double = 0.5
    ) -> BASTrainingExampleCandidate {
        BASTrainingExampleCandidate(
            inputText: input,
            contextSummary: "ctx",
            goodAnswerTraits: ["a"],
            badAnswerTraits: ["b"],
            score: score)
    }

    private func makeSubmission(
        input: String = "test input",
        score: Double = 0.5,
        sessionID: String = "s-1"
    ) -> BASTrainingExampleSubmission {
        BASTrainingExampleSubmission(
            candidate: makeCandidate(
                input: input, score: score),
            sourceSessionID: sessionID)
    }

    // MARK: - Empty flush

    func testFlushEmptyReturnsEmpty() async {
        let sub = BASTrainingExampleSublimator()
        let result = await sub.flush(
            flushedAtMs: 1_000)
        XCTAssertEqual(result.rows.count, 0)
        XCTAssertEqual(result.trigger, .empty)
        XCTAssertEqual(result.report.rowCount, 0)
        XCTAssertEqual(result.report.meanScore, 0)
    }

    // MARK: - Single submission

    func testSingleSubmitBuffers() async {
        let sub = BASTrainingExampleSublimator(
            flushThreshold: 10)
        _ = await sub.submit(
            makeSubmission(),
            flushedAtMs: 1)
        let count = await sub.bufferCount
        XCTAssertEqual(count, 1)
    }

    func testThresholdReachedTriggersFlush() async {
        let sub = BASTrainingExampleSublimator(
            flushThreshold: 3)
        var fired: Bool = false
        for _ in 0..<3 {
            if let result = await sub.submit(
                makeSubmission(),
                flushedAtMs: 1)
            {
                XCTAssertEqual(result.trigger,
                    .thresholdReached)
                XCTAssertEqual(result.rows.count, 3)
                fired = true
            }
        }
        XCTAssertTrue(fired)
        let count = await sub.bufferCount
        XCTAssertEqual(count, 0,
            "Buffer cleared on flush")
    }

    // MARK: - Mean score

    func testMeanScoreCalculation() async {
        let sub = BASTrainingExampleSublimator()
        _ = await sub.submit(
            makeSubmission(score: 0.4),
            flushedAtMs: 1)
        _ = await sub.submit(
            makeSubmission(score: 0.6),
            flushedAtMs: 1)
        let result = await sub.flush(flushedAtMs: 2)
        XCTAssertEqual(result.report.rowCount, 2)
        XCTAssertEqual(
            result.report.meanScore,
            0.5,
            accuracy: 0.001)
    }

    // MARK: - Per-session histogram

    func testPerSessionRowCount() async {
        let sub = BASTrainingExampleSublimator()
        _ = await sub.submit(
            makeSubmission(sessionID: "A"),
            flushedAtMs: 1)
        _ = await sub.submit(
            makeSubmission(sessionID: "A"),
            flushedAtMs: 1)
        _ = await sub.submit(
            makeSubmission(sessionID: "B"),
            flushedAtMs: 1)
        let result = await sub.flush(flushedAtMs: 2)
        XCTAssertEqual(
            result.report.perSessionRowCount["A"], 2)
        XCTAssertEqual(
            result.report.perSessionRowCount["B"], 1)
    }

    // MARK: - Deterministic datum ID

    func testDeterministicDatumID() async {
        let sub1 = BASTrainingExampleSublimator()
        let sub2 = BASTrainingExampleSublimator()
        _ = await sub1.submit(
            makeSubmission(input: "same",
                score: 0.7,
                sessionID: "s-det"),
            flushedAtMs: 1)
        _ = await sub2.submit(
            makeSubmission(input: "same",
                score: 0.7,
                sessionID: "s-det"),
            flushedAtMs: 99)
        let r1 = await sub1.flush(flushedAtMs: 2)
        let r2 = await sub2.flush(flushedAtMs: 2)
        XCTAssertEqual(
            r1.rows.first?.datumID,
            r2.rows.first?.datumID,
            "Same (input, score, sessionID) → same datumID")
    }

    // MARK: - Batch submit

    func testBatchSubmitAllAppended() async {
        let sub = BASTrainingExampleSublimator(
            flushThreshold: 100)
        let batch = (0..<5).map {
            makeSubmission(
                input: "input-\($0)",
                score: Double($0) / 10.0)
        }
        _ = await sub.submit(
            batch: batch,
            flushedAtMs: 1)
        let count = await sub.bufferCount
        XCTAssertEqual(count, 5)
    }

    // MARK: - Telemetry

    func testTotalCounters() async {
        let sub = BASTrainingExampleSublimator(
            flushThreshold: 5)
        for _ in 0..<5 {
            _ = await sub.submit(
                makeSubmission(),
                flushedAtMs: 1)
        }
        // Threshold tripped → flush fired
        _ = await sub.submit(
            makeSubmission(),
            flushedAtMs: 1)
        let totalSub = await sub.totalSubmissions
        let totalFlush = await sub.totalFlushes
        let totalRows = await sub.totalRowsEmitted
        XCTAssertEqual(totalSub, 6)
        XCTAssertEqual(totalFlush, 1)
        XCTAssertEqual(totalRows, 5)
    }

    // MARK: - Codable round-trip

    func testReportRoundTrip() throws {
        let report = BASTrainingExampleSublimationReport(
            rowCount: 3,
            meanScore: 0.85,
            perSessionRowCount: ["a": 2, "b": 1],
            flushedAtMs: 1_700_000_000_000,
            flushSequenceNumber: 5)
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(
            BASTrainingExampleSublimationReport.self,
            from: data)
        XCTAssertEqual(decoded, report)
    }

    func testDatumRoundTrip() throws {
        let datum = BASMambaTrainingDatum(
            datumID: "d-1",
            inputText: "test",
            contextSummary: "ctx",
            goodAnswerTraits: ["good"],
            badAnswerTraits: ["bad"],
            score: 0.75,
            sublimatedAtMs: 1_000,
            sourceSessionID: "s-1")
        let data = try JSONEncoder().encode(datum)
        let decoded = try JSONDecoder().decode(
            BASMambaTrainingDatum.self, from: data)
        XCTAssertEqual(decoded, datum)
    }
}
