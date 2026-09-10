// MARK: - BASBiomimeticCheckpointReplayTests
// chapter 四百六十八 / M1250 PROOF tests
//
// Verifies the replay-side recovery surface closes
// the cross-session biomimetic-state loop:
//
//   chapter 467:engine auto-emits checkpoint events
//        ↓ (event log)
//   chapter 468:replay namespace restores observer
//                state on a new session
//
// Tests use chapter 462 BASCoordinatorTestStubs +
// BASInMemoryEventLogStorage for end-to-end emit ←
// → restore proofs。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASBiomimeticCheckpointReplayTests: XCTestCase
{

    // MARK: - 1. Empty log returns nil

    func testLatestCheckpointReturnsNilForEmptyLog()
        async throws
    {
        let eventLog = BASInMemoryEventLogStorage()
        let result = await BASBiomimeticCheckpointReplay
            .latestCheckpoint(
                in: eventLog,
                sessionID: "any-session")
        XCTAssertNil(result,
            "no entries → no checkpoint")
    }

    // MARK: - 2. Log with non-checkpoint entries returns nil

    func testLatestCheckpointReturnsNilWhenOnlyOtherKinds()
        async throws
    {
        let eventLog = BASInMemoryEventLogStorage()
        // Append a non-checkpoint entry
        let entry = BASEventLogEntry(
            eventID: "other-1",
            timestampMs: 0,
            kind: .substrateAudit,
            sessionID: "s1",
            sequenceNumber: 0,
            source: nil,
            turnRef: nil,
            rawInputDigest: nil,
            intent: nil,
            emotion: nil,
            riskBand: .unknown,
            project: nil,
            memoryRefs: [],
            stateBeforeID: nil,
            stateAfterID: nil,
            actions: ["other-event"],
            confidence: 0,
            payloadJson: nil)
        _ = try await eventLog.append(entry)
        let result = await BASBiomimeticCheckpointReplay
            .latestCheckpoint(
                in: eventLog,
                sessionID: "s1")
        XCTAssertNil(result,
            "only non-checkpoint entries → no result")
    }

    // MARK: - 3. Single checkpoint returns that entry

    func testLatestCheckpointReturnsSingleEntry()
        async throws
    {
        let eventLog = BASInMemoryEventLogStorage()
        let snap = BASBiomimeticStateSnapshot()
        let payload =
            BASBiomimeticCheckpointEventPayload(
                snapshot: snap,
                turnIndex: 5,
                everyNTurns: 5,
                sessionID: "session-a")
        let entry = BASEventLogEntry
            .biomimeticCheckpointEvent(
                eventID: "cp-1",
                timestampMs: 100,
                sessionID: "session-a",
                payload: payload)
        _ = try await eventLog.append(entry)
        let result = await BASBiomimeticCheckpointReplay
            .latestCheckpoint(
                in: eventLog,
                sessionID: "session-a")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.turnIndex, 5)
    }

    // MARK: - 4. Multiple checkpoints — highest turnIndex wins

    func testLatestCheckpointPicksHighestTurnIndex()
        async throws
    {
        let eventLog = BASInMemoryEventLogStorage()
        let sid = "session-b"
        // Append in NON-monotonic turnIndex order
        for turnIdx in [10, 30, 20] {
            let payload =
                BASBiomimeticCheckpointEventPayload(
                    snapshot: BASBiomimeticStateSnapshot(
                        snapshotVersion:
                            "biomimetic-snapshot-v1",
                        timestampMs: Int64(turnIdx)),
                    turnIndex: turnIdx,
                    everyNTurns: 10,
                    sessionID: sid)
            let entry = BASEventLogEntry
                .biomimeticCheckpointEvent(
                    eventID: "cp-\(turnIdx)",
                    timestampMs: Int64(turnIdx),
                    sessionID: sid,
                    payload: payload)
            _ = try await eventLog.append(entry)
        }
        let result = await BASBiomimeticCheckpointReplay
            .latestCheckpoint(
                in: eventLog,
                sessionID: sid)
        XCTAssertEqual(result?.turnIndex, 30,
            "must pick the highest turnIndex (30)" +
            " regardless of insertion order")
    }

    // MARK: - 5. Session isolation

    func testLatestCheckpointIsolatesBySession()
        async throws
    {
        let eventLog = BASInMemoryEventLogStorage()
        // Append checkpoints for 2 different sessions
        let payloadA =
            BASBiomimeticCheckpointEventPayload(
                snapshot: BASBiomimeticStateSnapshot(),
                turnIndex: 100,
                everyNTurns: 10,
                sessionID: "session-a")
        let payloadB =
            BASBiomimeticCheckpointEventPayload(
                snapshot: BASBiomimeticStateSnapshot(),
                turnIndex: 50,
                everyNTurns: 10,
                sessionID: "session-b")
        _ = try await eventLog.append(
            BASEventLogEntry.biomimeticCheckpointEvent(
                eventID: "cp-a",
                timestampMs: 100,
                sessionID: "session-a",
                payload: payloadA))
        _ = try await eventLog.append(
            BASEventLogEntry.biomimeticCheckpointEvent(
                eventID: "cp-b",
                timestampMs: 50,
                sessionID: "session-b",
                payload: payloadB))
        let resultA = await BASBiomimeticCheckpointReplay
            .latestCheckpoint(
                in: eventLog,
                sessionID: "session-a")
        let resultB = await BASBiomimeticCheckpointReplay
            .latestCheckpoint(
                in: eventLog,
                sessionID: "session-b")
        XCTAssertEqual(resultA?.turnIndex, 100,
            "session-a query must NOT pick up" +
            " session-b's checkpoint")
        XCTAssertEqual(resultB?.turnIndex, 50,
            "session-b query must NOT pick up" +
            " session-a's checkpoint")
    }

    // MARK: - 6. checkpointCount

    func testCheckpointCount() async throws {
        let eventLog = BASInMemoryEventLogStorage()
        let sid = "session-c"
        for i in 1...3 {
            let payload =
                BASBiomimeticCheckpointEventPayload(
                    snapshot: BASBiomimeticStateSnapshot(),
                    turnIndex: i * 5,
                    everyNTurns: 5,
                    sessionID: sid)
            _ = try await eventLog.append(
                BASEventLogEntry
                    .biomimeticCheckpointEvent(
                        eventID: "cp-\(i)",
                        timestampMs: Int64(i),
                        sessionID: sid,
                        payload: payload))
        }
        let count = await BASBiomimeticCheckpointReplay
            .checkpointCount(
                in: eventLog,
                sessionID: sid)
        XCTAssertEqual(count, 3)
        // Cross-session count
        let countOther =
            await BASBiomimeticCheckpointReplay
                .checkpointCount(
                    in: eventLog,
                    sessionID: "no-such")
        XCTAssertEqual(countOther, 0)
    }

    // MARK: - 7. restoreObserver — returns false when empty

    func testRestoreObserverReturnsFalseWhenEmpty()
        async throws
    {
        let eventLog = BASInMemoryEventLogStorage()
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.5,
                initialPrediction: [0]))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        let restored =
            try await BASBiomimeticCheckpointReplay
                .restoreObserver(
                    observer,
                    from: eventLog,
                    sessionID: "any")
        XCTAssertFalse(restored,
            "empty log → no restoration")
        let prediction = await probe
            .currentPredictionSnapshot()
        XCTAssertEqual(prediction[0], 0,
            "observer state must be untouched")
    }

    // MARK: - 8. END-TO-END loop closure

    /// THE bedrock test:emit checkpoints via engine
    /// (chapter 467) into event log,then on a FRESH
    /// observer query the log + restore (chapter 468),
    /// verify the restored observer's state byte-
    /// matches the emitter's state at checkpoint
    /// time。
    func testEndToEndEmitThenRestoreLoopClosure()
        async throws
    {
        // === EMITTER SIDE (chapter 467) ===
        // Setup engine 1 with observer + checkpoint
        let probe1 = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 1.0,
                initialPrediction: [0]))
        let observer1 = BASBiomimeticTurnObserver(
            predictive: probe1)
        let eventLog =
            BASInMemoryEventLogStorage()
        let config1 = BASTurnRuntimeEngineConfiguration
            .default()
            .with(eventLog: eventLog)
            .with(biomimeticTurnObserver: observer1)
            .with(biomimeticTurnSignalBuilder: {
                _ in
                BASBiomimeticTurnSignal(
                    predictiveObservation: [0.42])
            } as @Sendable (BASEBrainTurnResult)
                -> BASBiomimeticTurnSignal)
            .with(biomimeticCheckpointEveryNTurns: 2)
        let engine1 = BASTurnRuntimeEngine(
            coordinator: BASCoordinatorTestStubs
                .makeStub(),
            configuration: config1)
        // Run 4 turns。 With α=1 + obs=0.42,
        // prediction snaps to 0.42 after first turn,
        // stays at 0.42。 Cadence=2 emits at turn 2
        // and turn 4。
        for _ in 0..<4 {
            _ = await engine1.runWithPlan(
                BASCoordinatorTestStubs
                    .makeStubRequest())
        }
        let count = await observer1.turnsObservedCount()
        XCTAssertEqual(count, 4)
        let stateAtCheckpoint = await observer1
            .exportAggregate()
        // Discover the actual sessionID the engine
        // used by scanning the event log for any
        // biomimetic-checkpoint event
        let allEntries = await eventLog.events(
            sinceTimestampMs: 0, limit: 10_000)
        let checkpoints = allEntries.filter {
            $0.payloadKind == .biomimeticCheckpoint
        }
        XCTAssertGreaterThan(checkpoints.count, 0,
            "engine must have emitted checkpoints")
        let sessionID = checkpoints[0].sessionID

        // === REPLAY SIDE (chapter 468) ===
        // Create a NEW fresh observer with same shape
        let probe2 = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 1.0,
                initialPrediction: [0]))
        let observer2 = BASBiomimeticTurnObserver(
            predictive: probe2)
        // Verify fresh observer is in initial state
        let initialState = await observer2
            .exportAggregate()
        XCTAssertEqual(
            initialState.predictive?.prediction[0],
            Float(0),
            "fresh observer must start at initial 0")
        // RESTORE via replay namespace
        let restored =
            try await BASBiomimeticCheckpointReplay
                .restoreObserver(
                    observer2,
                    from: eventLog,
                    sessionID: sessionID)
        XCTAssertTrue(restored,
            "log has checkpoints for this session →" +
            " restoration must succeed")
        // Verify observer2 state byte-matches
        // observer1's state at checkpoint time
        let restoredState = await observer2
            .exportAggregate()
        XCTAssertEqual(
            restoredState.predictive?.prediction[0]
                ?? -999,
            stateAtCheckpoint.predictive?.prediction[0]
                ?? -888,
            "loop closure:restored prediction must" +
            " byte-match emitter prediction at" +
            " checkpoint time")
    }

    // MARK: - 9. Restoration applies most-recent checkpoint

    func testRestoreObserverAppliesLatestCheckpoint()
        async throws
    {
        // Build an event log with 3 checkpoints,
        // each carrying a DIFFERENT prediction snapshot。
        // Restoration must pick the LAST one (highest
        // turnIndex)。
        let eventLog = BASInMemoryEventLogStorage()
        let sid = "session-multicp"
        let shape = BASPredictiveCodingProbeShape(
            dim: 1,
            learningRate: 0.1,
            initialPrediction: [0])
        for (turnIdx, predValue) in [(10, Float(0.1)),
                                      (30, Float(0.5)),
                                      (20, Float(0.3))]
        {
            let snap = BASBiomimeticStateSnapshot(
                predictive: BASPredictiveCodingSnapshot(
                    shape: shape,
                    prediction: [predValue],
                    observationsProcessed: turnIdx,
                    sumSquaredError: 0))
            let payload =
                BASBiomimeticCheckpointEventPayload(
                    snapshot: snap,
                    turnIndex: turnIdx,
                    everyNTurns: 10,
                    sessionID: sid)
            _ = try await eventLog.append(
                BASEventLogEntry
                    .biomimeticCheckpointEvent(
                        eventID: "cp-\(turnIdx)",
                        timestampMs: Int64(turnIdx),
                        sessionID: sid,
                        payload: payload))
        }
        // Restore into a fresh observer
        let probe = BASPredictiveCodingProbe(
            shape: shape)
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        let restored =
            try await BASBiomimeticCheckpointReplay
                .restoreObserver(
                    observer,
                    from: eventLog,
                    sessionID: sid)
        XCTAssertTrue(restored)
        let state = await observer.exportAggregate()
        // turnIndex=30 had prediction=0.5 — that
        // must win
        XCTAssertEqual(
            state.predictive?.prediction[0] ?? 0,
            Float(0.5),
            "restoration must apply the HIGHEST-" +
            "turnIndex checkpoint (turn=30,pred=0.5)")
    }
}
