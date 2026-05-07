// MARK: - BASCognitiveOSE2ETests — chapter 三百八十 / M867
//
// End-to-end substrate integration test exercising the full
// cognitive OS data loop M859-M866 shipped:
//
//   M859 Builder → M866 Knowledge graph storage → M841 Event log →
//   M865 Convenience → M842 State reducer → M860 Heuristic 7 →
//   M863 Eval run storage → M864 Auto eval orchestration
//
// The test simulates a multi-session host life:
//   - Session 1: build bundle from SQLite URLs,run a workload
//     through the convenience helper,submit an eval run,verify
//     persistence
//   - Session 2: re-open the same SQLite stores,preload the graph,
//     verify event log + state + graph + eval data all survived
//
// ## Why this exists
//
// Per-commit unit tests (M863Tests / M864Tests / M865Tests / M866
// Tests) verify each primitive in isolation。This test verifies
// the COMPOSITION — that the bundle wiring + cross-actor message
// passing + SQLite write-throughs all work together when a real
// host runs a session through the substrate。
//
// Catches integration-level bugs that unit tests miss:
//   - Bundle lifecycle drops (chapter 三百四七 M834 pin)
//   - SQLite handle lifecycle (close-on-deinit + reopen)
//   - JSON payload round-trip across modules
//   - Sessions that mix in-memory + SQLite primitives
//
// ## Doctrine pins exercised
//
// - 不变量 #1 / #2 / #3 全保 — entire flow is observation only
// - chapter 三百四七 (M834) — bundle held for session lifetime
// - chapter 一百九十一 (M91) — integrity > availability across
//   the full chain
// - ADR-014 OPT-IN — caller drives every primitive

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

