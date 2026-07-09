import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

/// audit M-k F1 — BASTurnRuntimeEngine is a REENTRANT actor. Between the
/// runWithPlan write of the shared `lastDispatchLedger` / `lastAssignmentLedger`
/// and the emit helpers' reads of them, a concurrent turn could overwrite the
/// shared var — so an emitted audit event carried THIS turn's sessionID with the
/// OTHER turn's ledger payload (the documented "sessionID 与 payload 不一致"
/// crossing). The two routed emit helpers now take the per-turn ledger BY VALUE
/// (ledger-locality) instead of reading shared state.
///
/// Teeth: with the shared var at its DEFAULT (.empty / .unwired, count 0), a
/// NON-empty ledger passed as the param must still drive emission — proving the
/// guard + payload read the PARAM. Reverting the helpers to read the shared var
/// makes these red (shared count 0 ⇒ the `count > 0` guard skips).
final class BASTurnRuntimeEngineLedgerLocalityTests: XCTestCase {

    private func makeEngine(log: BASInMemoryEventLogStorage) -> BASTurnRuntimeEngine {
        BASTurnRuntimeEngine(
            coordinator: BASCoordinatorTestStubs.makeStub(),
            eventLog: log,
            eventIDFactory: { "evt-\(UUID().uuidString)" },
            clockMs: { 1000 })
    }

    private func result() -> BASEBrainTurnResult {
        BASCoordinatorTestStubs.makeStub().runTurn(
            BASCoordinatorTestStubs.makeStubRequest())
    }

    private func dispatchRecord() -> BASNativeStageExecutionRecord {
        BASNativeStageExecutionRecord(
            stageRawValue: "stage-x", assignment: nil,
            durationMs: 1, sequenceIndex: 0, honoredAssignment: false)
    }

    private func assignmentRecord() -> BASTurnRuntimeStageAssignmentRecord {
        let hint = BASStageAcceleratorHint(
            operation: .matMul, preferredDataType: .float16,
            batchSize: 1, sequenceLength: 1, latencyBudgetMs: 10.0)
        let assignment = BASStageAcceleratorAssignment(
            selectedBackingKind: .metalBuffer, selectedKernelKey: nil,
            costScore: 1.0, thermalSnapshot: .nominal,
            assignmentRationale: .aneSupported)
        return BASTurnRuntimeStageAssignmentRecord(
            stageRawValue: "stage-0", hint: hint,
            assignment: assignment, sequenceIndex: 0)
    }

    // MARK: - dispatch helper (reads THIS turn's ledger, not shared)

    func testDispatchEmitUsesParamLedgerNotSharedState() async {
        let log = BASInMemoryEventLogStorage()
        let engine = makeEngine(log: log)
        let r = result()
        let ledger = BASNativeStageDispatchLedger.empty.appending(dispatchRecord())
        // shared lastDispatchLedger is still .empty (no runWithPlan ran).
        await engine.emitNativeStageDispatchEventIfNeeded(
            for: r, dispatchLedger: ledger, timestampMsOverride: 1000)
        let evts = await log.events(forSession: r.runtimeTrace.sessionID)
            .filter { $0.payloadKind == .nativeStageDispatch }
        XCTAssertEqual(evts.count, 1,
            "the non-empty PARAM ledger must drive emission even though the shared "
            + "lastDispatchLedger is .empty (reverting to the shared read reds this)")
        let turnID = r.sovereignAuditEntry?.turnID ?? r.runtimeTrace.sessionID
        XCTAssertEqual(evts.first?.turnRef, turnID,
            "attribution: the emitted event's turn matches THIS turn's result")
        XCTAssertEqual(evts.first?.sessionID, r.runtimeTrace.sessionID)
    }

    func testDispatchEmitSkipsOnEmptyParamLedger() async {
        let log = BASInMemoryEventLogStorage()
        let engine = makeEngine(log: log)
        let r = result()
        await engine.emitNativeStageDispatchEventIfNeeded(
            for: r, dispatchLedger: .empty, timestampMsOverride: 1000)
        let evts = await log.events(forSession: r.runtimeTrace.sessionID)
            .filter { $0.payloadKind == .nativeStageDispatch }
        XCTAssertEqual(evts.count, 0,
            "empty PARAM ledger ⇒ the guard (executionCount > 0) skips emission")
    }

    // MARK: - assignment helper (reads THIS turn's ledger, not shared)

    func testAssignmentEmitUsesParamLedgerNotSharedState() async {
        let log = BASInMemoryEventLogStorage()
        let engine = makeEngine(log: log)
        let r = result()
        let ledger = BASTurnRuntimePlanAssignmentLedger
            .empty(turnID: "t-mk-f1").appending(assignmentRecord())
        // shared lastAssignmentLedger is still .unwired (recordCount 0).
        await engine.emitPlanAssignmentEventIfNeeded(
            for: r, assignmentLedger: ledger, timestampMsOverride: 1000)
        let evts = await log.events(forSession: r.runtimeTrace.sessionID)
            .filter { $0.payloadKind == .planAssignment }
        XCTAssertEqual(evts.count, 1,
            "the non-empty PARAM ledger must drive emission even though the shared "
            + "lastAssignmentLedger is .unwired (reverting to the shared read reds this)")
        XCTAssertEqual(evts.first?.sessionID, r.runtimeTrace.sessionID)
    }

    func testAssignmentEmitSkipsOnEmptyParamLedger() async {
        let log = BASInMemoryEventLogStorage()
        let engine = makeEngine(log: log)
        let r = result()
        await engine.emitPlanAssignmentEventIfNeeded(
            for: r, assignmentLedger: .empty(turnID: "t"), timestampMsOverride: 1000)
        let evts = await log.events(forSession: r.runtimeTrace.sessionID)
            .filter { $0.payloadKind == .planAssignment }
        XCTAssertEqual(evts.count, 0,
            "empty PARAM ledger ⇒ the guard (recordCount > 0) skips emission")
    }
}
