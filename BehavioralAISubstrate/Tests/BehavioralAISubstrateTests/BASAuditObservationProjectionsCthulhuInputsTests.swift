// MARK: - BASAuditObservationProjectionsCthulhuInputsTests
// chapter 五百十一 / M1423 — V1 monolith fold continues
//
// PROOF tests for the Cthulhu inputs typed-surface block
// + convenience init on BASAuditObservationProjections:
//   1. compose() produces both factory outputs
//   2. Pass-through accessors mirror underlying trios
//   3. Convenience init equals all-fields init
//   4. Non-Cthulhu args propagate verbatim
//   5. cthulhuFieldCount pinned to 8 (anti-drift)
//   6. Determinism — same inputs produce same output

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASAuditObservationProjectionsCthulhuInputsTests:
    XCTestCase
{

    // MARK: - Fixtures

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
            leaseID: "lease-ct",
            leaseExpiresAt: Date(
                timeIntervalSince1970: 1_705_000_000),
            maintenanceClass: .none,
            wakeIntentID: BASWakeIntentLevel.guard.rawValue,
            allowedHeads: ["primary"],
            policyBundleVersion: "policy.v1",
            policyDecisionIDs: ["d1"])
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

    private func makeBothFactories() -> (
        trio: BASTurnAuditProjectionsAbyssalThermalTrio,
        penta: BASTurnAuditProjectionsCthulhuPenta
    ) {
        let budget = makeBudget()
        let trio =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: budget,
                    turnID: "turn-ct")
        let penta = BASTurnAuditProjectionsCthulhuPenta
            .compute(
                routedBudget: budget,
                runMode: budget.runMode,
                hostID: "host-ct",
                riskLevel: .medium,
                memoryTemperatureLayer:
                    trio.memoryTemperatureLayer,
                candidates: makeCandidates(),
                unknownRefs: ["u-1"],
                assertionCeilingRaw:
                    BASUnknownAssertionCeiling.qualified
                        .rawValue,
                turnID: "turn-ct")
        return (trio, penta)
    }

    // MARK: - 1) compose() produces both factory outputs

    func testComposeProducesBothFactoryOutputs() {
        let parts = makeBothFactories()
        let inputs =
            BASAuditObservationProjectionsCthulhuInputs
                .compose(
                    abyssalThermalTrio: parts.trio,
                    cthulhuPenta: parts.penta)
        XCTAssertEqual(
            inputs.abyssalThermalTrio, parts.trio)
        XCTAssertEqual(
            inputs.cthulhuPenta, parts.penta)
    }

    // MARK: - 2) Pass-through accessors mirror trios

    func testPassThroughAccessorsMirrorUnderlyingFactories() {
        let parts = makeBothFactories()
        let inputs =
            BASAuditObservationProjectionsCthulhuInputs(
                abyssalThermalTrio: parts.trio,
                cthulhuPenta: parts.penta)
        // Trio fields
        XCTAssertEqual(
            inputs.abyssalRunMode,
            parts.trio.abyssalRunMode)
        XCTAssertEqual(
            inputs.abyssBudget, parts.trio.abyssBudget)
        XCTAssertEqual(
            inputs.memoryTemperatureLayer,
            parts.trio.memoryTemperatureLayer)
        // Penta fields
        XCTAssertEqual(
            inputs.abyssalOrganAlias,
            parts.penta.abyssalOrganAlias)
        XCTAssertEqual(
            inputs.humanAnchorProfile,
            parts.penta.humanAnchorProfile)
        XCTAssertEqual(
            inputs.sealedMemory, parts.penta.sealedMemory)
        XCTAssertEqual(
            inputs.cosmicScaleView,
            parts.penta.cosmicScaleView)
        XCTAssertEqual(
            inputs.ontologyFog, parts.penta.ontologyFog)
    }

    // MARK: - 3) Convenience init equals all-fields init

    /// CRITICAL byte-equality PROOF:the convenience init
    /// must produce a result EQUAL to the all-fields init
    /// when called with the 8 unpacked Cthulhu fields。
    func testCthulhuConvenienceInitEqualsAllFieldsInit() {
        let parts = makeBothFactories()
        let inputs =
            BASAuditObservationProjectionsCthulhuInputs(
                abyssalThermalTrio: parts.trio,
                cthulhuPenta: parts.penta)
        let viaConvenience =
            BASAuditObservationProjections(
                cthulhuInputs: inputs)
        let viaAllFields = BASAuditObservationProjections(
            cosmicScaleView: parts.penta.cosmicScaleView,
            ontologyFog: parts.penta.ontologyFog,
            abyssalRunMode: parts.trio.abyssalRunMode,
            abyssBudget: parts.trio.abyssBudget,
            memoryTemperatureLayer:
                parts.trio.memoryTemperatureLayer,
            sealedMemory: parts.penta.sealedMemory,
            humanAnchorProfile:
                parts.penta.humanAnchorProfile,
            abyssalOrganAlias:
                parts.penta.abyssalOrganAlias)
        XCTAssertEqual(
            viaConvenience, viaAllFields,
            "convenience init MUST produce byte-equal" +
            " result to all-fields init with same" +
            " Cthulhu field values")
    }

    // MARK: - 4) Non-Cthulhu args propagate verbatim

    func testNonCthulhuArgsPropagateVerbatim() {
        let parts = makeBothFactories()
        let inputs =
            BASAuditObservationProjectionsCthulhuInputs(
                abyssalThermalTrio: parts.trio,
                cthulhuPenta: parts.penta)
        let p = BASAuditObservationProjections(
            cthulhuInputs: inputs,
            cthulhuAssertionCeilingReasonCodes: ["a-1"],
            cthulhuPermitEscalationReasonCodes:
                ["p-1", "p-2"])
        XCTAssertEqual(
            p.cthulhuAssertionCeilingReasonCodes, ["a-1"])
        XCTAssertEqual(
            p.cthulhuPermitEscalationReasonCodes,
            ["p-1", "p-2"])
    }

    // MARK: - 5) cthulhuFieldCount pinned to 8

    func testCthulhuFieldCountPinnedToEight() {
        XCTAssertEqual(
            BASAuditObservationProjectionsCthulhuInputs
                .cthulhuFieldCount,
            8,
            "Cthulhu field count must match" +
            " BASAuditObservationProjections" +
            " cthulhu-source field count")
    }

    // MARK: - 6) Determinism

    func testDeterminismAcrossRepeatComposeCalls() {
        let parts = makeBothFactories()
        let inputs1 =
            BASAuditObservationProjectionsCthulhuInputs(
                abyssalThermalTrio: parts.trio,
                cthulhuPenta: parts.penta)
        let inputs2 =
            BASAuditObservationProjectionsCthulhuInputs(
                abyssalThermalTrio: parts.trio,
                cthulhuPenta: parts.penta)
        XCTAssertEqual(inputs1, inputs2)
        XCTAssertEqual(
            inputs1.hashValue, inputs2.hashValue)
        // Result equality via convenience init
        let p1 = BASAuditObservationProjections(
            cthulhuInputs: inputs1)
        let p2 = BASAuditObservationProjections(
            cthulhuInputs: inputs2)
        XCTAssertEqual(p1, p2)
    }
}
