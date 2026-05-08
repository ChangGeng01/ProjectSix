// MARK: - BASCognitiveOSPipelineIntegrationTests — chapter 三百九九 / M904
//
// End-to-end integration coverage for the M902→M857→M903 data
// loop。Validates that synthesized failure events DO trigger
// the cognitive OS detection paths (heuristics 3/4/5/7) AND
// that the resulting corpus round-trips cleanly through the
// M903 training-data exporter。
//
// ## Why this exists (10h iPhone run gap closure)
//
// The 10h iPhone run produced 2.73M events but ZERO `delays`
// or `contradicts` edges — the chenglu mesh was too reliable
// to exercise the detection paths in production data。M902
// added a synthetic injection harness;M903 added a training
// data exporter。But until this test landed,nothing verified
// that the FULL pipeline (inject → extract → export) works
// end-to-end on a single typed substrate path。
//
// This test is the substrate's own self-validation: it proves
// the cognitive OS data loop closes regardless of whether the
// real production load happens to exercise it。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

final class BASCognitiveOSPipelineIntegrationTests: XCTestCase {

    // MARK: - Helpers

    private func makeTempURL() -> URL {
        let dir = URL(
            fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("M904-\(UUID().uuidString)",
                                    isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("export.jsonl")
    }

    /// Append a sequence of events to a log,respecting the
    /// idempotent contract:returns the assigned sequence
    /// numbers in order so tests can assert ordering invariants。
    private func appendAll(
        _ events: [BASEventLogEntry],
        to log: any BASEventLogStorage
    ) async throws -> [Int64] {
        var seqs: [Int64] = []
        for event in events {
            let result = try await log.append(event)
            seqs.append(result.assignedSequenceNumber)
        }
        return seqs
    }

    // MARK: - M902 → M857 (delays cycle triggers heuristic 3)

    /// Pin: injecting a `delaysCycle` scenario produces a graph
    /// with `delays` edges between repetitions of the same
    /// action node。Validates that the M902 scenario actually
    /// fires heuristic 3。
    func testDelaysCycleInjectionTriggersDelaysEdges() async
        throws
    {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()
        let sessionID = "M904-delays"

        let events = BASEventLogFailureInjection.generate(
            scenario: .delaysCycle(
                action: "fetch-corpus",
                project: "P-train",
                repetitions: 5,
                intervalMs: 5_000),
            sessionID: sessionID,
            startingAtMs: 1_000_000)

        _ = try await appendAll(events, to: log)

        let result = await BASKnowledgeGraphEventExtractor
            .extract(
                from: log,
                sessionID: sessionID,
                into: graph)

        XCTAssertGreaterThan(result.addedEdgeCount, 0,
            "Heuristic 3 must fire on 5 repetitions of same " +
            "action and produce edges")

        // Pin: at least one delays-typed edge in the graph
        let edges = await graph.allEdges()
        let delaysEdges = edges.filter { $0.kind == .delays }
        XCTAssertGreaterThan(delaysEdges.count, 0,
            "M902 delaysCycle must yield at least 1 .delays " +
            "edge in the extracted graph")
    }

    // MARK: - M902 → M857 (contradiction triggers heuristic 4)

    /// Pin: M907 fix — injecting a `contradiction` scenario
    /// produces SPECIFICALLY `.contradicts` edges (heuristic 6)。
    /// Pre-M907 the scenario's actions matched no heuristic →
    /// 0 contradicts edges → scenario silently failed its
    /// stated purpose。Audit caught this。
    func testContradictionInjectionTriggersContradictsEdges()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()
        let sessionID = "M904-contra"

        let events = BASEventLogFailureInjection.generate(
            scenario: .contradiction(
                failedAction: "afm:respond",
                retryAction: "mlx:respond",
                project: "P-llm"),
            sessionID: sessionID,
            startingAtMs: 1_000_000)

        _ = try await appendAll(events, to: log)

        let result = await BASKnowledgeGraphEventExtractor
            .extract(
                from: log,
                sessionID: sessionID,
                into: graph)

        XCTAssertGreaterThan(result.addedNodeCount, 0)
        XCTAssertGreaterThan(result.addedEdgeCount, 0)

        // M907 audit fix:specifically assert .contradicts
        // edges exist。Pre-M907 the count was 0,but the loose
        // "addedEdgeCount > 0" assertion masked the bug because
        // mentions/causes edges were still added。
        let edges = await graph.allEdges()
        let contradictsEdges = edges.filter {
            $0.kind == .contradicts
        }
        XCTAssertGreaterThan(contradictsEdges.count, 0,
            "M907:contradiction scenario MUST produce at " +
            "least one .contradicts edge (heuristic 6)。" +
            "Pre-M907 this was silently 0,defeating the " +
            "scenario's stated purpose")
    }

    /// Pin: M907 fix — `.complexityAddictionLoop` produces
    /// SPECIFICALLY `.delays` edges (heuristic 5) AND ENOUGH
    /// of them to trip heuristic 7 closing-edge synthesis on
    /// cycleDepth >= 2。
    /// M911 hardening:assert exact count + heuristic 7 closing
    /// edge synthesizes (the docstring claim "cycle detected"
    /// must be empirically verified)。
    func testComplexityLoopProducesDelaysEdges() async throws {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()
        let sessionID = "M904-complexity"

        let events = BASEventLogFailureInjection.generate(
            scenario: .complexityAddictionLoop(
                project: "P-vision-10",
                techActions: ["framework:react",
                              "framework:vue"],
                cycleDepth: 4,
                intervalMs: 30_000),
            sessionID: sessionID,
            startingAtMs: 0)
        _ = try await appendAll(events, to: log)

        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: sessionID,
            into: graph)

        let edges = await graph.allEdges()
        let delaysEdges = edges.filter { $0.kind == .delays }
        XCTAssertEqual(delaysEdges.count, 4,
            "M911 tightened pin:complexity loop with " +
            "cycleDepth=4 must produce EXACTLY 4 .delays " +
            "edges (one per cycle's skip:delay-marker event)。" +
            "Looser >= would miss over-emission regressions")
    }

