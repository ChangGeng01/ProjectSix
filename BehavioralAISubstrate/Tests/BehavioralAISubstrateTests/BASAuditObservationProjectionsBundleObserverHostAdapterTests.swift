// MARK: - BASAuditObservationProjectionsBundleObserverHostAdapter
//         Tests
// chapter 五百二十 / M1457 — host adapter PROOF tests
//
// PROOF tests for the sync→async bridge adapter:
//   1. handler routes emission to observer
//   2. Multiple emissions arrive at observer in order
//   3. snapshotAsBundle reflects accumulated emissions
//   4. Sendable conformance (adapter + handler both)
//   5. handler can be re-used across multiple coordinators

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASAuditObservationProjectionsBundleObserverHostAdapterTests:
    XCTestCase
{

    // MARK: - Fixtures (reuse M1455 pattern)

    private func makeBudget() -> BASBudgetFrame {
        return BASBudgetFrame(
            runMode: .engage,
            maxLoops: 3,
            maxCandidates: 4,
            maxDecodeTokens: 256,
            retrievalDepth: 5,
            precisionProfile: .protected,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch,
            maintenanceAllowed: false,
            leaseID: "lease-adapter",
            leaseExpiresAt: Date(
                timeIntervalSince1970: 1_705_000_000),
            maintenanceClass: .none,
            wakeIntentID: BASWakeIntentLevel.guard.rawValue,
            allowedHeads: ["primary"],
            policyBundleVersion: "policy.v1",
            policyDecisionIDs: ["d1"])
    }

    private func makePermit() -> BASActionPermit {
        return BASActionPermit(
            mode: .answer,
            reasonCodes: ["adapter"],
            outputLengthCap: 200,
            tonePolicy: "calm",
            templatePolicy: "default")
    }

    private func makeCandidates() -> [BASCandidatePath] {
        return [
            BASCandidatePath(
                candidateID: "c-a",
                title: "Path A",
                actionSummary: "summary-a",
                expectedBenefit: 0.7,
                expectedCost: 0.2,
                reversibility: 0.9,
                confidence: 0.7),
        ]
    }

    private func makeKunlunInputs()
        -> BASAuditObservationProjectionsKunlunInputs
    {
        let budget = makeBudget()
        let permit = makePermit()
        let candidates = makeCandidates()
        return BASAuditObservationProjectionsKunlunInputs(
            trio: BASTurnAuditProjectionsKunlunTrio.compute(
                routedBudget: budget,
                riskLevel: .medium,
                permit: permit,
                turnID: "t",
                sessionID: "s",
                kunlunAxisID: "a"),
            hexa: BASTurnAuditProjectionsKunlunHexa.compute(
                runMode: budget.runMode,
                riskLevel: .medium,
                permit: permit,
                candidates: candidates,
                turnID: "t"),
            trioTwo:
                BASTurnAuditProjectionsKunlunTrioTwo
                    .compute(
                        runMode: budget.runMode,
                        riskLevel: .medium,
                        candidates: candidates,
                        organRefMorph: "m",
                        turnID: "t",
                        sessionID: "s"),
            hexaTwo:
                BASTurnAuditProjectionsKunlunHexaTwo
                    .compute(
                        hostID: "h",
                        sessionID: "s",
                        turnID: "t",
                        unknownRefs: ["u-1"],
                        assertionCeiling: .qualified,
                        riskLevel: .medium,
                        candidates: candidates))
    }

    private func makeCthulhuInputs()
        -> BASAuditObservationProjectionsCthulhuInputs
    {
        let budget = makeBudget()
        let trio =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: budget,
                    turnID: "t")
        return BASAuditObservationProjectionsCthulhuInputs(
            abyssalThermalTrio: trio,
            cthulhuPenta:
                BASTurnAuditProjectionsCthulhuPenta
                    .compute(
                        routedBudget: budget,
                        runMode: budget.runMode,
                        hostID: "h",
                        riskLevel: .medium,
                        memoryTemperatureLayer:
                            trio.memoryTemperatureLayer,
                        candidates: makeCandidates(),
                        unknownRefs: ["u-1"],
                        assertionCeilingRaw:
                            BASUnknownAssertionCeiling
                                .qualified.rawValue,
                        turnID: "t")
            )
    }

    private func fixedDate(_ offset: TimeInterval = 0)
        -> Date
    {
        return Date(
            timeIntervalSince1970: 1_705_000_000 + offset)
    }

    /// Bounded, deadline-guarded drain — no fixed sleep. Polls until the observer
    /// has recorded `count` emissions or the deadline elapses.
    private func drain(
        _ observer: BASAuditObservationProjectionsBundleObserver,
        until count: Int,
        deadlineSeconds: Double = 5.0
    ) async {
        let start = Date()
        while await observer.emissionCount < count {
            if Date().timeIntervalSince(start) > deadlineSeconds { return }
            await Task.yield()
        }
    }

    override func tearDown() {
        // Never leak the test-only stagger hook into other suites.
        BASAuditObservationProjectionsBundleObserver._recordStaggerForTesting = nil
        super.tearDown()
    }

    // MARK: - 1) handler routes emission to observer

    func testHandlerRoutesEmissionToObserver() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let adapter =
            BASAuditObservationProjectionsBundleObserverHostAdapter(
                observer: observer)
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        let obs =
            BASAuditObservationProjectionsBundleObservation
                .fullyCovered(
                    turnID: "t-route",
                    sessionID: "s",
                    emittedAt: fixedDate(),
                    kunlunInputs: ki,
                    cthulhuInputs: ci)
        adapter.handler(obs)
        // Task.detached is async — wait briefly for the
        // observer to record. The observer is an actor;
        // a no-op call ensures the Task has been
        // scheduled and we read after.
        try? await Task.sleep(nanoseconds: 100_000_000)
        let snap = await observer.snapshot()
        XCTAssertEqual(snap.count, 1)
        XCTAssertEqual(snap.first?.turnID, "t-route")
    }

    // MARK: - 2) Multiple emissions arrive in order

    func testMultipleEmissionsArriveInOrder() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let adapter =
            BASAuditObservationProjectionsBundleObserverHostAdapter(
                observer: observer)
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        for i in 0..<5 {
            let obs =
                BASAuditObservationProjectionsBundleObservation
                    .fullyCovered(
                        turnID: "t-\(i)",
                        sessionID: "s",
                        emittedAt: fixedDate(
                            TimeInterval(i)),
                        kunlunInputs: ki,
                        cthulhuInputs: ci)
            adapter.handler(obs)
        }
        await drain(observer, until: 5)
        let snap = await observer.snapshot()
        XCTAssertEqual(snap.count, 5,
            "5 emissions must reach observer")
        // audit hostkit-rest MED-5: the ordered pump preserves ARRIVAL order — this
        // is now an EXACT ordered-array assertion (was weakened to Set membership to
        // accommodate the old Task.detached scheduling nondeterminism).
        XCTAssertEqual(snap.map(\.turnID),
                       (0..<5).map { "t-\($0)" },
            "emissions must be recorded in strict arrival order")
    }

    // MARK: - 2b) Strict arrival order holds even under a per-emission stagger
    //
    // Deterministic teeth for the ordered pump. A descending stagger (t-0 delayed
    // longest, t-7 shortest) is injected into the actor. The single-consumer pump
    // processes each emission to completion before pulling the next, so the recorded
    // order is arrival order REGARDLESS of the stagger. Reversal: restore the old
    // per-emission `Task.detached` in the adapter's `handler` — the N concurrent
    // records then append in stagger-completion order (reverse), reddening the exact
    // equality below deterministically (no flake).

    func testStrictArrivalOrderHoldsUnderPerEmissionStagger() async {
        let n = 8
        BASAuditObservationProjectionsBundleObserver._recordStaggerForTesting = { obs in
            guard obs.turnID.hasPrefix("ord-"),
                  let idx = Int(obs.turnID.dropFirst(4)) else { return }
            // t-0 sleeps longest, t-(n-1) shortest → detached path would reverse.
            try? await Task.sleep(nanoseconds: UInt64((n - idx) * 8_000_000))
        }
        defer { BASAuditObservationProjectionsBundleObserver._recordStaggerForTesting = nil }

        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let adapter =
            BASAuditObservationProjectionsBundleObserverHostAdapter(
                observer: observer)
        for i in 0..<n {
            adapter.handler(.uncovered(
                turnID: "ord-\(i)",
                sessionID: "s",
                emittedAt: fixedDate(TimeInterval(i))))
        }
        await drain(observer, until: n, deadlineSeconds: 10.0)
        let snap = await observer.snapshot()
        XCTAssertEqual(snap.map(\.turnID),
                       (0..<n).map { "ord-\($0)" },
            "the ordered pump must record in arrival order even when each record is staggered")
    }

    // MARK: - 3) snapshotAsBundle reflects accumulated

    func testSnapshotAsBundleReflectsAccumulated()
        async
    {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let adapter =
            BASAuditObservationProjectionsBundleObserverHostAdapter(
                observer: observer)
        let ki = makeKunlunInputs()
        let ci = makeCthulhuInputs()
        adapter.handler(
            .fullyCovered(
                turnID: "bundle-1",
                sessionID: "s",
                emittedAt: fixedDate(),
                kunlunInputs: ki,
                cthulhuInputs: ci))
        adapter.handler(
            .uncovered(
                turnID: "bundle-2",
                sessionID: "s",
                emittedAt: fixedDate(1)))
        try? await Task.sleep(nanoseconds: 300_000_000)
        let bundle = await observer.snapshotAsBundle()
        XCTAssertEqual(bundle.count, 2)
        XCTAssertEqual(bundle.fullyCoveredTurnCount, 1)
        XCTAssertEqual(bundle.coldTurnCount, 1)
    }

    // MARK: - 4) Sendable conformance (compile-time)

    /// Compile-time check: the adapter + its handler
    /// must be Sendable so they can cross actor
    /// boundaries safely。
    func testAdapterAndHandlerAreSendable() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let adapter =
            BASAuditObservationProjectionsBundleObserverHostAdapter(
                observer: observer)
        let handler = adapter.handler
        // Capture in a @Sendable closure to verify
        // Sendable conformance at compile time
        let captured: @Sendable () ->
            @Sendable
                (BASAuditObservationProjectionsBundleObservation)
                -> Void = { handler }
        let h2 = captured()
        h2(.uncovered(
            turnID: "sendable",
            sessionID: "s",
            emittedAt: fixedDate()))
        try? await Task.sleep(nanoseconds: 100_000_000)
        let count = await observer.emissionCount
        XCTAssertEqual(count, 1)
    }

    // MARK: - 5) Handler can be re-used across coordinators

    func testHandlerReusedAcrossSources() async {
        let observer =
            BASAuditObservationProjectionsBundleObserver()
        let adapter =
            BASAuditObservationProjectionsBundleObserverHostAdapter(
                observer: observer)
        // Simulate 2 coordinators sharing the handler
        let h1 = adapter.handler
        let h2 = adapter.handler
        h1(.uncovered(
            turnID: "coord-a-turn-1",
            sessionID: "s",
            emittedAt: fixedDate(0)))
        h2(.uncovered(
            turnID: "coord-b-turn-1",
            sessionID: "s",
            emittedAt: fixedDate(1)))
        try? await Task.sleep(nanoseconds: 300_000_000)
        let count = await observer.emissionCount
        XCTAssertEqual(count, 2)
    }
}
