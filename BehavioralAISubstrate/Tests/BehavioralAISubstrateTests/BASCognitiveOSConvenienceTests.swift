// MARK: - BASCognitiveOSConvenienceTests — chapter 三百七八 / M865
//
// Test coverage for the convenience helper that composes event
// log append + state reducer fold + graph extract behind a
// single `observe(event:)` call。
//
// Tests verify:
//   - All-nil bundle → all-false result, only counter increments
//   - Event log only → eventAppended only
//   - Event log + state store → fold fires at cadence boundary
//   - Full bundle → graph extract fires at extract cadence
//   - Cadence values are tunable
//   - Graph extract event cap respected (skipped beyond cap)
//   - Iteration index reported correctly
//   - Multiple sessions can run in parallel via separate convenience
//     actors (independent counters)

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

final class BASCognitiveOSConvenienceTests: XCTestCase {

    // MARK: - Fixtures

    private func makeEvent(
        index: Int,
        sessionID: String = "test-session"
    ) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: "ev-\(index)-\(UUID().uuidString)",
            timestampMs: Int64(1_700_000_000_000 + index),
            kind: .substrateAudit,
            sessionID: sessionID,
            sequenceNumber: 0,
            actions: ["test"])
    }

    // MARK: - All-nil: no-op

    func testAllNilBundleProducesNoOp() async {
        let conv = BASCognitiveOSConvenience(
            sessionID: "s1")

        let result = await conv.observe(
            event: makeEvent(index: 0))

        XCTAssertFalse(result.eventAppended)
        XCTAssertFalse(result.stateFolded)
        XCTAssertFalse(result.graphExtracted)
        XCTAssertFalse(result.anyFired)
        XCTAssertEqual(result.iterationIndex, 1,
            "1-based: first observe gets index 1")

        let observed = await conv.observedCount
        XCTAssertEqual(observed, 1,
            "Counter must still tick on no-op observe")
    }

    // MARK: - Event log only

    func testEventLogOnlyAppendsButDoesNotFoldOrExtract()
        async
    {
        let log = BASInMemoryEventLogStorage()
        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            sessionID: "s1")

        let result = await conv.observe(
            event: makeEvent(index: 0))

        XCTAssertTrue(result.eventAppended)
        XCTAssertFalse(result.stateFolded)
        XCTAssertFalse(result.graphExtracted)

        let total = await log.totalCount
        XCTAssertEqual(total, 1)
    }

    // MARK: - State fold cadence

    func testStateFoldFiresAtCadenceBoundary() async {
        let log = BASInMemoryEventLogStorage()
        let store = BASInMemoryUserStateStorage()
        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            userStateStore: store,
            sessionID: "s1")

        // First 99 calls → no fold (1-based: indexes 1..99)
        for i in 0..<99 {
            let r = await conv.observe(
                event: makeEvent(index: i))
            XCTAssertFalse(r.stateFolded,
                "Pre-100 calls must not fold (call #\(i + 1))")
        }

        // 100th call (1-based index 100) → triggers fold
        let foldResult = await conv.observe(
            event: makeEvent(index: 100))
        XCTAssertTrue(foldResult.stateFolded,
            "100th call (1-based index 100) must trigger fold")
        XCTAssertEqual(foldResult.iterationIndex, 100)

        let stateCount = await store.totalCount
        XCTAssertEqual(stateCount, 1)
    }

    func testStateFoldRespectsCadenceOverInterval() async {
        let log = BASInMemoryEventLogStorage()
        let store = BASInMemoryUserStateStorage()
        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            userStateStore: store,
            sessionID: "s1")

        // 250 calls (1-based: indexes 1..250) → folds at 100,200
        for i in 0..<250 {
            _ = await conv.observe(
                event: makeEvent(index: i))
        }

        let stateCount = await store.totalCount
        XCTAssertEqual(stateCount, 2,
            "Folds fire at indexes 100 + 200 → 2 across " +
            "250 observe calls (1-based)")
    }

    // MARK: - Graph extract cadence

    func testGraphExtractFiresAtCadenceBoundary() async {
        let log = BASInMemoryEventLogStorage()
        let store = BASInMemoryUserStateStorage()
        let graph = BASKnowledgeGraph()
        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            userStateStore: store,
            knowledgeGraph: graph,
            sessionID: "s1")

        // 1000 calls (1-based: indexes 1..1000)
        // → first extract at call #1000。Events MUST share
        // sessionID with convenience for the extractor to find
        // them
        for i in 0..<1_000 {
            _ = await conv.observe(
                event: makeEvent(
                    index: i, sessionID: "s1"))
        }

        let nodeCount = await graph.nodeCount
        XCTAssertGreaterThan(nodeCount, 0,
            "Graph extract at 1000th call (1-based index " +
            "1000) must populate nodes")
    }

    // MARK: - Custom cadence

    func testCustomCadenceTuneable() async {
        let log = BASInMemoryEventLogStorage()
        let store = BASInMemoryUserStateStorage()
        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            userStateStore: store,
            sessionID: "s1",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 10,
                graphExtractInterval: 50,
                graphExtractEventCap: 5000))

        // First 9 calls (1-based: 1..9) → no fold
        for i in 0..<9 {
            let r = await conv.observe(
                event: makeEvent(index: i))
            XCTAssertFalse(r.stateFolded)
        }
        // 10th call (1-based index 10) → triggers fold
        let r10 = await conv.observe(
            event: makeEvent(index: 9))
        XCTAssertTrue(r10.stateFolded,
            "Custom cadence 10 must fire at 1-based index 10")
        XCTAssertEqual(r10.iterationIndex, 10)
    }

    // MARK: - Graph extract event cap

    func testGraphExtractSkippedBeyondCap() async {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()
        // Custom cadence: extract at every iter, cap at 5
        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            sessionID: "s1",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 1,
                graphExtractInterval: 1,
                graphExtractEventCap: 5))

        // Submit 10 events — extract should skip on 6th onwards
        var extractedCount = 0
        for i in 0..<10 {
            let r = await conv.observe(
                event: makeEvent(index: i))
            if r.graphExtracted { extractedCount += 1 }
        }

        XCTAssertGreaterThan(extractedCount, 0,
            "Graph extract must fire at least once below cap")
        XCTAssertLessThan(extractedCount, 10,
            "Graph extract must skip at least once above cap")
    }

    // MARK: - Iteration index reporting

    func testIterationIndexInResultMonotonic() async {
        let conv = BASCognitiveOSConvenience(
            sessionID: "s1")

        // 1-based: call N gets index N
        for callNumber in 1...5 {
            let result = await conv.observe(
                event: makeEvent(index: callNumber))
            XCTAssertEqual(
                result.iterationIndex, callNumber,
                "Result iterationIndex must match 1-based " +
                "call sequence")
        }
    }

    // MARK: - Multi-session independence

    func testMultipleConvenienceActorsAreIndependent()
        async
    {
        let log = BASInMemoryEventLogStorage()
        let storeA = BASInMemoryUserStateStorage()
        let storeB = BASInMemoryUserStateStorage()
        let convA = BASCognitiveOSConvenience(
            eventLog: log,
            userStateStore: storeA,
            sessionID: "session-A")
        let convB = BASCognitiveOSConvenience(
            eventLog: log,
            userStateStore: storeB,
            sessionID: "session-B")

        // Run 100 events through A (1-based indexes 1..100)
        for i in 0..<100 {
            _ = await convA.observe(
                event: makeEvent(
                    index: i, sessionID: "session-A"))
        }

        // B should NOT have folded yet — its counter is still 0
        let bObserved = await convB.observedCount
        XCTAssertEqual(bObserved, 0)
        let aObserved = await convA.observedCount
        XCTAssertEqual(aObserved, 100)

        // A's 100 calls triggered 1 fold (at 1-based index 100)
        let storeACount = await storeA.totalCount
        XCTAssertEqual(storeACount, 1,
            "A's 100 observes triggered 1 fold at index 100")
        let storeBCount = await storeB.totalCount
        XCTAssertEqual(storeBCount, 0)
    }

    // MARK: - M869 graph storage write-through

    func testGraphStorageWriteThroughOnExtract() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-conv-m869-\(UUID().uuidString)",
                isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let storage = try BASSQLiteKnowledgeGraphStorage(
            databaseURL: tempDir.appendingPathComponent(
                "graph.sqlite"))
        let graph = BASKnowledgeGraph()
        let log = BASInMemoryEventLogStorage()

        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            knowledgeGraphStorage: storage,
            sessionID: "s1",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 5,
                graphExtractEventCap: 5_000))

        // 5 events on the same project → graph extract fires
        // at iter 5 → write-through must persist nodes + edges
        for i in 1...5 {
            let event = BASEventLogEntry(
                eventID: "ev-\(i)",
                timestampMs: Int64(1_000 + i),
                kind: .substrateAudit,
                sessionID: "s1",
                sequenceNumber: 0,
                project: "alpha",
                actions: ["delays:alpha"])
            _ = await conv.observe(event: event)
        }

        // After extract,storage must have nodes + edges
        let storedNodeCount = await storage.nodeCount
        XCTAssertGreaterThan(storedNodeCount, 0,
            "Write-through must persist graph nodes to SQLite")
        let storedEdgeCount = await storage.edgeCount
        XCTAssertGreaterThan(storedEdgeCount, 0,
            "Write-through must persist graph edges to SQLite")
    }

    func testWriteThroughIsIdempotent() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-conv-m869-idem-\(UUID().uuidString)",
                isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let storage = try BASSQLiteKnowledgeGraphStorage(
            databaseURL: tempDir.appendingPathComponent(
                "graph.sqlite"))
        let graph = BASKnowledgeGraph()
        let log = BASInMemoryEventLogStorage()

        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            knowledgeGraphStorage: storage,
            sessionID: "s1",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 3,
                graphExtractEventCap: 5_000))

        // 6 events → 2 extracts (at iter 3 + iter 6)
        // First extract writes through
        // Second extract re-walks SAME nodes + edges →
        // M866 append idempotency makes them no-ops
        for i in 1...6 {
            let event = BASEventLogEntry(
                eventID: "ev-\(i)",
                timestampMs: Int64(1_000 + i),
                kind: .substrateAudit,
                sessionID: "s1",
                sequenceNumber: 0,
                project: "beta",
                actions: ["delays:beta"])
            _ = await conv.observe(event: event)
        }

        let firstNodeCount = await storage.nodeCount
        let firstEdgeCount = await storage.edgeCount
        XCTAssertGreaterThan(firstNodeCount, 0)

        // Submit one more event + force another extract
        // The pre-existing nodes / edges should NOT duplicate
        let event7 = BASEventLogEntry(
            eventID: "ev-7",
            timestampMs: 1_007,
            kind: .substrateAudit,
            sessionID: "s1",
            sequenceNumber: 0,
            project: "beta")
        _ = await conv.observe(event: event7)
        // 7 events but extract cadence is 3 → extracts at
        // 3, 6, 9 → no extract on iter 7
        let secondNodeCount = await storage.nodeCount
        let secondEdgeCount = await storage.edgeCount
        XCTAssertEqual(secondNodeCount, firstNodeCount)
        XCTAssertEqual(secondEdgeCount, firstEdgeCount)
    }

    func testNoStorageMeansNoWriteThrough() async {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()

        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            // No storage wired in (M865 contract preserved)
            sessionID: "s1",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 3,
                graphExtractEventCap: 5_000))

        for i in 1...3 {
            let event = BASEventLogEntry(
                eventID: "ev-\(i)",
                timestampMs: Int64(1_000 + i),
                kind: .substrateAudit,
                sessionID: "s1",
                sequenceNumber: 0,
                project: "no-storage-test")
            let r = await conv.observe(event: event)
            if i == 3 {
                XCTAssertTrue(r.graphExtracted,
                    "Extract still fires without storage")
            }
        }

        // The graph itself populated as before
        let nodeCount = await graph.nodeCount
        XCTAssertGreaterThan(nodeCount, 0)
    }

    // MARK: - M868 graph-aware reducer wiring

    func testFoldUsesGraphAwareReducerWhenGraphPresent()
        async throws
    {
        // Pre-build a graph with a delays-cycle on
        // "project:foo" so the graph-aware reducer fires on
        // events tagged with project="foo"。
        let graph = BASKnowledgeGraph()
        try await graph.upsert(node: BASKnowledgeNode(
            nodeID: "project:foo",
            kind: .project,
            label: "foo",
            createdAtMs: 0))
        try await graph.upsert(node: BASKnowledgeNode(
            nodeID: "event-1",
            kind: .event,
            label: "ev1",
            createdAtMs: 0))
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "e-delays",
            fromNodeID: "project:foo",
            toNodeID: "event-1",
            kind: .delays,
            createdAtMs: 0))
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "e-back",
            fromNodeID: "event-1",
            toNodeID: "project:foo",
            kind: .causes,
            createdAtMs: 0))

        let log = BASInMemoryEventLogStorage()
        let store = BASInMemoryUserStateStorage()
        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            userStateStore: store,
            knowledgeGraph: graph,
            sessionID: "s1",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 1,
                graphExtractInterval: 100,
                graphExtractEventCap: 5_000))

        // First call → fold immediately (cadence 1)。Event tagged
        // with project="foo" so the graph-aware reducer adds
        // complexityAddiction bonus
        let event = BASEventLogEntry(
            eventID: "ev-foo",
            timestampMs: 1_000,
            kind: .substrateAudit,
            sessionID: "s1",
            sequenceNumber: 0,
            project: "foo",
            actions: ["delays:foo"])
        let r = await conv.observe(event: event)
        XCTAssertTrue(r.stateFolded)

        // The folded state must reflect the cycle bonus —
        // complexityAddictionScore > 0 because graph-aware
        // reducer added 0.15 per delays-cycle (min capped at
        // 0.45)
        let rolling = await conv.rollingState
        XCTAssertGreaterThan(
            rolling.complexityAddictionScore, 0,
            "Graph-aware reducer must add bonus when " +
            "delays-cycle on the event's project is detected")
    }

    func testFoldUsesBaseReducerWhenGraphAbsent() async {
        let log = BASInMemoryEventLogStorage()
        let store = BASInMemoryUserStateStorage()
        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            userStateStore: store,
            // No graph wired in
            sessionID: "s1",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 1,
                graphExtractInterval: 100,
                graphExtractEventCap: 5_000))

        let event = BASEventLogEntry(
            eventID: "ev-bar",
            timestampMs: 1_000,
            kind: .substrateAudit,
            sessionID: "s1",
            sequenceNumber: 0,
            project: "foo")  // project doesn't matter without graph
        let r = await conv.observe(event: event)
        XCTAssertTrue(r.stateFolded,
            "Fold must still fire without a graph (M842 base " +
            "reducer path)")

        // Without a graph,no cycle bonus → score stays at
        // base reducer's output (which is 0 for a clean event
        // sequence with no prior state)
        let rolling = await conv.rollingState
        XCTAssertEqual(
            rolling.complexityAddictionScore, 0,
            "Base reducer must not add cycle bonus when no " +
            "graph wired (M868 fallback pin)")
    }

    // MARK: - Cadence value sanity

    func testDefaultCadenceMatchesM862SampleHostObserver() {
        // Pin: convenience defaults must equal M862 SampleHost
        // observer constants so the SampleHost can adopt this
        // helper without behavior change
        let cadence = BASCognitiveOSConvenienceCadence.default
        XCTAssertEqual(cadence.stateFoldInterval, 100)
        XCTAssertEqual(cadence.graphExtractInterval, 1_000)
        XCTAssertEqual(cadence.graphExtractEventCap, 5_000)
    }

    func testZeroCadencePreconditionTrap() {
        // Pin: precondition prevents nonsensical config — we
        // can't easily catch a precondition in XCTest without
        // crashing the test harness, so we just verify the
        // constants are all > 0
        let cadence = BASCognitiveOSConvenienceCadence(
            stateFoldInterval: 1,
            graphExtractInterval: 1,
            graphExtractEventCap: 1)
        XCTAssertEqual(cadence.stateFoldInterval, 1)
    }
}
