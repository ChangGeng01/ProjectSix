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

    // MARK: - Real-engine integration (production host path)

    /// Exercises the loop through the FULL real host-runtime pipeline
    /// (BASHostRuntime → buildEBrainTurn → BASHostRuntimeEBrainLoop
    /// Service), not a counting double. A high-risk turn carries a
    /// multi-pass budget; with the loop ON, the real service's
    /// persistence bias refines surviving candidates across passes,
    /// so the on-frame differs from the byte-equal off-frame.
    func testActivatesAndRefinesViaRealHostRuntimePath() throws {
        let configuration = BASHostConfiguration.fixtureGeneric
        let runtime = BASHostRuntime(configuration: configuration)
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .reflective,
            surface: .application,
            prompt: "Push into an irreversible high-stakes move now.",
            riskLevel: .high)
        let seed = try runtime.startSession(request)
        let currentBrain = seed.currentBrain
        let projection = BASBrainProjection(
            records: [], candidates: [], recentEvents: [])
        let device = BASCoordinatorTestStubs.nominalDeviceState

        let off = runtime.buildEBrainTurn(
            request: request,
            currentBrain: currentBrain,
            projection: projection,
            deviceStateOverride: device,
            deliberationLoopEnabled: false)
        let on = runtime.buildEBrainTurn(
            request: request,
            currentBrain: currentBrain,
            projection: projection,
            deviceStateOverride: device,
            deliberationLoopEnabled: true)

        // High-risk → the real loop service requests a multi-pass
        // budget (desiredLoopCount = 3), so loopCount > 1.
        XCTAssertGreaterThan(off.runtimeTrace.loopCount, 1,
            "high-risk turn should carry a multi-loop budget")
        XCTAssertEqual(on.runtimeTrace.loopCount,
            off.runtimeTrace.loopCount,
            "loopCount is the analytical budget — identical on/off")
        // Flag ON ran real refinement passes through the full
        // pipeline: the persistence bias raises surviving
        // candidates' confidence, so the on-frame differs from the
        // byte-equal off-frame.
        XCTAssertNotEqual(on.thoughtFrame.candidates,
            off.thoughtFrame.candidates,
            "the deliberation loop's persistence bias refines" +
            " candidates vs the single-pass frame")
        // Pin the bias semantics: it is a SINGLE non-accumulating
        // +bonus for surviving candidates, NOT graduated by pass
        // count. Each pass regenerates base candidates then applies
        // `reinforce` once, so the refinement saturates after the
        // first biased pass — a matched candidate is exactly
        // off.confidence + bonus (capped at 1.0) regardless of how
        // many passes ran. Graduated/accumulating refinement would
        // need a contract change to forward prior confidences
        // (ADR-018 §7.3 follow-up); this assertion guards against a
        // silent change to that contract.
        let bonus = BASDeliberationBias.priorPersistenceConfidenceBonus
        for offCandidate in off.thoughtFrame.candidates {
            guard let onCandidate = on.thoughtFrame.candidates.first(
                where: { $0.candidateID == offCandidate.candidateID })
            else { continue }
            XCTAssertEqual(onCandidate.confidence,
                min(1.0, offCandidate.confidence + bonus),
                accuracy: 1e-9,
                "refinement is a single non-accumulating +bonus," +
                " not graduated by pass count")
        }
        // Deep-audit refinement: the +bonus is NOT fully inert — it
        // propagates to `confidenceFloor` (= min over candidates of
        // confidence − penalties), which the risk path DOES consume
        // (RiskService `if confidenceFloor < 0.55`, supportLevel). It
        // is "telemetry-consequential": the signal changes…
        if let onFloor = on.thoughtFrame.uncertaintyLedger?.confidenceFloor,
           let offFloor = off.thoughtFrame.uncertaintyLedger?.confidenceFloor {
            XCTAssertEqual(onFloor, min(1.0, offFloor + bonus),
                accuracy: 1e-9,
                "the +bonus propagates to confidenceFloor (a" +
                " risk-consumed signal), so the loop is NOT fully inert")
        }
        // ADR-019 P1.5a — the loop is now DECISION-CONSEQUENTIAL on a
        // genuinely-uncertain turn. The post-binding deliberation
        // caution (injected on the FINAL bound card, §10) raises this
        // high-stakes/uncertain turn across the high band: off lands at
        // 0.6427 (just below 0.65 → medium); the opt-in loop adds the
        // bounded caution → over 0.65 → high. This is a real decision
        // change (assertionCeiling, sovereign hint, Cthulhu permit
        // gating, downstream caution), safe-direction (caution can only
        // rise), and byte-equal when the flag is off.
        XCTAssertEqual(off.riskCard.riskLevel, .medium,
            "without the loop, this fixture lands just below the high band")
        XCTAssertEqual(on.riskCard.riskLevel, .high,
            "the opt-in deliberation caution crosses the band → high" +
            " (the loop is no longer decision-inert)")
        XCTAssertEqual(on.riskCard.totalRisk,
            min(1, off.riskCard.totalRisk
                + BASDeliberationCaution.uncertainDeliberationRiskIncrement),
            accuracy: 1e-9,
            "caution adds exactly the bounded increment on the final" +
            " bound card (NOT halved by the binding — see ADR-019 §10)")
        XCTAssertTrue(
            on.riskCard.factors.contains("deliberation_uncertain_caution"),
            "the deliberation-caution factor is surfaced on the card")
        // Honest scope (verified by diagnostic): the escalation is at
        // the risk-ASSESSMENT level — riskLevel (above) + the assertion
        // guardrail tightens to "guarded". The action permit MODE is
        // ALREADY `.block` (off and on): an uncertain + irreversible
        // high-stakes turn is already maximally cautious, so the caution
        // cannot escalate the MODE further (no room). riskLevel remains a
        // real consumed output (sovereign escalation / audit / downstream)
        // and WOULD flip the action mode on a borderline-permit turn —
        // but uncertain turns here are already block.
        XCTAssertEqual(off.actionPermit.mode, .block)
        XCTAssertEqual(on.actionPermit.mode, .block,
            "the action mode is already block (max caution); the caution" +
            " escalates the risk ASSESSMENT, not the action mode here")
        XCTAssertEqual(on.riskCard.assertionCeiling, "guarded",
            "the assertion guardrail tightens to the high-risk ceiling")
    }

    // MARK: - Coverage gaps closed by the ch1039 deep audit

    /// The cap branch `min(1.0, confidence + bonus)` was never
    /// exercised — no existing test drove confidence high enough to
    /// clamp. Pin it directly on the shared bias helper.
    func testReinforceCapsConfidenceAtOne() {
        let candidate = BASCandidatePath(
            candidateID: "near-one",
            title: "t",
            actionSummary: "a",
            expectedBenefit: 0.5,
            expectedCost: 0.5,
            reversibility: 0.5,
            confidence: 0.98)
        let frame = BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "cap.decomp",
            memoryRefs: [],
            candidates: [candidate],
            forecasts: [],
            critiques: [],
            stabilityScore: 0.5,
            stopReason: .candidateStable)
        let reinforced = BASDeliberationBias.reinforce(
            frame, priorCandidateIDs: ["near-one"])
        XCTAssertEqual(reinforced.candidates[0].confidence, 1.0,
            accuracy: 1e-9,
            "0.98 + 0.05 clamps to 1.0, never exceeds it")
    }

    /// Flag ON but maxLoops==1 → the budget forbids looping → exactly
    /// one pass. (The service requests 3, but normalize clamps to 1.)
    func testFlagOnButMaxLoopsOneRunsSinglePass() {
        let loop = CountingLoop(requestedStep: 3, stop: .candidateStable)
        let coord = makeCoordinator(loop: loop, maxLoops: 1, enabled: true)
        _ = coord.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertEqual(loop.iterateCalls, 1,
            "flag on but maxLoops=1 → budget forbids looping → 1 pass")
    }

    /// Flag ON with ample budget, but the service requests a
    /// single-pass budget (stepIndex==1) → exactly one pass (the loop
    /// honors the service's own requested depth, not just maxLoops).
    func testFlagOnButServiceRequestsSinglePassRunsOnce() {
        let loop = CountingLoop(requestedStep: 1, stop: .candidateStable)
        let coord = makeCoordinator(loop: loop, maxLoops: 4, enabled: true)
        _ = coord.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertEqual(loop.iterateCalls, 1,
            "flag on + budget=4 but service requests stepIndex=1 → 1 pass")
    }
}
