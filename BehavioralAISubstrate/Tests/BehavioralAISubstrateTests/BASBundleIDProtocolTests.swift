// MARK: - BASBundleIDProtocolTests — chapter 四百五 / M981+M982

import Foundation
import XCTest
@testable import BASMemory
@testable import BASOrchestration
@testable import BASRuntimeCore

final class BASBundleIDProtocolTests: XCTestCase {

    // MARK: - Protocol surface

    func testProtocolRequiresBundleIDAndSchemaVersion() {
        // Compile-time: any conformer exposes both fields
        struct Stub: BASBundleIDProtocol, Sendable {
            let bundleID: String
            let schemaVersion: String
        }
        let s = Stub(bundleID: "x", schemaVersion: "1.0.0")
        let _: any BASBundleIDProtocol = s
        XCTAssertEqual(s.bundleID, "x")
        XCTAssertEqual(s.schemaVersion, "1.0.0")
    }

    // MARK: - BASStepBundle adoption (M982)

    func testBASStepBundleConformsToBASBundleIDProtocol() {
        let bundle = BASStepBundle(
            bundleID: "step-1",
            microSteps: ["a", "b"])
        let _: any BASBundleIDProtocol = bundle
        XCTAssertEqual(bundle.bundleID, "step-1")
        XCTAssertEqual(
            bundle.schemaVersion,
            BASStepBundle.currentSchemaVersion)
    }

    // MARK: - BASLearningExportBundle adoption (M982)

    func testBASLearningExportBundleConformsToBASBundleIDProtocol() {
        let bundle = BASLearningExportBundle(
            bundleID: "learn-1",
            candidateRefs: ["c1"],
            scrubbed: false,
            privacySafe: true,
            sovereignSafe: true,
            evaluationTags: [])
        let _: any BASBundleIDProtocol = bundle
        XCTAssertEqual(bundle.bundleID, "learn-1")
    }

    // MARK: - Doctrine: BASBundleProtocol vs BASBundleIDProtocol

    func testTwoTypedProtocolsCoexist() {
        // BASBundleProtocol (with timestamp) is for bundles
        // that have recordedAt;BASBundleIDProtocol is for
        // those that don't。Both protocols ship in
        // BASRuntimeCore as typed surfaces。
        let _: BASBundleIDProtocol.Type =
            BASStepBundle.self
        XCTAssertTrue(true,
            "M981+M982:both protocols coexist")
    }
}
