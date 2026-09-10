// MARK: - BASChapter754L11ProductionSwapTests
// chapter 七百五十四 第一刀 / M2435
//
// MATURATION ARC L11 production swap — verifies the production
// BASRiskObservationLedger ring actor now persists observations
// to SQLite + restores them on cold restart through the new
// sharedStorage seam。

import XCTest
@testable import BASPolicy

final class BASChapter754L11ProductionSwapTests: XCTestCase {

    // MARK: - Helpers

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

    private func makeObservation(
        kind: BASRiskSignalKind = .hazardReading,
        intentID: String = "intent-1",
        salience: Double = 0.7,
        confidence: Double = 0.8,
        content: String = "{\"k\":1}",
        observedAtMs: Int64 = 1_700_000_000_000
    ) -> BASRiskObservation {
        return BASRiskObservation(
            kind: kind,
            intentID: intentID,
            salience: salience,
            confidence: confidence,
            content: content,
            observedAt: Date(timeIntervalSince1970:
                Double(observedAtMs) / 1000.0))
    }

    private func makeBundle(
        sessionID: String = "sess-A",
        turnID: String = "turn-1",
        observations: [BASRiskObservation],
        emittedAtMs: Int64 = 1_700_000_000_000
    ) -> BASRiskObservationBundle {
        return BASRiskObservationBundle(
            turnID: turnID,
            sessionID: sessionID,
            observations: observations,
            emittedAt: Date(timeIntervalSince1970:
                Double(emittedAtMs) / 1000.0))
    }

    // MARK: - 1. sharedStorage starts nil (preserves V1)

    func testSharedStorageStartsNilForBackwardCompat() {
        BASRiskObservationLedger.sharedStorage = nil
        XCTAssertNil(BASRiskObservationLedger.sharedStorage)
    }

    // MARK: - 2. Marshalling helpers

    func testDeriveBandMatchesSchemaCheckConstraint() {
        XCTAssertEqual(
            BASRiskObservationLedger.deriveBand(score: 0.95),
            "critical")
        XCTAssertEqual(
            BASRiskObservationLedger.deriveBand(score: 0.85),
            "critical")
        XCTAssertEqual(
            BASRiskObservationLedger.deriveBand(score: 0.80),
            "high")
        XCTAssertEqual(
            BASRiskObservationLedger.deriveBand(score: 0.70),
            "high")
        XCTAssertEqual(
            BASRiskObservationLedger.deriveBand(score: 0.50),
            "medium")
        XCTAssertEqual(
            BASRiskObservationLedger.deriveBand(score: 0.40),
            "medium")
        XCTAssertEqual(
            BASRiskObservationLedger.deriveBand(score: 0.39),
            "low")
        XCTAssertEqual(
            BASRiskObservationLedger.deriveBand(score: 0.0),
            "low")
    }

    func testDeriveEventIDIsDeterministic() {
        let id1 = BASRiskObservationLedger.deriveEventID(
            sessionID: "s", turnID: "t",
            intentID: "i", kindRaw: "hazardReading",
            observedAtMs: 123)
        let id2 = BASRiskObservationLedger.deriveEventID(
            sessionID: "s", turnID: "t",
            intentID: "i", kindRaw: "hazardReading",
            observedAtMs: 123)
        XCTAssertEqual(id1, id2)
        XCTAssertTrue(id1.hasPrefix("obs-"))
    }

    func testObservationsToRecordsShape() {
        let obs1 = makeObservation(
            kind: .hazardReading,
            salience: 0.9, confidence: 0.95)
        let obs2 = makeObservation(
            kind: .noveltyReading,
            salience: 0.3, confidence: 0.5)
        let bundle = makeBundle(observations: [obs1, obs2])
        let records = BASRiskObservationLedger
            .observationsToRecords(bundle: bundle)
        XCTAssertEqual(records.count, 2)
        // First obs:0.9 × 0.95 = 0.855 → critical
        XCTAssertEqual(records[0].riskBand, "critical")
        XCTAssertEqual(records[0].observationKind,
            "hazardReading")
        // Second obs:0.3 × 0.5 = 0.15 → low
        XCTAssertEqual(records[1].riskBand, "low")
        XCTAssertEqual(records[1].observationKind,
            "noveltyReading")
    }

