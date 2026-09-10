// MARK: - BASCognitiveOSBuilderTests — chapter 三百七二 / M859
//
// Test coverage for the cognitive OS bundle + builder。
// Closes M858 audit gap H2: M841-M858 primitives now have a
// single-call factory entry point。
//
// Tests verify:
//   - Default options → empty bundle (zero behavior change pin)
//   - Each flag enables exactly its primitive
//   - SQLite URL switches between in-memory + persistent
//   - Cross-primitive composition works
//   - Bundle convenience: populatedCount, isEmpty

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore

final class BASCognitiveOSBuilderTests: XCTestCase {

    private var tempDir: URL?

    override func setUpWithError() throws {
        tempDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "qinao-cognitive-os-test-\(UUID().uuidString)",
                isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDir!,
            withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Default → empty bundle (ADR-014 OPT-IN pin)

    func testDefaultOptionsReturnsEmptyBundle() throws {
        let bundle = try BASCognitiveOSBuilder.build(
            options: .allDisabled)
        XCTAssertTrue(
            bundle.isEmpty,
            "Default options must produce empty bundle " +
            "(ADR-014 OPT-IN pin: zero behavior change " +
            "for hosts that don't opt in)")
        XCTAssertEqual(bundle.populatedCount, 0)
        XCTAssertNil(bundle.eventLog)
        XCTAssertNil(bundle.userStateStore)
        XCTAssertNil(bundle.vectorIndex)
        XCTAssertNil(bundle.vectorIndexStorage)
        XCTAssertNil(bundle.knowledgeGraph)
    }

    func testInjectedEventLogSurvivesBothEmptyShortcutsByIdentity() throws {
        let log = BASInMemoryEventLogStorage()
        let first = try BASCognitiveOSBuilder.build(
            options: .allDisabled, eventLog: log)
        let second = try BASCognitiveOSBuilder.build(
            options: .allDisabled,
            embeddingProvider: nil,
            eventLog: log)
        for bundle in [first, second] {
            XCTAssertEqual(bundle.populatedCount, 1)
            let actual = try XCTUnwrap(
                bundle.eventLog
                    as? BASInMemoryEventLogStorage)
            XCTAssertTrue(actual === log)
        }
    }

    func testInjectedEventLogOverridesSQLiteURLWithoutOpeningIt() throws {
        let url = try XCTUnwrap(tempDir)
            .appendingPathComponent(
                "missing/events.sqlite")
        let log = BASInMemoryEventLogStorage()
        for enabled in [false, true] {
            let bundle = try BASCognitiveOSBuilder.build(
                options: BASCognitiveOSBundleOptions(
                    enableEventLog: enabled,
                    eventLogSQLiteURL: url),
                eventLog: log)
            let actual = try XCTUnwrap(
                bundle.eventLog
                    as? BASInMemoryEventLogStorage)
            XCTAssertTrue(actual === log)
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: url.path))
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: url.deletingLastPathComponent()
                        .path))
        }
    }

    func testEmptyBundleConvenience() {
        let bundle = BASCognitiveOSBundle.empty
        XCTAssertTrue(bundle.isEmpty)
        XCTAssertEqual(bundle.populatedCount, 0)
    }

    // MARK: - Each flag enables exactly its primitive

    func testEnableEventLogInMemory() throws {
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true))
        XCTAssertNotNil(bundle.eventLog)
        XCTAssertNil(bundle.userStateStore)
        XCTAssertNil(bundle.vectorIndex)
        XCTAssertNil(bundle.knowledgeGraph)
        // In-memory conformer when no URL passed
        XCTAssertTrue(
            bundle.eventLog is BASInMemoryEventLogStorage,
            "No SQLite URL → in-memory conformer")
    }

    func testEnableEventLogSQLite() throws {
        let url = try XCTUnwrap(tempDir)
            .appendingPathComponent("events.sqlite")
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true,
                eventLogSQLiteURL: url))
        XCTAssertNotNil(bundle.eventLog)
        XCTAssertTrue(
            bundle.eventLog is BASSQLiteEventLogStorage,
            "SQLite URL → SQLite-backed conformer")
    }

    func testEnableUserStateInMemory() throws {
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableUserState: true))
        XCTAssertNotNil(bundle.userStateStore)
        XCTAssertTrue(
            bundle.userStateStore
                is BASInMemoryUserStateStorage)
    }

    func testEnableUserStateSQLite() throws {
        let url = try XCTUnwrap(tempDir)
            .appendingPathComponent("state.sqlite")
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableUserState: true,
                userStateSQLiteURL: url))
        XCTAssertNotNil(bundle.userStateStore)
        XCTAssertTrue(
            bundle.userStateStore
                is BASSQLiteUserStateStorage)
    }

    func testEnableVectorIndexInMemoryOnly() throws {
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableVectorIndex: true))
        XCTAssertNotNil(bundle.vectorIndex)
        XCTAssertNil(
            bundle.vectorIndexStorage,
            "No SQLite URL → no persistence sibling")
    }

    func testEnableVectorIndexWithSQLitePersistence()
        throws
    {
        let url = try XCTUnwrap(tempDir)
            .appendingPathComponent("vectors.sqlite")
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableVectorIndex: true,
                vectorIndexSQLiteURL: url))
        XCTAssertNotNil(bundle.vectorIndex)
        XCTAssertNotNil(
            bundle.vectorIndexStorage,
            "SQLite URL → both vectorIndex + storage " +
            "primitives populated for preload pattern")
    }

    func testEnableKnowledgeGraph() throws {
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableKnowledgeGraph: true))
        XCTAssertNotNil(bundle.knowledgeGraph)
        XCTAssertNil(
            bundle.knowledgeGraphStorage,
            "No SQLite URL → no persistence sibling (M866)")
    }

    func testEnableKnowledgeGraphWithSQLitePersistence()
        throws
    {
        let url = try XCTUnwrap(tempDir)
            .appendingPathComponent("graph.sqlite")
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableKnowledgeGraph: true,
                knowledgeGraphSQLiteURL: url))
        XCTAssertNotNil(bundle.knowledgeGraph)
        XCTAssertNotNil(
            bundle.knowledgeGraphStorage,
            "SQLite URL → both knowledge graph + storage " +
            "primitives populated for preload pattern (M866)")
    }

    // MARK: - Cross-primitive composition

    func testAllPrimitivesEnabled() throws {
        let url = try XCTUnwrap(tempDir)
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true,
                eventLogSQLiteURL:
                    url.appendingPathComponent(
                        "events.sqlite"),
                enableUserState: true,
                userStateSQLiteURL:
                    url.appendingPathComponent(
                        "state.sqlite"),
                enableVectorIndex: true,
                vectorIndexSQLiteURL:
                    url.appendingPathComponent(
                        "vectors.sqlite"),
                enableKnowledgeGraph: true,
                knowledgeGraphSQLiteURL:
                    url.appendingPathComponent(
                        "graph.sqlite")))
        XCTAssertEqual(
            bundle.populatedCount, 6,
            "All 6 primitive slots populated " +
            "(event log + user state + vector index + " +
            "vector storage + knowledge graph + " +
            "knowledge graph storage — M866 added the 6th slot)")
        XCTAssertFalse(bundle.isEmpty)
        XCTAssertNotNil(bundle.eventLog)
        XCTAssertNotNil(bundle.userStateStore)
        XCTAssertNotNil(bundle.vectorIndex)
        XCTAssertNotNil(bundle.vectorIndexStorage)
        XCTAssertNotNil(bundle.knowledgeGraph)
        XCTAssertNotNil(bundle.knowledgeGraphStorage)
    }

    func testEnableTwoPrimitivesProducesTwo() throws {
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true,
                enableKnowledgeGraph: true))
        XCTAssertEqual(bundle.populatedCount, 2)
        XCTAssertNotNil(bundle.eventLog)
        XCTAssertNil(bundle.userStateStore)
        XCTAssertNil(bundle.vectorIndex)
        XCTAssertNotNil(bundle.knowledgeGraph)
    }

    // MARK: - Functional smoke (post-build, primitives work)

    func testEventLogAcceptsAppendPostBuild() async throws {
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true))
        let log = try XCTUnwrap(bundle.eventLog)
        let entry = BASEventLogEntry(
            eventID: "test-1",
            timestampMs: 1_700_000_000_000,
            kind: .chat,
            sessionID: "s",
            sequenceNumber: 0)
        let result = try await log.append(entry)
        XCTAssertTrue(result.wasNew)
        let count = await log.totalCount
        XCTAssertEqual(count, 1)
    }

    func testKnowledgeGraphAcceptsInsertPostBuild()
        async throws
    {
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableKnowledgeGraph: true))
        let graph = try XCTUnwrap(bundle.knowledgeGraph)
        try await graph.insert(node: BASKnowledgeNode(
            nodeID: "n1",
            kind: .event,
            label: "test",
            createdAtMs: 0))
        let count = await graph.nodeCount
        XCTAssertEqual(count, 1)
    }

    // MARK: - Bundle convenience pins

    func testPopulatedCountAccurate() throws {
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true,
                enableUserState: true,
                enableKnowledgeGraph: true))
        XCTAssertEqual(bundle.populatedCount, 3)
    }

    func testIsEmptyOnlyTrueWhenZeroPopulated() throws {
        let empty = try BASCognitiveOSBuilder.build(
            options: .allDisabled)
        XCTAssertTrue(empty.isEmpty)
        let oneEnabled = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true))
        XCTAssertFalse(oneEnabled.isEmpty)
    }

    // MARK: - M889 query API (chapter 三百九〇)

    func testEmptyBundleSnapshotIsAllZero() async throws {
        let bundle = BASCognitiveOSBundle.empty
        let snap = await bundle.snapshot()
        XCTAssertEqual(snap.eventCount, 0)
        XCTAssertEqual(snap.stateCount, 0)
        XCTAssertEqual(snap.graphNodeCount, 0)
        XCTAssertEqual(snap.graphEdgeCount, 0)
        XCTAssertEqual(snap.populatedSlotCount, 0)
    }

    func testSnapshotReportsActualPrimitiveCounts()
        async throws
    {
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true,
                enableUserState: true,
                enableKnowledgeGraph: true))
        // Empty stores → all zeros except slot count
        let snap = await bundle.snapshot()
        XCTAssertEqual(snap.eventCount, 0)
        XCTAssertEqual(snap.stateCount, 0)
        XCTAssertEqual(snap.graphNodeCount, 0)
        XCTAssertEqual(snap.graphEdgeCount, 0)
        XCTAssertEqual(snap.populatedSlotCount, 3)
    }

    func testDetectComplexityLoopsEmptyGraph() async throws {
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableKnowledgeGraph: true))
        let loops = await bundle.detectComplexityLoops()
        XCTAssertTrue(loops.isEmpty,
            "Empty graph must return empty loop list")
    }

    func testDetectComplexityLoopsNoGraphConfigured()
        async
    {
        let bundle = BASCognitiveOSBundle.empty
        let loops = await bundle.detectComplexityLoops()
        XCTAssertTrue(loops.isEmpty,
            "Bundle without graph wired returns empty list,not nil")
    }

    func testDetectComplexityLoopsFindsDelaysCycle()
        async throws
    {
        let bundle = try BASCognitiveOSBuilder.build(
            options: BASCognitiveOSBundleOptions(
                enableKnowledgeGraph: true))
        let graph = try XCTUnwrap(bundle.knowledgeGraph)

        // Build a 2-node cycle:project ⇄ event with delays edge
        await graph.upsert(node: BASKnowledgeNode(
            nodeID: "project:foo",
            kind: .project, label: "foo",
            createdAtMs: 0))
        await graph.upsert(node: BASKnowledgeNode(
            nodeID: "ev1",
            kind: .event, label: "e1",
            createdAtMs: 0))
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "e1",
            fromNodeID: "project:foo",
            toNodeID: "ev1",
            kind: .delays,
            createdAtMs: 0))
        try await graph.insert(edge: BASKnowledgeEdge(
            edgeID: "e2",
            fromNodeID: "ev1",
            toNodeID: "project:foo",
            kind: .causes,
            createdAtMs: 0))

        let loops = await bundle.detectComplexityLoops()
        XCTAssertFalse(loops.isEmpty,
            "Cycle containing delays edge must be detected")
        XCTAssertTrue(
            loops.first?.containsEdgeKind(.delays) ?? false,
            "Returned cycles must include delays edges per " +
            "user-vision §10 doctrine")
    }

    // MARK: - Equatable options pin

    func testOptionsAllDisabledEquatable() {
        XCTAssertEqual(
            BASCognitiveOSBundleOptions.allDisabled,
            BASCognitiveOSBundleOptions())
    }

    func testOptionsDifferingFlagsNotEqual() {
        let a = BASCognitiveOSBundleOptions(
            enableEventLog: true)
        let b = BASCognitiveOSBundleOptions(
            enableEventLog: false)
        XCTAssertNotEqual(a, b)
    }
}
