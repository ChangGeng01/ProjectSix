// MARK: - BASObservationBundleProtocolBatch2Tests
// chapter 四百五 / M986

import Foundation
import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASObservationBundleProtocolBatch2Tests:
    XCTestCase
{

    // MARK: - 6 more observation bundles adopt BASBundleProtocol

    func testCandidateBundleConformsToBASBundleProtocol() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let b = BASCandidateObservationBundle(
            turnID: "t-1", sessionID: "s",
            observations: [], emittedAt: date)
        let _: any BASBundleProtocol = b
        XCTAssertEqual(
            b.bundleID,
            "candidate-observation-bundle:t-1")
    }

    func testHostConstitutionBundleConformsToBASBundleProtocol() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let b = BASHostConstitutionObservationBundle(
            turnID: "t-2", sessionID: "s",
            observations: [], emittedAt: date)
        let _: any BASBundleProtocol = b
        XCTAssertEqual(
            b.bundleID,
            "host-constitution-observation-bundle:t-2")
    }

    func testSoftHandBundleConformsToBASBundleProtocol() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let b = BASSoftHandObservationBundle(
            turnID: "t-3", sessionID: "s",
            observations: [], emittedAt: date)
        let _: any BASBundleProtocol = b
        XCTAssertEqual(
            b.bundleID,
            "soft-hand-observation-bundle:t-3")
    }

    func testUpdateTicketBundleConformsToBASBundleProtocol() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let b = BASUpdateTicketObservationBundle(
            turnID: "t-4", sessionID: "s",
            observations: [], emittedAt: date)
        let _: any BASBundleProtocol = b
        XCTAssertEqual(
            b.bundleID,
            "update-ticket-observation-bundle:t-4")
    }

    func testThoughtFoldBundleConformsToBASBundleProtocol() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let b = BASThoughtFoldObservationBundle(
            turnID: "t-5", sessionID: "s",
            observations: [], emittedAt: date)
        let _: any BASBundleProtocol = b
        XCTAssertEqual(
            b.bundleID,
            "thought-fold-observation-bundle:t-5")
    }

    func testHippocampalMemoryBundleConformsToBASBundleProtocol() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let b = BASHippocampalMemoryObservationBundle(
            turnID: "t-6", sessionID: "s",
            observations: [], emittedAt: date)
        let _: any BASBundleProtocol = b
        XCTAssertEqual(
            b.bundleID,
            "hippocampal-memory-observation-bundle:t-6")
    }

    // MARK: - Aggregate query

    func testSixBundlesUniformProtocolAccess() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let bundles: [any BASBundleProtocol] = [
            BASCandidateObservationBundle(
                turnID: "t", sessionID: "s",
                observations: [], emittedAt: date),
            BASHostConstitutionObservationBundle(
                turnID: "t", sessionID: "s",
                observations: [], emittedAt: date),
            BASSoftHandObservationBundle(
                turnID: "t", sessionID: "s",
                observations: [], emittedAt: date),
            BASUpdateTicketObservationBundle(
                turnID: "t", sessionID: "s",
                observations: [], emittedAt: date),
            BASThoughtFoldObservationBundle(
                turnID: "t", sessionID: "s",
                observations: [], emittedAt: date),
            BASHippocampalMemoryObservationBundle(
                turnID: "t", sessionID: "s",
                observations: [], emittedAt: date)
        ]
        XCTAssertEqual(bundles.count, 6)
        for b in bundles {
            XCTAssertEqual(b.recordedAt, date)
            XCTAssertEqual(b.schemaVersion, "1.0.0")
        }
    }
}
