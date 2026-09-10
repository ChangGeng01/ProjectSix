// MARK: - BASChengluMeshRegistrationTests — chapter 三百二一 / M808
//
// Phase F (附录 X) 第二刀 测试覆盖第二部分:assembly helper +
// canonical 8-slot doctrine + report shape + reason codes +
// idempotence + cascade compatibility with rules-tier placeholders。
//
// All tests use parametric closure variants (assembleFromClosures)
// so no real `.mlpackage` binary required。

import XCTest
@testable import BASAppleAdapters
@testable import BASRuntimeCore

final class BASChengluMeshRegistrationTests: XCTestCase {

    // MARK: - Helpers

    private func makeStubClosure(
        scoreMap: [String: Double] = ["x": 0.5]
    ) -> @Sendable (BASCoreMLFeatureFrame) async throws
        -> BASCoreMLPredictionFrame
    {
        return { _ in
            BASCoreMLPredictionFrame(
                scores: scoreMap, inferenceLatencyMs: 0.5)
        }
    }

    private func makeAllClosuresOptions()
        -> BASChengluMeshRegistration.ClosureRegistrationOptions
    {
        BASChengluMeshRegistration.ClosureRegistrationOptions(
            preflightClosure: makeStubClosure(
                scoreMap: ["afm_success_probability": 0.7]),
            multiHeadClosure: makeStubClosure(scoreMap: [
                "intent": 0.6,
                "emotion": 0.4,
                "risk": 0.5,
                "memory_importance": 0.55
            ]),
            permitPredictClosure: makeStubClosure(
                scoreMap: ["block_probability": 0.3]),
            lengthHeadClosure: makeStubClosure(
                scoreMap: ["body_length": 750]),
            latencyHeadClosure: makeStubClosure(
                scoreMap: ["duration_ms": 1500]))
    }

    // MARK: - BASChengluMeshRegistrationReport

    func testRegistrationReportDefaults() {
        let report = BASChengluMeshRegistrationReport()
        XCTAssertEqual(report.schemaVersion, "1.0.0")
        XCTAssertEqual(report.registeredHeadCount, 0)
        XCTAssertTrue(report.perLayerCounts.isEmpty)
        XCTAssertTrue(report.missingMLModels.isEmpty)
        XCTAssertTrue(report.reasonCodes.isEmpty)
        XCTAssertFalse(report.isComplete)
    }

    func testRegistrationReportClampsNegativeCount() {
        let report = BASChengluMeshRegistrationReport(
            registeredHeadCount: -3)
        XCTAssertEqual(
            report.registeredHeadCount, 0,
            "negative count must clamp to 0")
    }

    func testRegistrationReportTrimsAndFiltersEmpty() {
        let report = BASChengluMeshRegistrationReport(
            missingMLModels: ["  preflight  ", "", "\n"],
            reasonCodes: ["  code-a  ", "", "\n"])
        XCTAssertEqual(report.missingMLModels, ["preflight"])
        XCTAssertEqual(report.reasonCodes, ["code-a"])
    }

    func testRegistrationReportIsCompleteOnlyAt8() {
        let r0 = BASChengluMeshRegistrationReport(
            registeredHeadCount: 0)
        let r7 = BASChengluMeshRegistrationReport(
            registeredHeadCount: 7)
        let r8 = BASChengluMeshRegistrationReport(
            registeredHeadCount: 8)
        XCTAssertFalse(r0.isComplete)
        XCTAssertFalse(r7.isComplete)
        XCTAssertTrue(r8.isComplete)
    }

