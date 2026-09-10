// MARK: - BASObservationBundleProtocolBatch3Tests
// chapter 四百五 / M987

import Foundation
import XCTest
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASWorldPrior

final class BASObservationBundleProtocolBatch3Tests:
    XCTestCase
{

    // MARK: - 5 standard observation bundles

    func testWorldPriorBundleConforms() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let b = BASWorldPriorObservationBundle(
            turnID: "t-1", sessionID: "s",
            observations: [], emittedAt: date)
        let _: any BASBundleProtocol = b
        XCTAssertEqual(
            b.bundleID,
            "world-prior-observation-bundle:t-1")
    }

    func testPresenceBundleConforms() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let b = BASPresenceObservationBundle(
            turnID: "t-2", sessionID: "s",
            observations: [], emittedAt: date)
        let _: any BASBundleProtocol = b
        XCTAssertEqual(
            b.bundleID,
            "presence-observation-bundle:t-2")
    }

    func testDecompositionBundleConforms() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let b = BASDecompositionObservationBundle(
            turnID: "t-3", sessionID: "s",
            observations: [], emittedAt: date)
        let _: any BASBundleProtocol = b
        XCTAssertEqual(
            b.bundleID,
            "decomposition-observation-bundle:t-3")
    }

    func testShadowTrialBundleConforms() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let b = BASShadowTrialObservationBundle(
            turnID: "t-4", sessionID: "s",
            observations: [], emittedAt: date)
        let _: any BASBundleProtocol = b
        XCTAssertEqual(
            b.bundleID,
            "shadow-trial-observation-bundle:t-4")
    }

    func testRiskBundleConforms() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let b = BASRiskObservationBundle(
            turnID: "t-5", sessionID: "s",
            observations: [], emittedAt: date)
        let _: any BASBundleProtocol = b
        XCTAssertEqual(
            b.bundleID,
            "risk-observation-bundle:t-5")
    }

    // MARK: - BASRiskCalibrationBundle (different shape)

    func testRiskCalibrationBundleConforms() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let b = BASRiskCalibrationBundle(
            bundleVersion: "v1.0.0",
            producedAt: date,
            aggregateProvenanceRef: "ref",
            strataDeltas: [],
            sovereignWarrantRef: "warrant-1")
        let _: any BASBundleProtocol = b
        XCTAssertEqual(
            b.bundleID,
            "risk-calibration-bundle:v1.0.0")
        XCTAssertEqual(b.recordedAt, date)
    }
}
