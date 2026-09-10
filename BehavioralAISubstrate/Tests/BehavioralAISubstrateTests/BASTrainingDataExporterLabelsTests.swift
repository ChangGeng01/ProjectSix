// MARK: - BASTrainingDataExporterLabelsTests — chapter 四百 / M925

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

final class BASTrainingDataExporterLabelsTests: XCTestCase {

    private func makeTempURL() -> URL {
        let dir = URL(
            fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("M925-\(UUID().uuidString)",
                                    isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("labels.jsonl")
    }

    private func makeEvent(
        index: Int,
        sessionID: String = "test"
    ) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: "ev-\(index)",
            timestampMs: Int64(1_700_000_000_000 + index),
            kind: .substrateAudit,
            sessionID: sessionID,
            sequenceNumber: 0,
            actions: ["test"])
    }

    /// Test enricher that always returns the same labels。
    private struct ConstantLabelEnricher:
        BASTrainingLabelEnricher
    {
        let labels: BASTrainingLabels

        func labels(
            for event: BASEventLogEntry,
            priorEventsInSession: [BASEventLogEntry]
        ) async -> BASTrainingLabels? {
            self.labels
        }
    }

    /// Test enricher that returns labels based on event count
    /// in the session (verifies prior-events-window is fed)。
    private struct CountingLabelEnricher:
        BASTrainingLabelEnricher
    {
        func labels(
            for event: BASEventLogEntry,
            priorEventsInSession: [BASEventLogEntry]
        ) async -> BASTrainingLabels? {
            // Verdict based on prior-events count
            let verdict: String
            if priorEventsInSession.count < 2 {
                verdict = "allow"
            } else if priorEventsInSession.count < 5 {
                verdict = "softCaution"
            } else {
                verdict = "hardNoGo"
            }
            // Cycle-closing fires every 3rd event
            let cycleClosing =
                priorEventsInSession.count % 3 == 2
            return BASTrainingLabels(
                permitVerdict: verdict,
                cycleClosingTriggered: cycleClosing)
        }
    }

    /// Test enricher that returns nil to signal "no labels"
    private struct NilEnricher: BASTrainingLabelEnricher {
        func labels(
            for event: BASEventLogEntry,
            priorEventsInSession: [BASEventLogEntry]
        ) async -> BASTrainingLabels? {
            nil
        }
    }

    func testNoEnricherProducesNilLabels() async throws {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(index: 0))

        // No enricher → labels = nil
        let exporter = BASTrainingDataExporter(eventLog: log)
        let url = makeTempURL()
        _ = try await exporter.exportToJSONL(
            filter: .all, to: url)

