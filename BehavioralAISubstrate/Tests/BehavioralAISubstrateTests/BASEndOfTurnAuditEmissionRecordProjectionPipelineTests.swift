// MARK: - BASEndOfTurnAuditEmissionRecord
//         ProjectionPipelineTests
// chapter 五百十三 / M1430 — 5th pipeline tests
//
// PROOF tests for the 5th pipeline (projection-block
// observations) added to BASEndOfTurnAuditEmissionRecord:
//   1. Default construction has nil projection bundle
//   2. Pipeline 5 populates correctly
//   3. populatedPipelineCount counts all 5
//   4. hasAllFivePipelines true only with 5 pipelines
//   5. hasAllFourPipelines remains backwards-compat
//      (legacy 4-of-4 semantic)
//   6. Codable round-trip preserves pipeline 5

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASEndOfTurnAuditEmissionRecordProjectionPipelineTests:
    XCTestCase
{

    // MARK: - Fixtures

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
            leaseID: "lease-p5",
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
            reasonCodes: ["p5"],
            outputLengthCap: 200,
            tonePolicy: "calm",
            templatePolicy: "default")
    }

    private func makeProjectionBundle()
        -> BASAuditObservationProjectionsBundle
    {
        let budget = makeBudget()
        let permit = makePermit()
        let candidates = makeCandidates()
        let ki = BASAuditObservationProjectionsKunlunInputs(
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
        let trio =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: budget,
                    turnID: "t")
        let ci = BASAuditObservationProjectionsCthulhuInputs(
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
                        candidates: candidates,
                        unknownRefs: ["u-1"],
                        assertionCeilingRaw:
                            BASUnknownAssertionCeiling
                                .qualified.rawValue,
                        turnID: "t"))
        return BASAuditObservationProjectionsBundle(
            bundleID: "bundle-fixture-1",
            items: [
                .fullyCovered(
                    turnID: "t",
                    sessionID: "s",
                    emittedAt: Date(
                        timeIntervalSince1970:
                            1_705_000_000),
                    kunlunInputs: ki,
                    cthulhuInputs: ci),
            ],
            recordedAt: Date(
                timeIntervalSince1970: 1_705_000_000))
    }

    // MARK: - 1) Default has nil projection bundle

    func testDefaultConstructionHasNilProjectionBundle() {
        let record = BASEndOfTurnAuditEmissionRecord(
            turnID: "t",
            recordedAtMs: 1)
        XCTAssertNil(record.projectionBlockObservations)
    }

    // MARK: - 2) Pipeline 5 populates

    func testPipelineFivePopulates() {
        let bundle = makeProjectionBundle()
        let record = BASEndOfTurnAuditEmissionRecord(
            turnID: "t",
            projectionBlockObservations: bundle,
            recordedAtMs: 1)
        XCTAssertEqual(
            record.projectionBlockObservations, bundle)
    }

    // MARK: - 3) populatedPipelineCount counts 5

    func testPopulatedPipelineCountCountsAllFive() {
        // Build a fully-populated record (all 5
        // pipelines). Pipelines 1-4 use empty stubs;
        // pipeline 5 uses the real projection bundle.
        let bundle = makeProjectionBundle()
        let r1 = BASEndOfTurnAuditEmissionRecord(
            turnID: "t",
            projectionBlockObservations: bundle,
            recordedAtMs: 1)
        XCTAssertEqual(r1.populatedPipelineCount, 1)
        let r0 = BASEndOfTurnAuditEmissionRecord(
            turnID: "t", recordedAtMs: 1)
        XCTAssertEqual(r0.populatedPipelineCount, 0)
    }

    // MARK: - 4) hasAllFivePipelines requires all 5

    func testHasAllFivePipelinesRequiresAllFive() {
        let r1 = BASEndOfTurnAuditEmissionRecord(
            turnID: "t",
            projectionBlockObservations:
                makeProjectionBundle(),
            recordedAtMs: 1)
        XCTAssertFalse(r1.hasAllFivePipelines,
            "1-of-5 must NOT report fully populated")
        let r0 = BASEndOfTurnAuditEmissionRecord(
            turnID: "t", recordedAtMs: 1)
        XCTAssertFalse(r0.hasAllFivePipelines,
            "0-of-5 must NOT report fully populated")
    }

    // MARK: - 5) hasAllFourPipelines backwards-compat

    func testHasAllFourPipelinesRemainsBackwardsCompat() {
        // Pre-M1430, hasAllFourPipelines == (count == 4).
        // Post-M1430, it ignores the 5th pipeline and
        // checks the legacy 4-pipeline shape — exact
        // backwards compat。 Build a record with all 4
        // legacy pipelines + no projection bundle:
        // hasAllFourPipelines must be true。
        // Build a record with the 5th pipeline only:
        // hasAllFourPipelines must be false。
        let r5only = BASEndOfTurnAuditEmissionRecord(
            turnID: "t",
            projectionBlockObservations:
                makeProjectionBundle(),
            recordedAtMs: 1)
        XCTAssertFalse(r5only.hasAllFourPipelines,
            "pipeline 5 alone is NOT 4-of-4")
        XCTAssertEqual(
            r5only.populatedPipelineCount, 1)
    }

    // MARK: - 6) Codable round-trip preserves pipeline 5

    func testCodableRoundTripPreservesPipelineFive()
        throws
    {
        let bundle = makeProjectionBundle()
        let original = BASEndOfTurnAuditEmissionRecord(
            turnID: "t",
            projectionBlockObservations: bundle,
            recordedAtMs: 42)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(
            BASEndOfTurnAuditEmissionRecord.self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(
            decoded.projectionBlockObservations, bundle)
    }
}
