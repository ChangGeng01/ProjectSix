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
        enabled: Bool,
        provisionalVerdictSink:
            (@Sendable (BASProvisionalVerdict) -> Void)? = nil
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
            deliberationLoopEnabled: enabled,
            provisionalVerdictSink: provisionalVerdictSink)
    }

    /// Stub turn request carrying a chosen thermal level. Identical to
    /// `BASCoordinatorTestStubs.makeStubRequest()` except the device's
    /// `thermalLevel` is overridden — the minimal knob the existing sync
    /// harness lacks, needed to drive the ADR-018 P3 thermal floor.
    private func makeRequest(
        thermalLevel: BASThermalLevel
    ) -> BASEBrainTurnRequest {
        let nominal = BASCoordinatorTestStubs.nominalDeviceState
        let device = BASDeviceState(
            batteryLevel: nominal.batteryLevel,
            thermalLevel: thermalLevel,
            memoryFreeMB: nominal.memoryFreeMB,
            networkState: nominal.networkState,
            foregroundState: nominal.foregroundState,
            cpuLoad: nominal.cpuLoad,
            gpuLoad: nominal.gpuLoad,
            npuAvailable: nominal.npuAvailable,
            latencyBudgetMs: nominal.latencyBudgetMs)
        return BASEBrainTurnRequest(
            userInput: "stub test input",
            deviceState: device,
            hostID: "stub.test.host",
            recordedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testSinglePassWhenDisabled() {
        let loop = CountingLoop(requestedStep: 3, stop: .candidateStable)
        let coord = makeCoordinator(loop: loop, maxLoops: 4, enabled: false)
        _ = coord.runTurn(BASCoordinatorTestStubs.makeStubRequest())
        XCTAssertEqual(loop.iterateCalls, 1,
            "disabled (default) → exactly one deliberation pass" +
            " (byte-equal with pre-P1)")
    }

    // MARK: - ADR-018 P3 Commit 2 — deliberation thermal floor

    /// Flag ON, multi-pass budget (maxLoops 4, service requests stepIndex 3
    /// → 3 passes when cool, exactly like `testRunsBudgetedPassesWhenEnabled`),
    /// but the device is `.hot` → the thermal floor collapses the loop to a
    /// single pass.
    func testThermalFloorCollapsesLoopWhenHot() {
        let loop = CountingLoop(requestedStep: 3, stop: .candidateStable)
        let coord = makeCoordinator(loop: loop, maxLoops: 4, enabled: true)
        _ = coord.runTurn(makeRequest(thermalLevel: .hot))
        XCTAssertEqual(loop.iterateCalls, 1,
            "flag on + .hot → thermal floor caps maxLoops at 1 → 1 pass" +
            " (vs 3 when cool — see testThermalFloorPassthroughWhenNominal)")
    }

    /// `.critical` floors the loop to a single pass exactly like `.hot`.
    func testThermalFloorCollapsesLoopWhenCritical() {
        let loop = CountingLoop(requestedStep: 3, stop: .candidateStable)
        let coord = makeCoordinator(loop: loop, maxLoops: 4, enabled: true)
        _ = coord.runTurn(makeRequest(thermalLevel: .critical))
        XCTAssertEqual(loop.iterateCalls, 1,
            "flag on + .critical → thermal floor caps maxLoops at 1 → 1 pass")
    }

    /// Flag ON, same multi-pass budget, but `.nominal` → the floor is a no-op
    /// and the full service-requested passes run (proving the floor is inert
    /// when cool — byte-equal with pre-floor behaviour, matching
    /// `testRunsBudgetedPassesWhenEnabled`'s iterateCalls == 3).
    func testThermalFloorPassthroughWhenNominal() {
        let loop = CountingLoop(requestedStep: 3, stop: .candidateStable)
        let coord = makeCoordinator(loop: loop, maxLoops: 4, enabled: true)
        _ = coord.runTurn(makeRequest(thermalLevel: .nominal))
        XCTAssertEqual(loop.iterateCalls, 3,
            "flag on + .nominal → floor is passthrough → full budgeted" +
            " passes (min(maxLoops, stepIndex) = 3)")
    }

    /// `.warm` is also a passthrough — only `.hot`/`.critical` floor the loop.
    func testThermalFloorPassthroughWhenWarm() {
        let loop = CountingLoop(requestedStep: 3, stop: .candidateStable)
        let coord = makeCoordinator(loop: loop, maxLoops: 4, enabled: true)
        _ = coord.runTurn(makeRequest(thermalLevel: .warm))
        XCTAssertEqual(loop.iterateCalls, 3,
            "flag on + .warm → floor is passthrough → full budgeted passes")
    }

    /// Flag OFF + `.hot`: the whole deliberation-loop block is gated by
    /// `deliberationLoopEnabled`, so the floor never runs — the turn takes the
    /// pre-P1 single pass (byte-equal, exactly like `testSinglePassWhenDisabled`
    /// but with a hot device, confirming the floor is reached ONLY inside the
    /// gated block).
    func testThermalFloorByteEqualOffWhenFlagDisabled() {
        let loop = CountingLoop(requestedStep: 3, stop: .candidateStable)
        let coord = makeCoordinator(loop: loop, maxLoops: 4, enabled: false)
        _ = coord.runTurn(makeRequest(thermalLevel: .hot))
        XCTAssertEqual(loop.iterateCalls, 1,
            "flag off + .hot → gated block skipped → single pass" +
            " (byte-equal; the floor is unreachable when the flag is off)")
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

    // MARK: - ADR-020 Arc-3 Phase C — pre-render provisional verdict

    /// The opt-in provisional sink fires once per turn with a faithful
    /// PRE-render forecast of the post-render verdict LEVEL, and the
    /// emission is OBSERVATION-ONLY: the decision is identical to running
    /// the same turn with no sink (the emit mutates nothing the
    /// verdict / risk / permit read).
    func testProvisionalVerdictEmittedFaithfullyAndInert() throws {
        final class Capture: @unchecked Sendable {
            var verdicts: [BASProvisionalVerdict] = []
        }
        let capture = Capture()
        let coord = makeCoordinator(
            loop: CountingLoop(requestedStep: 1, stop: .candidateStable),
            maxLoops: 4,
            enabled: true,
            provisionalVerdictSink: { capture.verdicts.append($0) })
        let result = coord.runTurn(BASCoordinatorTestStubs.makeStubRequest())

        XCTAssertEqual(capture.verdicts.count, 1,
            "the sink fires exactly once per turn when flag + sink are set")
        let provisional = try XCTUnwrap(capture.verdicts.first)
        let finalVerdict = try XCTUnwrap(result.sovereignVerdict)
        XCTAssertEqual(provisional.provisionalLevel, finalVerdict.verdictLevel,
            "the pre-render provisional LEVEL forecasts the post-render" +
            " verdict level — identical pre-render inputs, same lattice")
        XCTAssertTrue(provisional.renderIndependent)

        // Observation-only: the SAME turn with NO sink yields the same
        // decision (the provisional emit is a side-channel — it assigns to
        // nothing the verdict / risk / permit consume).
        let bare = makeCoordinator(
            loop: CountingLoop(requestedStep: 1, stop: .candidateStable),
            maxLoops: 4, enabled: true)
        let bareResult = bare.runTurn(
            BASCoordinatorTestStubs.makeStubRequest())
        let bareVerdict = try XCTUnwrap(bareResult.sovereignVerdict)
        XCTAssertEqual(finalVerdict.verdictLevel, bareVerdict.verdictLevel,
            "the provisional emit is observation-only → verdict unchanged")
        XCTAssertEqual(finalVerdict.verdictID, bareVerdict.verdictID)
        XCTAssertEqual(finalVerdict.reasonCodes, bareVerdict.reasonCodes)
        XCTAssertEqual(result.riskCard.riskLevel, bareResult.riskCard.riskLevel)
        XCTAssertEqual(result.actionPermit.mode, bareResult.actionPermit.mode)
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
        XCTAssertGreaterThan(on.riskCard.totalRisk, off.riskCard.totalRisk,
            "the deliberation caution raises totalRisk across the band" +
            " (not asserted as off+0.06 exactly: the ch1041 tilt also" +
            " fires, so the +0.06 lands on the more-reversible" +
            " candidate's slightly-lower binding — see below)")
        XCTAssertTrue(
            on.riskCard.factors.contains("deliberation_uncertain_caution"),
            "the deliberation-caution factor is surfaced on the card")
        // ch1041 — the reversibility-tilt ALSO fires here (same opt-in
        // flag + uncertain turn): selection breaks the near-tie toward
        // the MORE-reversible candidate, so `on` selects a different,
        // SAFER candidate than `off`. The two safe effects compose:
        // tilt (safer choice) + caution (higher assessment).
        XCTAssertNotEqual(on.mergedChoice.candidateID,
            off.mergedChoice.candidateID,
            "the reversibility-tilt selects a different (safer) candidate")
        let offSel = off.thoughtFrame.candidates.first {
            $0.candidateID == off.mergedChoice.candidateID
        }
        let onSel = on.thoughtFrame.candidates.first {
            $0.candidateID == on.mergedChoice.candidateID
        }
        XCTAssertGreaterThan(onSel?.reversibility ?? 0, offSel?.reversibility ?? 1,
            "the tilt's choice is STRICTLY more reversible" +
            " (monotonic-toward-conservative)")
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

    // MARK: - 效率战役 effort-loop FACE activation (2026-07-11, operator: 移动端极高效)

    /// The ε→effort→tier loop was BUILT (governedPlan → effortPlan → RunTurn effort floor) but the
    /// production host FACE never threaded `effortPlan` — every host turn spent the FULL
    /// deliberation budget regardless of surprise×stakes×headroom. The face now carries it
    /// (default nil ⇒ byte-parity). Teeth ride the real-engine fixture above: a `.fast` effort
    /// floor collapses the loop to 1 pass, so its frame equals the loop-OFF frame (the avoided
    /// compute is REAL); a nil plan keeps the multi-pass refinement (≠ off).
    func testFaceThreadedEffortFloorCollapsesRealLoop() throws {
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
        let projection = BASBrainProjection(records: [], candidates: [], recentEvents: [])
        let device = BASCoordinatorTestStubs.nominalDeviceState

        let off = runtime.buildEBrainTurn(
            request: request, currentBrain: currentBrain, projection: projection,
            deviceStateOverride: device, deliberationLoopEnabled: false)
        let fastEffort = runtime.buildEBrainTurn(
            request: request, currentBrain: currentBrain, projection: projection,
            deviceStateOverride: device, deliberationLoopEnabled: true,
            effortPlan: BASEffortPlan(requested: .fast, applied: .fast, overrideReason: nil))
        let fullEffort = runtime.buildEBrainTurn(
            request: request, currentBrain: currentBrain, projection: projection,
            deviceStateOverride: device, deliberationLoopEnabled: true)

        XCTAssertEqual(fastEffort.thoughtFrame.candidates, off.thoughtFrame.candidates,
            ".fast effort floors the loop to 1 pass — no refinement bias ⇒ frame equals loop-OFF "
            + "(the avoided compute is real, not cosmetic)")
        XCTAssertNotEqual(fullEffort.thoughtFrame.candidates, off.thoughtFrame.candidates,
            "nil effortPlan ⇒ passthrough — the multi-pass refinement still fires (byte-parity of "
            + "the pre-effort pipeline)")
    }
}
