// MARK: - BASBiomimeticAutoCheckpointTests
// chapter 四百六十七 / M1246 PROOF tests
//
// Verifies the auto-checkpoint integration shipped in
// chapter 467:`BASTurnRuntimeEngine` auto-emits a
// `BASBiomimeticCheckpointEventPayload` event to the
// configured event log every N turns when all 3
// prerequisites are wired (observer + cadence +
// eventLog)。
//
// Tests use the chapter 462 BASCoordinatorTestStubs
// factory + BASInMemoryEventLogStorage for end-to-end
// verification with REAL `engine.runWithPlan(...)`
// calls。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASBiomimeticAutoCheckpointTests: XCTestCase
{

    // MARK: - Payload Codable round-trip

    func testPayloadCodableRoundTrip() throws {
        let snap = BASBiomimeticStateSnapshot(
            mamba: nil,
            predictive: BASPredictiveCodingSnapshot(
                shape: BASPredictiveCodingProbeShape(
                    dim: 1,
                    learningRate: 0.1,
                    initialPrediction: [0]),
                prediction: [0.5],
                observationsProcessed: 3,
                sumSquaredError: 0.1),
            plasticity: nil,
            snapshotVersion: "biomimetic-snapshot-v1",
            timestampMs: 1_700_000_000_000)
        let payload =
            BASBiomimeticCheckpointEventPayload(
                snapshot: snap,
                turnIndex: 10,
                everyNTurns: 10,
                sessionID: "test-session")
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(
            BASBiomimeticCheckpointEventPayload.self,
            from: data)
        XCTAssertEqual(decoded, payload)
        XCTAssertEqual(decoded.turnIndex, 10)
        XCTAssertEqual(decoded.everyNTurns, 10)
    }

    // MARK: - Init clamps

    func testPayloadInitClampsNegativeTurnIndex() {
        let snap = BASBiomimeticStateSnapshot()
        let p = BASBiomimeticCheckpointEventPayload(
            snapshot: snap,
            turnIndex: -5,
            everyNTurns: 10,
            sessionID: "s")
        XCTAssertEqual(p.turnIndex, 0,
            "negative turnIndex must clamp to 0")
    }

    func testPayloadInitClampsZeroOrNegativeCadence() {
        let snap = BASBiomimeticStateSnapshot()
        let p = BASBiomimeticCheckpointEventPayload(
            snapshot: snap,
            turnIndex: 0,
            everyNTurns: 0,
            sessionID: "s")
        XCTAssertEqual(p.everyNTurns, 1,
            "cadence <= 0 must clamp to 1")
    }

    // MARK: - Payload kind discriminator

    func testPayloadKindIsBiomimeticCheckpoint() {
        XCTAssertEqual(
            BASEventPayloadKind.biomimeticCheckpoint
                .rawValue,
            "biomimetic-checkpoint-event")
    }

    func testAllCasesIncludes8thKind() {
        XCTAssertEqual(
            BASEventPayloadKind.allCases.count, 8,
            "chapter 467 added the 8th payload kind" +
            " (biomimeticCheckpoint)")
        XCTAssertTrue(BASEventPayloadKind.allCases
            .contains(.biomimeticCheckpoint))
    }

    // MARK: - Event factory + reverse accessor

    func testEventFactoryAndAccessorRoundTrip() {
        let snap = BASBiomimeticStateSnapshot()
        let payload =
            BASBiomimeticCheckpointEventPayload(
                snapshot: snap,
                turnIndex: 5,
                everyNTurns: 5,
                sessionID: "test")
        let entry = BASEventLogEntry
            .biomimeticCheckpointEvent(
                eventID: "evt-1",
                timestampMs: 0,
                sessionID: "test",
                payload: payload)
        XCTAssertEqual(entry.payloadKind,
            .biomimeticCheckpoint)
        XCTAssertTrue(entry.hasPayloadKind(
            .biomimeticCheckpoint))
        let decoded =
            entry.biomimeticCheckpointEventPayload
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded, payload)
    }

    func testNonCheckpointEntryAccessorReturnsNil() {
        // Build a non-checkpoint entry via direct init
        let entry = BASEventLogEntry(
            eventID: "evt-2",
            timestampMs: 0,
            kind: .substrateAudit,
            sessionID: "s",
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
        XCTAssertNil(
            entry.biomimeticCheckpointEventPayload)
    }

    // MARK: - End-to-end: engine auto-emits every N turns

    func testEngineEmitsCheckpointEveryNTurns()
        async throws
    {
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.5,
                initialPrediction: [0]))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        let eventLog =
            BASInMemoryEventLogStorage()
        let config = BASTurnRuntimeEngineConfiguration
            .default()
            .with(eventLog: eventLog)
            .with(biomimeticTurnObserver: observer)
            .with(biomimeticCheckpointEveryNTurns: 3)
        let engine = BASTurnRuntimeEngine(
            coordinator: BASCoordinatorTestStubs
                .makeStub(),
            configuration: config)
        // Run 6 turns。 Cadence=3 means checkpoint events
        // emit on turn 3 and turn 6
        for _ in 0..<6 {
            _ = await engine.runWithPlan(
                BASCoordinatorTestStubs
                    .makeStubRequest())
        }
        let entries = await eventLog.events(
            sinceTimestampMs: 0, limit: 10_000)
        let checkpoints = entries.filter {
            $0.payloadKind == .biomimeticCheckpoint
        }
        XCTAssertEqual(checkpoints.count, 2,
            "6 turns @ cadence=3 must emit 2" +
            " checkpoint events")
        // First checkpoint must carry turnIndex=3
        let p1 = checkpoints[0]
            .biomimeticCheckpointEventPayload
        XCTAssertEqual(p1?.turnIndex, 3)
        XCTAssertEqual(p1?.everyNTurns, 3)
        // Second carries turnIndex=6
        let p2 = checkpoints[1]
            .biomimeticCheckpointEventPayload
        XCTAssertEqual(p2?.turnIndex, 6)
    }

    // MARK: - End-to-end: no emission when cadence is nil

    func testEngineDoesNotEmitWhenCadenceIsNil()
        async throws
    {
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.5,
                initialPrediction: [0]))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        let eventLog =
            BASInMemoryEventLogStorage()
        // Observer wired but NO cadence → no emission
        let config = BASTurnRuntimeEngineConfiguration
            .default()
            .with(eventLog: eventLog)
            .with(biomimeticTurnObserver: observer)
        let engine = BASTurnRuntimeEngine(
            coordinator: BASCoordinatorTestStubs
                .makeStub(),
            configuration: config)
        for _ in 0..<5 {
            _ = await engine.runWithPlan(
                BASCoordinatorTestStubs
                    .makeStubRequest())
        }
        let entries = await eventLog.events(
            sinceTimestampMs: 0, limit: 10_000)
        let checkpoints = entries.filter {
            $0.payloadKind == .biomimeticCheckpoint
        }
        XCTAssertEqual(checkpoints.count, 0,
            "cadence=nil → no checkpoint events emitted")
    }

    // MARK: - End-to-end: no emission when eventLog is nil

    func testEngineDoesNotEmitWhenEventLogIsNil()
        async throws
    {
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 0.5,
                initialPrediction: [0]))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        // Cadence wired but NO eventLog → no emission
        // (verified by no crash + observer still
        // increments turn counter)
        let config = BASTurnRuntimeEngineConfiguration
            .default()
            .with(biomimeticTurnObserver: observer)
            .with(biomimeticCheckpointEveryNTurns: 2)
        let engine = BASTurnRuntimeEngine(
            coordinator: BASCoordinatorTestStubs
                .makeStub(),
            configuration: config)
        for _ in 0..<4 {
            _ = await engine.runWithPlan(
                BASCoordinatorTestStubs
                    .makeStubRequest())
        }
        let count = await observer.turnsObservedCount()
        XCTAssertEqual(count, 4,
            "observer still fires 4 times even" +
            " without eventLog;cadence checks just" +
            " no-op silently")
    }

    // MARK: - Default config has nil cadence

    func testDefaultConfigHasNilCadence() {
        let config = BASTurnRuntimeEngineConfiguration
            .default()
        XCTAssertNil(
            config.biomimeticCheckpointEveryNTurns,
            "ADR-014 OPT-IN:default config disables" +
            " auto-checkpoint emission")
    }

    // MARK: - End-to-end: checkpoint snapshot reflects state

    func testCheckpointSnapshotReflectsObserverState()
        async throws
    {
        let probe = BASPredictiveCodingProbe(
            shape: BASPredictiveCodingProbeShape(
                dim: 1,
                learningRate: 1.0,
                initialPrediction: [0]))
        let observer = BASBiomimeticTurnObserver(
            predictive: probe)
        let eventLog =
            BASInMemoryEventLogStorage()
        let config = BASTurnRuntimeEngineConfiguration
            .default()
            .with(eventLog: eventLog)
            .with(biomimeticTurnObserver: observer)
            .with(biomimeticTurnSignalBuilder: {
                _ in
                BASBiomimeticTurnSignal(
                    predictiveObservation: [0.7])
            } as @Sendable (BASEBrainTurnResult)
                -> BASBiomimeticTurnSignal)
            .with(biomimeticCheckpointEveryNTurns: 2)
        let engine = BASTurnRuntimeEngine(
            coordinator: BASCoordinatorTestStubs
                .makeStub(),
            configuration: config)
        // Run 2 turns。 With α=1 + obs=0.7,prediction
        // snaps to 0.7 after first turn,stays at 0.7
        // after second。 Cadence=2 emits at turn 2。
        _ = await engine.runWithPlan(
            BASCoordinatorTestStubs.makeStubRequest())
        _ = await engine.runWithPlan(
            BASCoordinatorTestStubs.makeStubRequest())
        let entries = await eventLog.events(
            sinceTimestampMs: 0, limit: 10_000)
        let checkpoints = entries.filter {
            $0.payloadKind == .biomimeticCheckpoint
        }
        XCTAssertEqual(checkpoints.count, 1)
        let p = checkpoints[0]
            .biomimeticCheckpointEventPayload
        XCTAssertNotNil(p?.snapshot.predictive)
        // The snapshot's prediction reflects the
        // probe state at turn 2 (snapped to 0.7)
        XCTAssertEqual(
            p?.snapshot.predictive?.prediction[0]
                ?? 0,
            Float(0.7), accuracy: Float(1e-5))
    }
}
