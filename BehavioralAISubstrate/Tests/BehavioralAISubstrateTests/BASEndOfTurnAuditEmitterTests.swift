// MARK: - BASEndOfTurnAuditEmitterTests
// chapter 五百五 / M1398 — end-of-turn audit emitter tests

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASRuntimeCore

final class BASEndOfTurnAuditEmitterTests: XCTestCase {

    // MARK: - Helpers

    private func sampleProbeBundle()
        -> BASKernelEvaluateLatencyProbeBundle
    {
        let body =
            BASMPSGraphKernelBuildLatencyResultBody(
                operation: .matMul,
                dataType: .float32,
                inputShapes: [[4, 4]],
                buildNanos: 100,
                dispatchNanos: 50,
                cacheHitSavedNanos: 0,
                wasCacheHit: false)
        return BASKernelEvaluateLatencyProbeBundle(
            bundleID: "probe-bundle",
            schemaVersion: "1.0.0",
            items: [body],
            metadata: [:],
            recordedAt: Date(
                timeIntervalSince1970: 0))
    }

    // MARK: - 1) Empty emitter has zero connections

    func testEmptyEmitterHasZeroConnections() async {
        let emitter = BASEndOfTurnAuditEmitter()
        XCTAssertFalse(emitter.hasProbeBundle)
        XCTAssertFalse(emitter.hasRoutingObserver)
        XCTAssertFalse(emitter.hasStatisticsRecorder)
        XCTAssertFalse(emitter.hasAdvisoryLedger)
        XCTAssertEqual(
            emitter.connectedPipelineCount, 0)
    }

    // MARK: - 2) Empty emitter emits empty record

    func testEmptyEmitterEmitsEmptyRecord() async {
        let emitter = BASEndOfTurnAuditEmitter()
        let record = await emitter.emit(
            turnID: "empty",
            recordedAtMs: 0)
        XCTAssertEqual(record.turnID, "empty")
        XCTAssertEqual(
            record.populatedPipelineCount, 0)
        XCTAssertFalse(record.hasAllFourPipelines)
    }

    // MARK: - 3) Single pipeline emitter

    func testSinglePipelineEmitter() async {
        let emitter = BASEndOfTurnAuditEmitter(
            probeBundle: sampleProbeBundle())
        XCTAssertTrue(emitter.hasProbeBundle)
        XCTAssertEqual(
            emitter.connectedPipelineCount, 1)
        let record = await emitter.emit(
            turnID: "single",
            recordedAtMs: 100)
        XCTAssertNotNil(record.cacheReport)
        XCTAssertNil(record.routingDecisions)
        XCTAssertNil(record.dispatchStatistics)
        XCTAssertNil(record.runtimeModeAdvisories)
        XCTAssertEqual(
            record.populatedPipelineCount, 1)
    }

    // MARK: - 4) All-4-pipelines emitter PROOF

    func testAllFourPipelinesEmitterProof() async {
        let observer =
            BASKernelRoutingDecisionObserver()
        await observer.recordDecision(
            operation: .matMul,
            thermalState: .nominal,
            anePriority: .aneFirst,
            recordedAtMs: 0)
        let recorder =
            BASKernelDispatchStatisticsRecorder()
        await recorder.recordAttempt(
            operation: .matMul,
            kind: .success)
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        await ledger.record(
            preferredMode: .v1ByteEqual,
            hostID: "H",
            recordedAtMs: 0)
        let emitter = BASEndOfTurnAuditEmitter(
            probeBundle: sampleProbeBundle(),
            routingObserver: observer,
            statisticsRecorder: recorder,
            advisoryLedger: ledger)
        XCTAssertEqual(
            emitter.connectedPipelineCount, 4)
        let record = await emitter.emit(
            turnID: "full",
            recordedAtMs: 1_000)
        XCTAssertEqual(record.turnID, "full")
        XCTAssertTrue(record.hasAllFourPipelines)
        XCTAssertEqual(
            record.populatedPipelineCount, 4)
        // Verify each pipeline has a record
        XCTAssertNotNil(record.cacheReport)
        XCTAssertNotNil(record.routingDecisions)
        XCTAssertNotNil(record.dispatchStatistics)
        XCTAssertNotNil(record.runtimeModeAdvisories)
    }

