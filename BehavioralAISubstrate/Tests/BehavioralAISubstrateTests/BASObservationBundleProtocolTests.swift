// MARK: - BASObservationBundleProtocolTests — chapter 四百五 / M985

import Foundation
import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASObservationBundleProtocolTests: XCTestCase {

    // MARK: - BASTribunalObservationBundle

    func testTribunalBundleConformsToBASBundleProtocol() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let bundle = BASTribunalObservationBundle(
            turnID: "turn-1",
            sessionID: "sess-1",
            observations: [],
            emittedAt: date)
        let _: any BASBundleProtocol = bundle
        XCTAssertEqual(
            bundle.bundleID,
            "tribunal-observation-bundle:turn-1")
        XCTAssertEqual(bundle.recordedAt, date)
    }

    func testLeaseLifeBundleConformsToBASBundleProtocol() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let bundle = BASLeaseLifeObservationBundle(
            turnID: "turn-1",
            sessionID: "sess-1",
            observations: [],
            emittedAt: date)
        let _: any BASBundleProtocol = bundle
        XCTAssertEqual(
            bundle.bundleID,
            "lease-life-observation-bundle:turn-1")
        XCTAssertEqual(bundle.recordedAt, date)
    }

    func testNeuralOrganBundleConformsToBASBundleProtocol() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let bundle = BASNeuralOrganObservationBundle(
            turnID: "turn-1",
            sessionID: "sess-1",
            observations: [],
            emittedAt: date)
        let _: any BASBundleProtocol = bundle
        XCTAssertEqual(
            bundle.bundleID,
            "neural-organ-observation-bundle:turn-1")
        XCTAssertEqual(bundle.recordedAt, date)
    }

    // MARK: - Cross-bundle protocol query

    func testThreeBundlesUniformProtocolAccessor() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let t = BASTribunalObservationBundle(
            turnID: "t1", sessionID: "s",
            observations: [], emittedAt: date)
        let l = BASLeaseLifeObservationBundle(
            turnID: "t1", sessionID: "s",
            observations: [], emittedAt: date)
        let n = BASNeuralOrganObservationBundle(
            turnID: "t1", sessionID: "s",
            observations: [], emittedAt: date)
        let bundles: [any BASBundleProtocol] = [t, l, n]
        XCTAssertEqual(bundles.count, 3)
        for b in bundles {
            XCTAssertEqual(b.recordedAt, date)
        }
    }
}
