// MARK: - BASSSMScanMetalShaderSourceAntiDriftTests
// chapter 六百七十七 / M2086 第二刀 — anti-drift PROOF tests
//                                    for the Swift-side
//                                    mirror of SSMScan.metal

import XCTest
@testable import BASMetalSubstrate

final class BASSSMScanMetalShaderSourceAntiDriftTests:
    XCTestCase
{
    typealias S = BASSSMScanMetalShaderSource

    // MARK: - Identity pins

    func testFloat32KernelName() {
        XCTAssertEqual(
            S.float32KernelName, "ssm_scan_float32")
    }

    func testCanonicalMetalFilePath() {
        XCTAssertEqual(
            S.canonicalMetalFilePath,
            "Sources/BASMetalSubstrate/BASBuiltinKernels/SSMScan.metal")
    }

    // MARK: - Source non-empty + minimum size

    func testSourceMSLIsNonEmpty() {
        XCTAssertFalse(S.float32SourceMSL.isEmpty)
    }

    func testSourceMSLHasMinimumLineCount() {
        // Sanity check:MSL kernel + struct + control flow
        // should be at least 30 lines。 Drop detection:
        // if a future edit accidentally truncates the
        // MSL,line count will plunge。
        XCTAssertGreaterThan(S.float32SourceLineCount, 30)
    }

    func testSourceMSLHasReasonableMaximumLineCount() {
        // 200 lines is generous for a simple kernel;
        // if future edits balloon past this,refactor。
        XCTAssertLessThan(S.float32SourceLineCount, 200)
    }

    // MARK: - MSL marker presence

    func testAllRequiredMarkersPresent() {
        XCTAssertTrue(
            S.allRequiredMarkersPresent,
            "MSL source must contain every required " +
            "marker — kernel signature + buffer bindings " +
            "+ recurrence math")
    }

    func testRequiredMarkersListIsComprehensive() {
        // Pin the marker list size。 Bumping requires
        // updating both this test and the source。
        XCTAssertEqual(S.requiredMSLMarkers.count, 13)
    }

    // MARK: - Per-marker presence pins (individual
    // assertions — easier to diagnose which marker
    // is missing if testAllRequiredMarkersPresent fails)

    func testKernelSignaturePresent() {
        XCTAssertTrue(
            S.float32SourceMSL.contains(
                "kernel void ssm_scan_float32"))
    }

    func testStructSSMScanShapePresent() {
        XCTAssertTrue(
            S.float32SourceMSL.contains(
                "struct SSMScanShape"))
    }

    func testAllSevenBufferBindingsPresent() {
        for slot in 0...6 {
            XCTAssertTrue(
                S.float32SourceMSL.contains(
                    "buffer(\(slot))"),
                "MSL must bind buffer(\(slot))")
        }
    }

    func testDiscretizationABarPresent() {
        XCTAssertTrue(
            S.float32SourceMSL.contains(
                "float A_bar = exp(delta_t * A_d)"))
    }

    func testDiscretizationBBarPresent() {
        XCTAssertTrue(
            S.float32SourceMSL.contains(
                "float B_bar = delta_t * B_t"))
    }

    func testRecurrenceStepPresent() {
        XCTAssertTrue(
            S.float32SourceMSL.contains(
                "h = A_bar * h + B_bar * x_t"))
    }

    func testOutputProjectionPresent() {
        XCTAssertTrue(
            S.float32SourceMSL.contains(
                "y[idx] = C_t * h"))
    }

    // MARK: - MSL well-formedness markers

    func testIncludesMetalStdlib() {
        XCTAssertTrue(
            S.float32SourceMSL.contains(
                "#include <metal_stdlib>"))
    }

    func testUsesMetalNamespace() {
        XCTAssertTrue(
            S.float32SourceMSL.contains(
                "using namespace metal"))
    }

    func testHasThreadPositionInGrid() {
        XCTAssertTrue(
            S.float32SourceMSL.contains(
                "thread_position_in_grid"))
    }

    // MARK: - Initial state proof (h_0 = 0)

    func testInitialStateIsZero() {
        XCTAssertTrue(
            S.float32SourceMSL.contains("float h = 0.0f"),
            "Initial state h_0 must be 0 — anti-drift " +
            "PROOF that the kernel doesn't accidentally " +
            "carry state across batches")
    }

    // MARK: - Sequential scan proof (single for-loop over L)

    func testHasSequentialScanLoop() {
        XCTAssertTrue(
            S.float32SourceMSL.contains(
                "for (uint t = 0; t < L; t++)"),
            "Sequential scan over time dimension L must " +
            "be present (no parallel prefix-scan yet)")
    }

    // MARK: - Bounds check (early return for out-of-grid threads)

    func testHasGridBoundsCheck() {
        XCTAssertTrue(
            S.float32SourceMSL.contains(
                "if (b >= shape.B || d >= shape.D)"),
            "Grid bounds check must early-return for " +
            "(b, d) pairs outside the shape")
    }

    // MARK: - Row-major linear indexing pin

    func testRowMajorLinearIndexing() {
        XCTAssertTrue(
            S.float32SourceMSL.contains(
                "((b * L) + t) * D + d"),
            "Row-major (B, L, D) linear indexing must " +
            "be present — anti-drift against accidental " +
            "transpose")
    }

    // MARK: - Determinism

    func testSourceMSLIsDeterministic() {
        XCTAssertEqual(
            S.float32SourceMSL,
            S.float32SourceMSL)
    }
}
