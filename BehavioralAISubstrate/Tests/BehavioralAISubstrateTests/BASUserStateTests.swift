// MARK: - BASUserStateTests — chapter 三百五五 / M842
//
// Test coverage for G2 deliverable from M840 roadmap:
//   - BASUserState clamp invariants + Codable + array bounds
//   - BASUserStateReducer determinism + clamp + EMA decay +
//     project momentum + memory heat + risk trend + complexity
//     addiction detection
//   - BASUserStateStore append + idempotent + latest-for-session
//   - SQLite cross-session persistence (chapter 二百四十八 idiom)
//   - Replay integration (G1 BASEventReplayRunner) — fold events
//     through reducer to produce final state

import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASUserStateTests: XCTestCase {

    // MARK: - Test fixtures

    private var tempURL: URL?

    override func setUpWithError() throws {
        tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "qinao-userstate-test-\(UUID().uuidString)" +
                ".sqlite")
    }

    override func tearDownWithError() throws {
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-wal"))
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-shm"))
        }
    }

    private func makeEvent(
        eventID: String = UUID().uuidString,
        timestampMs: Int64 = 1_700_000_000_000,
        kind: BASEventLogKind = .chat,
        sessionID: String = "test-ssn",
        sequenceNumber: Int64 = 0,
        emotion: String? = "calm",
        riskBand: BASEventLogRiskBand = .low,
        project: String? = "test-project",
        memoryRefs: [String] = [],
        actions: [String] = []
    ) -> BASEventLogEntry {
        BASEventLogEntry(
            eventID: eventID,
            timestampMs: timestampMs,
            kind: kind,
            sessionID: sessionID,
            sequenceNumber: sequenceNumber,
            emotion: emotion,
            riskBand: riskBand,
            project: project,
            memoryRefs: memoryRefs,
            actions: actions)
    }

    // MARK: - BASUserState shape

    func testZeroStateAllZeroFields() {
        let zero = BASUserState.zero
        XCTAssertEqual(zero.emotionalTrend, 0)
        XCTAssertEqual(zero.projectMomentum, 0)
        XCTAssertEqual(zero.memoryHeat, 0)
        XCTAssertEqual(zero.riskTrend, 0)
        XCTAssertEqual(zero.complexityAddictionScore, 0)
        XCTAssertEqual(zero.agentRouteHistory, [])
        XCTAssertEqual(zero.lastNEventKinds, [])
        XCTAssertTrue(zero.isZero)
    }

    func testStateClampsSignedTendenciesToMinusOnePlusOne() {
        let above = BASUserState(
            stateID: "id-1",
            generatedAtMs: 0,
            emotionalTrend: 5.0,
            projectMomentum: 3.0,
            memoryHeat: 0.5,
            riskTrend: 99.0,
            complexityAddictionScore: 0.5,
            agentRouteHistory: [],
            lastNEventKinds: [])
        XCTAssertEqual(above.emotionalTrend, 1.0)
        XCTAssertEqual(above.projectMomentum, 1.0)
        XCTAssertEqual(above.riskTrend, 1.0)

        let below = BASUserState(
            stateID: "id-2",
            generatedAtMs: 0,
            emotionalTrend: -5.0,
            projectMomentum: -3.0,
            memoryHeat: 0.5,
            riskTrend: -99.0,
            complexityAddictionScore: 0.5,
            agentRouteHistory: [],
            lastNEventKinds: [])
        XCTAssertEqual(below.emotionalTrend, -1.0)
        XCTAssertEqual(below.projectMomentum, -1.0)
        XCTAssertEqual(below.riskTrend, -1.0)
    }

    func testStateClampsUnsignedScoresToZeroOne() {
        let above = BASUserState(
            stateID: "id-1",
            generatedAtMs: 0,
            emotionalTrend: 0,
            projectMomentum: 0,
            memoryHeat: 5.0,
            riskTrend: 0,
            complexityAddictionScore: 9.0,
            agentRouteHistory: [],
            lastNEventKinds: [])
        XCTAssertEqual(above.memoryHeat, 1.0)
        XCTAssertEqual(above.complexityAddictionScore, 1.0)

        let below = BASUserState(
            stateID: "id-2",
            generatedAtMs: 0,
            emotionalTrend: 0,
            projectMomentum: 0,
            memoryHeat: -1.0,
            riskTrend: 0,
            complexityAddictionScore: -2.0,
            agentRouteHistory: [],
            lastNEventKinds: [])
        XCTAssertEqual(below.memoryHeat, 0.0)
        XCTAssertEqual(below.complexityAddictionScore, 0.0)
    }

    func testStateBoundsAgentRouteHistoryAndEventKinds() {
        let state = BASUserState(
            stateID: "id-1",
            generatedAtMs: 0,
            emotionalTrend: 0, projectMomentum: 0,
            memoryHeat: 0, riskTrend: 0,
            complexityAddictionScore: 0,
            agentRouteHistory: ["a", "b", "c", "d", "e"],
            lastNEventKinds: Array(
                repeating: "chat", count: 50))
        XCTAssertEqual(
            state.agentRouteHistory.count,
            BASUserState.agentRouteHistoryCap,
            "agentRouteHistory must be capped at " +
            "agentRouteHistoryCap (3)")
        XCTAssertEqual(
            state.lastNEventKinds.count,
            BASUserState.lastNEventKindsCap,
            "lastNEventKinds must be capped at " +
            "lastNEventKindsCap (10)")
    }

    func testStateCodableRoundTrip() throws {
        let original = BASUserState(
            stateID: "round-trip",
            generatedAtMs: 1_700_000_000_000,
            emotionalTrend: 0.45,
            projectMomentum: -0.3,
            memoryHeat: 0.8,
            riskTrend: 0.2,
            complexityAddictionScore: 0.75,
            agentRouteHistory: ["single-llm"],
            lastNEventKinds: ["chat", "voice"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASUserState.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testStateConvenienceThresholds() {
        let elevated = BASUserState(
            stateID: "ce", generatedAtMs: 0,
            emotionalTrend: 0, projectMomentum: 0,
            memoryHeat: 0, riskTrend: 0,
            complexityAddictionScore: 0.7,
            agentRouteHistory: [], lastNEventKinds: [])
        XCTAssertTrue(elevated.isComplexityAddictionElevated)

        let stalling = BASUserState(
            stateID: "ps", generatedAtMs: 0,
            emotionalTrend: 0, projectMomentum: -0.5,
            memoryHeat: 0, riskTrend: 0,
            complexityAddictionScore: 0,
            agentRouteHistory: [], lastNEventKinds: [])
        XCTAssertTrue(stalling.isProjectStalling)

        let riskUp = BASUserState(
            stateID: "ru", generatedAtMs: 0,
            emotionalTrend: 0, projectMomentum: 0,
            memoryHeat: 0, riskTrend: 0.5,
            complexityAddictionScore: 0,
            agentRouteHistory: [], lastNEventKinds: [])
        XCTAssertTrue(riskUp.isRiskTrendingUp)
    }

    // MARK: - BASUserStateReducer

    func testReducerProducesNewStateID() {
        let event = makeEvent()
        let next = BASUserStateReducer.reduce(
            prior: .zero,
            event: event,
            newStateID: "new-state-id",
            generatedAtMs: 1_000)
        XCTAssertEqual(next.stateID, "new-state-id")
        XCTAssertEqual(next.generatedAtMs, 1_000)
    }

    func testReducerEMAOnEmotionalTrend() {
        // Single anxious event: trend should move toward -0.5
        // (mapped delta) at rate (1 - decay) = 0.3
        let event = makeEvent(emotion: "anxious")
        let next = BASUserStateReducer.reduce(
            prior: .zero,
            event: event,
            newStateID: "s1",
            generatedAtMs: 0)
        // 0 * 0.7 + (-0.5) * 0.3 = -0.15
        XCTAssertEqual(
            next.emotionalTrend, -0.15, accuracy: 1e-9)
    }

    func testReducerProjectMomentumAdvancesOnPermitAnswer() {
        let event = makeEvent(
            actions: ["permit:answer"])
        let next = BASUserStateReducer.reduce(
            prior: .zero,
            event: event,
            newStateID: "s1",
            generatedAtMs: 0)
        XCTAssertEqual(
            next.projectMomentum,
            BASUserStateReducer.projectMomentumStep,
            accuracy: 1e-9)
    }

    func testReducerProjectMomentumStallsOnSkip() {
        let event = makeEvent(
            actions: ["skip:thermal-pause"])
        let next = BASUserStateReducer.reduce(
            prior: .zero,
            event: event,
            newStateID: "s1",
            generatedAtMs: 0)
        XCTAssertEqual(
            next.projectMomentum,
            -BASUserStateReducer.projectMomentumStep,
            accuracy: 1e-9)
    }

    func testReducerProjectMomentumIgnoredWhenNoProject() {
        let event = makeEvent(
            project: nil,
            actions: ["permit:answer"])
        let next = BASUserStateReducer.reduce(
            prior: .zero,
            event: event,
            newStateID: "s1",
            generatedAtMs: 0)
        XCTAssertEqual(
            next.projectMomentum, 0, accuracy: 1e-9,
            "Events without a project tag must not " +
            "shift projectMomentum")
    }

    func testReducerMemoryHeatGainsOnRefHit() {
        let event = makeEvent(memoryRefs: ["mem-1"])
        let next = BASUserStateReducer.reduce(
            prior: .zero, event: event,
            newStateID: "s1", generatedAtMs: 0)
        XCTAssertEqual(
            next.memoryHeat,
            BASUserStateReducer.memoryHeatGainStep,
            accuracy: 1e-9)
    }

    func testReducerMemoryHeatDecaysOnRefMiss() {
        let warm = BASUserState(
            stateID: "warm", generatedAtMs: 0,
            emotionalTrend: 0, projectMomentum: 0,
            memoryHeat: 0.5, riskTrend: 0,
            complexityAddictionScore: 0,
            agentRouteHistory: [], lastNEventKinds: [])
        let event = makeEvent(memoryRefs: [])
        let next = BASUserStateReducer.reduce(
            prior: warm, event: event,
            newStateID: "s1", generatedAtMs: 0)
        XCTAssertEqual(
            next.memoryHeat,
            0.5 - BASUserStateReducer.memoryHeatDecayStep,
            accuracy: 1e-9)
    }

    func testReducerRiskTrendEMAOnHighEvent() {
        let event = makeEvent(riskBand: .high)
        let next = BASUserStateReducer.reduce(
            prior: .zero, event: event,
            newStateID: "s1", generatedAtMs: 0)
        // 0 * 0.85 + 0.05 * 0.15 = 0.0075
        XCTAssertEqual(
            next.riskTrend, 0.0075, accuracy: 1e-9)
    }

    func testReducerLastNEventKindsPrepended() {
        let event = makeEvent(kind: .voice)
        let next = BASUserStateReducer.reduce(
            prior: .zero, event: event,
            newStateID: "s1", generatedAtMs: 0)
        XCTAssertEqual(
            next.lastNEventKinds.first,
            BASEventLogKind.voice.rawValue,
            "Most recent kind must be at index 0")
    }

    func testReducerAgentRouteHistoryFromDispatchAction() {
        let event = makeEvent(
            actions: ["dispatch:single-llm"])
        let next = BASUserStateReducer.reduce(
            prior: .zero, event: event,
            newStateID: "s1", generatedAtMs: 0)
        XCTAssertEqual(
            next.agentRouteHistory.first, "single-llm")
    }

    func testReducerComplexityAddictionGainsOnInputLoop() {
        // Prior state has 5 input-class kinds in history,
        // tagged project → next event should add to score
        let prior = BASUserState(
            stateID: "p", generatedAtMs: 0,
            emotionalTrend: 0, projectMomentum: 0,
            memoryHeat: 0, riskTrend: 0,
            complexityAddictionScore: 0.3,
            agentRouteHistory: [],
            lastNEventKinds: [
                "chat", "chat", "voice", "file", "chat"])
        let event = makeEvent(
            project: "stuck-project",
            actions: [])  // no commit-class action
        let next = BASUserStateReducer.reduce(
            prior: prior, event: event,
            newStateID: "s1", generatedAtMs: 0)
        XCTAssertEqual(
            next.complexityAddictionScore,
            0.3 + BASUserStateReducer
                .complexityAddictionGainStep,
            accuracy: 1e-9)
    }

    func testReducerComplexityAddictionDecaysOnCommit() {
        let prior = BASUserState(
            stateID: "p", generatedAtMs: 0,
            emotionalTrend: 0, projectMomentum: 0,
            memoryHeat: 0, riskTrend: 0,
            complexityAddictionScore: 0.5,
            agentRouteHistory: [], lastNEventKinds: [])
        let event = makeEvent(
            actions: ["permit:answer"])
        let next = BASUserStateReducer.reduce(
            prior: prior, event: event,
            newStateID: "s1", generatedAtMs: 0)
        XCTAssertEqual(
            next.complexityAddictionScore,
            0.5 - BASUserStateReducer
                .complexityAddictionDecayStep,
            accuracy: 1e-9)
    }

    func testReducerDeterminism() {
        let event = makeEvent()
        let a = BASUserStateReducer.reduce(
            prior: .zero, event: event,
            newStateID: "fixed", generatedAtMs: 1_000)
        let b = BASUserStateReducer.reduce(
            prior: .zero, event: event,
            newStateID: "fixed", generatedAtMs: 1_000)
        XCTAssertEqual(a, b,
            "Reducer must be deterministic — same input " +
            "always produces same output")
    }

    // MARK: - BASUserStateStore (in-memory)

    func testInMemoryStoreAppendThenReadByID() async throws {
        let store = BASInMemoryUserStateStorage()
        let state = BASUserState(
            stateID: "fetch-by-id",
            generatedAtMs: 1_000,
            emotionalTrend: 0.2,
            projectMomentum: 0.1,
            memoryHeat: 0.5,
            riskTrend: 0.3,
            complexityAddictionScore: 0.4,
            agentRouteHistory: [],
            lastNEventKinds: [])
        try await store.append(state, sessionID: "ssn-A")
        let read = await store.state(forID: "fetch-by-id")
        XCTAssertEqual(read, state)
    }

    func testInMemoryStoreLatestForSession() async throws {
        let store = BASInMemoryUserStateStorage()
        for i in 0..<5 {
            let s = BASUserState(
                stateID: "s\(i)",
                generatedAtMs: 1_000 + Int64(i),
                emotionalTrend: 0,
                projectMomentum: 0,
                memoryHeat: Double(i) * 0.1,
                riskTrend: 0,
                complexityAddictionScore: 0,
                agentRouteHistory: [], lastNEventKinds: [])
            try await store.append(s, sessionID: "ssn-A")
        }
        let latest = await store.latestState(
            forSession: "ssn-A")
        XCTAssertEqual(latest?.stateID, "s4",
            "Latest state must be the highest generatedAtMs")
    }

    func testInMemoryStoreIdempotentAppend() async throws {
        let store = BASInMemoryUserStateStorage()
        let s = BASUserState(
            stateID: "dup", generatedAtMs: 0,
            emotionalTrend: 0, projectMomentum: 0,
            memoryHeat: 0, riskTrend: 0,
            complexityAddictionScore: 0,
            agentRouteHistory: [], lastNEventKinds: [])
        let first = try await store.append(
            s, sessionID: "x")
        let second = try await store.append(
            s, sessionID: "x")
        XCTAssertTrue(first)
        XCTAssertFalse(second)
        let count = await store.totalCount
        XCTAssertEqual(count, 1)
    }

    // MARK: - BASUserStateStore (SQLite)

    func testSQLiteStoreAppendAndFetch() async throws {
        let url = try XCTUnwrap(tempURL)
        let store = try BASSQLiteUserStateStorage(
            databaseURL: url)
        let s = BASUserState(
            stateID: "sqlite-1",
            generatedAtMs: 1_000,
            emotionalTrend: 0.1,
            projectMomentum: 0.2,
            memoryHeat: 0.3,
            riskTrend: 0.4,
            complexityAddictionScore: 0.5,
            agentRouteHistory: ["single-llm"],
            lastNEventKinds: ["chat"])
        try await store.append(s, sessionID: "ssn-X")
        let read = await store.state(forID: "sqlite-1")
        XCTAssertEqual(read, s)
    }

    func testSQLiteStoreCrossSessionPersistence() async throws {
        let url = try XCTUnwrap(tempURL)
        let original: BASUserState
        do {
            let store = try BASSQLiteUserStateStorage(
                databaseURL: url)
            original = BASUserState(
                stateID: "persist",
                generatedAtMs: 1_000,
                emotionalTrend: 0.5,
                projectMomentum: -0.3,
                memoryHeat: 0.8,
                riskTrend: 0.2,
                complexityAddictionScore: 0.6,
                agentRouteHistory: ["local-only"],
                lastNEventKinds: ["chat", "voice"])
            try await store.append(
                original, sessionID: "ssn-persist")
        }
        // Reopen
        let reopened = try BASSQLiteUserStateStorage(
            databaseURL: url)
        let restored = await reopened.state(
            forID: "persist")
        XCTAssertEqual(
            restored, original,
            "User state must round-trip byte-equal across " +
            "process restart (chapter 二百四十八 idiom)")
    }

    func testSQLiteSchemaVersionPin() {
        XCTAssertEqual(
            BASSQLiteUserStateStorage.schemaVersion, 1,
            "Schema version pin: bump triggers explicit " +
            "migration review")
    }

    // MARK: - Replay integration (G1 + G2 composed)

    /// Architectural pin: G2 reducer + G1 event log + replay
    /// runner compose end-to-end。Walking events through reducer
    /// rebuilds the exact same state vector at each step。
    func testReducerPlusReplayProducesDeterministicState()
        async throws
    {
        let log = BASInMemoryEventLogStorage()
        // Seed events
        let now: Int64 = 1_000_000
        for i in 0..<10 {
            _ = try await log.append(BASEventLogEntry(
                eventID: "e\(i)",
                timestampMs: now + Int64(i),
                kind: .chat,
                sessionID: "replay-ssn",
                sequenceNumber: 0,  // overwritten by storage
                emotion: i % 2 == 0 ? "calm" : "anxious",
                riskBand: .low,
                project: "replay-project",
                memoryRefs: i % 3 == 0 ? ["mem-x"] : [],
                actions: ["permit:answer"]))
        }
        // Replay through reducer
        let result = await BASEventReplayRunner
            .replaySession(
                storage: log,
                sessionID: "replay-ssn",
                initial: BASUserState.zero
            ) { prior, event in
                BASUserStateReducer.reduce(
                    prior: prior,
                    event: event,
                    newStateID: "replay-\(event.eventID)",
                    generatedAtMs: event.timestampMs)
            }
        XCTAssertEqual(result.eventsConsumed, 10)
        // After 10 events with permit:answer, momentum trended +
        // emotion EMA should be in [-1, 1]
        XCTAssertGreaterThan(
            result.finalState.projectMomentum, 0,
            "10 events with permit:answer should trend " +
            "projectMomentum positive")
        XCTAssertGreaterThanOrEqual(
            result.finalState.emotionalTrend, -1)
        XCTAssertLessThanOrEqual(
            result.finalState.emotionalTrend, 1)
        // Idempotent re-replay must produce identical state
        let result2 = await BASEventReplayRunner
            .replaySession(
                storage: log,
                sessionID: "replay-ssn",
                initial: BASUserState.zero
            ) { prior, event in
                BASUserStateReducer.reduce(
                    prior: prior,
                    event: event,
                    newStateID: "replay-\(event.eventID)",
                    generatedAtMs: event.timestampMs)
            }
        XCTAssertEqual(
            result.finalState, result2.finalState,
            "Replay must be deterministic across runs")
    }
}
