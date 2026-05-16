// MARK: - BASChapter677SSMScanShaderShipDoctrineTests
// chapter 六百七十七 / M2088 第四刀 — anti-drift PROOF tests
//                                    for chapter 677
//                                    close-out doctrine

import XCTest
@testable import BASRuntimeCore

final class BASChapter677SSMScanShaderShipDoctrineTests:
    XCTestCase
{
    typealias D = BASChapter677SSMScanShaderShipDoctrine

    // MARK: - Chapter identity

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百七十七")
    }

    func testPhase() {
        XCTAssertEqual(D.phase, "Phase M")
    }

    func testPhaseStatus() {
        XCTAssertEqual(D.phaseStatus, "in-progress")
    }

    // MARK: - M-number range

    func testFirstKnifeMNumber() {
        XCTAssertEqual(D.firstKnifeMNumber, 2085)
    }

    func testSecondKnifeMNumber() {
        XCTAssertEqual(D.secondKnifeMNumber, 2086)
    }

    func testThirdKnifeMNumber() {
        XCTAssertEqual(D.thirdKnifeMNumber, 2087)
    }

    func testFourthKnifeMNumber() {
        XCTAssertEqual(D.fourthKnifeMNumber, 2088)
    }

    func testMNumberFirstMatchesFirstKnife() {
        XCTAssertEqual(
            D.mNumberFirst, D.firstKnifeMNumber)
    }

    func testMNumberLastMatchesFourthKnife() {
        XCTAssertEqual(
            D.mNumberLast, D.fourthKnifeMNumber)
    }

    func testKnivesCountIsFour() {
        XCTAssertEqual(D.knivesCount, 4)
    }

    // MARK: - Artifacts shipped

    func testArtifactCountIsThree() {
        XCTAssertEqual(D.artifactCount, 3)
    }

    func testArtifactPathsAllUnique() {
        XCTAssertEqual(
            Set(D.artifactPaths).count, D.artifactCount)
    }

    func testArtifactPathsAllUnderSources() {
        for path in D.artifactPaths {
            XCTAssertTrue(
                path.hasPrefix("Sources/"),
                "artifact path \(path) must be under " +
                "Sources/")
        }
    }

    func testMetalFileArtifactPresent() {
        XCTAssertTrue(D.artifactPaths.contains(
            "Sources/BASMetalSubstrate/BASBuiltinKernels/SSMScan.metal"))
    }

    func testSwiftMirrorArtifactPresent() {
        XCTAssertTrue(D.artifactPaths.contains(
            "Sources/BASMetalSubstrate/BASBuiltinKernels/BASSSMScanMetalShaderSource.swift"))
    }

    func testShapeStructArtifactPresent() {
        XCTAssertTrue(D.artifactPaths.contains(
            "Sources/BASMetalSubstrate/BASBuiltinKernels/BASSSMScanShape.swift"))
    }

    // MARK: - New types

    func testNewTypesCountIsThree() {
        XCTAssertEqual(D.newTypesCount, 3)
    }

    func testAllThreeNewTypesPresent() {
        for typeName in [
            "BASSSMScanMetalShaderSource",
            "BASSSMScanShape",
            "BASSSMScanShapeError"
        ] {
            XCTAssertTrue(
                D.newTypes.contains(typeName))
        }
    }

    // MARK: - Test coverage

    func testAntiDriftTestFileCountIsTwo() {
        XCTAssertEqual(D.antiDriftTestFiles.count, 2)
    }

    func testTotalAntiDriftTestCountIs46() {
        // 22 (M2086) + 24 (M2087) = 46
        XCTAssertEqual(D.chapter677AntiDriftTestCount, 46)
    }

    // MARK: - MSL kernel facts

    func testKernelName() {
        XCTAssertEqual(
            D.kernelName, "ssm_scan_float32")
    }

    func testKernelDataType() {
        XCTAssertEqual(D.kernelDataType, "float32")
    }

    func testKernelBufferBindingCountIsSeven() {
        XCTAssertEqual(D.kernelBufferBindingCount, 7)
    }

    func testKernelAlgorithm() {
        XCTAssertEqual(
            D.kernelAlgorithm,
            "selective-scan-scalar-state-per-channel")
    }

    func testKernelIsNotParallelPrefixScan() {
        XCTAssertFalse(D.kernelIsParallelPrefixScan)
    }

    func testKernelDiscretization() {
        XCTAssertEqual(
            D.kernelDiscretization, "zero-order-hold")
    }

    func testKernelInitialStateIsZero() {
        XCTAssertEqual(
            D.kernelInitialStateValue, "h_0 = 0")
    }

    // MARK: - Layout contracts

    func testShapeStructByteSizeIsTwelve() {
        XCTAssertEqual(D.shapeStructByteSize, 12)
    }

    func testShapeStructFieldCountIsThree() {
        XCTAssertEqual(D.shapeStructFieldCount, 3)
    }

    func testShapeStructFieldTypeIsUInt32() {
        XCTAssertEqual(D.shapeStructFieldType, "UInt32")
    }

    // MARK: - Achievement flags

    func testMSLCompilesViaXcodeMetalIfAvailable() {
        XCTAssertTrue(D.mslCompilesViaXcodeMetalIfAvailable)
    }

    func testSwiftMirrorEnablesSpmRuntimeCompile() {
        XCTAssertTrue(D.swiftMirrorEnablesSpmRuntimeCompile)
    }

    func testShapeStructByteEqualToMSL() {
        XCTAssertTrue(D.shapeStructByteEqualToMSL)
    }

    func testAntiDriftFullyCovers46Aspects() {
        XCTAssertTrue(D.antiDriftFullyCovers46Aspects)
    }

    // MARK: - Next chapter pointer

    func testNextChapterIs678() {
        XCTAssertEqual(
            D.nextChapter, "chapter 六百七十八")
    }

    func testNextChapterMNumberStartIs2089() {
        XCTAssertEqual(
            D.nextChapterMNumberStart, 2089)
    }

    // MARK: - Phase M progress

    func testPhaseMChaptersCompleteIsOne() {
        XCTAssertEqual(D.phaseMChaptersComplete, 1)
    }

    func testPhaseMChaptersTotalIsSix() {
        XCTAssertEqual(D.phaseMChaptersTotal, 6)
    }

    func testPhaseMCommitsCompleteIsFour() {
        XCTAssertEqual(D.phaseMCommitsComplete, 4)
    }

    func testPhaseMCommitsTotalIsTwentyFour() {
        XCTAssertEqual(D.phaseMCommitsTotal, 24)
    }

    // MARK: - Cross-doctrine refs

    func testPriorPhaseLCompletionRef() {
        XCTAssertEqual(
            D.priorPhaseLCompletionRef,
            "BASPhaseLCumulativeCompletionDoctrine")
    }

    func testPriorHexa9CatalogRef() {
        XCTAssertEqual(
            D.priorHexa9CatalogRef,
            "BASPhaseJKLCompletionHexaCatalogDoctrine")
    }
}
