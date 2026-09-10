// MARK: - BASRuntimeModeToggleWiringDoctrineTests
// chapter 六百六十八 / M2051 — anti-drift PROOF tests

import XCTest
@testable import BASRuntimeCore

final class BASRuntimeModeToggleWiringDoctrineTests:
    XCTestCase
{
    typealias D = BASRuntimeModeToggleWiringDoctrine

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百六十八")
    }
    func testPhase() { XCTAssertEqual(D.phase, "Phase K") }
    func testPhaseGoal() {
        XCTAssertEqual(D.phaseGoal,
            "runtimeMode toggle + dual-mode CI for Phase L default flip readiness")
    }

    // 4-knife M-numbers
    func testFirstKnifeMNumber() {
        XCTAssertEqual(D.firstKnifeMNumber, 2049)
    }
    func testSecondKnifeMNumber() {
        XCTAssertEqual(D.secondKnifeMNumber, 2050)
    }
    func testThirdKnifeMNumber() {
        XCTAssertEqual(D.thirdKnifeMNumber, 2051)
    }
    func testFourthKnifeMNumber() {
        XCTAssertEqual(D.fourthKnifeMNumber, 2052)
    }

    // New async surface
    func testNewAsyncSurfaceName() {
        XCTAssertEqual(D.newAsyncSurfaceName,
            "buildEBrainTurnWithRuntimeMode")
    }
    func testNewAsyncSurfaceLocation() {
        XCTAssertEqual(D.newAsyncSurfaceLocation,
            "BASHostRuntime extension in EBrainHostRuntimeSynthesis.swift")
    }
    func testNewAsyncSurfaceParameterCount() {
        XCTAssertEqual(D.newAsyncSurfaceParameterCount, 6)
    }
    func testNewAsyncSurfaceParametersContainsAllSix() {
        XCTAssertTrue(D.newAsyncSurfaceParameters
            .contains("request"))
        XCTAssertTrue(D.newAsyncSurfaceParameters
            .contains("currentBrain"))
        XCTAssertTrue(D.newAsyncSurfaceParameters
            .contains("projection"))
        XCTAssertTrue(D.newAsyncSurfaceParameters
            .contains("deviceStateOverride"))
        XCTAssertTrue(D.newAsyncSurfaceParameters
            .contains("runtimeMode"))
        XCTAssertTrue(D.newAsyncSurfaceParameters
            .contains("now"))
    }
    func testNewAsyncSurfaceDefaultRuntimeMode() {
        XCTAssertEqual(D.newAsyncSurfaceDefaultRuntimeMode,
            "v1ByteEqual")
    }

    // Extracted helper
    func testExtractedHelperName() {
        XCTAssertEqual(D.extractedHelperName,
            "buildCoordinator")
    }
    func testExtractedHelperPrivacy() {
        XCTAssertEqual(D.extractedHelperPrivacy,
            "private")
    }
    func testExtractedHelperRationale() {
        XCTAssertEqual(D.extractedHelperRationale,
            "single source-of-truth for V1 service wiring shared between sync + async paths")
    }

    // PROOF test pins
    func testProofTestCount() {
        XCTAssertEqual(D.proofTestCount, 7)
    }
    func testProofTestNamesCount() {
        XCTAssertEqual(D.proofTestNames.count, 7)
    }

    // Mode handling
    func testModeCount() {
        XCTAssertEqual(D.modeCount, 3)
    }
    func testV1ByteEqualBehavior() {
        XCTAssertEqual(D.v1ByteEqualBehavior,
            "direct coordinator.runTurn — byte-equal to existing synchronous buildEBrainTurn")
    }

    // Phase K progress markers
    func testIsPhaseKFirstChapter() {
        XCTAssertTrue(D.isPhaseKFirstChapter)
    }
    func testPhaseKChaptersTotal() {
        XCTAssertEqual(D.phaseKChaptersTotal, 4)
    }
    func testPhaseKChaptersRemainingAfterThis() {
        XCTAssertEqual(D.phaseKChaptersRemainingAfterThis,
            3)
    }
    func testPhaseKRemainingChaptersCount() {
        XCTAssertEqual(D.phaseKRemainingChapters.count, 3)
        XCTAssertTrue(D.phaseKRemainingChapters
            .contains("chapter 六百六十九"))
        XCTAssertTrue(D.phaseKRemainingChapters
            .contains("chapter 六百七十"))
        XCTAssertTrue(D.phaseKRemainingChapters
            .contains("chapter 六百七十一"))
    }

    // Backward compatibility
    func testSyncBuildEBrainTurnPreserved() {
        XCTAssertTrue(D.syncBuildEBrainTurnPreserved)
    }
    func testADR014OptInPreserved() {
        XCTAssertTrue(D.adr014OptInPreserved)
    }
    func testByteEqualityPreserved() {
        XCTAssertTrue(D.byteEqualityPreserved)
    }
    func testPurelyAdditive() {
        XCTAssertTrue(D.purelyAdditive)
    }

    // Phase L readiness target
    func testPhaseLDefaultFlipChapterTag() {
        XCTAssertEqual(D.phaseLDefaultFlipChapterTag,
            "chapter 六百七十四")
    }
    func testPhaseLDefaultFlipMNumber() {
        XCTAssertEqual(D.phaseLDefaultFlipMNumber, 2074)
    }
    func testPhaseLPreFlipGateChapterTag() {
        XCTAssertEqual(D.phaseLPreFlipGateChapterTag,
            "chapter 六百七十三")
    }
    func testPhaseLPreFlipGateDuration() {
        XCTAssertEqual(D.phaseLPreFlipGateDuration,
            "24h dual-mode 0-divergence")
    }

    // Cross-doctrine refs
    func testPriorPhaseJCompletionRef() {
        XCTAssertEqual(D.priorPhaseJCompletionRef,
            "BASPhaseJKernelCacheCompletionDoctrine")
    }
    func testPlanRef() {
        XCTAssertEqual(D.planRef,
            "wild-rolling-meerkat REAL HOT-PATH ATTACK Phase K")
    }
}
