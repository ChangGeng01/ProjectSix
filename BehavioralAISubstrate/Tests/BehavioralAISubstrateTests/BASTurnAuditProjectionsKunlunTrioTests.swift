// MARK: - BASTurnAuditProjectionsKunlunTrioTests
// chapter 四百七十八 / M1288
//
// PROOF tests for the first V1 monolith fold pilot:
//
//   - Factory produces all 3 typed projections
//   - Factory output is bit-equal to calling the 3
//     derive methods directly (byte-equality preserved
//     by construction)
//   - Determinism — same inputs produce same outputs
//     across repeat calls (chapter 三百九二)
//   - Different inputs produce different outputs
//     (sanity flow)
//   - Hashable + Sendable conformance (compile-time
//     check)

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASTurnAuditProjectionsKunlunTrioTests:
    XCTestCase
{

    // MARK: - Test fixtures

    private func makeBudgetFrame(
        runMode: BASEBrainRunMode = .engage,
        maxLoops: Int = 3,
        leaseID: String? = "lease-pilot"
    ) -> BASBudgetFrame {
        return BASBudgetFrame(
            runMode: runMode,
            maxLoops: maxLoops,
            maxCandidates: 4,
            maxDecodeTokens: 256,
            retrievalDepth: 5,
            precisionProfile: .protected,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: .watch,
            maintenanceAllowed: false,
            leaseID: leaseID,
            leaseExpiresAt: Date(
                timeIntervalSince1970: 1_705_000_000),
            maintenanceClass: .none,
            wakeIntentID: BASWakeIntentLevel.guard.rawValue,
            allowedHeads: ["primary"],
            policyBundleVersion: "policy.v1",
            policyDecisionIDs: ["d1"])
    }

    private func makePermit(
        mode: BASActionPermitMode = .answer
    ) -> BASActionPermit {
        return BASActionPermit(
            mode: mode,
            reasonCodes: ["pilot"],
            outputLengthCap: 200,
            tonePolicy: "calm",
            templatePolicy: "default")
    }

    // MARK: - Factory produces 3 typed projections

    func testTrioFactoryProducesAllThreeProjections() {
        let budget = makeBudgetFrame()
        let permit = makePermit()
        let trio = BASTurnAuditProjectionsKunlunTrio
            .compute(
                routedBudget: budget,
                riskLevel: .medium,
                permit: permit,
                turnID: "turn-pilot",
                sessionID: "session-pilot",
                kunlunAxisID: "axis-pilot")
        // Compile-time + runtime structural check:
        // all 3 fields populated
        XCTAssertFalse(
            trio.ascentLease.leaseID.isEmpty,
            "ascentLease must derive a leaseID")
        XCTAssertFalse(
            trio.axisDeviation.deviationID.isEmpty,
            "axisDeviation must derive a deviationID")
        XCTAssertFalse(
            trio.gatePressure.pressureID.isEmpty,
            "gatePressure must derive a pressureID")
    }

    // MARK: - Byte-equality with direct derive calls

    /// PROOF that the factory produces bit-identical
    /// output to calling the 3 derive methods directly。
    /// This is THE invariant: any future modification
    /// to the factory must keep this test green to
    /// preserve byte-equality with the pre-fold
    /// coordinator behavior。
    func testTrioFactoryOutputEqualsDirectDeriveCalls() {
        let budget = makeBudgetFrame()
        let permit = makePermit()
        let turnID = "turn-equality"
        let sessionID = "session-equality"
        let kunlunAxisID = "axis-equality"

        // Direct derive — mirror the coordinator
        // monolith lines 1240-1255 exactly
        let directAscent = BASKunlunLayerProjections
            .AscentLease
            .derive(
                from: budget,
                turnID: turnID)
        let directDeviation = BASKunlunLayerProjections
            .AxisDeviation
            .derive(
                from: .medium,
                turnID: turnID,
                situationRef: sessionID,
                centerlineRef: kunlunAxisID)
        let directPressure = BASKunlunLayerProjections
            .GatePressure
            .derive(
                from: .medium,
                permit: permit,
                turnID: turnID,
                situationRef: sessionID)

        // Factory call
        let trio = BASTurnAuditProjectionsKunlunTrio
            .compute(
                routedBudget: budget,
                riskLevel: .medium,
                permit: permit,
                turnID: turnID,
                sessionID: sessionID,
                kunlunAxisID: kunlunAxisID)

        // Field-by-field equality assertion
        XCTAssertEqual(
            trio.ascentLease, directAscent,
            "factory.ascentLease must equal direct" +
            " derive call (byte-equality pin)")
        XCTAssertEqual(
            trio.axisDeviation, directDeviation,
            "factory.axisDeviation must equal direct" +
            " derive call")
        XCTAssertEqual(
            trio.gatePressure, directPressure,
            "factory.gatePressure must equal direct" +
            " derive call")
    }

    // MARK: - Determinism

    func testTrioFactoryIsDeterministic() {
        let budget = makeBudgetFrame()
        let permit = makePermit()
        let trio1 = BASTurnAuditProjectionsKunlunTrio
            .compute(
                routedBudget: budget,
                riskLevel: .high,
                permit: permit,
                turnID: "turn-determinism",
                sessionID: "session-determinism",
                kunlunAxisID: "axis-determinism")
        let trio2 = BASTurnAuditProjectionsKunlunTrio
            .compute(
                routedBudget: budget,
                riskLevel: .high,
                permit: permit,
                turnID: "turn-determinism",
                sessionID: "session-determinism",
                kunlunAxisID: "axis-determinism")
        XCTAssertEqual(
            trio1, trio2,
            "same inputs must produce equal trios" +
            " (chapter 三百九二 replay-determinism)")
    }

    // MARK: - Different inputs → different outputs

    func testTrioFactoryFlowsInputsThrough() {
        let budget = makeBudgetFrame()
        let permit = makePermit()
        let lowTrio = BASTurnAuditProjectionsKunlunTrio
            .compute(
                routedBudget: budget,
                riskLevel: .low,
                permit: permit,
                turnID: "turn-flow",
                sessionID: "session-flow",
                kunlunAxisID: "axis-flow")
        let highTrio = BASTurnAuditProjectionsKunlunTrio
            .compute(
                routedBudget: budget,
                riskLevel: .high,
                permit: permit,
                turnID: "turn-flow",
                sessionID: "session-flow",
                kunlunAxisID: "axis-flow")
        // Different risk levels must produce different
        // axisDeviation + gatePressure projections。 The
        // ascentLease is unaffected by riskLevel — same
        // value expected。
        XCTAssertNotEqual(
            lowTrio.axisDeviation,
            highTrio.axisDeviation,
            "risk level must flow through to axis" +
            " deviation derivation")
        XCTAssertNotEqual(
            lowTrio.gatePressure,
            highTrio.gatePressure,
            "risk level must flow through to gate" +
            " pressure derivation")
        XCTAssertEqual(
            lowTrio.ascentLease,
            highTrio.ascentLease,
            "ascentLease doesn't depend on riskLevel —" +
            " unchanged across risk variations")
    }

    // MARK: - Hashable + Sendable conformance

    func testTrioIsHashableAndSendable() {
        // Compile-time check via Set + Sendable typed
        // var assignment
        let budget = makeBudgetFrame()
        let permit = makePermit()
        let trio = BASTurnAuditProjectionsKunlunTrio
            .compute(
                routedBudget: budget,
                riskLevel: .low,
                permit: permit,
                turnID: "t1",
                sessionID: "s1",
                kunlunAxisID: "a1")
        let set: Set<BASTurnAuditProjectionsKunlunTrio> = [trio]
        XCTAssertTrue(set.contains(trio))
        let sendableRef:
            any Sendable = trio
        _ = sendableRef
    }

    // MARK: - Compute order preserved (sequence pin)

    /// Sanity check that the factory is a single static
    /// function (not split across multiple async-let or
    /// re-ordered)。 Pinned via fixture symmetry — same
    /// inputs across many concurrent invocations
    /// preserve byte-equality。
    func testTrioFactoryThreadSafetyUnderConcurrentLoad()
        async
    {
        let budget = makeBudgetFrame()
        let permit = makePermit()

        let firstTrio = BASTurnAuditProjectionsKunlunTrio
            .compute(
                routedBudget: budget,
                riskLevel: .medium,
                permit: permit,
                turnID: "concurrent",
                sessionID: "concurrent",
                kunlunAxisID: "concurrent")

        await withTaskGroup(of: BASTurnAuditProjectionsKunlunTrio.self) {
            group in
            for _ in 0..<10 {
                group.addTask {
                    BASTurnAuditProjectionsKunlunTrio
                        .compute(
                            routedBudget: budget,
                            riskLevel: .medium,
                            permit: permit,
                            turnID: "concurrent",
                            sessionID: "concurrent",
                            kunlunAxisID: "concurrent")
                }
            }
            for await result in group {
                XCTAssertEqual(
                    result, firstTrio,
                    "concurrent factory invocations" +
                    " must produce identical trios")
            }
        }
    }
}