    func testRegistrationReportCodableRoundTrip() throws {
        let original = BASChengluMeshRegistrationReport(
            registeredHeadCount: 8,
            perLayerCounts: [
                "l1": 2, "l4": 1, "l6": 1,
                "l8": 1, "l11": 2, "l12": 1
            ],
            missingMLModels: [],
            reasonCodes: ["mesh-coreml:registered:8"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASChengluMeshRegistrationReport.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - canonicalHeadID doctrine

    func testCanonicalHeadIDFormat() {
        XCTAssertEqual(
            BASChengluMeshRegistration.canonicalHeadID(
                layer: .l1, role: "wake-policy"),
            "chenglu.l1.wake-policy")
        XCTAssertEqual(
            BASChengluMeshRegistration.canonicalHeadID(
                layer: .l11, role: "risk-scorer"),
            "chenglu.l11.risk-scorer")
    }

    // MARK: - assembleFromClosures: full happy path

    func testAssembleAllClosuresRegisters8Slots() async throws {
        let registry = BASLayerMLHeadRegistry()
        let report = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry,
                options: makeAllClosuresOptions())

        XCTAssertEqual(
            report.registeredHeadCount, 8,
            "All 5 closures present → 8 canonical slots")
        XCTAssertTrue(report.isComplete)
        XCTAssertTrue(
            report.missingMLModels.isEmpty,
            "No models missing when all closures provided")

        // Verify per-layer counts match附录 X §X.2 doctrine
        XCTAssertEqual(
            report.perLayerCounts["l1"], 2,
            "L1 = wake-policy + compute-cost-predictor = 2")
        XCTAssertEqual(report.perLayerCounts["l4"], 1)
        XCTAssertEqual(report.perLayerCounts["l6"], 1)
        XCTAssertEqual(report.perLayerCounts["l8"], 1)
        XCTAssertEqual(
            report.perLayerCounts["l11"], 2,
            "L11 = risk-scorer + safety-action-selector = 2")
        XCTAssertEqual(report.perLayerCounts["l12"], 1)

        // Registry should hold 8 heads total
        let totalCount = await registry.totalHeadCount
        XCTAssertEqual(totalCount, 8)
    }

    // MARK: - assembleFromClosures: partial input

    func testAssembleOnlyPreflightRegisters1Slot() async throws {
        let registry = BASLayerMLHeadRegistry()
        let options = BASChengluMeshRegistration
            .ClosureRegistrationOptions(
                preflightClosure: makeStubClosure(
                    scoreMap: [
                        "afm_success_probability": 0.7
                    ]))
        let report = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry, options: options)

        XCTAssertEqual(report.registeredHeadCount, 1)
        XCTAssertFalse(report.isComplete)
        XCTAssertEqual(report.perLayerCounts["l1"], 1)
        XCTAssertEqual(
            Set(report.missingMLModels),
            Set([
                "latencyHead", "multiHead",
                "permitPredict", "lengthHead"
            ]),
            "All 4 unset closures must be reported as missing")
    }

    func testAssembleEmptyOptionsRegistersZeroSlots() async throws
    {
        let registry = BASLayerMLHeadRegistry()
        let options = BASChengluMeshRegistration
            .ClosureRegistrationOptions()
        let report = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry, options: options)
        XCTAssertEqual(report.registeredHeadCount, 0)
        XCTAssertEqual(report.missingMLModels.count, 5)
        let totalCount = await registry.totalHeadCount
        XCTAssertEqual(totalCount, 0)
    }

    // MARK: - reason codes typed format

    func testAssembleEmitsCanonicalReasonCodes() async throws {
        let registry = BASLayerMLHeadRegistry()
        let report = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry,
                options: makeAllClosuresOptions())

        XCTAssertTrue(report.reasonCodes.contains(
            "mesh-coreml:registered:8"))
        XCTAssertTrue(report.reasonCodes.contains(
            "mesh-coreml:expected:8"))