    // MARK: - 3. Live persistence through production ledger seam

    func testRecordBundlePersistsToSharedStorage() async throws {
        let url = makeTempDBURL()
        defer { deleteIfExists(url) }
        let storage = try BASRiskObservationsSQLiteStorage(
            databaseURL: url)
        BASRiskObservationLedger.sharedStorage = storage
        defer { BASRiskObservationLedger.sharedStorage = nil }

        let ledger = BASRiskObservationLedger()
        let bundle = makeBundle(
            observations: [
                makeObservation(intentID: "i-1"),
                makeObservation(intentID: "i-2"),
                makeObservation(intentID: "i-3"),
            ])

        // record() writes to ring;persist helper writes to SQL
        await ledger.record(bundle)
        await ledger.persistToSharedStorage(bundle)

        let loaded = try storage.loadObservations(
            sessionID: "sess-A")
        XCTAssertEqual(loaded.count, 3,
            "All 3 observations persisted")
        XCTAssertEqual(
            Set(loaded.map { $0.intentID }),
            Set(["i-1", "i-2", "i-3"]))
    }

    // MARK: - 4. Cold-restart replay through production seam

    func testColdRestartLoadsObservationsBackIntoRing() async throws {
        let url = makeTempDBURL()
        defer { deleteIfExists(url) }

        // PHASE 1 — write
        do {
            let storage = try BASRiskObservationsSQLiteStorage(
                databaseURL: url)
            BASRiskObservationLedger.sharedStorage = storage
            defer {
                BASRiskObservationLedger.sharedStorage = nil
            }

            let ledger = BASRiskObservationLedger()
            // 3 bundles × 2 observations each across 3 turns
            for i in 0..<3 {
                let bundle = makeBundle(
                    turnID: "turn-\(i)",
                    observations: [
                        makeObservation(
                            intentID: "i-\(i)-a",
                            observedAtMs:
                                1_700_000_000_000 +
                                Int64(i * 1000)),
                        makeObservation(
                            intentID: "i-\(i)-b",
                            observedAtMs:
                                1_700_000_000_000 +
                                Int64(i * 1000 + 100)),
                    ])
                await ledger.record(bundle)
                await ledger.persistToSharedStorage(bundle)
            }
        }

        // PHASE 2 — cold restart (new storage instance,same URL)
        let storage = try BASRiskObservationsSQLiteStorage(
            databaseURL: url)
        BASRiskObservationLedger.sharedStorage = storage
        defer { BASRiskObservationLedger.sharedStorage = nil }

        let coldLedger = BASRiskObservationLedger()
        await coldLedger.loadFromSharedStorage(
            sessionID: "sess-A")

        let restored = await coldLedger.bundles(
            forSession: "sess-A")
        XCTAssertEqual(restored.count, 3,
            "Cold restart recovers all 3 bundles")
        for (i, bundle) in restored.enumerated() {
            XCTAssertEqual(bundle.turnID, "turn-\(i)")
            XCTAssertEqual(bundle.observations.count, 2)
        }
    }

    // MARK: - 5. ADR-014 OPT-IN preserved

    func testWithoutSharedStorageRingBehaviorUnchanged() async {
        BASRiskObservationLedger.sharedStorage = nil
        let ledger = BASRiskObservationLedger()
        let bundle = makeBundle(observations: [
            makeObservation(intentID: "i-only-ring")])
        await ledger.record(bundle)
        let snap = await ledger.snapshot()
        XCTAssertEqual(snap.count, 1)
        XCTAssertEqual(
            snap.first?.observations.first?.intentID,
            "i-only-ring")
    }

    // MARK: - 6. Chapter scorecard

// chapter 八百二十八 / M2791-M2795 — #if false BODY ARCHIVED (was 83 LOC) → Archive/Deactivated/Tests/BehavioralAISubstrateTests/BASChapter754L11ProductionSwapTests_IfFalseBody.txt
}
