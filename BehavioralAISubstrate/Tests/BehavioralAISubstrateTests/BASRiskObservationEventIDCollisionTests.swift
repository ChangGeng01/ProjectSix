import XCTest
@testable import BASPolicy

/// audit policy-obs-misc MED-2 — two risk observations minted in the SAME millisecond with the
/// same (intent, kind) used to derive the SAME event_id, so the storage INSERT's
/// `ON CONFLICT(event_id) DO NOTHING` silently DROPPED the second (a lost risk observation).
/// The event_id now carries the observation's ordinal within its bundle, so both survive.
final class BASRiskObservationEventIDCollisionTests: XCTestCase {

    private func makeTempDBURL(function: String = #function) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(function)-\(UUID().uuidString).sqlite")
    }

    private func obs(_ content: String) -> BASRiskObservation {
        // Identical (intent, kind, observedAt-ms) — only the content differs.
        BASRiskObservation(
            kind: .hazardReading, intentID: "i-dup", salience: 0.7, confidence: 0.6,
            content: content,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000_000.0 / 1000.0))
    }

    private func bundle() -> BASRiskObservationBundle {
        BASRiskObservationBundle(
            turnID: "turn-1", sessionID: "sess-A",
            observations: [obs("first"), obs("second")],
            emittedAt: Date(timeIntervalSince1970: 1_700_000_000_000.0 / 1000.0))
    }

    func testSameMillisecondObservationsGetDistinctEventIDs() {
        let records = BASRiskObservationLedger.observationsToRecords(bundle: bundle())
        XCTAssertEqual(records.count, 2)
        XCTAssertNotEqual(records[0].eventID, records[1].eventID,
            "two same-ms/same-intent/same-kind observations must NOT collide on event_id")
    }

    func testBothObservationsSurvivePersistence() throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let storage = try BASRiskObservationsSQLiteStorage(databaseURL: url)
        for rec in BASRiskObservationLedger.observationsToRecords(bundle: bundle()) {
            try storage.persistObservation(rec)
        }
        let loaded = try storage.loadObservations(sessionID: "sess-A")
        XCTAssertEqual(loaded.count, 2,
            "both same-ms observations must survive — ON CONFLICT no longer swallows the second")
    }
}
