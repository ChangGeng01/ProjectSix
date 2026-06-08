// ADR-039 Phase 3 — the router decision is DETERMINISTIC + replay-stable. Pin the routing table so the
// CHOICE (op × thermal × priority → backend) can never silently drift; the COMPUTE behind it is approximate
// + on-device.

import XCTest
@testable import BASMetalSubstrate

final class BASMetalKernelDispatchRouterTests: XCTestCase {

    private func route(_ op: BASNeuralOp, _ thermal: BASCapabilityThermalSnapshot,
                       _ ane: BASAcceleratorPriority) -> BASKernelRoutingPreference {
        BASMetalKernelDispatchRouter.decide(op: op, thermalState: thermal, anePriority: ane).routing
    }

    func testRule1_CriticalThermalForcesCPU() {
        // Even an ANE-native op at the strongest ANE priority goes to CPU under critical thermal.
        XCTAssertEqual(route(.matMul, .critical, .aneFirst), .cpuStub)
        XCTAssertTrue(BASMetalKernelDispatchRouter.decide(
            op: .matMul, thermalState: .critical, anePriority: .aneFirst).declinedAccelerator)
    }

    func testRule2_FallbackRequiredOpGoesCPU() {
        // ssmScan has no ANE/MPSGraph native impl → CPU stub, regardless of priority (non-critical thermal).
        XCTAssertEqual(route(.ssmScan, .nominal, .aneFirst), .cpuStub)
        XCTAssertEqual(route(.ssmScan, .fair, .gpuOnly), .cpuStub)
    }

    func testRule4_GpuOnlyPriorityGoesMPSGraph() {
        XCTAssertEqual(route(.matMul, .nominal, .gpuOnly), .gpuMPSGraph)
    }

    func testRule5_SeriousThermalDemotesANEtoGPU() {
        // matMul is ANE-native, but at serious thermal the ANE dispatch overhead isn't worth it → GPU.
        XCTAssertEqual(route(.matMul, .serious, .aneFirst), .gpuMPSGraph)
    }

    func testRule6_ANENativeWithANEFirstGoesANE() {
        XCTAssertEqual(route(.matMul, .nominal, .aneFirst), .aneNative)
        XCTAssertEqual(route(.attention, .nominal, .aneFirst), .aneNative)
    }

    func testRule7_MPSGraphNativeDefaultsToGPU() {
        // softmax/rmsNorm are MPSGraph-native (not ANE-native) → default GPU even at ANE-first priority.
        XCTAssertEqual(route(.softmax, .nominal, .aneFirst), .gpuMPSGraph)
        XCTAssertEqual(route(.rmsNorm, .nominal, .aneFirst), .gpuMPSGraph)
    }

    func testDecisionRecordRoundTrips() throws {
        let d = BASMetalKernelDispatchRouter.decide(op: .matMul, thermalState: .nominal, anePriority: .aneFirst)
        let data = try JSONEncoder().encode(d)
        let back = try JSONDecoder().decode(BASMetalKernelDispatchDecision.self, from: data)
        XCTAssertEqual(d, back)
        XCTAssertEqual(d.op, "mat-mul")
        XCTAssertEqual(d.routing, .aneNative)
        XCTAssertFalse(d.declinedAccelerator)
    }
}