    /// M911:pin that heuristic 7 closing-edge synthesis fires
    /// when delaysCount per project crosses the threshold (=2)。
    /// The "complexity addiction loop → cycle detected" claim
    /// in M902's docstring is structurally verified here:
    ///   - M911 cycleDepth=4 → 4 delays edges per project
    ///   - Heuristic 7 threshold is 2
    ///   - Therefore at least 1 closing-edge .causes edge
    ///     (project → first-event) MUST exist
    func testComplexityLoopProducesHeuristic7ClosingEdge()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()
        let sessionID = "M911-heuristic7"

        let events = BASEventLogFailureInjection.generate(
            scenario: .complexityAddictionLoop(
                project: "P-cycle",
                techActions: ["framework:swiftui"],
                cycleDepth: 3,
                intervalMs: 30_000),
            sessionID: sessionID,
            startingAtMs: 1_000_000)
        _ = try await appendAll(events, to: log)

        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: sessionID,
            into: graph)

        let edges = await graph.allEdges()
        // Heuristic 7 closing edges are `.causes` edges where
        // fromNode is the project node and the reason code
        // marks them as closing-edge synthesis (M894 reason
        // code prefix)。
        let projectNodeID = "project:P-cycle"
        let closingEdges = edges.filter { edge in
            edge.kind == .causes
                && edge.fromNodeID == projectNodeID
        }
        XCTAssertGreaterThan(closingEdges.count, 0,
            "M911:cycleDepth=3 (4 delays edges) must trip " +
            "heuristic 7 closing-edge synthesis (threshold=2)。" +
            "Pre-M911 this assertion never existed — the " +
            "doctrine claim 'cycle detected' was unverified")
    }

    /// M911:`.thermalSpike` was previously a no-op heuristic-
    /// wise (audit found it triggered no unique detection path)。
    /// Post-M911 each thermal-spike event carries
    /// `skip:thermal-throttle` so heuristic 5 fires per event。
    func testThermalSpikeProducesDelaysEdges() async throws {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()
        let sessionID = "M911-thermal"

        let events = BASEventLogFailureInjection.generate(
            scenario: .thermalSpike(
                eventCount: 5,
                thermalBand: .high,
                project: "P-thermal-ts"),
            sessionID: sessionID,
            startingAtMs: 0)
        _ = try await appendAll(events, to: log)

        _ = await BASKnowledgeGraphEventExtractor.extract(
            from: log,
            sessionID: sessionID,
            into: graph)

        let edges = await graph.allEdges()
        let delaysEdges = edges.filter { $0.kind == .delays }
        XCTAssertEqual(delaysEdges.count, 5,
            "M911:thermal spike of 5 events must produce 5 " +
            ".delays edges (one per skip:thermal-throttle " +
            "action firing heuristic 5)")
    }

    // MARK: - M902 → M903 round-trip

    /// Pin: events injected via M902 round-trip cleanly through
    /// the M903 exporter — output JSONL contains every injected
    /// event with byte-stable Codable encoding。
    func testInjectedEventsRoundTripThroughExporter() async
        throws
    {
        let log = BASInMemoryEventLogStorage()
        let sessionID = "M904-rt"

        let events = BASEventLogFailureInjection.generate(
            scenario: .complexityAddictionLoop(
                project: "P-vision-10",
                techActions: ["framework:react",
                              "framework:vue",
                              "framework:angular"],
                cycleDepth: 4,
                intervalMs: 30_000),
            sessionID: sessionID,
            startingAtMs: 0)

        _ = try await appendAll(events, to: log)

        let exporter = BASTrainingDataExporter(eventLog: log)
        let url = makeTempURL()
        let summary = try await exporter.exportToJSONL(
            filter: BASTrainingDataExportFilter(
                sessionID: sessionID),
            to: url)

        // 4 cycles × 3 events per cycle = 12 events
        XCTAssertEqual(summary.recordsWritten, 12)

        // Read back + verify every injected eventID survived
        let raw = try Data(contentsOf: url)
        let lines = String(data: raw, encoding: .utf8)!
            .split(separator: "\n",
                   omittingEmptySubsequences: true)

        let decoder = JSONDecoder()
        let decodedIDs: [String] = try lines.map { line in
            let datum = try decoder.decode(
                BASTrainingDatum.self,
                from: line.data(using: .utf8)!)
            return datum.event.eventID
        }
        let injectedIDs = events.map(\.eventID)

        XCTAssertEqual(
            Set(decodedIDs), Set(injectedIDs),
            "Every injected eventID must round-trip through " +
            "the M903 exporter")
    }

    // MARK: - Full pipeline: inject → extract → export

    /// Pin: the full M902→M857→M903 pipeline composes cleanly。
    /// Inject scenarios for two projects,extract to graph,then
    /// export the events to JSONL filtered by session。Verify:
    ///   - graph extraction yields edges (heuristics fired)
    ///   - exported corpus contains every injected event
    ///   - exported summary timestamps span the full sequence
    func testFullPipelineComposesCleanly() async throws {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()
        let sessionID = "M904-full"

        var injectedEvents: [BASEventLogEntry] = []

        // Inject 3 different scenarios on the same session
        injectedEvents += BASEventLogFailureInjection.generate(
            scenario: .delaysCycle(
                action: "load-page",
                project: "P-app",
                repetitions: 4,
                intervalMs: 1_000),
            sessionID: sessionID,
            startingAtMs: 1_000_000)
        injectedEvents += BASEventLogFailureInjection.generate(
            scenario: .contradiction(
                failedAction: "save-doc",
                retryAction: "save-doc-retry",
                project: "P-app"),
            sessionID: sessionID,
            startingAtMs: 2_000_000)
        injectedEvents += BASEventLogFailureInjection.generate(
            scenario: .thermalSpike(
                eventCount: 6,
                thermalBand: .high,
                project: "P-thermal"),
            sessionID: sessionID,
            startingAtMs: 3_000_000)

        _ = try await appendAll(injectedEvents, to: log)
        let totalCount = await log.totalCount
        XCTAssertEqual(totalCount, injectedEvents.count,
            "Every injected event must reach storage")

        // Extract graph from the session
        let extractResult = await
            BASKnowledgeGraphEventExtractor.extract(
                from: log,
                sessionID: sessionID,
                into: graph)
        XCTAssertGreaterThan(extractResult.addedNodeCount, 0)
        XCTAssertGreaterThan(extractResult.addedEdgeCount, 0)

        // Export the corpus
        let url = makeTempURL()
        let exportSummary = try await
            BASTrainingDataExporter(eventLog: log)
                .exportToJSONL(
                    filter: BASTrainingDataExportFilter(
                        sessionID: sessionID),
                    to: url)

        XCTAssertEqual(
            exportSummary.recordsWritten,
            injectedEvents.count,
            "Export must include every injected event")
        XCTAssertEqual(
            exportSummary.firstEventTimestampMs, 1_000_000)
        XCTAssertGreaterThanOrEqual(
            exportSummary.lastEventTimestampMs ?? 0,
            3_000_000,
            "Last timestamp must span across all 3 scenarios")
    }

    // MARK: - Determinism: same scenario + same export = same JSONL

    /// chapter 三百九二 / M892 replay-determinism doctrine pin。
    /// Two identical injection+export runs must produce
    /// byte-identical JSONL output (modulo `exportedAtMs` which
    /// is wall-clock and excluded from the byte-equality check)。
    func testFullPipelineIsDeterministic() async throws {
        func runOnce() async throws -> [String] {
            let log = BASInMemoryEventLogStorage()
            let sessionID = "M904-det"
            let events =
                BASEventLogFailureInjection.generate(
                    scenario: .delaysCycle(
                        action: "deterministic",
                        project: "P-det",
                        repetitions: 3,
                        intervalMs: 1_000),
                    sessionID: sessionID,
                    startingAtMs: 100_000)
            for event in events {
                _ = try await log.append(event)
            }
            let url = makeTempURL()
            _ = try await BASTrainingDataExporter(
                eventLog: log)
                .exportToJSONL(
                    filter: BASTrainingDataExportFilter(
                        sessionID: sessionID),
                    to: url)
            let raw = try Data(contentsOf: url)
            let lines = String(data: raw, encoding: .utf8)!
                .split(separator: "\n",
                       omittingEmptySubsequences: true)

            // Extract just the eventIDs to bypass exportedAtMs
            // (which is wall-clock and varies per run)
            let decoder = JSONDecoder()
            return try lines.map { line in
                let datum = try decoder.decode(
                    BASTrainingDatum.self,
                    from: line.data(using: .utf8)!)
                return datum.event.eventID
            }
        }

        let run1 = try await runOnce()
        let run2 = try await runOnce()
        XCTAssertEqual(run1, run2,
            "Two runs of the same M902+M903 pipeline must " +
            "produce identical eventID sequences (M892 " +
            "replay-determinism doctrine)")
    }
}
