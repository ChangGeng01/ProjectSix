import XCTest
import BASOrgan
@testable import BASMLXAdapter

/// E2E: the spec-SAMPLING lane at the REAL production preset (.core, temp 0.7) through the full pipeline.
/// BAS_MTP_SAMPLE=1 (heavy). Distribution-losslessness is unit-proven; here: engagement, speed, telemetry.
final class BASMTPSamplingE2ETests: XCTestCase {
    func testSamplingLaneAtCorePreset() async throws {
        guard ProcessInfo.processInfo.environment["BAS_MTP_SAMPLE"] == "1" else { throw XCTSkip("BAS_MTP_SAMPLE=1") }
        let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)   // default-ON resolution
        try await organ.loadModel()
        let req = BASOrganRequest(requestID: "samp", role: .core, preset: .core,
                                  instruction: "Describe a lighthouse in two sentences.", context: [])
        // streaming plain baseline (production sampling)
        var t0 = Date()
        var plainBody = ""
        for try await c in organ.streamDraft(req) { plainBody = c.cumulativeBody }
        let plainSec = Date().timeIntervalSince(t0)
        // spec-sampling via the planner-routed draft() (temp 0.7 → .mtpSpecSampling)
        t0 = Date()
        let d = try await organ.draft(req)
        let specSec = Date().timeIntervalSince(t0)
        print(String(format: "=== SAMPLE-E2E plain %.1fs (%d ch) | spec-sampling %.1fs (%d ch) = %.2fx ===",
                     plainSec, plainBody.count, specSec, d.body.count, plainSec / specSec))
        print("=== SAMPLE-E2E spec text: \(String(d.body.prefix(110))) ===")
        let stat = await organ.mtpSamplingProfilerStat()
        print("=== SAMPLE-E2E telemetry: \(String(describing: stat)) ===")
        XCTAssertFalse(d.body.isEmpty)
        XCTAssertNotNil(stat, "sampling-lane telemetry must fold")
        XCTAssertGreaterThan(stat?.emaAccepted ?? 0, 0.2, "distributional acceptance collapsed — wiring suspect")
    }
}
