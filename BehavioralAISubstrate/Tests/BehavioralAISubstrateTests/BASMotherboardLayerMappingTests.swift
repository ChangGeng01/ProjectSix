import XCTest
@testable import BASRuntimeCore

/// 六十二.1 — L1-L14 ↔ motherboard mapping tests.
final class BASMotherboardLayerMappingTests: XCTestCase {

    func test_fourteenLayers() {
        XCTAssertEqual(
            BASMotherboardLayer14.allCases.count, 14)
    }

    func test_everyLayerHasPrimaryKernel() {
        for layer in BASMotherboardLayer14.allCases {
            // Non-optional access pinned: must compile.
            _ = layer.primaryKernel
        }
    }

    func test_l1MapsToLeaseAndLifeKernel() {
        XCTAssertEqual(
            BASMotherboardLayer14.l1.primaryKernel,
            .leaseAndLife)
        XCTAssertEqual(
            BASMotherboardLayer14.l1.primaryBus, .lease)
        XCTAssertEqual(
            BASMotherboardLayer14.l1.primaryVault,
            .snapshotArk)
    }

    func test_l2L3MapToNeuralOrganRuntime() {
        XCTAssertEqual(
            BASMotherboardLayer14.l2.primaryKernel,
            .neuralOrganRuntime)
        XCTAssertEqual(
            BASMotherboardLayer14.l3.primaryKernel,
            .neuralOrganRuntime)
        XCTAssertEqual(
            BASMotherboardLayer14.l2.primaryVault,
            .snapshotArk)
        XCTAssertEqual(
            BASMotherboardLayer14.l3.primaryVault,
            .snapshotArk)
    }

    func test_l4MapsToWorldPriorVault() {
        XCTAssertEqual(
            BASMotherboardLayer14.l4.primaryVault,
            .worldPriorVault)
    }

    func test_l5MapsToHostConstitutionVault() {
        XCTAssertEqual(
            BASMotherboardLayer14.l5.primaryVault,
            .hostConstitutionVault)
    }

    func test_l4ToL13InStateGraphKernel() {
        for layer: BASMotherboardLayer14 in [
            .l4, .l5, .l6, .l7, .l8,
            .l9, .l10, .l11, .l12, .l13,
        ] {
            XCTAssertEqual(
                layer.primaryKernel,
                .stateAndEvolutionGraph,
                "\(layer) must home in stateAndEvolutionGraph")
        }
    }

    func test_l14InSovereignMicrokernel() {
        XCTAssertEqual(
            BASMotherboardLayer14.l14.primaryKernel,
            .sovereignMicrokernel)
        XCTAssertEqual(
            BASMotherboardLayer14.l14.primaryVault,
            .snapshotArk)
        XCTAssertEqual(
            BASMotherboardLayer14.l14.primaryBus,
            .versionAudit)
    }

    func test_snapshotArkReferencedByL1L2L3L14() {
        let referencing =
            BASMotherboardVault.snapshotArk
                .referencingLayers
        let expected: Set<BASMotherboardLayer14> = [
            .l1, .l2, .l3, .l14,
        ]
        XCTAssertEqual(Set(referencing), expected)
    }

    func test_inverseHostedLayersConsistent() {
        for kernel in BASMotherboardKernel.allCases {
            for layer in kernel.hostedLayers {
                XCTAssertEqual(
                    layer.primaryKernel, kernel)
            }
        }
    }

    func test_inverseSpeakingLayersConsistent() {
        for bus in BASMotherboardBus.allCases {
            for layer in bus.speakingLayers {
                XCTAssertEqual(
                    layer.primaryBus, bus)
            }
        }
    }

    func test_codableRoundTrip() throws {
        for layer in BASMotherboardLayer14.allCases {
            let data = try JSONEncoder().encode(layer)
            let decoded = try JSONDecoder().decode(
                BASMotherboardLayer14.self, from: data)
            XCTAssertEqual(decoded, layer)
        }
    }
}
