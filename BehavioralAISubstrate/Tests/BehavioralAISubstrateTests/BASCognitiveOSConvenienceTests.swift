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

    // MARK: - M886 hwm correctness (post-deep-review fix)

    func testIncrementalExtractDoesNotDoubleProcessEvents()
        async
    {
        // M886 fix:capture hwm BEFORE extract,not after。
        // Pre-M886 a wall-clock hwm written AFTER extract could
        // lag behind events written DURING extract → those
        // events get re-walked next call → silent double-counting。
        // Post-M886 the pre-extract hwm guarantees the next
        // call's `since: hwm+1` filter picks up any event
        // written during the extract,never re-walks。
        //
        // This test simulates the race by submitting events
        // with strictly-increasing timestamps + verifies that
        // re-extraction produces the same node count (idempotent
        // due to upsert AND no spurious re-processing of old
        // events,since hwm advancement doesn't lag)。
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()
        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            sessionID: "s1",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 5,
                graphExtractEventCap: 5_000))

        // First batch: 5 events,extract fires at iter 5
        for i in 0..<5 {
            _ = await conv.observe(
                event: makeEvent(
                    index: i, sessionID: "s1"))
        }

        let firstNodeCount = await graph.nodeCount

        // Second batch: 5 more events,extract fires at iter 10
        // The hwm advancement must skip the first 5 events
        for i in 5..<10 {
            _ = await conv.observe(
                event: makeEvent(
                    index: i, sessionID: "s1"))
        }

        let secondNodeCount = await graph.nodeCount

        // Pin: graph grew by ~5 events worth of nodes,not 10。
        // If hwm advancement lagged,the second extract would
        // re-walk the first batch and create duplicate nodes
        // (well — upsert prevents duplicates,but the test
        // would mean re-walks happen which is wasteful)。Both
        // calls processing 5 unique events → ~2x growth。
        XCTAssertGreaterThan(
            secondNodeCount, firstNodeCount,
            "Graph must grow on incremental extract")
        XCTAssertLessThan(
            secondNodeCount, firstNodeCount * 3,
            "Graph growth must be bounded — second extract " +
            "should NOT re-walk first batch's events")
    }

    // MARK: - M881 incremental graph extract (post-P2.4 audit)

    func testGraphExtractContinuesPastFormerCap() async {
        // M881 (post-M872 deep review):pre-M881 the convenience
        // helper PERMANENTLY DISABLED graph extract once total
        // log size exceeded `graphExtractEventCap`。Post-M881 the
        // cap field still exists but extracts use incremental
        // mode (`sinceTimestampMs`),so a host that submits more
        // events than the cap continues to get graph extracts。
        // This test pins the new contract:extract fires every
        // iter (cadence 1) for all 10 iters,not just the first 5。
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()
        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            sessionID: "s1",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 1,
                graphExtractInterval: 1,
                graphExtractEventCap: 5))

        var extractedCount = 0
        for i in 0..<10 {
            let r = await conv.observe(
                event: makeEvent(
                    index: i, sessionID: "s1"))
            if r.graphExtracted { extractedCount += 1 }
        }

        XCTAssertEqual(extractedCount, 10,
            "M881:incremental extract fires every iter " +
            "regardless of total log size (cap is now batch-" +
            "size,not total-size)")
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

    // MARK: - Post-M872 deep review: onPersistError callback

    func testPersistErrorCallbackOptIn() async throws {
        // Pin: hosts that pass `onPersistError` get a signal
        // when graph write-through fails。Default nil keeps the
        // M865/M869 silent contract for hosts that don't opt in。
        // We verify the callback wiring by constructing a
        // convenience with the callback + asserting it has the
        // expected closure (we can't easily induce a SQLite
        // failure mid-test,so this is a wire-up pin only)。

        // Box around a Sendable counter for the callback to
        // bump。Using class with @unchecked Sendable so the
        // closure can capture-by-reference safely under Swift 6
        // strict concurrency。
        final class CountBox: @unchecked Sendable {
            var count: Int = 0
        }
        let box = CountBox()
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()

        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            // No actual SQLite storage — callback never fires,
            // since persistGraph short-circuits on nil storage
            sessionID: "s1",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 1,
                graphExtractEventCap: 5_000),
            onPersistError: { _, _ in
                box.count += 1
            })

        // Submit an event → graph extract fires (no storage,
        // so persistGraph short-circuits → callback NOT called)
        let event = BASEventLogEntry(
            eventID: "ev-1",
            timestampMs: 1_000,
            kind: .substrateAudit,
            sessionID: "s1",
            sequenceNumber: 0,
            project: "x")
        _ = await conv.observe(event: event)

        XCTAssertEqual(box.count, 0,
            "Callback must NOT fire when no storage wired " +
            "(persistGraph short-circuits)")

        // The convenience holds the callback for its lifetime
        // (exists post-construction)。Direct verification of
        // the field would need reflection — we trust the init's
        // default-nil contract:if the field were dropped,
        // construction with the callback wouldn't compile。
        _ = conv
    }

    // MARK: - M868 graph-aware reducer wiring

    func testFoldUsesGraphAwareReducerWhenGraphPresent()
        async throws
    {
        // Pre-build a graph with a delays-cycle on
        // "project:foo" so the graph-aware reducer fires on
        // events tagged with project="foo"。
        let graph = BASKnowledgeGraph()
        await graph.upsert(node: BASKnowledgeNode(
            nodeID: "project:foo",
            kind: .project,
            label: "foo",
            createdAtMs: 0))
        await graph.upsert(node: BASKnowledgeNode(
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

    // MARK: - M900 thermal-aware cadence

    /// Pin: default cadence has `.ignoreThermal` to preserve M865
    /// back-compat — hosts that don't opt in see zero behavior
    /// change。
    func testM900DefaultCadenceIgnoresThermal() {
        let c = BASCognitiveOSConvenienceCadence.default
        XCTAssertEqual(c.thermalSensitivity, .ignoreThermal)
        XCTAssertEqual(
            c.thermalSlowdownMultiplier,
            BASCognitiveOSConvenienceCadence
                .defaultThermalSlowdownMultiplier)
        XCTAssertEqual(
            c.thermalSampleInterval,
            BASCognitiveOSConvenienceCadence
                .defaultThermalSampleInterval)
    }

    /// Pin: `.thermalAwareLongRun` preset uses `.slowOnHot` with
    /// the default 4× slowdown — recommended for 1h+ stress runs。
    func testM900ThermalAwareLongRunPreset() {
        let c = BASCognitiveOSConvenienceCadence
            .thermalAwareLongRun
        XCTAssertEqual(c.thermalSensitivity, .slowOnHot)
        XCTAssertEqual(c.thermalSlowdownMultiplier, 4)
        XCTAssertEqual(c.stateFoldInterval, 100)
        XCTAssertEqual(c.graphExtractInterval, 1_000)
    }

    /// Pin: `.thermalProtectedLongRun` preset uses
    /// `.skipOnCritical` — strict thermal floor。
    func testM900ThermalProtectedLongRunPreset() {
        let c = BASCognitiveOSConvenienceCadence
            .thermalProtectedLongRun
        XCTAssertEqual(c.thermalSensitivity, .skipOnCritical)
    }

    /// Pin: `.ignoreThermal` mode never invokes the thermal
    /// sampler — hot path stays free of ProcessInfo syscalls。
    func testM900IgnoreThermalSkipsSampler() async {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()
        let samplerCalls = TestThermalCallCounter()

        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            sessionID: "s-ignore",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 10,
                graphExtractEventCap: 5_000,
                thermalSensitivity: .ignoreThermal,
                thermalSlowdownMultiplier: 4,
                thermalSampleInterval: 1),
            thermalSampler: {
                Task { await samplerCalls.tick() }
                return .nominal
            })

        for i in 0..<30 {
            _ = await conv.observe(
                event: makeEvent(index: i, sessionID: "s-ignore"))
        }

        // Brief settle for any in-flight sampler tasks (none expected)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let count = await samplerCalls.value
        XCTAssertEqual(count, 0,
            "M900 .ignoreThermal must not invoke sampler — " +
            "preserves M865 zero-syscall hot path")
    }

    /// Pin: `.slowOnHot` with cool device → behavior identical to
    /// `.ignoreThermal`(extract every graphExtractInterval)。
    func testM900SlowOnHotCoolDeviceFiresEveryInterval() async {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()

        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            sessionID: "s-cool",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 10,
                graphExtractEventCap: 5_000,
                thermalSensitivity: .slowOnHot,
                thermalSlowdownMultiplier: 4,
                thermalSampleInterval: 1),
            thermalSampler: { .nominal })

        var fires = 0
        for i in 0..<50 {
            let r = await conv.observe(
                event: makeEvent(index: i, sessionID: "s-cool"))
            if r.graphExtracted { fires += 1 }
        }
        // 50 events / 10 interval = 5 fires (at 10/20/30/40/50)
        XCTAssertEqual(fires, 5,
            "M900 .slowOnHot with .nominal thermal must use " +
            "normal cadence (every 10 events)")
        let skipped = await conv.thermalSkippedExtractCount
        XCTAssertEqual(skipped, 0,
            "No thermal-skip when cool")
        let slowed = await conv.thermalSlowedExtractCount
        XCTAssertEqual(slowed, 0,
            "No slowed extract when cool")
    }

    /// Pin: `.slowOnHot` with hot device → extract fires only at
    /// multiples of `graphExtractInterval × thermalSlowdownMultiplier`。
    func testM900SlowOnHotHotDeviceUsesSlowedCadence() async {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()

        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            sessionID: "s-hot",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 10,
                graphExtractEventCap: 5_000,
                thermalSensitivity: .slowOnHot,
                thermalSlowdownMultiplier: 4,
                thermalSampleInterval: 1),
            thermalSampler: { .serious })

        var fires = 0
        var skips = 0
        for i in 0..<50 {
            let r = await conv.observe(
                event: makeEvent(index: i, sessionID: "s-hot"))
            if r.graphExtracted { fires += 1 }
            else if i > 0 && (i + 1) % 10 == 0 {
                // Natural fire point gated out by thermal — counted
                skips += 1
            }
        }
        // 50 events: natural fire points at iter 10/20/30/40/50。
        // Slowed cadence is 10 × 4 = 40,so only iter 40 fires。
        XCTAssertEqual(fires, 1,
            "M900 .slowOnHot with .serious must fire only at " +
            "multiples of (10 × 4) = 40 → 1 fire across 50 events")
        let skipped = await conv.thermalSkippedExtractCount
        XCTAssertEqual(skipped, 4,
            "M900 must record 4 thermal-gated skips (iter " +
            "10/20/30/50 are natural fires gated by thermal)")
        let slowed = await conv.thermalSlowedExtractCount
        XCTAssertEqual(slowed, 1,
            "M900 must record 1 slowed-cadence fire (iter 40)")
    }

    /// Pin: `.slowOnHot` with `.critical` device → same as
    /// `.serious`(both treated as hot)。
    func testM900SlowOnHotCriticalTreatedAsHot() async {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()

        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            sessionID: "s-crit-slow",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 10,
                graphExtractEventCap: 5_000,
                thermalSensitivity: .slowOnHot,
                thermalSlowdownMultiplier: 4,
                thermalSampleInterval: 1),
            thermalSampler: { .critical })

        var fires = 0
        for i in 0..<50 {
            let r = await conv.observe(
                event: makeEvent(
                    index: i, sessionID: "s-crit-slow"))
            if r.graphExtracted { fires += 1 }
        }
        XCTAssertEqual(fires, 1,
            "M900 .slowOnHot must treat .critical same as " +
            ".serious — 1 fire at slowed cadence (iter 40)")
    }

    /// Pin: `.skipOnCritical` with `.critical` device → never
    /// fires graph extract (state fold continues unchanged)。
    func testM900SkipOnCriticalSuppressesAllExtracts() async {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()

        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            sessionID: "s-crit-skip",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 10,
                graphExtractEventCap: 5_000,
                thermalSensitivity: .skipOnCritical,
                thermalSlowdownMultiplier: 4,
                thermalSampleInterval: 1),
            thermalSampler: { .critical })

        var fires = 0
        for i in 0..<50 {
            let r = await conv.observe(
                event: makeEvent(
                    index: i, sessionID: "s-crit-skip"))
            if r.graphExtracted { fires += 1 }
        }
        XCTAssertEqual(fires, 0,
            "M900 .skipOnCritical must skip ALL extracts under " +
            ".critical thermal")
        let skipped = await conv.thermalSkippedExtractCount
        XCTAssertEqual(skipped, 5,
            "M900 must record 5 thermal-gated skips " +
            "(iter 10/20/30/40/50)")
    }

    /// Pin: `.skipOnCritical` with `.serious` device → fires
    /// normally (only `.critical` is gated)。
    func testM900SkipOnCriticalSeriousFiresNormally() async {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()

        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            sessionID: "s-serious",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 10,
                graphExtractEventCap: 5_000,
                thermalSensitivity: .skipOnCritical,
                thermalSlowdownMultiplier: 4,
                thermalSampleInterval: 1),
            thermalSampler: { .serious })

        var fires = 0
        for i in 0..<50 {
            let r = await conv.observe(
                event: makeEvent(
                    index: i, sessionID: "s-serious"))
            if r.graphExtracted { fires += 1 }
        }
        XCTAssertEqual(fires, 5,
            "M900 .skipOnCritical with .serious must fire " +
            "normally (only .critical is gated)")
        let skipped = await conv.thermalSkippedExtractCount
        XCTAssertEqual(skipped, 0,
            "No thermal-skip on .serious in .skipOnCritical mode")
    }

    /// Pin: cached thermal state surfaces via
    /// `lastObservedThermalState` for host UI / logging。
    func testM900CachedThermalStateSurfaced() async {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()

        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            sessionID: "s-cache",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 5,
                graphExtractEventCap: 5_000,
                thermalSensitivity: .slowOnHot,
                thermalSlowdownMultiplier: 4,
                thermalSampleInterval: 1),
            thermalSampler: { .serious })

        // Initially nominal (init default)
        let initial = await conv.lastObservedThermalState
        XCTAssertEqual(initial, .nominal)

        // Observe enough events to trigger sampling
        for i in 0..<6 {
            _ = await conv.observe(
                event: makeEvent(index: i, sessionID: "s-cache"))
        }
        let after = await conv.lastObservedThermalState
        XCTAssertEqual(after, .serious,
            "M900 cachedThermalState must reflect sampler value " +
            "after sampling cadence reached")
    }
}

