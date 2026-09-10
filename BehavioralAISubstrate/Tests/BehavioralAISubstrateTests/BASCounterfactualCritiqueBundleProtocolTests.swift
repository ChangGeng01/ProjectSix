// MARK: - BASCounterfactualCritiqueBundleProtocolTests
// chapter 四百五 / M984

import Foundation
import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASCounterfactualCritiqueBundleProtocolTests:
    XCTestCase
{

    // MARK: - BASCounterfactualBundle

    func testCounterfactualConformsToBASBundleIDProtocol() {
        let bundle = BASCounterfactualBundle(
            candidateID: "cand-1",
            shortTerm: "s",
            midTerm: "m",
            worstCase: "w",
            uncertainty: 0.5)
        let _: any BASBundleIDProtocol = bundle
        XCTAssertEqual(
            bundle.bundleID,
            "counterfactual-bundle:cand-1")
    }

    func testCounterfactualBundleIDByteStable() {
        let b1 = BASCounterfactualBundle(
            candidateID: "x", shortTerm: "", midTerm: "",
            worstCase: "", uncertainty: 0)
        let b2 = BASCounterfactualBundle(
            candidateID: "x", shortTerm: "", midTerm: "",
            worstCase: "", uncertainty: 0)
        XCTAssertEqual(b1.bundleID, b2.bundleID,
            "M984:M892 byte-stable bundleID")
    }

    // MARK: - BASCritiqueBundle

    func testCritiqueConformsToBASBundleIDProtocol() {
        let bundle = BASCritiqueBundle(
            candidateID: "cand-2",
            evidenceGap: 0.1,
            manipulationRisk: 0.2,
            emotionalBias: 0.3,
            boundaryConflict: 0.4,
            critiqueStrength: 0.5)
        let _: any BASBundleIDProtocol = bundle
        XCTAssertEqual(
            bundle.bundleID,
            "critique-bundle:cand-2")
    }

    func testCritiqueBundleIDByteStable() {
        let b1 = BASCritiqueBundle(
            candidateID: "y",
            evidenceGap: 0, manipulationRisk: 0,
            emotionalBias: 0, boundaryConflict: 0,
            critiqueStrength: 0)
        let b2 = BASCritiqueBundle(
            candidateID: "y",
            evidenceGap: 0, manipulationRisk: 0,
            emotionalBias: 0, boundaryConflict: 0,
            critiqueStrength: 0)
        XCTAssertEqual(b1.bundleID, b2.bundleID)
    }

    // MARK: - Cross-bundle protocol queries

    func testBothConformToProtocolViaUniformAccessor() {
        let cf = BASCounterfactualBundle(
            candidateID: "a", shortTerm: "", midTerm: "",
            worstCase: "", uncertainty: 0)
        let cr = BASCritiqueBundle(
            candidateID: "a",
            evidenceGap: 0, manipulationRisk: 0,
            emotionalBias: 0, boundaryConflict: 0,
            critiqueStrength: 0)
        let bundles: [any BASBundleIDProtocol] = [cf, cr]
        let ids = bundles.map { $0.bundleID }
        XCTAssertEqual(ids.count, 2)
        XCTAssertTrue(
            ids[0].hasPrefix("counterfactual-bundle:"))
        XCTAssertTrue(
            ids[1].hasPrefix("critique-bundle:"))
    }
}
