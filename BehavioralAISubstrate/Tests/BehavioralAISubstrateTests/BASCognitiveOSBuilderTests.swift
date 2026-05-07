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
                enableKnowledgeGraph: true))
        XCTAssertEqual(
            bundle.populatedCount, 5,
            "All 5 primitive slots populated " +
            "(event log + user state + vector index + " +
            "vector storage + knowledge graph)")
        XCTAssertFalse(bundle.isEmpty)
        XCTAssertNotNil(bundle.eventLog)
        XCTAssertNotNil(bundle.userStateStore)
        XCTAssertNotNil(bundle.vectorIndex)
        XCTAssertNotNil(bundle.vectorIndexStorage)
        XCTAssertNotNil(bundle.knowledgeGraph)
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
