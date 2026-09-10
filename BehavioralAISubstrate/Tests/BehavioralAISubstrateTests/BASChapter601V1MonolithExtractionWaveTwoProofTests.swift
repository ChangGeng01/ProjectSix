// MARK: - BASChapter601V1MonolithExtractionWaveTwoProofTests
// chapter 六百一 / M1782 — PROOF tests for the M1781
//                          V1 monolith extraction wave 2
//                          (Kunlun hot-path + cosmic-
//                          cold counterweight helpers
//                          moved to sibling extension
//                          file)
//
// ## Coverage (10 PROOF tests)
//
// Verifies:
//   - 4 Kunlun hot-path constants reachable through
//     BASEBrainRuntimeCoordinator (cross-file path
//     preserved)
//   - 4 cosmic-cold counterweight helpers exhibit
//     expected output values for canonical inputs
//     (anti-drift PROOF — same constants as pre-move)
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:replay-determinism preserved
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1781 → M1782

import XCTest
@testable import BASHostKit
@testable import BASPolicy

final class BASChapter601V1MonolithExtractionWaveTwoProofTests:
    XCTestCase
{
    // MARK: - Kunlun hot-path constants

    func testKunlunActiveLayerRefsHas14Elements() {
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .kunlunActiveLayerRefs.count,
            14)
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .kunlunActiveLayerRefs.first,
            "L1")
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .kunlunActiveLayerRefs.last,
            "L14")
    }

    func testKunlunAxisDeviationThresholdIsPointSeven() {
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .kunlunAxisDeviationThreshold,
            0.7,
            accuracy: 1e-9)
    }

    func testDefaultConfidenceFloorIsOne() {
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .defaultConfidenceFloorWhenNoUncertaintyLedger,
            1.0,
            accuracy: 1e-9)
    }

    func testRiverOriginTransformationStepsHas5Elements() {
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .riverOriginTransformationSteps.count,
            5)
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .riverOriginTransformationSteps.first,
            "risk.bind")
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .riverOriginTransformationSteps.last,
            "audit.emit")
    }

    // MARK: - Cosmic-cold counterweight (anti-drift)

    func testDignityBiasFromRiskExtremeWithAnswer() {
        // Anti-drift PROOF — extreme risk + answer
        // permit mode (not narrowed) yields 0.5。
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .dignityBiasFromRisk(
                    .extreme, permitMode: .answer),
            0.5,
            accuracy: 1e-9)
    }

    func testDignityBiasFromRiskExtremeWithNarrowedMode() {
        // extreme risk + non-answer permit (narrowed)
        // yields 0.85。
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .dignityBiasFromRisk(
                    .extreme, permitMode: .block),
            0.85,
            accuracy: 1e-9)
    }

    func testAgencyFloorFromCandidatesZeroCandidates() {
        // Zero candidates yields max agency-floor 0.85。
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .agencyFloorFromCandidates(0),
            0.85,
            accuracy: 1e-9)
    }

    func testAgencyFloorFromCandidatesManyYieldsBaseline() {
        // ≥ 3 candidates yields baseline 0.2。
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .agencyFloorFromCandidates(5),
            0.2,
            accuracy: 1e-9)
    }

    func testAntiFatalismFromRiskExtreme() {
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .antiFatalismFromRisk(.extreme),
            0.85,
            accuracy: 1e-9)
    }

    func testAntiPaternalismFromPermitDelay() {
        XCTAssertEqual(
            BASEBrainRuntimeCoordinator
                .antiPaternalismFromPermit(.delay),
            0.85,
            accuracy: 1e-9)
    }
}