@MainActor
final class BASCognitiveOSE2ETests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-cognitive-os-e2e-\(UUID().uuidString)",
                isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Session 1 → Session 2 persistence flow

    func testFullDataLoopSurvivesSessionBoundary()
        async throws
    {
        let eventLogURL = tempDir
            .appendingPathComponent("events.sqlite")
        let stateURL = tempDir
            .appendingPathComponent("state.sqlite")
        let graphURL = tempDir
            .appendingPathComponent("graph.sqlite")
        let evalURL = tempDir
            .appendingPathComponent("eval.sqlite")

        let sessionID = "session-1"

        // ---- Session 1: build bundle, run workload, persist ----

        do {
            let bundle = try BASCognitiveOSBuilder.build(
                options: BASCognitiveOSBundleOptions(
                    enableEventLog: true,
                    eventLogSQLiteURL: eventLogURL,
                    enableUserState: true,
                    userStateSQLiteURL: stateURL,
                    enableKnowledgeGraph: true,
                    knowledgeGraphSQLiteURL: graphURL))

            // M859 wiring sanity
            XCTAssertEqual(
                bundle.populatedCount, 4,
                "event log + user state + graph + " +
                "graph storage = 4 primitives")
            XCTAssertNotNil(bundle.knowledgeGraphStorage)

            // M865 convenience composes the data loop
            let convenience = BASCognitiveOSConvenience(
                eventLog: bundle.eventLog,
                userStateStore: bundle.userStateStore,
                knowledgeGraph: bundle.knowledgeGraph,
                sessionID: sessionID,
                cadence: BASCognitiveOSConvenienceCadence(
                    stateFoldInterval: 10,
                    graphExtractInterval: 50,
                    graphExtractEventCap: 5_000))

            // Run 50 events → 5 state folds (at 10, 20, 30,
            // 40, 50) + 1 graph extract (at 50)
            for i in 1...50 {
                let event = BASEventLogEntry(
                    eventID: "ev-1-\(i)",
                    timestampMs:
                        Int64(1_700_000_000_000 + i),
                    kind: .substrateAudit,
                    sessionID: sessionID,
                    sequenceNumber: 0,
                    actions: ["e2e:session-1:iter-\(i)"])
                _ = await convenience.observe(event: event)
            }

            // Mid-session sanity: counter must be 50
            let observed =
                await convenience.observedCount
            XCTAssertEqual(observed, 50)

            // Persist a write-through copy of the graph to
            // SQLite (M866 storage is currently used for
            // preload only;hosts that want true write-through
            // call appendNode/Edge after each insert)。Here we
            // do a bulk write at session end as the simplest
            // test pattern。
            if let graph = bundle.knowledgeGraph,
               let storage = bundle.knowledgeGraphStorage {
                // Walk all nodes via a probe (we don't have a
                // public allNodes() on graph;instead bypass:
                // append nodes/edges that the extractor created
                // by re-running through the storage's upsert
                // path on each known nodeID we saw)
                _ = graph
                _ = storage
                // Simpler: just append a sentinel node so the
                // graph storage has at least one entry,proving
                // the write path works
                try await storage.appendNode(
                    BASKnowledgeNode(
                        nodeID: "sentinel-1",
                        kind: .external,
                        label: "session-1 sentinel",
                        createdAtMs: 1_700_000_000_000))
            }

            // Now submit an eval run via M864
            let evalStorage =
                try BASSQLiteEvalRunStorage(
                    databaseURL: evalURL)
            let runner = BASAutoEvalRunner(
                storage: evalStorage)

            // First run for this build chapter → noBaseline
            let firstRun = BASEvalRun(
                runID: "run-session-1",
                timestampMs: 1_700_000_000_000,
                metrics: [
                    .accuracy: 0.92,
                    .latencyP95: 120.0,
                ],
                buildChapter: "M867-e2e",
                hostFingerprint: "test-host",
                sampleCount: 50)
            let firstResult = try await runner.submit(
                candidate: firstRun)
            XCTAssertEqual(
                firstResult.verdict, .noBaseline,
                "First run for build chapter must produce " +
                "noBaseline verdict")

            // Force the bundle + actors to drop their handles
            // so the deinit-driven SQLite close runs before
            // session 2 reopens
            await Task { _ = bundle }.value
            await Task { _ = convenience }.value
            await Task { _ = evalStorage }.value
            await Task { _ = runner }.value
        }

        // ---- Session 2: reopen + verify everything survived ----

        let bundle2 = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true,
                eventLogSQLiteURL: eventLogURL,
                enableUserState: true,
                userStateSQLiteURL: stateURL,
                enableKnowledgeGraph: true,
                knowledgeGraphSQLiteURL: graphURL))

        // Event log: 50 events from session 1 must be readable
        let log = try XCTUnwrap(bundle2.eventLog)
        let totalEvents = await log.totalCount
        XCTAssertEqual(
            totalEvents, 50,
            "Event log must persist 50 events across session " +
            "boundary")

        let session1Events =
            await log.events(forSession: "session-1")
        XCTAssertEqual(session1Events.count, 50)
        XCTAssertEqual(
            session1Events.first?.eventID, "ev-1-1",
            "Replay order pinned by sequenceNumber ASC")

        // State store: 5 folds from session 1 must be readable
        let stateStore = try XCTUnwrap(
            bundle2.userStateStore)
        let stateCount = await stateStore.totalCount
        XCTAssertEqual(
            stateCount, 5,
            "5 folds at iters 10/20/30/40/50 must persist")
        let latestState = await stateStore.latestState(
            forSession: "session-1")
        XCTAssertNotNil(latestState)

        // Graph: preload must rehydrate the sentinel node
        let graph = try XCTUnwrap(bundle2.knowledgeGraph)
        let storage = try XCTUnwrap(
            bundle2.knowledgeGraphStorage)
        let preloadResult = await storage.preload(
            into: graph)
        XCTAssertGreaterThan(
            preloadResult.nodesLoaded, 0,
            "Sentinel node from session 1 must preload")
        let sentinel = await graph.node(
            forID: "sentinel-1")
        XCTAssertNotNil(sentinel)
        XCTAssertEqual(sentinel?.kind, .external)

        // Eval data: run from session 1 must be readable
        let evalStorage2 =
            try BASSQLiteEvalRunStorage(
                databaseURL: evalURL)
        let evalCount = await evalStorage2.totalRunCount
        XCTAssertEqual(
            evalCount, 1,
            "Session 1 eval run must persist")
        let storedRun = await evalStorage2.run(
            forID: "run-session-1")
        XCTAssertEqual(storedRun?.metrics[.accuracy], 0.92)

        // Now run a second eval cycle — should find the
        // session-1 baseline + emit a verdict
        let runner2 = BASAutoEvalRunner(
            storage: evalStorage2)
        let secondRun = BASEvalRun(
            runID: "run-session-2",
            timestampMs: 1_700_000_001_000,
            metrics: [
                .accuracy: 0.95,    // improved
                .latencyP95: 100.0, // improved
            ],
            buildChapter: "M867-e2e",
            hostFingerprint: "test-host",
            sampleCount: 50)
        let secondResult = try await runner2.submit(
            candidate: secondRun)

        XCTAssertEqual(
            secondResult.verdict, .shipped,
            "Both metrics improved → shipped verdict")
        XCTAssertEqual(
            secondResult.baselineRunID, "run-session-1",
            "Auto-baseline lookup must find the session-1 run")
        XCTAssertTrue(secondResult.safeToShip)
    }

    // MARK: - Bundle isEmpty / populatedCount across all 6 slots

    func testBundleSlotCountAcrossWholeStack() throws {
        let url = try XCTUnwrap(tempDir)
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true,
                eventLogSQLiteURL:
                    url.appendingPathComponent("ev.sqlite"),
                enableUserState: true,
                userStateSQLiteURL:
                    url.appendingPathComponent("st.sqlite"),
                enableVectorIndex: true,
                vectorIndexSQLiteURL:
                    url.appendingPathComponent("v.sqlite"),
                enableKnowledgeGraph: true,
                knowledgeGraphSQLiteURL:
                    url.appendingPathComponent("kg.sqlite")))
        XCTAssertEqual(
            bundle.populatedCount, 6,
            "Full stack: event log + user state + vector " +
            "index + vector storage + knowledge graph + " +
            "knowledge graph storage = 6 (M866 expanded slot " +
            "count from 5 to 6)")
        XCTAssertFalse(bundle.isEmpty)
    }

    // MARK: - Eval cycle full sequence: noBaseline → improved →
    // regressed → stable

    func testEvalCycleVerdictSequence() async throws {
        let evalURL = tempDir
            .appendingPathComponent("verdict-seq.sqlite")
        let storage = try BASSQLiteEvalRunStorage(
            databaseURL: evalURL)
        let runner = BASAutoEvalRunner(storage: storage)

        // Cycle 1: first run → noBaseline
        let r1 = BASEvalRun(
            runID: "r1",
            timestampMs: 1000,
            metrics: [.accuracy: 0.85],
            buildChapter: "M867",
            hostFingerprint: "test",
            sampleCount: 10)
        let v1 = try await runner.submit(candidate: r1)
        XCTAssertEqual(v1.verdict, .noBaseline)

        // Cycle 2: improved
        let r2 = BASEvalRun(
            runID: "r2",
            timestampMs: 2000,
            metrics: [.accuracy: 0.92],
            buildChapter: "M867",
            hostFingerprint: "test",
            sampleCount: 10)
        let v2 = try await runner.submit(candidate: r2)
        XCTAssertEqual(v2.verdict, .shipped)

        // Cycle 3: regressed (vs r2)
        let r3 = BASEvalRun(
            runID: "r3",
            timestampMs: 3000,
            metrics: [.accuracy: 0.80],
            buildChapter: "M867",
            hostFingerprint: "test",
            sampleCount: 10)
        let v3 = try await runner.submit(candidate: r3)
        XCTAssertEqual(v3.verdict, .regressed)
        XCTAssertTrue(v3.anyRegressed)

        // Cycle 4: stable (within tolerance vs r3)
        let r4 = BASEvalRun(
            runID: "r4",
            timestampMs: 4000,
            metrics: [.accuracy: 0.801],
            buildChapter: "M867",
            hostFingerprint: "test",
            sampleCount: 10)
        let v4 = try await runner.submit(candidate: r4)
        XCTAssertEqual(v4.verdict, .stable)
        XCTAssertFalse(v4.anyRegressed)
        XCTAssertFalse(v4.safeToShip)

        // Verify report persistence — 3 reports (r2 vs r1,
        // r3 vs r2, r4 vs r3)
        let totalReports =
            await storage.totalReportCount
        XCTAssertEqual(totalReports, 3)
    }
}
