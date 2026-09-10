// MARK: - BASEBrainTurnRequestFrameContextTests
// chapter 四百三 / M954
//
// Test coverage for the BASFrameContext factory extension on
// BASEBrainTurnRequest。Locks the derivation formula to a
// single source so future runTurn rewrites can't introduce
// drift (chapter 二百一一)。

import Foundation
import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASEBrainTurnRequestFrameContextTests:
    XCTestCase
{

    // MARK: - Fixtures

    private func makeRequest(
        hostID: String = "host.alice",
        recordedAt: Date =
            Date(timeIntervalSinceReferenceDate: 1234.5)
    ) -> BASEBrainTurnRequest {
        BASEBrainTurnRequest(
            userInput: "test",
            deviceState: BASDeviceState(
                schemaVersion:
                    BASDeviceState.currentSchemaVersion,
                batteryLevel: 0.8,
                thermalLevel: .nominal,
                memoryFreeMB: 1000,
                networkState: .online,
                foregroundState: .foreground,
                cpuLoad: 0.3,
                gpuLoad: 0.2,
                npuAvailable: true,
                latencyBudgetMs: 1000),
            hostID: hostID,
            recordedAt: recordedAt)
    }

    private func makeContextFrame(
        taskType: BASContextTaskType = .chat
    ) -> BASContextFrame {
        BASContextFrame(
            utterance: "x",
            taskType: taskType,
            emotionalLoad: 0,
            timePressure: 0,
            relationPattern: "neutral",
            ambiguityScore: 0,
            consequenceLevel: 0,
            hostRelevance: 0)
    }

    private func makeBudget(
        runMode: BASEBrainRunMode = .engage
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: runMode,
            maxLoops: 1,
            maxCandidates: 1,
            maxDecodeTokens: 64,
            retrievalDepth: 1,
            precisionProfile: .balanced,
            deviceRoute: .scoutCPU,
            thermalGuardLevel: .nominal,
            maintenanceAllowed: false)
    }

    // MARK: - Derivation formula tests

    func testFactoryProducesCanonicalSessionID() {
        let req = makeRequest(hostID: "host.alice")
        let ctx = req.makeFrameContext(
            rawContextFrame: makeContextFrame(taskType: .chat),
            routedBudget: makeBudget(runMode: .engage))
        XCTAssertEqual(
            ctx.sessionID,
            "host.alice|chat|engage",
            "M954:factory must produce the runTurn L756-762 sessionID")
    }

    func testFactoryProducesCanonicalTurnID() {
        let req = makeRequest(
            hostID: "host.b",
            recordedAt: Date(
                timeIntervalSinceReferenceDate: 99.5))
        let ctx = req.makeFrameContext(
            rawContextFrame: makeContextFrame(taskType: .chat),
            routedBudget: makeBudget(runMode: .engage))
        XCTAssertEqual(
            ctx.turnID,
            "host.b|chat|engage#99.5",
            "M954:factory must produce the runTurn L756-762 turnID")
    }

    func testFactoryEmittedAtMatchesRequestRecordedAt() {
        let date =
            Date(timeIntervalSinceReferenceDate: 1.5)
        let req = makeRequest(recordedAt: date)
        let ctx = req.makeFrameContext(
            rawContextFrame: makeContextFrame(),
            routedBudget: makeBudget())
        XCTAssertEqual(ctx.emittedAt, date)
    }

    // MARK: - Determinism (chapter 三百九二)

    func testFactoryIsPure() {
        let req = makeRequest()
        let ctxFrame = makeContextFrame()
        let budget = makeBudget()
        let c1 = req.makeFrameContext(
            rawContextFrame: ctxFrame, routedBudget: budget)
        let c2 = req.makeFrameContext(
            rawContextFrame: ctxFrame, routedBudget: budget)
        XCTAssertEqual(c1, c2,
            "M954:factory is pure — same inputs → same context")
    }

    func testFactoryDifferentTaskTypeProducesDifferentSessionID() {
        let req = makeRequest()
        let budget = makeBudget()
        let cChat = req.makeFrameContext(
            rawContextFrame: makeContextFrame(taskType: .chat),
            routedBudget: budget)
        let cConflict = req.makeFrameContext(
            rawContextFrame:
                makeContextFrame(taskType: .conflict),
            routedBudget: budget)
        XCTAssertNotEqual(cChat.sessionID, cConflict.sessionID)
    }

    func testFactoryDifferentRunModeProducesDifferentSessionID() {
        let req = makeRequest()
        let ctxFrame = makeContextFrame()
        let cEngage = req.makeFrameContext(
            rawContextFrame: ctxFrame,
            routedBudget: makeBudget(runMode: .engage))
        let cGuard = req.makeFrameContext(
            rawContextFrame: ctxFrame,
            routedBudget: makeBudget(runMode: .guard))
        XCTAssertNotEqual(cEngage.sessionID, cGuard.sessionID)
    }

    // MARK: - chapter 二百一一 single-source-of-truth pin

    func testFactoryResultMatchesInlineDerivationVerbatim() {
        // Mirror runTurn L756-762 inline derivation here。
        // If this test fails,either the factory diverged
        // OR runTurn's inline formula was changed without
        // updating BASFrameContext。Both are doctrine
        // violations。
        let req = makeRequest(
            hostID: "host.x",
            recordedAt:
                Date(timeIntervalSinceReferenceDate: 7.5))
        let ctxFrame = makeContextFrame(taskType: .conflict)
        let budget = makeBudget(runMode: .guard)

        // Manual replication of runTurn L756-762
        let manualSID = [
            req.hostID,
            ctxFrame.taskType.rawValue,
            budget.runMode.rawValue
        ].joined(separator: "|")
        let manualTID =
            "\(manualSID)#\(req.recordedAt.timeIntervalSinceReferenceDate)"

        let factoryCtx = req.makeFrameContext(
            rawContextFrame: ctxFrame, routedBudget: budget)
        XCTAssertEqual(factoryCtx.sessionID, manualSID,
            "M954:factory mirrors runTurn inline sessionID derivation")
        XCTAssertEqual(factoryCtx.turnID, manualTID,
            "M954:factory mirrors runTurn inline turnID derivation")
    }
}
