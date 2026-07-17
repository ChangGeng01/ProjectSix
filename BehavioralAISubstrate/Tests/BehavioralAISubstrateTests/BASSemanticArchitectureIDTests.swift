import Foundation
import XCTest
@testable import BASRuntimeCore

final class BASSemanticArchitectureIDTests: XCTestCase {
    func testSemanticLayerIDIsTheExistingType() {
        let semantic: BASSemanticLayerID = .dreamLoop
        let existing: BASCognitiveLayer = semantic
        XCTAssertEqual(existing.rawValue, "L9")
        XCTAssertEqual(BASSemanticLayerID.allCases.count, 14)
    }

    func testPhysicalKernelIDIsAProjectionOnMotherboardKernel() {
        let kernel: BASPhysicalKernelID = .leaseAndLife
        XCTAssertEqual(kernel.architectureID, "K1")
        XCTAssertEqual(
            BASMotherboardKernel.neuralOrganRuntime.architectureID,
            "K2")
        XCTAssertEqual(
            BASMotherboardKernel.stateAndEvolutionGraph.architectureID,
            "K3")
        XCTAssertEqual(
            BASMotherboardKernel.sovereignMicrokernel.architectureID,
            "K4")
        XCTAssertEqual(BASMotherboardKernel.allCases.count, 4)
    }

    func testMissingTaxonomiesAndLegacyPlaneProjectionAreTotal() {
        XCTAssertEqual(BASControlRingID.allCases.count, 4)
        XCTAssertEqual(BASTopLevelPlaneID.allCases.count, 7)
        let projected = Set(
            BASMotherboardPlane.allCases.flatMap(\.topLevelViewIDs))
        XCTAssertEqual(projected, Set(BASTopLevelPlaneID.allCases))
    }

    func testL9AliasesResolveToExistingDreamLoopCase() {
        for alias in ["L9", "Kunlun", "Dream"] {
            XCTAssertEqual(
                BASNamingMatrix.layerID(resolving: alias),
                .dreamLoop)
        }
    }
}