    // MARK: - 5) Emitter does NOT mutate observer state

    func testEmitDoesNotMutateObserverState() async {
        let observer =
            BASKernelRoutingDecisionObserver()
        await observer.recordDecision(
            operation: .matMul,
            thermalState: .nominal,
            anePriority: .aneFirst,
            recordedAtMs: 0)
        let beforeCount = await observer.decisionCount
        let emitter = BASEndOfTurnAuditEmitter(
            routingObserver: observer)
        _ = await emitter.emit(
            turnID: "no-mutate",
            recordedAtMs: 0)
        let afterCount = await observer.decisionCount
        XCTAssertEqual(beforeCount, afterCount,
            "emit MUST NOT mutate observer state" +
            " (read-only snapshot)")
    }

    // MARK: - 6) Multiple emits produce consistent
    //             results (deterministic)

    func testMultipleEmitsConsistent() async {
        let observer =
            BASKernelRoutingDecisionObserver()
        await observer.recordDecision(
            operation: .matMul,
            thermalState: .nominal,
            anePriority: .aneFirst,
            recordedAtMs: 100)
        let emitter = BASEndOfTurnAuditEmitter(
            routingObserver: observer)
        let r1 = await emitter.emit(
            turnID: "T",
            recordedAtMs: 200)
        let r2 = await emitter.emit(
            turnID: "T",
            recordedAtMs: 200)
        XCTAssertEqual(
            r1.routingDecisions?.items.count,
            r2.routingDecisions?.items.count,
            "repeated emits with same inputs MUST" +
            " produce same item counts")
    }

    // MARK: - 7) Turn ID flows through to bundle IDs

    func testTurnIDFlowsToBundleIDs() async {
        let recorder =
            BASKernelDispatchStatisticsRecorder()
        await recorder.recordAttempt(
            operation: .matMul,
            kind: .success)
        let ledger =
            BASEBrainHostRuntimeModeAdvisoryLedger()
        await ledger.record(
            preferredMode: .v1ByteEqual,
            hostID: "H",
            recordedAtMs: 0)
        let emitter = BASEndOfTurnAuditEmitter(
            statisticsRecorder: recorder,
            advisoryLedger: ledger)
        let record = await emitter.emit(
            turnID: "trace-xyz",
            recordedAtMs: 0)
        XCTAssertEqual(
            record.dispatchStatistics?.bundleID,
            "dispatch-trace-xyz")
        XCTAssertEqual(
            record.runtimeModeAdvisories?.bundleID,
            "advisory-trace-xyz")
    }

    // MARK: - 8) Connection count accurately reflects
    //             constructor args

    func testConnectionCountReflectsArgs() async {
        let e1 = BASEndOfTurnAuditEmitter(
            probeBundle: sampleProbeBundle())
        XCTAssertEqual(e1.connectedPipelineCount, 1)

        let e2 = BASEndOfTurnAuditEmitter(
            probeBundle: sampleProbeBundle(),
            advisoryLedger:
                BASEBrainHostRuntimeModeAdvisoryLedger())
        XCTAssertEqual(e2.connectedPipelineCount, 2)

        let e3 = BASEndOfTurnAuditEmitter(
            routingObserver:
                BASKernelRoutingDecisionObserver(),
            statisticsRecorder:
                BASKernelDispatchStatisticsRecorder(),
            advisoryLedger:
                BASEBrainHostRuntimeModeAdvisoryLedger())
        XCTAssertEqual(e3.connectedPipelineCount, 3)
    }
}