        let raw = try Data(contentsOf: url)
        let line = String(data: raw, encoding: .utf8)!
            .split(separator: "\n").first!
        let decoder = JSONDecoder()
        let datum = try decoder.decode(
            BASTrainingDatum.self,
            from: line.data(using: .utf8)!)
        XCTAssertNil(datum.labels,
            "No enricher = nil labels (M925 default)")
    }

    func testConstantEnricherPopulatesLabelsForEveryDatum()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<5 {
            _ = try await log.append(makeEvent(index: i))
        }

        let enricher = ConstantLabelEnricher(
            labels: BASTrainingLabels(
                permitVerdict: "allow",
                cycleClosingTriggered: false))
        let exporter = BASTrainingDataExporter(
            eventLog: log,
            labelEnricher: enricher)
        let url = makeTempURL()
        _ = try await exporter.exportToJSONL(
            filter: .all, to: url)

        let raw = try Data(contentsOf: url)
        let lines = String(data: raw, encoding: .utf8)!
            .split(separator: "\n",
                   omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 5)

        let decoder = JSONDecoder()
        for line in lines {
            let datum = try decoder.decode(
                BASTrainingDatum.self,
                from: line.data(using: .utf8)!)
            XCTAssertEqual(
                datum.labels?.permitVerdict, "allow")
            XCTAssertEqual(
                datum.labels?.cycleClosingTriggered, false)
        }
    }

    func testCountingEnricherSeesGrowingHistory() async
        throws
    {
        let log = BASInMemoryEventLogStorage()
        for i in 0..<6 {
            _ = try await log.append(makeEvent(index: i))
        }

        let exporter = BASTrainingDataExporter(
            eventLog: log,
            labelEnricher: CountingLabelEnricher())
        let url = makeTempURL()
        _ = try await exporter.exportToJSONL(
            filter: .all, to: url)

        let raw = try Data(contentsOf: url)
        let lines = String(data: raw, encoding: .utf8)!
            .split(separator: "\n",
                   omittingEmptySubsequences: true)
        let decoder = JSONDecoder()
        let labels = try lines.map { line ->
            BASTrainingLabels in
            let datum = try decoder.decode(
                BASTrainingDatum.self,
                from: line.data(using: .utf8)!)
            return datum.labels!
        }

        // Event 0: prior=0 → allow, cycle=false (0 % 3 == 0)
        // Event 1: prior=1 → allow, cycle=false (1 % 3 == 1)
        // Event 2: prior=2 → softCaution, cycle=true (2 % 3 == 2)
        // Event 3: prior=3 → softCaution, cycle=false
        // Event 4: prior=4 → softCaution, cycle=false
        // Event 5: prior=5 → hardNoGo, cycle=true
        XCTAssertEqual(labels[0].permitVerdict, "allow")
        XCTAssertEqual(
            labels[0].cycleClosingTriggered, false)
        XCTAssertEqual(labels[2].permitVerdict, "softCaution")
        XCTAssertEqual(
            labels[2].cycleClosingTriggered, true)
        XCTAssertEqual(labels[5].permitVerdict, "hardNoGo")
        XCTAssertEqual(
            labels[5].cycleClosingTriggered, true)
    }

    func testNilEnricherProducesNilLabels() async throws {
        let log = BASInMemoryEventLogStorage()
        _ = try await log.append(makeEvent(index: 0))

        let exporter = BASTrainingDataExporter(
            eventLog: log,
            labelEnricher: NilEnricher())
        let url = makeTempURL()
        _ = try await exporter.exportToJSONL(
            filter: .all, to: url)

        let raw = try Data(contentsOf: url)
        let line = String(data: raw, encoding: .utf8)!
            .split(separator: "\n").first!
        let decoder = JSONDecoder()
        let datum = try decoder.decode(
            BASTrainingDatum.self,
            from: line.data(using: .utf8)!)
        XCTAssertNil(datum.labels,
            "Enricher returning nil → datum.labels = nil")
    }

    func testHistoryWindowIsPerSession() async throws {
        let log = BASInMemoryEventLogStorage()
        // 3 events in session-A then 3 in session-B
        for i in 0..<3 {
            _ = try await log.append(makeEvent(
                index: i, sessionID: "A"))
        }
        for i in 100..<103 {
            _ = try await log.append(makeEvent(
                index: i, sessionID: "B"))
        }

        let exporter = BASTrainingDataExporter(
            eventLog: log,
            labelEnricher: CountingLabelEnricher())
        let url = makeTempURL()
        _ = try await exporter.exportToJSONL(
            filter: .all, to: url)

        let raw = try Data(contentsOf: url)
        let lines = String(data: raw, encoding: .utf8)!
            .split(separator: "\n",
                   omittingEmptySubsequences: true)
        let decoder = JSONDecoder()
        // Session B's first event should see prior=0 (B
        // events are SEPARATE from A history)。
        // Session A:event 0 prior=0,event 1 prior=1,
        //           event 2 prior=2 → softCaution
        // Session B:event 100 prior=0 → allow
        let parsed: [BASTrainingDatum] = try lines.map {
            line in
            try decoder.decode(BASTrainingDatum.self,
                from: line.data(using: .utf8)!)
        }
        let sessionAEvents = parsed.filter {
            $0.event.sessionID == "A" }
        let sessionBEvents = parsed.filter {
            $0.event.sessionID == "B" }
        XCTAssertEqual(sessionAEvents.count, 3)
        XCTAssertEqual(sessionBEvents.count, 3)

        XCTAssertEqual(
            sessionAEvents[2].labels?.permitVerdict,
            "softCaution",
            "Session A's 3rd event sees prior=2 → softCaution")
        XCTAssertEqual(
            sessionBEvents[0].labels?.permitVerdict, "allow",
            "Session B's 1st event sees prior=0 (NOT prior=3 " +
            "from session A) → allow")
    }
}
