// MARK: - BASInspectionBundleFrameAdapterTests
// chapter 五百九 / M1414 — Tier C inspection adapter tests

import XCTest
@testable import BASObservability
@testable import BASRuntimeCore

final class BASInspectionBundleFrameAdapterTests:
    XCTestCase
{

    private func sampleTrace() -> BASExecutionTrace {
        return BASExecutionTrace(
            inputSummary: "test input",
            selectedRoute: BASModelRoute.local(
                "test-model"),
            memoriesRecalled: ["mem-1", "mem-2"],
            toolsCalled: ["tool-a"],
            latency: BASTraceLatencyBreakdown(
                routeSelectionMs: 1,
                retrievalMs: 5,
                generationMs: 10,
                toolMs: 3),
            auditEvents: [],
            outputSummary: "test output")
    }

    private func sampleFingerprint()
        -> BASReplayFingerprint
    {
        return BASReplayFingerprint(value: "fp-1")
    }

    private func sampleBundle(
        generatedAt: Date = Date(
            timeIntervalSince1970: 1_700_000_000),
        anomalyCount: Int = 0,
        replayAvailable: Bool = true
    ) -> BASInspectionBundle {
        return BASInspectionBundle(
            generatedAt: generatedAt,
            trace: sampleTrace(),
            replayFingerprint: sampleFingerprint(),
            replayDisposition: BASReplayDisposition(
                isAvailable: replayAvailable),
            releaseDecision: BASReleaseDecision(
                kind: .allow,
                reason: "test allow"),
            anomalySignals:
                (0..<anomalyCount).map { i in
                BASAnomalySignal(
                    kind: "ANOM-\(i)",
                    severity: "info",
                    message: "test")
            },
            calibration: nil)
    }

    // MARK: - 1) Frame preserves generated-at timestamp

    func testFramePreservesGeneratedAt() {
        let bundle = sampleBundle()
        let frame = BASInspectionBundleFrameAdapter
            .frame(from: bundle)
        XCTAssertEqual(frame.inspectedAtMs,
                       1_700_000_000_000)
    }

    // MARK: - 2) inspectionID composes stable identifier

    func testInspectionIDComposesStableIdentifier() {
        let bundle = sampleBundle()
        let frame = BASInspectionBundleFrameAdapter
            .frame(from: bundle)
        XCTAssertEqual(frame.inspectionID,
                       "inspection@1700000000000")
    }

    // MARK: - 3) Default inspector + policy

    func testDefaultInspectorAndPolicy() {
        let bundle = sampleBundle()
        let frame = BASInspectionBundleFrameAdapter
            .frame(from: bundle)
        XCTAssertEqual(frame.inspectorRefs,
                       ["substrate"])
        XCTAssertEqual(frame.inspectionPolicy,
                       "observability-core")
    }

    // MARK: - 4) inspectedRefs combine tools + memories

    func testInspectedRefsCombineToolsAndMemories() {
        let bundle = sampleBundle()
        let frame = BASInspectionBundleFrameAdapter
            .frame(from: bundle)
        XCTAssertEqual(frame.inspectedRefs,
                       ["tool-a", "mem-1", "mem-2"],
            "inspectedRefs = trace.toolsCalled +" +
            " trace.memoriesRecalled")
    }

    // MARK: - 5) Body carries summaries

    func testBodyCarriesSummaries() {
        let bundle = sampleBundle()
        let frame = BASInspectionBundleFrameAdapter
            .frame(from: bundle)
        XCTAssertEqual(frame.body.inputSummary,
                       "test input")
        XCTAssertEqual(frame.body.outputSummary,
                       "test output")
        XCTAssertEqual(frame.body.anomalyCount, 0)
        XCTAssertNil(frame.body.calibrationStatus)
        XCTAssertTrue(frame.body.replayAvailable)
    }

    // MARK: - 6) Anomaly count flows through diagnostics

    func testAnomalyCountFlowsThroughDiagnostics() {
        let bundle = sampleBundle(anomalyCount: 3)
        let frame = BASInspectionBundleFrameAdapter
            .frame(from: bundle)
        XCTAssertEqual(frame.body.anomalyCount, 3)
        XCTAssertEqual(frame.diagnostics.count, 3)
        for diag in frame.diagnostics {
            XCTAssertTrue(diag.hasPrefix("anomaly:"))
        }
        // Passed flag derives from diagnostics empty
        XCTAssertFalse(frame.passed,
            "3 anomalies in diagnostics → not passed")
    }

    // MARK: - 7) Zero anomalies → passed

    func testZeroAnomaliesProducesPassedFrame() {
        let bundle = sampleBundle(anomalyCount: 0)
        let frame = BASInspectionBundleFrameAdapter
            .frame(from: bundle)
        XCTAssertTrue(frame.passed)
    }

    // MARK: - 8) Replay disposition reflected in body

    func testReplayDispositionReflectedInBody() {
        let available = sampleBundle(
            replayAvailable: true)
        let unavailable = sampleBundle(
            replayAvailable: false)
        XCTAssertTrue(
            BASInspectionBundleFrameAdapter
                .frame(from: available)
                .body.replayAvailable)
        XCTAssertFalse(
            BASInspectionBundleFrameAdapter
                .frame(from: unavailable)
                .body.replayAvailable)
    }

    // MARK: - 9) Determinism

    func testDeterminism() {
        let bundle = sampleBundle()
        let f1 = BASInspectionBundleFrameAdapter
            .frame(from: bundle)
        let f2 = BASInspectionBundleFrameAdapter
            .frame(from: bundle)
        XCTAssertEqual(f1, f2)
    }

    // MARK: - 10) Adapter is read-only (original bundle
    //             untouched)

    func testAdapterIsReadOnly() {
        let bundle = sampleBundle()
        let originalGeneratedAt = bundle.generatedAt
        _ = BASInspectionBundleFrameAdapter
            .frame(from: bundle)
        XCTAssertEqual(bundle.generatedAt,
                       originalGeneratedAt,
            "adapter MUST NOT mutate original bundle")
    }

    // MARK: - 11) Codable round-trip

    func testCodableRoundTrip() throws {
        let bundle = sampleBundle(anomalyCount: 2)
        let original = BASInspectionBundleFrameAdapter
            .frame(from: bundle)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASInspectionFrame<
                BASInspectionBundleFrameBody>.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }
}