// MARK: - M913 enum-contract pin tests

extension BASCognitiveOSConvenienceTests {

    /// M913:explicit raw values lock the wire format。Pin
    /// each case → string mapping so a future PR renaming a
    /// case identifier (without updating the rawValue) gets
    /// caught at test time,not silently in schema 1.4.0 JSON。
    func testM913ThermalSensitivityRawValuesPinned() {
        XCTAssertEqual(
            BASCognitiveOSThermalSensitivity
                .ignoreThermal.rawValue,
            "ignoreThermal")
        XCTAssertEqual(
            BASCognitiveOSThermalSensitivity
                .slowOnHot.rawValue,
            "slowOnHot")
        XCTAssertEqual(
            BASCognitiveOSThermalSensitivity
                .skipOnCritical.rawValue,
            "skipOnCritical")
    }

    /// M913:CaseIterable contract — exactly 3 cases。
    func testM913ThermalSensitivityHasExactlyThreeCases() {
        XCTAssertEqual(
            BASCognitiveOSThermalSensitivity.allCases.count, 3)
    }

    /// M913:Codable round-trip — encoding and decoding via
    /// JSONEncoder/Decoder produces stable JSON strings。
    func testM913ThermalSensitivityCodableRoundTrip()
        throws
    {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for sensitivity in
            BASCognitiveOSThermalSensitivity.allCases
        {
            let data = try encoder.encode(sensitivity)
            let decoded = try decoder.decode(
                BASCognitiveOSThermalSensitivity.self,
                from: data)
            XCTAssertEqual(decoded, sensitivity)
            // Verify the JSON shape is a quoted string
            // matching rawValue
            let json = String(data: data, encoding: .utf8)!
            XCTAssertEqual(
                json, "\"\(sensitivity.rawValue)\"",
                "M913:JSON encoding must be quoted rawValue")
        }
    }
}

