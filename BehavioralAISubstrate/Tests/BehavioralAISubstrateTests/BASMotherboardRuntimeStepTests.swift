import XCTest
@testable import BASRuntimeCore

/// 六十二.2 — runtime 8-step canonical sequence tests.
final class BASMotherboardRuntimeStepTests: XCTestCase {

    func test_eightSteps() {
        XCTAssertEqual(
            BASMotherboardRuntimeStep.allCases.count, 8)
    }

    func test_canonicalSequenceLength() {
        XCTAssertEqual(
            BASMotherboardRuntimeSequence.canonical.count, 8)
    }

    func test_canonicalSequenceOrder() {
        XCTAssertEqual(
            BASMotherboardRuntimeSequence.canonical, [
                .hostInputIntoSDK,
                .sovereignKernelCheck,
                .leaseAcquire,
                .neuralRuntimeAssembly,
                .stateGraphFlow,
                .permitGate,
                .sdkExecute,
                .eventSourcing,
            ])
    }

    func test_entryIsHostInputIntoSDK() {
        XCTAssertEqual(
            BASMotherboardRuntimeSequence.entry,
            .hostInputIntoSDK)
        XCTAssertEqual(
            BASMotherboardRuntimeSequence.canonical.first,
            .hostInputIntoSDK)
    }

    func test_terminusIsEventSourcing() {
        XCTAssertEqual(
            BASMotherboardRuntimeSequence.terminus,
            .eventSourcing)
        XCTAssertEqual(
            BASMotherboardRuntimeSequence.canonical.last,
            .eventSourcing)
    }

    func test_canonicalIndicesMatchPosition() {
        for (index, step) in
            BASMotherboardRuntimeSequence.canonical
                .enumerated()
        {
            XCTAssertEqual(step.canonicalIndex, index)
        }
    }

    func test_permitCheckpoints() {
        XCTAssertEqual(
            BASMotherboardRuntimeSequence
                .permitCheckpoints,
            [.sovereignKernelCheck, .permitGate])
        for step in BASMotherboardRuntimeStep.allCases {
            XCTAssertEqual(
                step.isPermitCheckpoint,
                BASMotherboardRuntimeSequence
                    .permitCheckpoints.contains(step))
        }
    }

    func test_leaseAcquireOwnedByLeaseAndLife() {
        XCTAssertEqual(
            BASMotherboardRuntimeStep.leaseAcquire
                .owningKernel,
            .leaseAndLife)
    }

    func test_neuralAssemblyOwnedByNeuralOrganRuntime() {
        XCTAssertEqual(
            BASMotherboardRuntimeStep
                .neuralRuntimeAssembly.owningKernel,
            .neuralOrganRuntime)
    }

    func test_sovereignChecksOwnedBySovereignKernel() {
        XCTAssertEqual(
            BASMotherboardRuntimeStep.sovereignKernelCheck
                .owningKernel,
            .sovereignMicrokernel)
        XCTAssertEqual(
            BASMotherboardRuntimeStep.permitGate
                .owningKernel,
            .sovereignMicrokernel)
    }

    func test_eventSourcingOwnedByStateGraph() {
        XCTAssertEqual(
            BASMotherboardRuntimeStep.eventSourcing
                .owningKernel,
            .stateAndEvolutionGraph)
    }

    func test_stepCodableRoundTrip() throws {
        for step in BASMotherboardRuntimeStep.allCases {
            let data = try JSONEncoder().encode(step)
            let decoded = try JSONDecoder().decode(
                BASMotherboardRuntimeStep.self, from: data)
            XCTAssertEqual(decoded, step)
        }
    }
}
