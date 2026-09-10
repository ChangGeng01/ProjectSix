// MARK: - BASChapter751RiskObservationsReplayTests
// chapter 七百五十一 第三刀 / M2428
//
// MATURATION ARC SQL persistence go-live — verifies that
// `BASRiskObservationsSQLiteStorage` actually persists risk
// observations across process boundaries。 User directive
// 2026-05-20「SQL 不要只做 schema,继续接入真实持久化和 replay」。
//
// ## Coverage
//
// 1. Schema applies cleanly on first open
// 2. Persist + load round-trip byte-equal for a single observation
// 3. 20-observation write + cold-restart + load returns identical
//    rows in identical order
// 4. ON CONFLICT idempotency:re-inserting same event_id keeps
//    first row (deterministic for replay)
// 5. Indexed COUNT(band, time-range) query works (chapter 七百三十八
//    preamble's stated query)
// 6. Cross-session isolation:session A observations don't
//    bleed into session B reads

import XCTest
@testable import BASPolicy

final class BASChapter751RiskObservationsReplayTests: XCTestCase {

    // MARK: - Helpers

    /// Returns a unique temp file URL for an isolated test DB。
    private func makeTempDBURL(
        function: String = #function
    ) -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
        let unique = "\(function)-\(UUID().uuidString).sqlite"
        return tmpDir.appendingPathComponent(unique)
    }

    private func deleteIfExists(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func makeRecord(
        eventID: String,
        sessionID: String = "sess-A",
        turnID: String = "turn-1",
        intentID: String = "intent-1",
        observedAtMs: Int64 = 1_700_000_000_000,
        riskBand: String = "medium",
        riskScore: Double = 0.55,
        observationKind: String = "hazardReading",
        salience: Double = 0.7,
        confidence: Double = 0.6,
        payloadJSON: String? = "{\"k\":1}"
    ) -> BASRiskObservationRecord {
        return BASRiskObservationRecord(
            eventID: eventID,
            sessionID: sessionID,
            turnID: turnID,
            intentID: intentID,
            observedAtMs: observedAtMs,
            riskBand: riskBand,
            riskScore: riskScore,
            observationKind: observationKind,
            salience: salience,
            confidence: confidence,
            payloadJSON: payloadJSON)
    }

    // MARK: - 1. Schema applies cleanly

    func testSchemaAppliesOnFirstOpen() throws {
        let url = makeTempDBURL()
        defer { deleteIfExists(url) }

        let storage = try BASRiskObservationsSQLiteStorage(
            databaseURL: url)
        // If schema applied,subsequent open re-runs the
        // CREATE IF NOT EXISTS and does not throw
        _ = storage
        let storage2 = try BASRiskObservationsSQLiteStorage(
            databaseURL: url)
        _ = storage2
    }

    // MARK: - 2. Single observation round-trip

    func testSingleObservationRoundTrip() throws {
        let url = makeTempDBURL()
        defer { deleteIfExists(url) }

        let storage = try BASRiskObservationsSQLiteStorage(
            databaseURL: url)
        let rec = makeRecord(eventID: "evt-1")
        try storage.persistObservation(rec)

        let loaded = try storage.loadObservations(
            sessionID: "sess-A")
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0], rec)
    }

    // MARK: - 3. 20-observation cold-restart replay

    func testColdRestartReplayPreservesAllObservations() throws {
        let url = makeTempDBURL()
        defer { deleteIfExists(url) }

        // Write phase — open,write 20 observations,implicit close
        // when storage1 is released at function end of inner scope
        let written: [BASRiskObservationRecord] = (0..<20).map {
            i in
            makeRecord(
                eventID: "evt-\(i)",
                observedAtMs: 1_700_000_000_000 + Int64(i),
                riskBand: ["low", "medium", "high",
                           "critical"][i % 4],
                observationKind: [
                    "hazardReading",
                    "irreversibilityReading",
                    "harmPotentialReading",
                    "consequenceHorizonReading",
                    "noveltyReading",
                    "gatePressure"][i % 6])
        }

        do {
            let storage = try BASRiskObservationsSQLiteStorage(
                databaseURL: url)
            for rec in written {
                try storage.persistObservation(rec)
            }
            // storage released here — db closes
        }

        // Cold-restart phase — new storage instance,same URL
        let coldStorage = try BASRiskObservationsSQLiteStorage(
            databaseURL: url)
        let loaded = try coldStorage.loadObservations(
            sessionID: "sess-A")

        XCTAssertEqual(loaded.count, written.count,
            "All 20 observations survived process restart")

        // Ordering by observed_at_ms is the SQL contract
        let writtenSorted = written.sorted(by: {
            ($0.observedAtMs, $0.eventID) <
            ($1.observedAtMs, $1.eventID)
        })
        for (loadedRow, writtenRow) in zip(
            loaded, writtenSorted)
        {
            XCTAssertEqual(loadedRow, writtenRow)
        }
    }

    // MARK: - 4. ON CONFLICT idempotency

    func testReinsertSameEventIdKeepsFirstRow() throws {
        let url = makeTempDBURL()
        defer { deleteIfExists(url) }

        let storage = try BASRiskObservationsSQLiteStorage(
            databaseURL: url)
        let first = makeRecord(
            eventID: "evt-dup",
            riskScore: 0.10,
            salience: 0.10)
        let second = makeRecord(
            eventID: "evt-dup",
            riskScore: 0.99,
            salience: 0.99)
        try storage.persistObservation(first)
        try storage.persistObservation(second)

        let loaded = try storage.loadObservations(
            sessionID: "sess-A")
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].riskScore, 0.10,
            "ON CONFLICT(event_id) DO NOTHING keeps first " +
            "row — deterministic for replay")
    }

    // MARK: - 5. Indexed COUNT(band, time-range) query

    func testCountByBandAndTimeRange() throws {
        let url = makeTempDBURL()
        defer { deleteIfExists(url) }

        let storage = try BASRiskObservationsSQLiteStorage(
            databaseURL: url)
        // 5 high-band observations within last 24h,3 outside
        let baseMs: Int64 = 1_700_000_000_000
        for i in 0..<5 {
            try storage.persistObservation(
                makeRecord(
                    eventID: "high-\(i)",
                    observedAtMs: baseMs + Int64(i * 1000),
                    riskBand: "high"))
        }
        // Older high-band (outside window)
        for i in 0..<3 {
            try storage.persistObservation(
                makeRecord(
                    eventID: "old-high-\(i)",
                    observedAtMs: baseMs - 86_400_000 - Int64(i),
                    riskBand: "high"))
        }
        // Other-band noise within window
        for i in 0..<4 {
            try storage.persistObservation(
                makeRecord(
                    eventID: "med-\(i)",
                    observedAtMs: baseMs + Int64(i * 1000),
                    riskBand: "medium"))
        }

        let highIn24h = try storage.countObservations(
            band: "high",
            sinceMs: baseMs - 86_400_000 + 1)
        XCTAssertEqual(highIn24h, 5,
            "5 high-band within 24h (3 older + 4 medium excluded)")
    }

    // MARK: - 6. Cross-session isolation

    func testCrossSessionIsolation() throws {
        let url = makeTempDBURL()
        defer { deleteIfExists(url) }

        let storage = try BASRiskObservationsSQLiteStorage(
            databaseURL: url)
        try storage.persistObservation(
            makeRecord(eventID: "A-1", sessionID: "sess-A"))
        try storage.persistObservation(
            makeRecord(eventID: "A-2", sessionID: "sess-A"))
        try storage.persistObservation(
            makeRecord(eventID: "B-1", sessionID: "sess-B"))

        let sessA = try storage.loadObservations(
            sessionID: "sess-A")
        let sessB = try storage.loadObservations(
            sessionID: "sess-B")

        XCTAssertEqual(sessA.count, 2)
        XCTAssertEqual(sessB.count, 1)
        XCTAssertEqual(sessB[0].eventID, "B-1")
    }

    // MARK: - 7. Scorecard print

// chapter 八百二十八 / M2791-M2795 — #if false BODY ARCHIVED (was 52 LOC) → Archive/Deactivated/Tests/BehavioralAISubstrateTests/BASChapter751RiskObservationsReplayTests_IfFalseBody.txt
}