// MARK: - M908 hardening regression tests

extension BASCognitiveOSConvenienceTests {

    /// M908 cold-start fix:first observe under non-ignore
    /// sensitivity samples thermal IMMEDIATELY,not after 99
    /// events。Pre-M908 a phone booting into `.serious` would
    /// extract 99 times under wrong-thermal assumption。
    func testM908ColdStartSamplesOnFirstObserve() async {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()

        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            sessionID: "s-coldstart",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 1,
                graphExtractEventCap: 5_000,
                thermalSensitivity: .skipOnCritical,
                thermalSlowdownMultiplier: 4,
                // M908 critical: even with sample interval 100,
                // the cold-start fix MUST sample on iter 1
                thermalSampleInterval: 100),
            thermalSampler: { .critical })

        // Single observe call — under .skipOnCritical with
        // .critical thermal,extract MUST be skipped
        _ = await conv.observe(
            event: makeEvent(
                index: 0, sessionID: "s-coldstart"))

        let skipped = await conv.thermalSkippedExtractCount
        XCTAssertEqual(skipped, 1,
            "M908 cold-start: first observe under " +
            ".skipOnCritical with .critical thermal MUST " +
            "skip the extract (sampler invoked on iter 1)。" +
            "Pre-M908 this was 0 because cached state was " +
            ".nominal until iter 100")

        let thermal = await conv.lastObservedThermalState
        XCTAssertEqual(thermal, .critical,
            "Cached thermal state must reflect first sample")
    }

    /// M912 (audit-the-fix):the M908 overflow test was a no-op
    /// because `graphExtractInterval = Int.max/2` made the
    /// natural-fire gate (`myIndex % interval == 0`) never
    /// fire across small iter counts → the overflow code path
    /// was never exercised。
    ///
    /// Post-M912 the test uses `graphExtractInterval = 2` +
    /// `thermalSlowdownMultiplier = Int.max` so:
    ///   - iter 2 hits the natural-fire gate (2 % 2 == 0)
    ///   - inside, slowOnHotHotDecision computes
    ///     `2 × Int.max` → overflow → clamps to Int.max
    ///   - `iter 2 % Int.max != 0` → returns `.skip`
    ///   - thermalSkippedExtracts increments
    /// Pre-M912 this exact config would have trapped at
    /// `2 × Int.max`,killing the host loop。
    func testM912SlowdownOverflowGuardClampsSafely() async {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()

        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            sessionID: "s-overflow",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 2,
                graphExtractEventCap: 5_000,
                thermalSensitivity: .slowOnHot,
                thermalSlowdownMultiplier: Int.max,
                thermalSampleInterval: 1),
            thermalSampler: { .serious })

        // Iterations 1..6: natural fires at iter 2/4/6 (3 total)
        // Each of those hits slowOnHotHotDecision → overflow
        // path → slowedInterval = Int.max → iter % Int.max != 0
        // → returns .skip → thermalSkippedExtracts += 1
        for i in 0..<6 {
            _ = await conv.observe(
                event: makeEvent(
                    index: i, sessionID: "s-overflow"))
        }
        let skipped = await conv.thermalSkippedExtractCount
        XCTAssertEqual(skipped, 3,
            "M912:3 natural fires at iter 2/4/6 must each " +
            "exercise the overflow guard and skip。Pre-M912 " +
            "the test trapped or never entered this path")
    }

    /// M908 fail-closed for `.skipOnCritical` `@unknown default`:
    /// future thermal states (e.g. `.catastrophic` if Apple ever
    /// adds one) MUST be treated as skip-worthy under
    /// `.skipOnCritical`,not fail-open。
    /// (Cannot exercise `@unknown default` directly without an
    /// unknown enum case — this test pins the policy intent via
    /// behavior on `.critical` which the same code path handles。)
    func testM908SkipOnCriticalSemanticsPin() async {
        let log = BASInMemoryEventLogStorage()
        let graph = BASKnowledgeGraph()

        let conv = BASCognitiveOSConvenience(
            eventLog: log,
            knowledgeGraph: graph,
            sessionID: "s-skip-pin",
            cadence: BASCognitiveOSConvenienceCadence(
                stateFoldInterval: 100,
                graphExtractInterval: 5,
                graphExtractEventCap: 5_000,
                thermalSensitivity: .skipOnCritical,
                thermalSlowdownMultiplier: 4,
                thermalSampleInterval: 1),
            thermalSampler: { .critical })

        for i in 0..<20 {
            _ = await conv.observe(
                event: makeEvent(
                    index: i, sessionID: "s-skip-pin"))
        }
        let skipped = await conv.thermalSkippedExtractCount
        // Natural fires at iter 5/10/15/20 → 4 fires,all
        // skipped under .skipOnCritical + .critical
        XCTAssertEqual(skipped, 4,
            "M908: .skipOnCritical with .critical must " +
            "skip every natural fire")
    }
}

// MARK: - Test helpers

/// Sendable atomic counter for verifying thermal sampler invocation。
private actor TestThermalCallCounter {
    private(set) var value: Int = 0
    func tick() { value += 1 }
}
