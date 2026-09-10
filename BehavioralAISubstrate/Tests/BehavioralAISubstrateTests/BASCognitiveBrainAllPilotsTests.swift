// MARK: - BASCognitiveBrainAllPilotsTests
// 主线 加强 实用性: makeWithAllPilots() default-wires
// all 5 native pilots (was 1/5 with makeWithDefaults())。
// Pins:
//   - Default factory yields 5/5 active brain
//   - Repetition signals flow from Rust/SQL to summary
//   - Cross-session echo detection works across two
//     brains sharing one tracker
//   - Cache hit path layers fresh repetition signals
//     onto cached ML classification

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRuntimeCore
@testable import BASRustCoreBridge
@testable import BASMetalSubstrate

final class BASCognitiveBrainAllPilotsTests: XCTestCase {

    // MARK: - Default factory wires all 5

    func testMakeWithAllPilotsActivates5Of5()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let status = await brain.pilotStatus
        XCTAssertTrue(status.allActive,
            "makeWithAllPilots must yield 5/5 active")
        XCTAssertEqual(status.activeCount, 5)
        XCTAssertTrue(status.cActive)
        XCTAssertTrue(status.sqlActive)
        XCTAssertTrue(status.rustActive)
        XCTAssertTrue(status.cxxActive)
        XCTAssertTrue(status.metalActive)
    }

    func testMakeWithAllPilotsForwardsInjectedEventLog()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(eventLog: log)
        let bundle = await brain.bundle
        let actual = try XCTUnwrap(
            bundle.eventLog as? BASInMemoryEventLogStorage)
        XCTAssertTrue(actual === log)
    }

    func testMakeWithDefaultsStillBareBrain() async throws {
        // Backward compat:legacy factory unchanged
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let status = await brain.pilotStatus
        XCTAssertEqual(status.activeCount, 1,
            "makeWithDefaults still wires only C (legacy" +
            " behavior preserved for backward compat)")
    }

    // MARK: - Summary populates repetitionCount

    func testRepetitionCountStartsAtZero() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let summary = await brain.summary(
            "first-time input")
        XCTAssertEqual(summary.repetitionCount, 0,
            "First occurrence → 0 prior repetitions")
        XCTAssertFalse(summary.crossSessionEcho)
    }

    func testRepetitionCountClimbsAcrossRepeats()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let s1 = await brain.summary("repeating input")
        let s2 = await brain.summary("repeating input")
        let s3 = await brain.summary("repeating input")
        XCTAssertEqual(s1.repetitionCount, 0,
            "1st call: no prior")
        XCTAssertEqual(s2.repetitionCount, 1,
            "2nd call: 1 prior")
        XCTAssertEqual(s3.repetitionCount, 2,
            "3rd call: 2 prior")
    }

    func testRepetitionDistinguishesInputs() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        _ = await brain.summary("A")
        _ = await brain.summary("A")
        let bSummary = await brain.summary("B")
        let aAgain = await brain.summary("A")
        XCTAssertEqual(bSummary.repetitionCount, 0,
            "B is first-seen even after 2× A")
        XCTAssertEqual(aAgain.repetitionCount, 2,
            "A has 2 prior occurrences")
    }

    // MARK: - crossSessionEcho across two brains

    func testCrossSessionEchoAcrossTwoBrains() async throws {
        // Two brains share one Rust tracker → distinct
        // sessionRefs。 The same input recorded by both
        // → crossSessionEcho true。
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let store1 = BASRustBrainHistoryStore(
            tracker: tracker)
        let store2 = BASRustBrainHistoryStore(
            tracker: tracker)
        let brainA = try await BASCognitiveBrain
            .makeWithDefaults(rustHistoryStore: store1)
        let brainB = try await BASCognitiveBrain
            .makeWithDefaults(rustHistoryStore: store2)
        // Brain A records the input。
        _ = await brainA.summary("shared input")
        // Brain B records the same input — it should now
        // see crossSessionEcho true。
        let bSummary = await brainB.summary(
            "shared input")
        XCTAssertEqual(bSummary.repetitionCount, 1,
            "Brain B sees 1 prior (from brain A)")
        XCTAssertTrue(bSummary.crossSessionEcho,
            "Two distinct sessionRefs → cross-session" +
            " echo")
    }

    func testNoEchoWithinSingleSession() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        _ = await brain.summary("only one session")
        let again = await brain.summary("only one session")
        XCTAssertEqual(again.repetitionCount, 1)
        XCTAssertFalse(again.crossSessionEcho,
            "Same brain = same sessionRef = no echo")
    }

    // MARK: - Cache hit layers fresh signals

    func testCacheHitLayersFreshRepetitionCount()
        async throws
    {
        // Bring up a brain with C++ + Rust both wired。
        // First call: cache miss → compute,record,cache。
        // Second call: cache hit → still report fresh
        // repetitionCount=1, not the cached 0。
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let first = await brain.summary("cached input")
        let second = await brain.summary("cached input")
        XCTAssertEqual(first.repetitionCount, 0)
        XCTAssertEqual(second.repetitionCount, 1,
            "Cache hit still reports fresh repetition" +
            " count of 1 (1 prior occurrence)")
    }

    func testCacheHitPreservesMLClassification()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let first = await brain.summary("classify me")
        let second = await brain.summary("classify me")
        // ML-derived fields must match (cached parts)
        XCTAssertEqual(first.taskType, second.taskType)
        XCTAssertEqual(first.confidence,
            second.confidence, accuracy: 1e-9)
        XCTAssertEqual(first.safetyVerdict,
            second.safetyVerdict)
        XCTAssertEqual(first.emotionalLoad,
            second.emotionalLoad, accuracy: 1e-9)
        // But repetition counts differ (per-call fields)
        XCTAssertNotEqual(first.repetitionCount,
            second.repetitionCount)
    }

    // MARK: - Backward-compat: bare brain still produces 0

    func testBareBrainAlwaysSeesZeroRepetition()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let s1 = await brain.summary("any input")
        let s2 = await brain.summary("any input")
        let s3 = await brain.summary("any input")
        XCTAssertEqual(s1.repetitionCount, 0)
        XCTAssertEqual(s2.repetitionCount, 0,
            "No history pilot wired → can't count repeats")
        XCTAssertEqual(s3.repetitionCount, 0)
    }

    // MARK: - Summary Codable round-trip with new fields

    func testSummaryCodableRoundTripWithNewFields() throws {
        let original = BASCognitiveBrainSummary(
            input: "x", taskType: .chat,
            confidence: 0.9, ambiguityScore: 0.1,
            safetyVerdict: .safe,
            manipulationHints: [], latencyNanos: 1,
            repetitionCount: 7,
            crossSessionEcho: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASCognitiveBrainSummary.self, from: data)
        XCTAssertEqual(decoded.repetitionCount, 7)
        XCTAssertTrue(decoded.crossSessionEcho)
        XCTAssertEqual(decoded, original)
    }

    func testSummaryBackwardCompatDefaultZero() {
        // Legacy initializer (no new args) defaults to
        // 0 / false for forward-compat with stored
        // historical summaries。
        let s = BASCognitiveBrainSummary(
            input: "x", taskType: .chat,
            confidence: 0.9, ambiguityScore: 0.1,
            safetyVerdict: .safe,
            manipulationHints: [], latencyNanos: 1)
        XCTAssertEqual(s.repetitionCount, 0)
        XCTAssertFalse(s.crossSessionEcho)
    }

    // MARK: - withNativePilotSignals reconstructor

    func testWithNativePilotSignalsRebuildsSummary() {
        let base = BASCognitiveBrainSummary(
            input: "x", taskType: .chat,
            confidence: 0.5, ambiguityScore: 0.5,
            safetyVerdict: .warn,
            manipulationHints: ["test"],
            latencyNanos: 999,
            repetitionCount: 0,
            crossSessionEcho: false)
        let layered = base.withNativePilotSignals(
            repetitionCount: 42,
            crossSessionEcho: true)
        XCTAssertEqual(layered.input, base.input)
        XCTAssertEqual(layered.confidence, base.confidence)
        XCTAssertEqual(layered.manipulationHints,
            base.manipulationHints)
        XCTAssertEqual(layered.latencyNanos,
            base.latencyNanos)
        // New fields swapped in
        XCTAssertEqual(layered.repetitionCount, 42)
        XCTAssertTrue(layered.crossSessionEcho)
    }
}