        // Per-layer codes
        XCTAssertTrue(report.reasonCodes.contains(
            "mesh-coreml:layer-l1:2"))
        XCTAssertTrue(report.reasonCodes.contains(
            "mesh-coreml:layer-l11:2"))
        XCTAssertTrue(report.reasonCodes.contains(
            "mesh-coreml:layer-l4:1"))
    }

    func testAssembleEmitsMissingReasonCodesWhenPartial()
        async throws
    {
        let registry = BASLayerMLHeadRegistry()
        let options = BASChengluMeshRegistration
            .ClosureRegistrationOptions(
                preflightClosure: makeStubClosure())
        let report = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry, options: options)
        XCTAssertTrue(report.reasonCodes.contains(
            "mesh-coreml:missing:multiHead"))
        XCTAssertTrue(report.reasonCodes.contains(
            "mesh-coreml:missing:permitPredict"))
        XCTAssertTrue(report.reasonCodes.contains(
            "mesh-coreml:missing:lengthHead"))
        XCTAssertTrue(report.reasonCodes.contains(
            "mesh-coreml:missing:latencyHead"))
    }

    // MARK: - Idempotence (independent registries)

    func testAssembleIntoIndependentRegistriesYieldsSameReport()
        async throws
    {
        let registry1 = BASLayerMLHeadRegistry()
        let registry2 = BASLayerMLHeadRegistry()
        let report1 = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry1,
                options: makeAllClosuresOptions())
        let report2 = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry2,
                options: makeAllClosuresOptions())
        XCTAssertEqual(
            report1.registeredHeadCount,
            report2.registeredHeadCount)
        XCTAssertEqual(
            report1.perLayerCounts, report2.perLayerCounts)
    }

    // MARK: - Duplicate registration throws

    func testAssembleSameRegistryTwiceThrowsDuplicateID()
        async
    {
        let registry = BASLayerMLHeadRegistry()
        do {
            _ = try await BASChengluMeshRegistration
                .assembleFromClosures(
                    into: registry,
                    options: makeAllClosuresOptions())
        } catch {
            XCTFail("First assemble must succeed: \(error)")
        }
        // Second assemble must fail at first duplicate
        do {
            _ = try await BASChengluMeshRegistration
                .assembleFromClosures(
                    into: registry,
                    options: makeAllClosuresOptions())
            XCTFail("Second assemble must throw duplicate ID")
        } catch {
            XCTAssertTrue(
                "\(error)".contains("duplicateHeadID"),
                "Error must be duplicateHeadID, got \(error)")
        }
    }

    // MARK: - Cascade compatibility with rules-tier placeholders

    func testCoreMLHeadsRegisteredAtCascadingTierPriority()
        async throws
    {
        let registry = BASLayerMLHeadRegistry()
        _ = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry,
                options: makeAllClosuresOptions())

        // All Chenglu heads should be at coremlOnDevice priority
        // = 10 per chapter 三百一三 (M800) doctrine。
        let l1Slots = await registry.slots(forLayer: .l1)
        XCTAssertEqual(l1Slots.count, 2)
        for slot in l1Slots {
            XCTAssertEqual(
                slot.priority,
                BAS14LayerMeshMap.coremlOnDeviceTierPriority,
                "All Chenglu heads must register at " +
                "coremlOnDevice tier priority (10)")
            XCTAssertEqual(slot.kind, .coremlOnDevice)
        }

        let l11Slots = await registry.slots(forLayer: .l11)
        XCTAssertEqual(l11Slots.count, 2)
        for slot in l11Slots {
            XCTAssertEqual(
                slot.priority,
                BAS14LayerMeshMap.coremlOnDeviceTierPriority)
        }
    }

    // MARK: - 8-slot doctrine (附录 X §X.2)

    func testCanonicalEightSlotMappingHeadIDs() async throws {
        let registry = BASLayerMLHeadRegistry()
        _ = try await BASChengluMeshRegistration
            .assembleFromClosures(
                into: registry,
                options: makeAllClosuresOptions())

        // Verify each canonical head ID is registered per
        // 附录 X §X.2 doctrine
        let expectedIDs: Set<String> = [
            "chenglu.l1.wake-policy",
            "chenglu.l1.compute-cost-predictor",
            "chenglu.l4.question-type",
            "chenglu.l6.emotion-classifier",
            "chenglu.l8.importance-scorer",
            "chenglu.l11.risk-scorer",
            "chenglu.l11.safety-action-selector",
            "chenglu.l12.density-controller"
        ]
        for headID in expectedIDs {
            do {
                _ = try await registry.head(headID: headID)
            } catch {
                XCTFail(
                    "Expected canonical head \(headID) " +
                    "missing: \(error)")
            }
        }
    }

    func testMakeReasonCodesFunctionDirectInvocation() {
        let codes = BASChengluMeshRegistration.makeReasonCodes(
            registered: 4,
            missing: ["multiHead", "lengthHead"],
            perLayerCounts: ["l1": 2, "l11": 2])
        XCTAssertTrue(codes.contains(
            "mesh-coreml:registered:4"))
        XCTAssertTrue(codes.contains(
            "mesh-coreml:expected:8"))
        XCTAssertTrue(codes.contains(
            "mesh-coreml:missing:lengthHead"))
        XCTAssertTrue(codes.contains(
            "mesh-coreml:missing:multiHead"))
        XCTAssertTrue(codes.contains(
            "mesh-coreml:layer-l1:2"))
        XCTAssertTrue(codes.contains(
            "mesh-coreml:layer-l11:2"))
        // Layers with 0 count must NOT appear
        XCTAssertFalse(codes.contains(
            "mesh-coreml:layer-l4:0"))
    }
}
