// MARK: - BASChapter1039DeliberationLoopTests
// chapter 一千零三十九 / ADR-018 P1 — unified deliberation loop
//
// Verifies the runTurn deliberation loop wired in ch 1039:
//   - OPT-IN (ADR-014 + 红线 7): `deliberationLoopEnabled` defaults
//     false → exactly one pass (byte-equal with pre-P1). The full
//     test sweep proves byte-equality across the suite; these tests
//     prove the loop's ON behaviour.
//   - When enabled, runs up to the service-requested budget
//     (min(maxLoops, stepIndex)) of refinement passes, each carrying
//     the prior pass's candidate IDs forward.
//   - Early-exits on a terminal stop (maxLoopsReached / blocked /
//     replaced / guardTakeover).

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASChapter1039DeliberationLoopTests: XCTestCase {

    /// Counting loop double — returns a fixed stepIndex + stopReason
    /// and tallies iterate invocations. The substrate calls the 4-arg
    /// iterate; this double implements only the 3-arg form, so the
    /// protocol's default 4-arg forwards here and the tally captures
    /// every pass.
    private final class CountingLoop: BASLoopServicing, @unchecked Sendable {
        private(set) var iterateCalls = 0
        let requestedStep: Int
        let stop: BASThoughtStopReason
        init(requestedStep: Int, stop: BASThoughtStopReason) {
            self.requestedStep = requestedStep
            self.stop = stop
        }
        func proposePaths(
            decomposeFrame: BASDecomposeFrame,
            memoryBundle: BASMemoryBundle,
            budget: BASBudgetFrame
        ) -> [BASCandidatePath] {
            [BASCandidatePath(
                candidateID: "c1.del",
                title: "del",
                actionSummary: "del",
                expectedBenefit: 0.5,
                expectedCost: 0.4,
                reversibility: 0.6,
                confidence: 0.5)]
        }
        func forecast(
            candidates: [BASCandidatePath],
            decomposeFrame: BASDecomposeFrame,
            memoryBundle: BASMemoryBundle
        ) -> [BASForecastItem] {
            candidates.map {
                BASForecastItem(
                    candidateID: $0.candidateID,
                    shortTermOutcome: "s",
                    midTermOutcome: "m",
                    worstCase: "w",
                    uncertainty: 0.3)
            }
        }
        func critique(
            candidates: [BASCandidatePath],
            forecasts: [BASForecastItem],
            hostContext: BASHostProfile
        ) -> [BASCritiqueItem] {
            candidates.map {
                BASCritiqueItem(
                    candidateID: $0.candidateID,
                    critiqueType: .evidenceGap,
                    critiqueText: "g",
                    severity: 0.3)
            }
        }
        func iterate(
            decomposeFrame: BASDecomposeFrame,
            memoryBundle: BASMemoryBundle,
            budget: BASBudgetFrame
        ) -> BASThoughtFrame {
            iterateCalls += 1
            let candidates = proposePaths(
                decomposeFrame: decomposeFrame,
                memoryBundle: memoryBundle,
                budget: budget)
            return BASThoughtFrame(
                stepIndex: requestedStep,
                decomposeRef: "del.decomp",
                memoryRefs: [],
                candidates: candidates,
                forecasts: forecast(
                    candidates: candidates,
                    decomposeFrame: decomposeFrame,
                    memoryBundle: memoryBundle),
                critiques: critique(
                    candidates: candidates,
                    forecasts: [],
                    hostContext: BASHostProfile(hostID: "del")),
                stabilityScore: 0.5,
                stopReason: stop)
        }
    }

    /// Power clock granting a fixed multi-loop budget.
    private struct BudgetClock: BASPowerClockServicing {
        let loops: Int
        func planBudget(
            deviceState: BASDeviceState,
            taskPing: String,
            riskHint: BASBrainRiskLevel?
        ) -> BASBudgetFrame {
            BASBudgetFrame(
                runMode: .engage,
                maxLoops: loops,
                maxCandidates: 2,
                maxDecodeTokens: 100,
                retrievalDepth: 1,
                precisionProfile: .minimal,
                deviceRoute: .scoutCPU,
                thermalGuardLevel: .nominal,
                maintenanceAllowed: false)
        }
        func routeDevice(
            deviceState: BASDeviceState,
            budget: BASBudgetFrame
        ) -> BASDeviceRoute { budget.deviceRoute }
        func scheduleMaintenance(
            deviceState: BASDeviceState,
            budget: BASBudgetFrame
        ) -> Bool { false }
    }

    private func makeCoordinator(
        loop: CountingLoop,
        maxLoops: Int,
        enabled: Bool
    ) -> BASEBrainRuntimeCoordinator {
        BASEBrainRuntimeCoordinator(
            powerClockService: BudgetClock(loops: maxLoops),
            hostProfileService: StubHost(),
            contextService: StubContext(),
            decomposeService: StubDecompose(),
            memoryService: StubMemory(),
            loopService: loop,
            triSelfService: StubTriSelf(),
            riskService: StubRisk(),
            actionService: StubAction(),
            evolutionService: StubEvolution(),
            deliberationLoopEnabled: enabled)
    }

    func testSinglePassWhenDisabled() {
        let loop = CountingLoop(requestedStep: 3, stop: .candidateStable)
        let coord = makeCoordinator(loop: loop, maxLoops: 4, enabled: false)
        _ = coord.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertEqual(loop.iterateCalls, 1,
            "disabled (default) → exactly one deliberation pass" +
            " (byte-equal with pre-P1)")
    }

    func testRunsBudgetedPassesWhenEnabled() {
        let loop = CountingLoop(requestedStep: 3, stop: .candidateStable)
        let coord = makeCoordinator(loop: loop, maxLoops: 4, enabled: true)
        let result = coord.runTurn(
            BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertGreaterThanOrEqual(result.budgetFrame.maxLoops, 3,
            "test precondition: budget must allow ≥3 loops")
        XCTAssertEqual(loop.iterateCalls, 3,
            "enabled → runs service-requested passes" +
            " (min(maxLoops, stepIndex) = 3)")
    }

    func testEarlyExitsOnTerminalStop() {
        let loop = CountingLoop(requestedStep: 3, stop: .maxLoopsReached)
        let coord = makeCoordinator(loop: loop, maxLoops: 4, enabled: true)
        _ = coord.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertEqual(loop.iterateCalls, 1,
            "a terminal stop (maxLoopsReached) on pass 1 halts the" +
            " loop immediately")
    }

    func testBoundedByMaxLoopsViaClampTerminal() {
        // stepIndex (5) > maxLoops (2) → normalize clamps stepIndex
        // to 2 AND sets stopReason = .maxLoopsReached (terminal) →
        // the loop cannot exceed the budget.
        let loop = CountingLoop(requestedStep: 5, stop: .candidateStable)
        let coord = makeCoordinator(loop: loop, maxLoops: 2, enabled: true)
        _ = coord.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertEqual(loop.iterateCalls, 1,
            "over-budget stepIndex is clamped to a terminal stop →" +
            " loop halts (never exceeds maxLoops)")
    }
}
