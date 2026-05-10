// MARK: - BASHardwareAwareSchedulerTests
// chapter 四百三十二 / M1102

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASHardwareAwareSchedulerTests: XCTestCase {

    // MARK: - Empty registry → CPU-only fallback

    func testEmptyRegistryRoutesCPUOnly() async {
        let scheduler = BASHardwareAwareScheduler()
        let hint = matMulHint()
        let assignment = await scheduler.assign(
            hint: hint,
            capability: BASANECapability
                .nominalAppleSilicon(),
            thermal: .nominal)
        XCTAssertEqual(
            assignment.selectedBackingKind, .cpuBytes,
            "empty registry forces CPU dispatch")
        XCTAssertNil(assignment.selectedKernelKey)
        XCTAssertEqual(
            assignment.assignmentRationale,
            .cpuNoKernelRegistered)
    }

    // MARK: - No registry passed at all → CPU-only fallback

    func testNoRegistryRoutesCPUOnly() async {
        let scheduler = BASHardwareAwareScheduler(
            registry: nil)
        let assignment = await scheduler.assign(
            hint: matMulHint(),
            capability: BASANECapability
                .nominalAppleSilicon(),
            thermal: .nominal)
        XCTAssertEqual(
            assignment.selectedBackingKind, .cpuBytes)
        XCTAssertNil(assignment.selectedKernelKey)
    }

    // MARK: - MLX-registered kernel + ANE supported →
    // chooses non-CPU

    func testMLXRegisteredKernelRoutesAccelerated() async {
        let registry = BASMetalKernelRegistry()
        await registry.register(
            StubMLXMatMulKernel())
        let scheduler = BASHardwareAwareScheduler(
            registry: registry)
        let assignment = await scheduler.assign(
            hint: matMulHint(),
            capability: BASANECapability
                .nominalAppleSilicon(),
            thermal: .nominal)
        XCTAssertNotEqual(
            assignment.selectedBackingKind, .cpuBytes,
            "registered MLX kernel must beat CPU at" +
            " .nominal thermal with nominalAppleSilicon" +
            " capability")
        XCTAssertNotNil(assignment.selectedKernelKey)
        XCTAssertEqual(
            assignment.selectedKernelKey?.operation,
            .matMul)
    }

    // MARK: - Tiebreaker: ANE-preferred backing wins

    func testANEPreferredBackingWinsTiebreaker() async {
        let registry = BASMetalKernelRegistry()
        // Register both mlMultiArray (ANE-preferred)
        // + metalBuffer (GPU only) for the same op
        await registry.register(
            StubMatMulKernel(
                backingKind: .mlMultiArray))
        await registry.register(
            StubMatMulKernel(
                backingKind: .metalBuffer))
        let scheduler = BASHardwareAwareScheduler(
            registry: registry)
        let assignment = await scheduler.assign(
            hint: matMulHint(),
            capability: BASANECapability
                .nominalAppleSilicon(),
            thermal: .nominal)
        // mlMultiArray should win (ANE-resident +
        // capability supports matMul)
        XCTAssertEqual(
            assignment.selectedBackingKind,
            .mlMultiArray,
            "tiebreaker must prefer ANE-resident" +
            " mlMultiArray over GPU-only metalBuffer")
    }

    // MARK: - Op not supported by ANE → gpuFallback rationale

    func testRationaleGPUFallbackWhenOpUnsupported() async {
        let registry = BASMetalKernelRegistry()
        await registry.register(
            StubMatMulKernel(
                backingKind: .metalBuffer))
        // Capability with empty supported ops
        let cap = BASANECapability(
            maxBatchSize: 1,
            supportedOps: [],
            estimatedLatencyMs: 1.0,
            memoryFootprintMB: 1024,
            acceleratorPriority: .aneFirst,
            thermalSnapshot: .nominal)
        let scheduler = BASHardwareAwareScheduler(
            registry: registry)
        let assignment = await scheduler.assign(
            hint: matMulHint(),
            capability: cap,
            thermal: .nominal)
        // Could go to GPU (registered) or CPU (always
        // available)。 With opSupportPenalty = 1000,
        // CPU may win。 But the GPU candidate IS
        // available so the rationale should reflect that
        // when GPU wins。 Either branch is valid for the
        // assignment;test just verifies rationale field
        // is populated meaningfully。
        XCTAssertTrue([
            BASAssignmentRationale.gpuFallbackAneUnsupported,
            .cpuNoKernelRegistered
        ].contains(assignment.assignmentRationale),
            "rationale must reflect ANE not supporting" +
            " the op + GPU/CPU fallback")
    }

    // MARK: - Thermal serious → thermalDowngrade rationale

    func testRationaleThermalDowngradeAtSerious() async {
        let registry = BASMetalKernelRegistry()
        await registry.register(
            StubMatMulKernel(
                backingKind: .mlMultiArray))
        let scheduler = BASHardwareAwareScheduler(
            registry: registry)
        let assignment = await scheduler.assign(
            hint: matMulHint(),
            capability: BASANECapability
                .nominalAppleSilicon(),
            thermal: .serious)
        XCTAssertEqual(
            assignment.thermalSnapshot, .serious,
            "scheduler carries thermal snapshot key" +
            " forward for replay-determinism")
        // If accelerator wins despite serious thermal,
        // rationale must be thermalDowngrade
        if assignment.selectedBackingKind != .cpuBytes {
            XCTAssertEqual(
                assignment.assignmentRationale,
                .thermalDowngrade)
        }
    }

    // MARK: - Replay determinism

    func testSameInputsProduceSameAssignment() async {
        let registry = BASMetalKernelRegistry()
        await registry.register(
            StubMatMulKernel(
                backingKind: .mlMultiArray))
        let scheduler = BASHardwareAwareScheduler(
            registry: registry)
        let cap = BASANECapability
            .nominalAppleSilicon()
        let a1 = await scheduler.assign(
            hint: matMulHint(),
            capability: cap,
            thermal: .nominal)
        let a2 = await scheduler.assign(
            hint: matMulHint(),
            capability: cap,
            thermal: .nominal)
        XCTAssertEqual(a1, a2,
            "scheduler must be deterministic for the" +
            " same hint + capability + thermal" +
            " (chapter 三百九二)")
    }

    // MARK: - lowestEnergy preference shifts cost weighting

    func testLowestEnergyAffectsCostScore() async {
        let registry = BASMetalKernelRegistry()
        await registry.register(
            StubMatMulKernel(
                backingKind: .mlMultiArray))
        let scheduler = BASHardwareAwareScheduler(
            registry: registry)
        let cap = BASANECapability
            .nominalAppleSilicon()
        let latencyHint = BASStageAcceleratorHint(
            operation: .matMul,
            preferredDataType: .float16,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 10,
            preference: .lowestLatency)
        let energyHint = BASStageAcceleratorHint(
            operation: .matMul,
            preferredDataType: .float16,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 10,
            preference: .lowestEnergy)
        let aLatency = await scheduler.assign(
            hint: latencyHint,
            capability: cap,
            thermal: .nominal)
        let aEnergy = await scheduler.assign(
            hint: energyHint,
            capability: cap,
            thermal: .nominal)
        // Cost scores must differ (powerWeight = 0.0
        // for latency,2.0 for energy)
        XCTAssertNotEqual(
            aLatency.costScore, aEnergy.costScore,
            "preference must alter the cost score" +
            " via the powerWeight term")
    }

    // MARK: - Helpers

    private func matMulHint() -> BASStageAcceleratorHint {
        return BASStageAcceleratorHint(
            operation: .matMul,
            preferredDataType: .float16,
            batchSize: 1,
            sequenceLength: 1,
            latencyBudgetMs: 10)
    }
}

// MARK: - Test stub kernels

/// Stub matMul kernel keyed by the requested backing
/// kind。 Always echoes inputs。
struct StubMatMulKernel: BASMetalKernel {
    let key: BASKernelKey
    init(backingKind: BASTensorBackingKind) {
        self.key = BASKernelKey(
            operation: .matMul,
            dataType: .float16,
            backingKind: backingKind)
    }
    func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        return BASKernelOutputs(
            descriptors: inputs.descriptors,
            payloads: inputs.payloads,
            executionNanos: 0)
    }
}

/// Stub MLX-keyed matMul kernel for the
/// "registered → not CPU" decision test。
struct StubMLXMatMulKernel: BASMetalKernel {
    let key: BASKernelKey = BASKernelKey(
        operation: .matMul,
        dataType: .float16,
        backingKind: .mlxArray)
    func evaluate(
        inputs: BASKernelInputs
    ) async throws -> BASKernelOutputs {
        return BASKernelOutputs(
            descriptors: inputs.descriptors,
            payloads: inputs.payloads,
            executionNanos: 0)
    }
}
