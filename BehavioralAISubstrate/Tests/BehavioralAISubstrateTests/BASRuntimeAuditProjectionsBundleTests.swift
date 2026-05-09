// MARK: - BASRuntimeAuditProjectionsBundleTests
// chapter 四百四 v3 / M976

import Foundation
import XCTest
@testable import BASOrchestration

final class BASRuntimeAuditProjectionsBundleTests: XCTestCase {

    // MARK: - Init shape

    func testInitDefaultsAllNamespacesEmpty() {
        let b = BASRuntimeAuditProjectionsBundle()
        XCTAssertFalse(b.kunlun.hasAnyProjection)
        XCTAssertFalse(b.abyssal.hasAnyProjection)
        XCTAssertFalse(b.cthulhu.hasAnyProjection)
        XCTAssertFalse(b.tribunal.hasAnyProjection)
    }

    func testNoneFactory() {
        let b = BASRuntimeAuditProjectionsBundle.none()
        XCTAssertFalse(b.hasAnyProjection)
        XCTAssertEqual(b.populatedSlotCount, 0)
    }

    // MARK: - With-chain immutable updates

    func testWithKunlunReturnsFreshBundle() {
        let original = BASRuntimeAuditProjectionsBundle.none()
        let updatedKunlun = BASKunlunAuditProjections(
            readinessRef: "r")
        let updated = original.with(kunlun: updatedKunlun)
        XCTAssertFalse(original.kunlun.hasAnyProjection,
            "M976:with-chain must NOT mutate original")
        XCTAssertTrue(updated.kunlun.hasAnyProjection)
    }

    func testWithChainComposesAcrossNamespaces() {
        let b = BASRuntimeAuditProjectionsBundle.none()
            .with(kunlun:
                BASKunlunAuditProjections(
                    readinessRef: "r"))
            .with(abyssal:
                BASAbyssalAuditProjections(
                    anomalyTraceRef: "a"))
            .with(tribunal:
                BASTribunalAuditProjections(
                    triScores: []))
        XCTAssertTrue(b.kunlun.hasAnyProjection)
        XCTAssertTrue(b.abyssal.hasAnyProjection)
        XCTAssertFalse(b.tribunal.hasAnyProjection,
            "tribunal stays empty since triScores is empty")
    }

    // MARK: - Aggregate accessors

    func testPopulatedSlotCountSumsAcrossNamespaces() {
        let b = BASRuntimeAuditProjectionsBundle(
            kunlun: BASKunlunAuditProjections(
                readinessRef: "r",
                jadeSealRef: "s"),
            abyssal: BASAbyssalAuditProjections(
                anomalyTraceRef: "a"))
        XCTAssertEqual(b.populatedSlotCount, 3,
            "M976:2 kunlun + 1 abyssal = 3")
    }

    func testHasAnyProjectionTrueWhenAnyNamespacePopulated() {
        let b = BASRuntimeAuditProjectionsBundle(
            kunlun: BASKunlunAuditProjections(
                readinessRef: "r"))
        XCTAssertTrue(b.hasAnyProjection)
    }

    // MARK: - Replay determinism

    func testEqualForSameInputs() {
        let a = BASRuntimeAuditProjectionsBundle(
            kunlun: BASKunlunAuditProjections(
                readinessRef: "x"))
        let b = BASRuntimeAuditProjectionsBundle(
            kunlun: BASKunlunAuditProjections(
                readinessRef: "x"))
        XCTAssertEqual(a, b,
            "M976:M892 byte-stable equality")
    }
}
